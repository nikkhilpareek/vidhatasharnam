import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class VisitAdminService {
  final _fs = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  Stream<List<String>> topSchemes({int limit = 12}) {
    return _fs
        .collection('schemes')
        .orderBy('uses', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map((d) => (d.data()['name'] ?? d.id).toString()).toList());
  }

  Future<void> approveVisit({
    required String visitId,
    required String userId,
    required String schemeName,
    required int gajSold,
  }) async {
    final adminUid = _auth.currentUser?.uid;
    if (adminUid == null) throw StateError('Not authenticated');

    final visitRef = _fs.collection('visits').doc(visitId);
    final userRef = _fs.collection('users').doc(userId);
    final schemeId = _slug(schemeName);
    final schemeRef = _fs.collection('schemes').doc(schemeId);

    await _fs.runTransaction((tx) async {
      final vSnap = await tx.get(visitRef);
      if (!vSnap.exists) throw StateError('Visit not found');
      final v = vSnap.data() as Map<String, dynamic>;
      final status = (v['status'] ?? 'Pending').toString();

      if (status == 'Approved') throw StateError('Already approved');
      if (status == 'Rejected') throw StateError('Already rejected');

      // Update visit
      tx.update(visitRef, {
        'status': 'Approved',
        'scheme': schemeName.trim(),
        'gajSold': gajSold,
        'approvedBy': adminUid,
        'approvedAt': FieldValue.serverTimestamp(),
      });

      // Increment user's total
      final uSnap = await tx.get(userRef);
      final current = (uSnap.data()?['totalGajSold'] ?? 0) as num;
      tx.set(userRef, {'totalGajSold': (current + gajSold)}, SetOptions(merge: true));

      // Upsert scheme
      tx.set(
        schemeRef,
        {
          'name': schemeName.trim(),
          'uses': FieldValue.increment(1),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });
  }

  Future<void> rejectVisit({
    required String visitId,
    String? reason,
  }) async {
    final adminUid = _auth.currentUser?.uid;
    if (adminUid == null) throw StateError('Not authenticated');

    final visitRef = _fs.collection('visits').doc(visitId);
    await _fs.runTransaction((tx) async {
      final vSnap = await tx.get(visitRef);
      if (!vSnap.exists) throw StateError('Visit not found');
      final v = vSnap.data() as Map<String, dynamic>;
      final status = (v['status'] ?? 'Pending').toString();
      if (status == 'Approved') throw StateError('Already approved');
      if (status == 'Rejected') throw StateError('Already rejected');

      tx.update(visitRef, {
        'status': 'Rejected',
        'rejectionReason': (reason ?? '').trim(),
        'rejectedBy': adminUid,
        'rejectedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  String _slug(String s) => s.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
}