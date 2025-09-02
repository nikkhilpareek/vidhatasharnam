import 'package:flutter/material.dart';

class TotalVisitsScreen extends StatefulWidget {
  const TotalVisitsScreen({super.key});

  @override
  State<TotalVisitsScreen> createState() => _TotalVisitsScreenState();
}

class _TotalVisitsScreenState extends State<TotalVisitsScreen> {
  // Placeholder data for total visits with different statuses
  final List<Map<String, dynamic>> totalVisits = [
    {
      'associateName': 'John Doe',
      'location': '123 Main Street, Delhi, India',
      'date': '20/08/2025',
      'time': '10:30 AM',
      'status': 'Accepted',
      'submittedOn': '20/08/2025 10:35 AM',
    },
    {
      'associateName': 'Jane Smith',
      'location': '456 Park Avenue, Mumbai, India',
      'date': '21/08/2025',
      'time': '02:15 PM',
      'status': 'Rejected',
      'submittedOn': '21/08/2025 02:20 PM',
    },
    {
      'associateName': 'Mike Johnson',
      'location': '789 Business District, Bangalore, India',
      'date': '22/08/2025',
      'time': '09:45 AM',
      'status': 'Accepted',
      'submittedOn': '22/08/2025 09:50 AM',
    },
    {
      'associateName': 'Sarah Wilson',
      'location': '321 Tech Park, Hyderabad, India',
      'date': '23/08/2025',
      'time': '11:20 AM',
      'status': 'Pending',
      'submittedOn': '23/08/2025 11:25 AM',
    },
    {
      'associateName': 'David Brown',
      'location': '654 Commercial Complex, Pune, India',
      'date': '24/08/2025',
      'time': '03:30 PM',
      'status': 'Accepted',
      'submittedOn': '24/08/2025 03:35 PM',
    },
    {
      'associateName': 'Emily Davis',
      'location': '987 Corporate Hub, Chennai, India',
      'date': '25/08/2025',
      'time': '01:00 PM',
      'status': 'Rejected',
      'submittedOn': '25/08/2025 01:05 PM',
    },
    {
      'associateName': 'Robert Taylor',
      'location': '159 Industrial Area, Kolkata, India',
      'date': '26/08/2025',
      'time': '04:45 PM',
      'status': 'Pending',
      'submittedOn': '26/08/2025 04:50 PM',
    },
    {
      'associateName': 'Lisa Anderson',
      'location': '753 Business Center, Ahmedabad, India',
      'date': '27/08/2025',
      'time': '08:15 AM',
      'status': 'Accepted',
      'submittedOn': '27/08/2025 08:20 AM',
    },
  ];

  String selectedFilter = 'All';
  List<String> filterOptions = ['All', 'Accepted', 'Rejected', 'Pending'];

  List<Map<String, dynamic>> get filteredVisits {
    if (selectedFilter == 'All') {
      return totalVisits;
    }
    return totalVisits.where((visit) => visit['status'] == selectedFilter).toList();
  }

  int get acceptedCount => totalVisits.where((visit) => visit['status'] == 'Accepted').length;
  int get rejectedCount => totalVisits.where((visit) => visit['status'] == 'Rejected').length;
  int get pendingCount => totalVisits.where((visit) => visit['status'] == 'Pending').length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: Text(
          'Total Visits',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
      ),
      body: Container(
        color: Colors.grey.shade50,
        child: Column(
          children: [
            // Header Info Section with Statistics
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Visit Summary',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatCard('Total', totalVisits.length.toString(), Icons.analytics, Colors.grey.shade700),
                      _buildStatCard('Accepted', acceptedCount.toString(), Icons.check_circle, Colors.green.shade600),
                      _buildStatCard('Rejected', rejectedCount.toString(), Icons.cancel, Colors.red.shade600),
                      _buildStatCard('Pending', pendingCount.toString(), Icons.access_time, Colors.orange.shade600),
                    ],
                  ),
                ],
              ),
            ),
            
            // Filter Section
            Container(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(
                    'Filter by: ',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: filterOptions.map((filter) {
                          return Padding(
                            padding: EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(filter),
                              selected: selectedFilter == filter,
                              onSelected: (bool selected) {
                                setState(() {
                                  selectedFilter = filter;
                                });
                              },
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
            
            // Total Visits List
            Expanded(
              child: filteredVisits.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      itemCount: filteredVisits.length,
                      itemBuilder: (context, index) {
                        return _buildVisitCard(filteredVisits[index]);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String count, IconData icon, Color iconColor) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            size: 24,
            color: iconColor,
          ),
        ),
        SizedBox(height: 8),
        Text(
          count,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildVisitCard(Map<String, dynamic> visit) {
    Color statusColor;
    Color statusTextColor;
    IconData statusIcon;
    
    switch (visit['status']) {
      case 'Accepted':
        statusColor = Colors.green;
        statusTextColor = Colors.green.shade700;
        statusIcon = Icons.check_circle;
        break;
      case 'Rejected':
        statusColor = Colors.red;
        statusTextColor = Colors.red.shade700;
        statusIcon = Icons.cancel;
        break;
      case 'Pending':
      default:
        statusColor = Colors.orange;
        statusTextColor = Colors.orange.shade700;
        statusIcon = Icons.access_time;
        break;
    }

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with Status only
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        statusIcon,
                        size: 14,
                        color: statusTextColor,
                      ),
                      SizedBox(width: 4),
                      Text(
                        visit['status'],
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: statusTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            SizedBox(height: 16),
            
            // Associate Name
            Row(
              children: [
                Icon(
                  Icons.person_outline,
                  size: 20,
                  color: Colors.grey.shade600,
                ),
                SizedBox(width: 8),
                Text(
                  'Associate:',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    visit['associateName'],
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
            
            SizedBox(height: 12),
            
            // Location
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.location_on_outlined,
                  size: 20,
                  color: Colors.grey.shade600,
                ),
                SizedBox(width: 8),
                Text(
                  'Location:',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    visit['location'],
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            
            SizedBox(height: 12),
            
            // Date and Time
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 18,
                        color: Colors.grey.shade600,
                      ),
                      SizedBox(width: 6),
                      Text(
                        visit['date'],
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.black87,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        Icons.access_time_outlined,
                        size: 18,
                        color: Colors.grey.shade600,
                      ),
                      SizedBox(width: 6),
                      Text(
                        visit['time'],
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.black87,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            SizedBox(height: 12),
            
            // Submitted On
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.upload_outlined,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Submitted on: ',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  Text(
                    visit['submittedOn'],
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    String emptyMessage;
    String emptySubtitle;
    
    switch (selectedFilter) {
      case 'Accepted':
        emptyMessage = 'No Accepted Visits';
        emptySubtitle = 'No visits have been accepted yet';
        break;
      case 'Rejected':
        emptyMessage = 'No Rejected Visits';
        emptySubtitle = 'No visits have been rejected';
        break;
      case 'Pending':
        emptyMessage = 'No Pending Visits';
        emptySubtitle = 'All visits have been processed';
        break;
      default:
        emptyMessage = 'No Visits Found';
        emptySubtitle = 'No visits have been created yet';
        break;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.analytics_outlined,
            size: 80,
            color: Colors.grey.shade400,
          ),
          SizedBox(height: 20),
          Text(
            emptyMessage,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          SizedBox(height: 8),
          Text(
            emptySubtitle,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
          SizedBox(height: 30),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text(
              'Go Back',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
