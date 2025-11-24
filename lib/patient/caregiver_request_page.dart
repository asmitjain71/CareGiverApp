import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:practice/services/notification_service.dart';

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

    final newRef = _requestsRef.child(_selectedPatientId!).push();
    await newRef.set({
      'message': message,
      'status': 'pending',
      'medication': medication,
      'timestamp': ServerValue.timestamp,
    });

    // Notify user locally
    await NotificationService().showNotification(
      id: newRef.key.hashCode,
      title: 'Request Sent',
      body: 'Your request for "$message" has been sent to caregivers.',
    );

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
            border: OutlineInputBorder(),
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
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Theme.of(context).colorScheme.surface,
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              hint: const Text('Select patient profile'),
              value: _selectedPatientId,
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down),
              items: dropdownItems,
              onChanged: (value) {
                setState(() {
                  _selectedPatientId = value;
                });
              },
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Quick Requests',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: _quickNeeds
              .map(
                (need) => ActionChip(
                  avatar: const Icon(Icons.flash_on, size: 16),
                  label: Text(need),
                  onPressed: () => _submitRequest(need),
                  backgroundColor:
                      Theme.of(context).colorScheme.primaryContainer,
                  labelStyle: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _openCustomRequestDialog,
            icon: const Icon(Icons.edit_note),
            label: const Text('Describe Custom Need'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.all(16),
            ),
          ),
        ),
        const SizedBox(height: 32),
        if (_selectedPatientId != null) ...[
          Text(
            'Medication-Linked Requests',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          _buildMedicationStream(),
          const SizedBox(height: 32),
          Text(
            'Recent Requests',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          _buildRequestStream(),
        ] else
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Text(
                'Select your profile to view schedules and previous requests.',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
            ),
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
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.medication,
                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                  ),
                ),
                title: Text(
                  schedule['medication'] ?? 'Medication',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                    '${schedule['dosage'] ?? '-'} • ${schedule['time'] ?? ''}'),
                trailing: IconButton.filledTonal(
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

            Color statusColor;
            switch (status) {
              case 'resolved':
                statusColor = Colors.green;
                break;
              case 'in-progress':
                statusColor = Colors.orange;
                break;
              default:
                statusColor = Colors.blue;
            }

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            data['message'] ?? 'Request',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: statusColor),
                          ),
                          child: Text(
                            status.toUpperCase(),
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (data['medication'] != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.link,
                                size: 16, color: Colors.grey),
                            const SizedBox(width: 8),
                            Text(
                              '${data['medication']['medication']} (${data['medication']['dosage'] ?? ''})',
                              style: TextStyle(color: Colors.grey.shade700),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      'Sent at: ${time.toLocal().toString().split('.')[0]}',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Colors.grey[500]),
                    ),
                  ],
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
      color: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.info_outline, color: Colors.grey.shade400),
              const SizedBox(height: 8),
              Text(
                message,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
