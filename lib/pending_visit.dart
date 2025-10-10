import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:vidhatasharnam/app_theme.dart';

class PendingVisitsScreen extends StatefulWidget {
  const PendingVisitsScreen({super.key});

  @override
  State<PendingVisitsScreen> createState() => _PendingVisitsScreenState();
}

class _PendingVisitsScreenState extends State<PendingVisitsScreen> {
  late final String? _uid = FirebaseAuth.instance.currentUser?.uid;

  // Simplified query: only one equality filter + orderBy(createdAt ASC) -> no composite index needed.
  Query<Map<String, dynamic>> _baseQuery(String uid) {
    return FirebaseFirestore.instance
        .collection('visits')
        .where('userId', isEqualTo: uid); // removed orderBy
  }

  @override
  Widget build(BuildContext context) {
    if (_uid == null) {
      return const Scaffold(
        body: Center(child: Text('Not authenticated')),
      );
    }

    final query = _baseQuery(_uid);

    return Scaffold(
      appBar: _buildAppBar(context),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: query.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ErrorPanel(
              title: 'Error loading visits',
              message: snapshot.error.toString(),
              onRetry: () => setState(() {}),
            );
          }

          final allDocs = snapshot.data?.docs ?? [];

          // Filter pending
          final pendingDocs = allDocs.where((d) {
            final s = (d.data()['status'] ?? 'Pending').toString();
            return s == 'Pending';
          }).toList();

          // Local sort by createdAt ASC
          pendingDocs.sort((a, b) {
            final ta = a.data()['createdAt'];
            final tb = b.data()['createdAt'];
            if (ta is Timestamp && tb is Timestamp) {
              return ta.toDate().compareTo(tb.toDate());
            }
            return 0;
          });

          final visits = pendingDocs.map(_mapVisit).toList();

          return Container(
            color: Color(0xFFFFF4E8),
            child: Column(
              children: [
                _HeaderInfo(
                  count: visits.length,
                  color: Theme.of(context).colorScheme.primary,
                ),
                Expanded(
                  child: visits.isEmpty
                      ? _EmptyState(onCreate: () => Navigator.pop(context))
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: visits.length,
                          itemBuilder: (context, i) =>
                              _VisitCard(visit: visits[i]),
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Map<String, dynamic> _mapVisit(
      QueryDocumentSnapshot<Map<String, dynamic>> snap) {
    final data = snap.data();
    final associateName = (data['associateName'] ?? 'Unknown').toString();
    final customerName = (data['customerName'] ?? 'N/A').toString();
    final upperlineName = (data['upperlineName'] ?? 'N/A').toString();
    final teamleaderName = (data['teamleaderName'] ?? 'N/A').toString();
    final reraNumber = (data['reraNumber'] ?? 'N/A').toString();
    final schemeName = (data['schemeName'] ?? data['scheme'] ?? 'N/A').toString();
    final location = (data['location'] ?? 'N/A').toString();
    final status = (data['status'] ?? 'Pending').toString();

    DateTime? dt;
    if (data['dateTime'] is Timestamp) {
      dt = (data['dateTime'] as Timestamp).toDate();
    } else if (data['createdAt'] is Timestamp) {
      dt = (data['createdAt'] as Timestamp).toDate();
    }

    String dateStr;
    String timeStr;
    if (data['date'] != null && data['time'] != null) {
      dateStr = data['date'].toString();
      timeStr = data['time'].toString();
    } else if (dt != null) {
      dateStr = _fmtDate(dt);
      timeStr = _fmtTime(dt);
    } else {
      dateStr = '--/--/----';
      timeStr = '--:--';
    }

    String submittedOn;
    if (data['submittedOn'] != null) {
      submittedOn = data['submittedOn'].toString();
    } else if (data['createdAt'] is Timestamp) {
      final cdt = (data['createdAt'] as Timestamp).toDate();
      submittedOn = '${_fmtDate(cdt)} ${_pad2(cdt.hour)}:${_pad2(cdt.minute)}';
    } else {
      submittedOn = 'Unknown';
    }

    return {
      'associateName': associateName,
      'customerName': customerName,
      'upperlineName': upperlineName,
      'teamleaderName': teamleaderName,
      'reraNumber': reraNumber,
      'schemeName': schemeName,
      'location': location,
      'date': dateStr,
      'time': timeStr,
      'status': status,
      'submittedOn': submittedOn,
      'originalData': data, // Keep original data for detailed view
    };
  }

  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      title: const Text(
        'Pending Visits',
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 20,
          color: Colors.black,
        ),
      ),
    );
  }

  static String _fmtDate(DateTime dt) =>
      '${_pad2(dt.day)}/${_pad2(dt.month)}/${dt.year}';
  static String _fmtTime(DateTime dt) =>
      '${_pad2(dt.hour)}:${_pad2(dt.minute)}';
  static String _pad2(int v) => v.toString().padLeft(2, '0');
}

/* ---------- UI SUB-WIDGETS (unchanged except error panel added) ---------- */

class _HeaderInfo extends StatelessWidget {
  final int count;
  final Color color;

  const _HeaderInfo({required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Visits Awaiting Approval',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.pending_actions,
                    color: Colors.black, size: 18),
                const SizedBox(width: 8),
                Text(
                  '$count visits pending',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _VisitCard extends StatelessWidget {
  final Map<String, dynamic> visit;

  const _VisitCard({required this.visit});

  @override
  Widget build(BuildContext context) {
    final associate = visit['associateName'] ?? 'Unknown';
    final location = visit['location'] ?? 'N/A';
    final date = visit['date'] ?? '--/--/----';
    final time = visit['time'] ?? '--:--';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Color(0xFFFFF4E8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          // Status indicator circle
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.access_time, color: Colors.orange, size: 20),
          ),
          const SizedBox(width: 12),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        associate,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Pending',
                        style: TextStyle(
                          color: Colors.orange,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.place_outlined, size: 12, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        location,
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.calendar_today_outlined, size: 10, color: Colors.grey.shade500),
                        const SizedBox(width: 2),
                        Text(
                          date,
                          style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.access_time_outlined, size: 10, color: Colors.grey.shade500),
                        const SizedBox(width: 2),
                        Text(
                          time,
                          style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                    Text(
                      'Submitted: ${visit['submittedOn'] ?? 'Unknown'}',
                      style: TextStyle(fontSize: 9, color: Colors.grey.shade400),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}



class _EmptyState extends StatelessWidget {
  final VoidCallback onCreate;
  const _EmptyState({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.pending_actions_outlined,
              size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 20),
          Text(
            'No Pending Visits',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'All your visits have been processed',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: onCreate,
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Color(0xFFFFF4E8),
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text(
              'Create New Visit',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback onRetry;

  const _ErrorPanel({
    required this.title,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline,
              size: 60, color: Colors.red.shade400),
          const SizedBox(height: 16),
          Text(title,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.red.shade700)),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
          ),

          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: onRetry,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
