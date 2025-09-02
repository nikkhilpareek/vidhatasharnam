import 'package:flutter/material.dart';

class PendingVisitsScreen extends StatefulWidget {
  const PendingVisitsScreen({super.key});

  @override
  State<PendingVisitsScreen> createState() => _PendingVisitsScreenState();
}

class _PendingVisitsScreenState extends State<PendingVisitsScreen> {
  final List<Map<String, dynamic>> pendingVisits = [
    {
      'associateName': 'John Doe',
      'location': '123 Main Street, Delhi, India',
      'date': '25/08/2025',
      'time': '10:30 AM',
      'status': 'Pending',
      'submittedOn': '25/08/2025 10:35 AM',
    },
    {
      'associateName': 'Jane Smith',
      'location': '456 Park Avenue, Mumbai, India',
      'date': '26/08/2025',
      'time': '02:15 PM',
      'status': 'Pending',
      'submittedOn': '26/08/2025 02:20 PM',
    },
    {
      'associateName': 'Mike Johnson',
      'location': '789 Business District, Bangalore, India',
      'date': '27/08/2025',
      'time': '09:45 AM',
      'status': 'Pending',
      'submittedOn': '27/08/2025 09:50 AM',
    },
    {
      'associateName': 'Sarah Wilson',
      'location': '321 Tech Park, Hyderabad, India',
      'date': '27/08/2025',
      'time': '11:20 AM',
      'status': 'Pending',
      'submittedOn': '27/08/2025 11:25 AM',
    },
    {
      'associateName': 'David Brown',
      'location': '654 Commercial Complex, Pune, India',
      'date': '27/08/2025',
      'time': '03:30 PM',
      'status': 'Pending',
      'submittedOn': '27/08/2025 03:35 PM',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(context),
      body: Container(
        color: Colors.grey.shade50,
        child: Column(
          children: [
            _HeaderInfo(
              count: pendingVisits.length,
              color: Theme.of(context).colorScheme.primary,
            ),
            Expanded(
              child: pendingVisits.isEmpty
                  ? _EmptyState(onCreate: () => Navigator.pop(context))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: pendingVisits.length,
                      itemBuilder: (context, index) =>
                          _VisitCard(visit: pendingVisits[index]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Theme.of(context).colorScheme.primary,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text(
        'Pending Visits',
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 20,
          color: Colors.white,
        ),
      ),
    );
  }
}

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
              const Icon(Icons.pending_actions, color: Colors.black, size: 18),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StatusBadge(status: visit['status']),
            const SizedBox(height: 16),
            _InfoRow(
              icon: Icons.person_outline,
              label: 'Associate:',
              value: visit['associateName'],
              valueStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            _InfoRow(
              icon: Icons.location_on_outlined,
              label: 'Location:',
              value: visit['location'],
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _IconText(
                    icon: Icons.calendar_today_outlined,
                    text: visit['date'],
                  ),
                ),
                Expanded(
                  child: _IconText(
                    icon: Icons.access_time_outlined,
                    text: visit['time'],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _SubmittedOn(submittedOn: visit['submittedOn']),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.access_time, size: 14, color: Colors.orange.shade700),
              const SizedBox(width: 4),
              Text(
                status,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.orange.shade700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final TextStyle? valueStyle;
  final int? maxLines;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueStyle,
    this.maxLines,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: maxLines != null ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: valueStyle ??
                const TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                ),
            maxLines: maxLines,
            overflow: maxLines != null ? TextOverflow.ellipsis : null,
          ),
        ),
      ],
    );
  }
}

class _IconText extends StatelessWidget {
  final IconData icon;
  final String text;

  const _IconText({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade600),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            color: Colors.black87,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _SubmittedOn extends StatelessWidget {
  final String submittedOn;

  const _SubmittedOn({required this.submittedOn});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.upload_outlined, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          const Text(
            'Submitted on: ',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
          Text(
            submittedOn,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black87,
              fontWeight: FontWeight.w500,
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
          Icon(Icons.pending_actions_outlined, size: 80, color: Colors.grey.shade400),
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
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
