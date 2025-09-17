import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MyVisitsScreen extends StatefulWidget {
  const MyVisitsScreen({super.key});

  @override
  State<MyVisitsScreen> createState() => _MyVisitsScreenState();
}

class _MyVisitsScreenState extends State<MyVisitsScreen> {
  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text("My Visits"),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Container(
        color: Colors.grey.shade50,
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('visits')
              .where('userId', isEqualTo: userId)
              .orderBy('createdAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return const Center(child: Text("Error loading visits"));
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.analytics_outlined, size: 80, color: Colors.grey),
                    SizedBox(height: 20),
                    Text(
                      "No visits submitted yet",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey),
                    ),
                    SizedBox(height: 8),
                    Text(
                      "Create your first visit to see it here",
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              );
            }

            final visits = snapshot.data!.docs;

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: visits.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final doc = visits[index];
                final visit = doc.data() as Map<String, dynamic>;
                return _UserVisitCard(
                  visitId: doc.id,
                  visit: visit,
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _UserVisitCard extends StatelessWidget {
  final String visitId;
  final Map<String, dynamic> visit;

  const _UserVisitCard({
    required this.visitId,
    required this.visit,
  });

  @override
  Widget build(BuildContext context) {
    final status = visit['status'] ?? 'Pending';
    final associate = visit['associateName'] ?? 'N/A';
    final location = visit['location'] ?? 'N/A';
    final scheme = visit['scheme'];
    final gajSold = visit['gajSold']; 
    final photoUrl = visit['photoUrl']?.toString();

    String formattedDate = '';
    if (visit['createdAt'] != null && visit['createdAt'] is Timestamp) {
      try {
        final ts = visit['createdAt'] as Timestamp;
        final dt = ts.toDate();
        formattedDate = '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
      } catch (_) {}
    }

    Color statusColor;
    String displayStatus = status;
    switch (status) {
      case 'Approved':
        statusColor = Colors.green;
        displayStatus = 'Approved';
        break;
      case 'Rejected':
        statusColor = Colors.red;
        displayStatus = 'Rejected';
        break;
      default:
        statusColor = Colors.orange;
        displayStatus = 'Pending';
    }

    // Check for missing information
    final hasScheme = scheme != null && scheme.toString().isNotEmpty;
    final hasGajSold = gajSold != null && gajSold.toString().isNotEmpty;
    final hasPhoto = photoUrl != null && photoUrl.isNotEmpty;
    
    final missingInfo = <String>[];
    if (!hasScheme && status == 'Approved') missingInfo.add('scheme');
    if (!hasGajSold && status == 'Approved') missingInfo.add('gaj');
    if (!hasPhoto) missingInfo.add('photo');

    return GestureDetector(
      onTap: () => _showDetailedView(context),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
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
                color: statusColor.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                status == 'Approved' ? Icons.check_circle : 
                status == 'Rejected' ? Icons.cancel : Icons.access_time,
                color: statusColor,
                size: 20,
              ),
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
                          color: statusColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          displayStatus,
                          style: TextStyle(
                            color: statusColor,
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
                          if (hasPhoto) ...[
                            Icon(Icons.photo_camera, size: 12, color: Colors.green.shade600),
                            const SizedBox(width: 4),
                          ],
                          if (hasScheme) ...[
                            Icon(Icons.lightbulb_outline, size: 12, color: Colors.blue.shade600),
                            const SizedBox(width: 4),
                          ],
                          if (hasGajSold) ...[
                            Icon(Icons.landscape_outlined, size: 12, color: Colors.purple.shade600),
                            const SizedBox(width: 4),
                          ],
                          // Warning indicators for missing info
                          if (missingInfo.isNotEmpty) ...[
                            Icon(Icons.warning_amber, size: 12, color: Colors.orange.shade600),
                            const SizedBox(width: 4),
                          ],
                        ],
                      ),
                      if (formattedDate.isNotEmpty)
                        Text(
                          formattedDate,
                          style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            // Arrow
            Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 20),
          ],
        ),
      ),
    );
  }

  void _showDetailedView(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _UserDetailedVisitView(
        visitId: visitId,
        visit: visit,
      ),
    );
  }
}

class _UserDetailedVisitView extends StatefulWidget {
  final String visitId;
  final Map<String, dynamic> visit;

  const _UserDetailedVisitView({
    required this.visitId,
    required this.visit,
  });

  @override
  State<_UserDetailedVisitView> createState() => _UserDetailedVisitViewState();
}

