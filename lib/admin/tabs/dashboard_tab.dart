import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class DashboardTab extends StatelessWidget {
  final VoidCallback onCreateUser;
  final VoidCallback onManageVisits;
  const DashboardTab({super.key, required this.onCreateUser, required this.onManageVisits});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Dashboard Overview',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('users').snapshots(),
                  builder: (context, snapshot) {
                    final totalUsers = snapshot.hasData ? snapshot.data!.docs.length : 0;
                    return _buildStatsCard('Total Users', totalUsers.toString(), Icons.people, Colors.blue);
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('visits').where('status', isEqualTo: 'Pending').snapshots(),
                  builder: (context, snapshot) {
                    final pendingCount = snapshot.hasData ? snapshot.data!.docs.length : 0;
                    return _buildStatsCard('Pending Visits', pendingCount.toString(), Icons.pending_actions, Colors.orange);
                  },
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          Text(
            'Quick Actions',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onCreateUser,
                  icon: const Icon(Icons.person_add),
                  label: const Text('Create User'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onManageVisits,
                  icon: const Icon(Icons.location_on),
                  label: const Text('Manage Visits'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildTopUsersSection(),
        ],
      ),
    );
  }

  Widget _buildTopUsersSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('visits').where('status', isEqualTo: 'Approved').snapshots(),
      builder: (context, visitsSnapshot) {
        if (visitsSnapshot.connectionState == ConnectionState.waiting) {
          return Container(
            height: 200,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.15),
                  spreadRadius: 1,
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        if (visitsSnapshot.hasError) {
          return Container(
            height: 200,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.15),
                  spreadRadius: 1,
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Center(child: Text('Error loading data')),
          );
        }

        // Calculate total gaj sold per user
        final Map<String, double> userGajTotals = {};
        final visits = visitsSnapshot.data?.docs ?? [];
        
        for (final doc in visits) {
          final data = doc.data() as Map<String, dynamic>;
          final userId = data['userId'] as String?;
          final gajSold = data['gajSold'];
          
          if (userId != null && gajSold != null) {
            double gajValue = 0.0;
            if (gajSold is num) {
              gajValue = gajSold.toDouble();
            } else if (gajSold is String) {
              gajValue = double.tryParse(gajSold) ?? 0.0;
            }
            userGajTotals[userId] = (userGajTotals[userId] ?? 0.0) + gajValue;
          }
        }

        // Sort users by total gaj sold (descending)
        final sortedUsers = userGajTotals.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        // Get top 5 users
        final topUsers = sortedUsers.take(5).toList();

        if (topUsers.isEmpty) {
          return Container(
            height: 200,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.15),
                  spreadRadius: 1,
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Center(child: Text('No approved visits found')),
          );
        }

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('users').snapshots(),
          builder: (context, usersSnapshot) {
            if (usersSnapshot.connectionState == ConnectionState.waiting) {
              return Container(
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.15),
                      spreadRadius: 1,
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Center(child: CircularProgressIndicator()),
              );
            }

            // Create user name map
            final Map<String, String> userNameMap = {};
            if (usersSnapshot.hasData) {
              for (final doc in usersSnapshot.data!.docs) {
                final data = doc.data() as Map<String, dynamic>;
                userNameMap[doc.id] = data['username'] ?? data['email']?.split('@')?.first ?? 'Unknown User';
              }
            }

            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.15),
                    spreadRadius: 1,
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.leaderboard, color: Colors.green, size: 24),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Top Performers',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => _showAllUsersPerformance(context),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.green.shade700,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          ),
                          child: const Text(
                            'View All',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: topUsers.length,
                    separatorBuilder: (context, index) => Divider(
                      height: 1,
                      color: Colors.grey.shade200,
                    ),
                    itemBuilder: (context, index) {
                      final userEntry = topUsers[index];
                      final userId = userEntry.key;
                      final totalGaj = userEntry.value;
                      final userName = userNameMap[userId] ?? 'Unknown User';

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: CircleAvatar(
                          backgroundColor: _getRankColor(index).withOpacity(0.1),
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _getRankColor(index),
                            ),
                          ),
                        ),
                        title: Text(
                          userName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${totalGaj.toInt()} Gaj',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Color _getRankColor(int index) {
    switch (index) {
      case 0:
        return Colors.amber; // Gold
      case 1:
        return Colors.grey; // Silver
      case 2:
        return Colors.brown; // Bronze
      default:
        return Colors.blue;
    }
  }

  Widget _buildStatsCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.15),
            spreadRadius: 1,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              CircleAvatar(backgroundColor: color.withOpacity(0.1), child: Icon(icon, color: color, size: 24)),
              Text(value, style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
          const SizedBox(height: 12),
          Text(title, style: TextStyle(fontSize: 14, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  void _showAllUsersPerformance(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const AllUsersPerformanceScreen(),
      ),
    );
  }
}

class AllUsersPerformanceScreen extends StatefulWidget {
  const AllUsersPerformanceScreen({super.key});

  @override
  State<AllUsersPerformanceScreen> createState() => _AllUsersPerformanceScreenState();
}

class _AllUsersPerformanceScreenState extends State<AllUsersPerformanceScreen> {
  String _selectedPeriod = 'All Time';
  DateTime? _startDate;
  DateTime? _endDate;

  final List<String> _timePeriods = [
    'All Time',
    'This Month',
    'Last Month',
    'Last 3 Months',
    'Last 6 Months',
    'This Year',
    'Custom Range'
  ];

  @override
  void initState() {
    super.initState();
    _updateDateRange();
  }

