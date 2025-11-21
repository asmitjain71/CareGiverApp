import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

class CaregiverRequestPage extends StatefulWidget {
  const CaregiverRequestPage({super.key});

  @override
  State<CaregiverRequestPage> createState() => _CaregiverRequestPageState();
}

class _CaregiverRequestPageState extends State<CaregiverRequestPage> {
  final DatabaseReference _patientsRef =
      FirebaseDatabase.instance.ref('Patients');
  final DatabaseReference _scheduleRef =
      FirebaseDatabase.instance.ref('MedicationSchedules');
  final DatabaseReference _requestsRef =
      FirebaseDatabase.instance.ref('CaregiverRequests');

  final TextEditingController _notesController = TextEditingController();
  String? _selectedPatientId;
  Map<String, dynamic>? _patientsCache;

  final List<String> _quickNeeds = const [
    'Water refill',
    'Next medication',
    'Assistance to restroom',
    'Pain relief',
    'Vitals check'
  ];

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submitRequest(String message,
      {Map<String, dynamic>? medication}) async {
    if (_selectedPatientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select your profile first.')),
      );
      return;
    }

    await _requestsRef.child(_selectedPatientId!).push().set({
      'message': message,
      'status': 'pending',
      'medication': medication,
      'timestamp': ServerValue.timestamp,
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Request sent: $message')),
    );
  }

  void _openCustomRequestDialog({Map<String, dynamic>? medication}) {
    _notesController.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(medication == null
            ? 'Describe your need'
            : 'Add note for ${medication['medication']}'),
        content: TextField(
          controller: _notesController,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'e.g. Need help taking 2 tablets with water',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              final text = _notesController.text.trim();
              if (text.isNotEmpty) {
                _submitRequest(text, medication: medication);
              }
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Caregiver Requests'),
      ),
      body: StreamBuilder<DatabaseEvent>(
        stream: _patientsRef.onValue,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
            return const Center(child: Text('No patients found.'));
          }
          _patientsCache = Map<String, dynamic>.from(
              snapshot.data!.snapshot.value as Map<dynamic, dynamic>);
          return _buildContent();
        },
      ),
    );
  }

  Widget _buildContent() {
    final patients = _patientsCache ?? {};
    final dropdownItems = patients.entries
        .map(
          (entry) => DropdownMenuItem(
            value: entry.key,
            child: Text(entry.value['firstName'] ?? 'Unnamed'),
          ),
        )
        .toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                hint: const Text('Select patient profile'),
                value: _selectedPatientId,
                isExpanded: true,
                items: dropdownItems,
                onChanged: (value) {
                  setState(() {
                    _selectedPatientId = value;
                  });
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Quick requests',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _quickNeeds
              .map(
                (need) => ChoiceChip(
                  label: Text(need),
                  selected: false,
                  onSelected: (_) => _submitRequest(need),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: _openCustomRequestDialog,
          icon: const Icon(Icons.edit_note),
          label: const Text('Describe another need'),
        ),
        const SizedBox(height: 24),
        if (_selectedPatientId != null) ...[
          Text(
            'Medication-linked requests',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          _buildMedicationStream(),
          const SizedBox(height: 24),
          Text(
            'Recent requests',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          _buildRequestStream(),
        ] else
          Text(
            'Select your profile to view schedules and previous requests.',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: Colors.grey[700]),
          ),
      ],
    );
  }

  Widget _buildMedicationStream() {
    return StreamBuilder<DatabaseEvent>(
      stream: _scheduleRef.child(_selectedPatientId!).onValue,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _StatusCard(message: 'Error loading schedules');
        }
        if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
          return _StatusCard(message: 'No schedules found for this patient');
        }
        final schedules = Map<String, dynamic>.from(
            snapshot.data!.snapshot.value as Map<dynamic, dynamic>);
        return Column(
          children: schedules.entries.map((entry) {
            final schedule = Map<String, dynamic>.from(entry.value);
            return Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                title: Text(schedule['medication'] ?? 'Medication'),
                subtitle: Text(
                    'Dosage: ${schedule['dosage'] ?? '-'} • ${schedule['time'] ?? ''}'),
                trailing: IconButton(
                  icon: const Icon(Icons.send),
                  tooltip: 'Request this medication',
                  onPressed: () => _openCustomRequestDialog(
                    medication: {
                      'medication': schedule['medication'],
                      'dosage': schedule['dosage'],
                      'time': schedule['time'],
                    },
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildRequestStream() {
    return StreamBuilder<DatabaseEvent>(
      stream: _requestsRef
          .child(_selectedPatientId!)
          .orderByChild('timestamp')
          .onValue,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
          return _StatusCard(message: 'No requests yet');
        }
        final requests = Map<String, dynamic>.from(
            snapshot.data!.snapshot.value as Map<dynamic, dynamic>);
        final sorted = requests.entries.toList()
          ..sort((a, b) {
            final aTime = (a.value['timestamp'] ?? 0) as int;
            final bTime = (b.value['timestamp'] ?? 0) as int;
            return bTime.compareTo(aTime);
          });

        return Column(
          children: sorted.map((entry) {
            final data = Map<String, dynamic>.from(entry.value);
            final status = (data['status'] ?? 'pending').toString();
            final timestamp = data['timestamp'] as int? ?? 0;
            final time = DateTime.fromMillisecondsSinceEpoch(timestamp);

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                title: Text(data['message'] ?? 'Request'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (data['medication'] != null)
                      Text(
                        'Linked to: ${data['medication']['medication']} (${data['medication']['dosage'] ?? ''})',
                      ),
                    Text(
                      'Sent at: ${time.toLocal()}',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Colors.grey[600]),
                    ),
                  ],
                ),
                trailing: Chip(
                  label: Text(status),
                  backgroundColor: status == 'resolved'
                      ? Colors.green.shade100
                      : (status == 'in-progress'
                          ? Colors.orange.shade100
                          : Colors.blue.shade100),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _StatusCard extends StatelessWidget {
  final String message;

  const _StatusCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Text(
            message,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: Colors.grey[700]),
          ),
        ),
      ),
    );
  }
}
