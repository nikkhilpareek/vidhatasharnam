import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TotalVisitsScreen extends StatefulWidget {
  const TotalVisitsScreen({super.key});

  @override
  State<TotalVisitsScreen> createState() => _TotalVisitsScreenState();
}

class _TotalVisitsScreenState extends State<TotalVisitsScreen> {
  String selectedFilter = 'All';
  final List<String> filterOptions = ['All', 'Accepted', 'Rejected', 'Pending'];

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(body: Center(child: Text('Not authenticated')));
    }

    final query = FirebaseFirestore.instance
        .collection('visits')
        .where('userId', isEqualTo: uid); // no orderBy -> no composite index

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Total Visits',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 20, color: Colors.black),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: query.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Error: ${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.red.shade600),
                ),
              ),
            );
          }

          final docs = snapshot.data?.docs ?? [];

          // Normalize, map, and sort locally by createdAt ASC
          final visits = docs.map(_mapVisit).toList()
            ..sort((a, b) {
              final ta = a['createdAt'] as DateTime?;
              final tb = b['createdAt'] as DateTime?;
              if (ta == null || tb == null) return 0;
              return ta.compareTo(tb);
            });

          // Counts (normalize 'Approved' -> 'Accepted' for display)
          final acceptedCount = visits.where((v) => _displayStatus(v['status']) == 'Accepted').length;
          final rejectedCount = visits.where((v) => _displayStatus(v['status']) == 'Rejected').length;
          final pendingCount = visits.where((v) => _displayStatus(v['status']) == 'Pending').length;

          // Filter by selected chip (client-side)
          final filtered = selectedFilter == 'All'
              ? visits
              : visits.where((v) => _displayStatus(v['status']) == selectedFilter).toList();

          return Container(
            color: Color(0xFFFFF4E8),
            child: Column(
              children: [
                // Header stats
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Visit Summary',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.grey.shade700)),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatCard('Total', visits.length.toString(), Icons.analytics, Colors.grey.shade700),
                          _buildStatCard('Accepted', acceptedCount.toString(), Icons.check_circle, Colors.green.shade600),
                          _buildStatCard('Rejected', rejectedCount.toString(), Icons.cancel, Colors.red.shade600),
                          _buildStatCard('Pending', pendingCount.toString(), Icons.access_time, Colors.orange.shade600),
                        ],
                      ),
                    ],
                  ),
                ),

                // Filters
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Text('Filter by: ',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: filterOptions.map((filter) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: FilterChip(
                                  label: Text(filter,style: TextStyle(color: Colors.black),),
                                  selected: selectedFilter == filter,
                                  onSelected: (_) => setState(() => selectedFilter = filter),
                                  selectedColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                                  checkmarkColor: Theme.of(context).colorScheme.primary,
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // List
                Expanded(
                  child: filtered.isEmpty
                      ? _buildEmptyState(selectedFilter)
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: filtered.length,
                          itemBuilder: (context, i) => _buildVisitCard(filtered[i]),
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Map<String, dynamic> _mapVisit(QueryDocumentSnapshot<Map<String, dynamic>> snap) {
    final data = snap.data();
    final status = (data['status'] ?? 'Pending').toString(); // likely 'Pending' | 'Approved' | 'Rejected'
    // Resolve primary datetime
    DateTime? dt;
    if (data['dateTime'] is Timestamp) {
      dt = (data['dateTime'] as Timestamp).toDate();
    } else if (data['createdAt'] is Timestamp) {
      dt = (data['createdAt'] as Timestamp).toDate();
    }

    // UI fields
    final dateStr = data['date']?.toString() ?? (dt != null ? _fmtDate(dt) : '--/--/----');
    final timeStr = data['time']?.toString() ?? (dt != null ? _fmtTime(dt) : '--:--');

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
      'id': snap.id, // Add document ID for detailed view
      'associateName': (data['associateName'] ?? 'Unknown').toString(),
      'customerName': (data['customerName'] ?? 'N/A').toString(),
      'upperlineName': (data['upperlineName'] ?? 'N/A').toString(),
      'teamleaderName': (data['teamleaderName'] ?? 'N/A').toString(),
      'reraNumber': (data['reraNumber'] ?? 'N/A').toString(),
      'schemeName': (data['schemeName'] ?? data['scheme'] ?? 'N/A').toString(), // Use schemeName, fallback to scheme
      'plotNumber': (data['plotNumber'] ?? 'N/A').toString(),
      'clientName': (data['clientName'] ?? 'N/A').toString(),
      'location': (data['location'] ?? 'N/A').toString(),
      'date': dateStr,
      'time': timeStr,
      'status': status,
      'submittedOn': submittedOn,
      'createdAt': dt, // for local sort
      'photoUrl': data['photoUrl']?.toString(), // Add photo URL
      'scheme': data['scheme'], // Add scheme for backward compatibility
      'gajSold': data['gajSold'], // Add gaj sold
      'originalData': data, // Keep original data for detailed view
    };
  }

  // Map stored status to display (treat 'Approved' as 'Accepted')
  String _displayStatus(String status) {
    if (status == 'Approved') return 'Accepted';
    return status;
  }

  Widget _buildStatCard(String label, String count, IconData icon, Color iconColor) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: iconColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, size: 24, color: iconColor),
        ),
        const SizedBox(height: 8),
        Text(count, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
      ],
    );
  }

  Widget _buildVisitCard(Map<String, dynamic> visit) {
    final displayStatus = _displayStatus(visit['status'] ?? 'Pending');
    final photoUrl = visit['photoUrl']?.toString();
    final hasPhoto = photoUrl != null && photoUrl.isNotEmpty;
    final hasScheme = visit['scheme'] != null && visit['scheme'].toString().isNotEmpty;
    final hasGajSold = visit['gajSold'] != null && visit['gajSold'].toString().isNotEmpty;

    Color statusColor;
    IconData statusIcon;
    switch (displayStatus) {
      case 'Accepted':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'Rejected':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      case 'Pending':
      default:
        statusColor = Colors.orange;
        statusIcon = Icons.access_time;
        break;
    }

    return GestureDetector(
      onTap: () => _showDetailedView(context, visit),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
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
              child: Icon(statusIcon, color: statusColor, size: 20),
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
                          visit['associateName'] ?? 'Unknown',
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
                          visit['location'] ?? 'N/A',
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
                            visit['date'] ?? '--/--/----',
                            style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                          ),
                          const SizedBox(width: 8),
                          Icon(Icons.access_time_outlined, size: 10, color: Colors.grey.shade500),
                          const SizedBox(width: 2),
                          Text(
                            visit['time'] ?? '--:--',
                            style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                          ),
                          // Add photo indicator
                          if (hasPhoto) ...[
                            const SizedBox(width: 8),
                            Icon(Icons.photo_camera, size: 10, color: Colors.green.shade600),
                          ],
                          // Add scheme indicator
                          if (hasScheme) ...[
                            const SizedBox(width: 4),
                            Icon(Icons.lightbulb_outline, size: 10, color: Colors.blue.shade600),
                          ],
                          // Add gaj indicator
                          if (hasGajSold) ...[
                            const SizedBox(width: 4),
                            Icon(Icons.landscape_outlined, size: 10, color: Colors.purple.shade600),
                          ],
                        ],
                      ),
                      Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 16),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDetailedView(BuildContext context, Map<String, dynamic> visit) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _TotalVisitsDetailedView(
        visitData: visit,
      ),
    );
  }  Widget _buildEmptyState(String filter) {
    String title;
    String subtitle;
    switch (filter) {
      case 'Accepted':
        title = 'No Accepted Visits';
        subtitle = 'No visits have been accepted yet';
        break;
      case 'Rejected':
        title = 'No Rejected Visits';
        subtitle = 'No visits have been rejected';
        break;
      case 'Pending':
        title = 'No Pending Visits';
        subtitle = 'All visits have been processed';
        break;
      default:
        title = 'No Visits Found';
        subtitle = 'No visits have been created yet';
    }
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.analytics_outlined, size: 80, color: Colors.grey.shade400),
        const SizedBox(height: 20),
        Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.grey)),
        const SizedBox(height: 8),
        Text(subtitle, style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
        const SizedBox(height: 30),
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          child: const Text('Go Back', style: TextStyle(fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }

  static String _fmtDate(DateTime dt) => '${_pad2(dt.day)}/${_pad2(dt.month)}/${dt.year}';
  static String _fmtTime(DateTime dt) => '${_pad2(dt.hour)}:${_pad2(dt.minute)}';
  static String _pad2(int v) => v.toString().padLeft(2, '0');
}

class _TotalVisitsDetailedView extends StatelessWidget {
  final Map<String, dynamic> visitData;

  const _TotalVisitsDetailedView({
    required this.visitData,
  });

  @override
  Widget build(BuildContext context) {
    final displayStatus = visitData['status'] == 'Approved' ? 'Accepted' : visitData['status'];
    final associate = visitData['associateName'] ?? 'N/A';
    final location = visitData['location'] ?? 'N/A';
    final scheme = visitData['scheme'];
    final gajSold = visitData['gajSold'];
    final photoUrl = visitData['photoUrl']?.toString();
    final date = visitData['date'] ?? '--/--/----';
    final time = visitData['time'] ?? '--:--';
    final submittedOn = visitData['submittedOn'] ?? 'Unknown';

    Color statusColor;
    IconData statusIcon;
    switch (displayStatus) {
      case 'Accepted':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'Rejected':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      case 'Pending':
      default:
        statusColor = Colors.orange;
        statusIcon = Icons.access_time;
        break;
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
                      _detailRow(Icons.person_outline, 'Associate Name', associate),
                      _detailRow(Icons.person_outline, 'Customer Name', visitData['customerName'] ?? 'N/A'),
                      _detailRow(Icons.person_outline, 'Upperline Name', visitData['upperlineName'] ?? 'N/A'),
                      _detailRow(Icons.person_outline, 'Teamleader Name', visitData['teamleaderName'] ?? 'N/A'),
                      _detailRow(Icons.numbers_outlined, 'RERA Number', visitData['reraNumber'] ?? 'N/A'),
                      _detailRow(Icons.lightbulb_outline, 'Scheme Name', visitData['schemeName'] ?? 'N/A'),
                      _detailRow(Icons.place_outlined, 'Location', location),
                      _detailRow(Icons.calendar_today_outlined, 'Date', date),
                      _detailRow(Icons.access_time_outlined, 'Time', time),
                      
                      // Scheme assignment details (if visit is approved and has these details)
                      if (visitData['originalData']['plotNumber'] != null && visitData['originalData']['plotNumber'].toString().isNotEmpty)
                        _detailRow(Icons.home_outlined, 'Plot Number', visitData['originalData']['plotNumber'].toString()),
                      if (visitData['originalData']['clientName'] != null && visitData['originalData']['clientName'].toString().isNotEmpty)
                        _detailRow(Icons.person_outline, 'Client Name', visitData['originalData']['clientName'].toString()),
                      if (gajSold != null && gajSold.toString().isNotEmpty)
                        _detailRow(Icons.landscape_outlined, 'Gaj Sold', '${gajSold} Gaj'),
                        
                      if (scheme != null && scheme.toString().isNotEmpty)
                        _detailRow(Icons.lightbulb_outline, 'Old Scheme', scheme.toString()),
                      _detailRow(Icons.upload_outlined, 'Submitted On', submittedOn),

                      // Status message
                      if (displayStatus == 'Pending') ...[
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
                      ] else if (displayStatus == 'Rejected') ...[
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
                      ] else if (displayStatus == 'Accepted') ...[
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