  void _updateDateRange() {
    final now = DateTime.now();
    switch (_selectedPeriod) {
      case 'This Month':
        _startDate = DateTime(now.year, now.month, 1);
        _endDate = DateTime(now.year, now.month + 1, 0);
        break;
      case 'Last Month':
        final lastMonth = DateTime(now.year, now.month - 1, 1);
        _startDate = lastMonth;
        _endDate = DateTime(lastMonth.year, lastMonth.month + 1, 0);
        break;
      case 'Last 3 Months':
        _startDate = DateTime(now.year, now.month - 3, 1);
        _endDate = now;
        break;
      case 'Last 6 Months':
        _startDate = DateTime(now.year, now.month - 6, 1);
        _endDate = now;
        break;
      case 'This Year':
        _startDate = DateTime(now.year, 1, 1);
        _endDate = DateTime(now.year, 12, 31);
        break;
      case 'All Time':
      default:
        _startDate = null;
        _endDate = null;
        break;
    }
  }

  Future<void> _selectCustomDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Performance'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey.shade50,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedPeriod,
                        decoration: const InputDecoration(
                          labelText: 'Time Period',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        items: _timePeriods.map((period) {
                          return DropdownMenuItem(
                            value: period,
                            child: Text(period),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedPeriod = value!;
                            if (value == 'Custom Range') {
                              _selectCustomDateRange();
                            } else {
                              _updateDateRange();
                            }
                          });
                        },
                      ),
                    ),
                  ],
                ),
                if (_selectedPeriod == 'Custom Range' && _startDate != null && _endDate != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'From ${_formatDate(_startDate!)} to ${_formatDate(_endDate!)}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _buildUsersList(),
          ),
        ],
      ),
    );
  }

  Widget _buildUsersList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _getFilteredVisitsStream(),
      builder: (context, visitsSnapshot) {
        if (visitsSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (visitsSnapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 60, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error: ${visitsSnapshot.error}'),
                const SizedBox(height: 8),
                Text(
                  'Try selecting "All Time" or check if data exists',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          );
        }

        // Calculate total gaj sold per user
        final Map<String, double> userGajTotals = {};
        final Map<String, int> userVisitCounts = {};
        final visits = visitsSnapshot.data?.docs ?? [];
        
        for (final doc in visits) {
          final data = doc.data() as Map<String, dynamic>;
          final userId = data['userId'] as String?;
          final gajSold = data['gajSold'];
          
          // Client-side date filtering as fallback
          bool includeVisit = true;
          if (_selectedPeriod != 'All Time' && _startDate != null && _endDate != null) {
            final createdAt = data['createdAt'];
            if (createdAt is Timestamp) {
              final visitDate = createdAt.toDate();
              includeVisit = visitDate.isAfter(_startDate!) && visitDate.isBefore(_endDate!.add(const Duration(days: 1)));
            } else {
              // If no createdAt, fall back to dateTime field
              final dateTime = data['dateTime'];
              if (dateTime is Timestamp) {
                final visitDate = dateTime.toDate();
                includeVisit = visitDate.isAfter(_startDate!) && visitDate.isBefore(_endDate!.add(const Duration(days: 1)));
              }
            }
          }
          
          if (userId != null && gajSold != null && includeVisit) {
            double gajValue = 0.0;
            if (gajSold is num) {
              gajValue = gajSold.toDouble();
            } else if (gajSold is String) {
              gajValue = double.tryParse(gajSold) ?? 0.0;
            }
            userGajTotals[userId] = (userGajTotals[userId] ?? 0.0) + gajValue;
            userVisitCounts[userId] = (userVisitCounts[userId] ?? 0) + 1;
          }
        }

        // Sort users by total gaj sold (descending)
        final sortedUsers = userGajTotals.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        if (sortedUsers.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.analytics_outlined, size: 60, color: Colors.grey),
                SizedBox(height: 16),
                Text('No data found for the selected period'),
              ],
            ),
          );
        }

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('users').snapshots(),
          builder: (context, usersSnapshot) {
            if (usersSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            // Create user name map
            final Map<String, String> userNameMap = {};
            if (usersSnapshot.hasData) {
              for (final doc in usersSnapshot.data!.docs) {
                final data = doc.data() as Map<String, dynamic>;
                userNameMap[doc.id] = data['username'] ?? data['email']?.split('@')?.first ?? 'Unknown User';
              }
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: sortedUsers.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final userEntry = sortedUsers[index];
                final userId = userEntry.key;
                final totalGaj = userEntry.value;
                final visitCount = userVisitCounts[userId] ?? 0;
                final userName = userNameMap[userId] ?? 'Unknown User';

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        spreadRadius: 1,
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: _getRankColor(index).withOpacity(0.1),
                        radius: 25,
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _getRankColor(index),
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              userName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$visitCount approved visits',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${totalGaj.toInt()} Gaj',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade700,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Stream<QuerySnapshot> _getFilteredVisitsStream() {
    // Simplified query - only filter by status at database level
    // Date filtering will be done client-side to avoid index issues
    return FirebaseFirestore.instance
        .collection('visits')
        .where('status', isEqualTo: 'Approved')
        .snapshots();
  }

  Color _getRankColor(int index) {
    if (index < 3) {
      switch (index) {
        case 0:
          return Colors.amber; // Gold
        case 1:
          return Colors.grey; // Silver
        case 2:
          return Colors.brown; // Bronze
      }
    }
    return Colors.blue;
  }

  String _formatDate(DateTime date) {
    return "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
  }
}
