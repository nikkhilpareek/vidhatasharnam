import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TotalGajSoldScreen extends StatefulWidget {
  const TotalGajSoldScreen({super.key});

  @override
  State<TotalGajSoldScreen> createState() => _TotalGajSoldScreenState();
}

class _TotalGajSoldScreenState extends State<TotalGajSoldScreen> {

  String _formatDate(DateTime date) {
    return "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
  }



  Widget _buildSummaryCard(int totalGajSold) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.primary.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'Total Gaj Sold',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            '$totalGajSold',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            'Gaj from approved visits',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVisitTile(Map<String, dynamic> visit) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: Colors.grey.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: Colors.green.withOpacity(0.1),
          child: const Icon(
            Icons.check_circle,
            color: Colors.green,
          ),
        ),
        title: Text(
          visit['associateName'],
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.grey[800],
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              '${visit['gajSold']} Gaj • ${_formatDate(visit['date'])}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '${visit['gajSold']} Gaj',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.green,
            ),
          ),
        ),
        children: [
          Divider(color: Colors.grey.withOpacity(0.3)),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                _buildDetailRow('Date', _formatDate(visit['date'])),
                const SizedBox(height: 8),
                _buildDetailRow('Associate Name', visit['associateName']),
                const SizedBox(height: 8),
                if (visit['customerName'] != null && visit['customerName'] != 'N/A') ...[
                  _buildDetailRow('Customer Name', visit['customerName']),
                  const SizedBox(height: 8),
                ],
                if (visit['upperlineName'] != null && visit['upperlineName'] != 'N/A') ...[
                  _buildDetailRow('Upperline Name', visit['upperlineName']),
                  const SizedBox(height: 8),
                ],
                if (visit['teamleaderName'] != null && visit['teamleaderName'] != 'N/A') ...[
                  _buildDetailRow('Teamleader Name', visit['teamleaderName']),
                  const SizedBox(height: 8),
                ],
                if (visit['reraNumber'] != null && visit['reraNumber'] != 'N/A') ...[
                  _buildDetailRow('RERA Number', visit['reraNumber']),
                  const SizedBox(height: 8),
                ],
                _buildDetailRow('Location', visit['location']),
                const SizedBox(height: 8),
                _buildDetailRow('Scheme Name', visit['schemeName'] ?? visit['scheme'] ?? 'N/A'),
                const SizedBox(height: 8),
                if (visit['plotNumber'] != null && visit['plotNumber'] != 'N/A') ...[
                  _buildDetailRow('Plot Number', visit['plotNumber']),
                  const SizedBox(height: 8),
                ],
                if (visit['clientName'] != null && visit['clientName'] != 'N/A') ...[
                  _buildDetailRow('Client Name', visit['clientName']),
                  const SizedBox(height: 8),
                ],
                _buildDetailRow('Gaj Sold', '${visit['gajSold']} Gaj'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
        ),
        Text(
          ': ',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    
    if (userId == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Total Gaj Sold'),
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: Text('Not authenticated')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Total Gaj Sold'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('visits')
            .where('userId', isEqualTo: userId)
            .where('status', isEqualTo: 'Approved')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 60, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                ],
              ),
            );
          }

          final visits = snapshot.data?.docs ?? [];
          
          // Calculate total gaj sold from approved visits
          int totalGajSold = 0;
          final visitData = <Map<String, dynamic>>[];
          
          for (final doc in visits) {
            final data = doc.data() as Map<String, dynamic>;
            
            // Handle both string and number formats for gajSold
            int gajSold = 0;
            final gajSoldData = data['gajSold'];
            if (gajSoldData != null) {
              if (gajSoldData is num) {
                gajSold = gajSoldData.toInt();
              } else if (gajSoldData is String) {
                gajSold = int.tryParse(gajSoldData) ?? 0;
              }
            }
            
            totalGajSold += gajSold;
            
            // Create visit data for display
            DateTime? visitDate;
            if (data['createdAt'] is Timestamp) {
              visitDate = (data['createdAt'] as Timestamp).toDate();
            } else if (data['dateTime'] is Timestamp) {
              visitDate = (data['dateTime'] as Timestamp).toDate();
            }
            
            visitData.add({
              'associateName': data['associateName'] ?? 'N/A',
              'customerName': data['customerName'] ?? 'N/A',
              'upperlineName': data['upperlineName'] ?? 'N/A',
              'teamleaderName': data['teamleaderName'] ?? 'N/A',
              'reraNumber': data['reraNumber'] ?? 'N/A',
              'schemeName': data['schemeName'] ?? 'N/A',
              'plotNumber': data['plotNumber'] ?? 'N/A',
              'clientName': data['clientName'] ?? 'N/A',
              'location': data['location'] ?? 'N/A',
              'scheme': data['scheme'] ?? 'N/A', // Keep for backward compatibility
              'gajSold': gajSold,
              'date': visitDate ?? DateTime.now(),
            });
          }
          
          // Sort by date (most recent first)
          visitData.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));

          return Column(
            children: [
              // Summary Card
              _buildSummaryCard(totalGajSold),
              
              // Visits List Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Text(
                      'Approved Visits',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${visitData.length} Visits',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              
              // Visits List
              Expanded(
                child: visitData.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.landscape_outlined,
                              size: 80,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No approved visits yet',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Your approved visits will appear here',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: visitData.length,
                        itemBuilder: (context, index) {
                          return _buildVisitTile(visitData[index]);
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
