import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class VisitsTab extends StatefulWidget {
  final String? initialFilter;
  const VisitsTab({super.key, this.initialFilter});

  @override
  State<VisitsTab> createState() => _VisitsTabState();
}

class _VisitsTabState extends State<VisitsTab> {
  late String _visitStatusFilter;
  String _visitSearchQuery = '';
  Map<String, int> _statusChipCounts = {'Pending': 0, 'Approved': 0, 'Rejected': 0};

  @override
  void initState() {
    super.initState();
    _visitStatusFilter = widget.initialFilter ?? 'All';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey.shade50,
      child: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Manage Visits', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey.shade800)),
                const SizedBox(height: 12),
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search by username, associate, customer, RERA, scheme... ',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 1.2),
                    ),
                  ),
                  onChanged: (v) => setState(() => _visitSearchQuery = v.trim().toLowerCase()),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildStatusChip('All'),
                      _buildStatusChip('Pending', color: Colors.orange),
                      _buildStatusChip('Approved', color: Colors.green),
                      _buildStatusChip('Rejected', color: Colors.red),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 0),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('users').snapshots(),
              builder: (context, usersSnap) {
                if (usersSnap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final Map<String, String> userNameMap = {};
                if (usersSnap.hasData) {
                  for (final d in usersSnap.data!.docs) {
                    final data = d.data() as Map<String, dynamic>;
                    final raw = (data['username'] ?? data['email'] ?? '').toString();
                    userNameMap[d.id] = raw.isNotEmpty ? raw : 'Unknown';
                  }
                }

                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('visits')
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, visitsSnap) {
                    if (visitsSnap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!visitsSnap.hasData || visitsSnap.data!.docs.isEmpty) {
                      return const Center(child: Text('No visits submitted yet.'));
                    }

                    final allDocs = visitsSnap.data!.docs;
                    final countPending = allDocs.where((d) => (d['status'] ?? '') == 'Pending').length;
                    final countApproved = allDocs.where((d) => (d['status'] ?? '') == 'Approved').length;
                    final countRejected = allDocs.where((d) => (d['status'] ?? '') == 'Rejected').length;

                    _statusChipCounts = {
                      'Pending': countPending,
                      'Approved': countApproved,
                      'Rejected': countRejected,
                    };

                    Iterable<QueryDocumentSnapshot> filtered = allDocs;
                    if (_visitStatusFilter != 'All') {
                      filtered = filtered.where((d) => (d['status'] ?? '') == _visitStatusFilter);
                    }

                    if (_visitSearchQuery.isNotEmpty) {
                      filtered = filtered.where((d) {
                        final data = d.data() as Map<String, dynamic>;
                        final userId = data['userId'] ?? '';
                        final username = (userNameMap[userId] ?? '').toLowerCase();
                        final associate = (data['associateName'] ?? '').toString().toLowerCase();
                        final customer = (data['customerName'] ?? '').toString().toLowerCase();
                        final upperline = (data['upperlineName'] ?? '').toString().toLowerCase();
                        final teamleader = (data['teamleaderName'] ?? '').toString().toLowerCase();
                        final rera = (data['reraNumber'] ?? '').toString().toLowerCase();
                        final schemeName = (data['schemeName'] ?? '').toString().toLowerCase();
                        final location = (data['location'] ?? '').toString().toLowerCase();
                        return username.contains(_visitSearchQuery) ||
                            associate.contains(_visitSearchQuery) ||
                            customer.contains(_visitSearchQuery) ||
                            upperline.contains(_visitSearchQuery) ||
                            teamleader.contains(_visitSearchQuery) ||
                            rera.contains(_visitSearchQuery) ||
                            schemeName.contains(_visitSearchQuery) ||
                            location.contains(_visitSearchQuery);
                      });
                    }

                    final filteredList = filtered.toList();
                    if (filteredList.isEmpty) {
                      return Center(
                        child: Text('No ${_visitStatusFilter == 'All' ? '' : _visitStatusFilter.toLowerCase()} visits match your search.'),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: filteredList.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, i) {
                        final doc = filteredList[i];
                        final data = doc.data() as Map<String, dynamic>;
                        return _CompactVisitCard(
                          visitId: doc.id,
                          visit: data,
                          userNameMap: userNameMap,
                          onUpdateStatus: _updateVisitStatus,
                          onAssignScheme: _showAssignSchemeDialog,
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String label, {Color? color}) {
    final isSelected = _visitStatusFilter == label;
    String display = label;
    if (label != 'All' && _statusChipCounts.containsKey(label)) {
      display = '$label (${_statusChipCounts[label]})';
    }
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(display),
        selected: isSelected,
        selectedColor: (color ?? Theme.of(context).colorScheme.primary).withOpacity(0.15),
        labelStyle: TextStyle(
          color: isSelected ? (color ?? Theme.of(context).colorScheme.primary) : Colors.grey.shade700,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
        ),
        side: BorderSide(color: isSelected ? (color ?? Theme.of(context).colorScheme.primary) : Colors.grey.shade300),
        onSelected: (_) => setState(() => _visitStatusFilter = label),
      ),
    );
  }

  Future<void> _updateVisitStatus(String visitId, String newStatus) async {
    await FirebaseFirestore.instance.collection('visits').doc(visitId).update({'status': newStatus});
  }

  void _showAssignSchemeDialog(String visitId, String? existingScheme) {
    final schemeNameController = TextEditingController();
    final plotNumberController = TextEditingController();
    final clientNameController = TextEditingController();
    final gajSoldController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        final future = FirebaseFirestore.instance.collection('visits').doc(visitId).get();

        return FutureBuilder<DocumentSnapshot>(
          future: future,
          builder: (context, snap) {
            if (snap.hasData) {
              final data = snap.data!.data() as Map<String, dynamic>? ?? {};
              
              // Pre-populate fields with existing data or defaults
              if (schemeNameController.text.isEmpty) {
                schemeNameController.text = data['schemeName'] ?? data['scheme'] ?? existingScheme ?? '';
              }
              if (plotNumberController.text.isEmpty) {
                plotNumberController.text = (data['plotNumber'] ?? '').toString();
              }
              if (clientNameController.text.isEmpty) {
                clientNameController.text = (data['clientName'] ?? '').toString();
              }
              if (gajSoldController.text.isEmpty) {
                gajSoldController.text = (data['gajSold'] ?? '').toString();
              }
            }

            return AlertDialog(
              title: const Text("Assign Scheme Details"),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: schemeNameController,
                        decoration: const InputDecoration(
                          labelText: "Scheme Name",
                          border: OutlineInputBorder(),
                          hintText: "Enter scheme name",
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: plotNumberController,
                        decoration: const InputDecoration(
                          labelText: "Plot Number",
                          border: OutlineInputBorder(),
                          hintText: "Enter plot number",
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: clientNameController,
                        decoration: const InputDecoration(
                          labelText: "Client Name",
                          border: OutlineInputBorder(),
                          hintText: "Enter client name",
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: gajSoldController,
                        decoration: const InputDecoration(
                          labelText: "Gaj Sold",
                          border: OutlineInputBorder(),
                          hintText: "Enter gaj sold",
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context), 
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final schemeName = schemeNameController.text.trim();
                    final plotNumber = plotNumberController.text.trim();
                    final clientName = clientNameController.text.trim();
                    final gajSoldText = gajSoldController.text.trim();
                    
                    // Validation
                    if (schemeName.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Please enter scheme name")),
                      );
                      return;
                    }
                    
                    // Convert gajSold to number, default to 0 if invalid
                    final gajSoldNumber = int.tryParse(gajSoldText) ?? 0;
                    
                    try {
                      await FirebaseFirestore.instance.collection('visits').doc(visitId).update({
                        'schemeName': schemeName,
                        'plotNumber': plotNumber,
                        'clientName': clientName,
                        'gajSold': gajSoldNumber,
                        'scheme': schemeName, // Keep for backward compatibility
                        'updatedAt': FieldValue.serverTimestamp(),
                      });
                      
                      if (!context.mounted) return;
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Scheme details updated successfully")),
                      );
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Error updating scheme details: $e")),
                      );
                    }
                  },
                  child: const Text("Save"),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _CompactVisitCard extends StatelessWidget {
  final String visitId;
  final Map<String, dynamic> visit;
  final Map<String, String> userNameMap;
  final Future<void> Function(String visitId, String newStatus) onUpdateStatus;
  final void Function(String visitId, String? existingScheme) onAssignScheme;

  const _CompactVisitCard({
    required this.visitId,
    required this.visit,
    required this.userNameMap,
    required this.onUpdateStatus,
    required this.onAssignScheme,
  });

  @override
  Widget build(BuildContext context) {
    final status = visit['status'] ?? 'Pending';
    final userId = visit['userId'] ?? '';
    final username = userNameMap[userId] ?? 'Unknown';
    final associate = visit['associateName'] ?? 'N/A';
    final location = visit['location'] ?? 'N/A';
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
    switch (status) {
      case 'Approved':
        statusColor = Colors.green;
        break;
      case 'Rejected':
        statusColor = Colors.red;
        break;
      default:
        statusColor = Colors.orange;
    }

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
            // Avatar
            CircleAvatar(
              radius: 16,
              backgroundColor: statusColor.withOpacity(0.12),
              child: Text(
                username.isNotEmpty ? username[0].toUpperCase() : '?',
                style: TextStyle(color: statusColor, fontWeight: FontWeight.w600, fontSize: 14),
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
                          username,
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
                          status,
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
                  Text(
                    associate,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
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
                      if (photoUrl != null && photoUrl.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Icon(Icons.photo_camera, size: 12, color: Colors.green.shade600),
                      ],
                      if (formattedDate.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(
                          formattedDate,
                          style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                        ),
                      ],
                    ],
                  ),
                  // Warning indicators row
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (photoUrl == null || photoUrl.isEmpty) ...[
                        Icon(Icons.photo_camera_outlined, size: 12, color: Colors.orange.shade600),
                        const SizedBox(width: 2),
                      ],
                      if (visit['scheme'] == null || visit['scheme'].toString().isEmpty) ...[
                        Icon(Icons.lightbulb_outlined, size: 12, color: Colors.orange.shade600),
                        const SizedBox(width: 2),
                      ],
                      if (visit['gajSold'] == null || visit['gajSold'].toString().isEmpty || visit['gajSold'] == 0) ...[
                        Icon(Icons.landscape_outlined, size: 12, color: Colors.orange.shade600),
                        const SizedBox(width: 2),
                      ],
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
      builder: (context) => _DetailedVisitView(
        visitId: visitId,
        visit: visit,
        userNameMap: userNameMap,
        onUpdateStatus: onUpdateStatus,
        onAssignScheme: onAssignScheme,
      ),
    );
  }
}

class _DetailedVisitView extends StatefulWidget {
  final String visitId;
  final Map<String, dynamic> visit;
  final Map<String, String> userNameMap;
  final Future<void> Function(String visitId, String newStatus) onUpdateStatus;
  final void Function(String visitId, String? existingScheme) onAssignScheme;

  const _DetailedVisitView({
    required this.visitId,
    required this.visit,
    required this.userNameMap,
    required this.onUpdateStatus,
    required this.onAssignScheme,
  });

  @override
  State<_DetailedVisitView> createState() => _DetailedVisitViewState();
}

class _DetailedVisitViewState extends State<_DetailedVisitView> {
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
    final userId = currentVisit['userId'] ?? '';
    final username = widget.userNameMap[userId] ?? 'Unknown';
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
    switch (status) {
      case 'Approved':
        statusColor = Colors.green;
        break;
      case 'Rejected':
        statusColor = Colors.red;
        break;
      default:
        statusColor = Colors.orange;
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
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SizedBox(width: 40), // Spacer for alignment
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(Icons.close, color: Colors.grey.shade600),
                        iconSize: 20,
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                      ),
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
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: statusColor.withOpacity(0.12),
                            child: Text(
                              username.isNotEmpty ? username[0].toUpperCase() : '?',
                              style: TextStyle(color: statusColor, fontWeight: FontWeight.w600, fontSize: 18),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Visit by $username',
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: statusColor.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    status,
                                    style: TextStyle(
                                      color: statusColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
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
                      _detailRow(Icons.person_outline, 'Customer Name', currentVisit['customerName'] ?? 'N/A'),
                      _detailRow(Icons.person_outline, 'Upperline Name', currentVisit['upperlineName'] ?? 'N/A'),
                      _detailRow(Icons.person_outline, 'Teamleader Name', currentVisit['teamleaderName'] ?? 'N/A'),
                      _detailRow(Icons.numbers_outlined, 'RERA Number', currentVisit['reraNumber'] ?? 'N/A'),
                      _detailRow(Icons.lightbulb_outline, 'Scheme Name', currentVisit['schemeName'] ?? 'N/A'),
                      _detailRow(Icons.place_outlined, 'Location', location),
                      if (formattedDate.isNotEmpty) 
                        _detailRow(Icons.access_time, 'Date & Time', formattedDate),
                      
                      // Scheme assignment details
                      if (currentVisit['plotNumber'] != null && currentVisit['plotNumber'].toString().isNotEmpty)
                        _detailRow(Icons.home_outlined, 'Plot Number', currentVisit['plotNumber'].toString()),
                      if (currentVisit['clientName'] != null && currentVisit['clientName'].toString().isNotEmpty)
                        _detailRow(Icons.person_outline, 'Client Name', currentVisit['clientName'].toString()),
                      if (gajSold != null && gajSold.toString().isNotEmpty)
                        _detailRow(Icons.landscape_outlined, 'Gaj Sold', '${gajSold} Gaj'),
                      
                      if (scheme != null && scheme.toString().isNotEmpty)
                        _detailRow(Icons.lightbulb_outline, 'Old Scheme', scheme.toString()),

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
                      ],

                      const SizedBox(height: 32),

                      // Action buttons
                      if (status == 'Pending') ...[
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  await widget.onUpdateStatus(widget.visitId, 'Approved');
                                  // Update local state and refresh UI
                                  setState(() {
                                    currentVisit['status'] = 'Approved';
                                  });
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                icon: const Icon(Icons.check, size: 20, color: Colors.white),
                                label: const Text('Approve', style: TextStyle(fontSize: 16, color: Colors.white)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  await widget.onUpdateStatus(widget.visitId, 'Rejected');
                                  Navigator.pop(context); // Close after rejection
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                icon: const Icon(Icons.close, size: 20, color: Colors.white),
                                label: const Text('Reject', style: TextStyle(fontSize: 16, color: Colors.white)),
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              widget.onAssignScheme(widget.visitId, scheme?.toString());
                              // Don't close the modal - let user see the updated data
                            },
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: BorderSide(color: Colors.blue.shade400),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.lightbulb_outline, size: 20, color: Colors.blue),
                            label: Text(
                              scheme == null || scheme.toString().isEmpty ? 'Assign Scheme' : 'Edit Scheme',
                              style: const TextStyle(color: Colors.blue, fontSize: 16),
                            ),
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