class _UserDetailedVisitViewState extends State<_UserDetailedVisitView> {
  late Map<String, dynamic> currentVisit;

  @override
  void initState() {
    super.initState();
    currentVisit = Map<String, dynamic>.from(widget.visit);
    _listenToVisitUpdates();
  }

  void _listenToVisitUpdates() {
    // Listen to Firestore document changes
    FirebaseFirestore.instance
        .collection('visits')
        .doc(widget.visitId)
        .snapshots()
        .listen((doc) {
      if (doc.exists && mounted) {
        setState(() {
          final newData = doc.data() as Map<String, dynamic>;
          currentVisit.addAll(newData);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final status = currentVisit['status'] ?? 'Pending';
    final associate = currentVisit['associateName'] ?? 'N/A';
    final location = currentVisit['location'] ?? 'N/A';
    final scheme = currentVisit['scheme'];
    final gajSold = currentVisit['gajSold'];
    final photoUrl = currentVisit['photoUrl']?.toString();

    String formattedDate = '';
    if (currentVisit['createdAt'] != null && currentVisit['createdAt'] is Timestamp) {
      try {
        final ts = currentVisit['createdAt'] as Timestamp;
        final dt = ts.toDate();
        formattedDate = '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      } catch (_) {}
    }

    Color statusColor;
    String displayStatus = status;
    IconData statusIcon;
    switch (status) {
      case 'Approved':
        statusColor = Colors.green;
        displayStatus = 'Approved';
        statusIcon = Icons.check_circle;
        break;
      case 'Rejected':
        statusColor = Colors.red;
        displayStatus = 'Rejected';
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = Colors.orange;
        displayStatus = 'Pending';
        statusIcon = Icons.access_time;
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle and close button
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close, color: Colors.grey.shade600),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              // Content
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(statusIcon, color: statusColor, size: 24),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Visit Details',
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: statusColor.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(statusIcon, size: 14, color: statusColor),
                                      const SizedBox(width: 4),
                                      Text(
                                        displayStatus,
                                        style: TextStyle(
                                          color: statusColor,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      
                      // Details
                      _detailRow(Icons.person_outline, 'Associate', associate),
                      _detailRow(Icons.place_outlined, 'Location', location),
                      if (formattedDate.isNotEmpty) 
                        _detailRow(Icons.access_time, 'Date & Time', formattedDate),
                      if (scheme != null && scheme.toString().isNotEmpty)
                        _detailRow(Icons.lightbulb_outline, 'Scheme', scheme.toString()),
                      if (gajSold != null && gajSold.toString().isNotEmpty)
                        _detailRow(Icons.landscape_outlined, 'Gaj Sold', '${gajSold} Gaj'),

                      // Status message
                      if (status == 'Pending') ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.orange.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.pending_actions, color: Colors.orange.shade600, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Your visit is pending approval. You will be notified once it\'s reviewed.',
                                  style: TextStyle(
                                    color: Colors.orange.shade700,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else if (status == 'Rejected') ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.cancel, color: Colors.red.shade600, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'This visit was not approved. Please contact your administrator for more details.',
                                  style: TextStyle(
                                    color: Colors.red.shade700,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else if (status == 'Approved') ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.check_circle, color: Colors.green.shade600, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Congratulations! Your visit has been approved.',
                                  style: TextStyle(
                                    color: Colors.green.shade700,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Photo section
                      if (photoUrl != null && photoUrl.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        const Text(
                          'Visit Photo',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: () => _showFullScreenImage(context, photoUrl),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              photoUrl,
                              height: 250,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Container(
                                  height: 250,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  height: 250,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.red.shade200),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.broken_image, 
                                           color: Colors.red.shade400, 
                                           size: 48),
                                      const SizedBox(height: 12),
                                      Text(
                                        'Failed to load image',
                                        style: TextStyle(
                                          color: Colors.red.shade600,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap to view full size',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ] else ...[
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.photo_camera_outlined, color: Colors.grey.shade600, size: 20),
                              const SizedBox(width: 12),
                              Text(
                                'No photo attached to this visit',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: Colors.grey.shade700),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showFullScreenImage(BuildContext context, String imageUrl) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            elevation: 0,
            title: const Text('Visit Photo'),
          ),
          body: Center(
            child: InteractiveViewer(
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.broken_image, 
                             color: Colors.white, 
                             size: 60),
                        SizedBox(height: 16),
                        Text(
                          'Failed to load image',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
