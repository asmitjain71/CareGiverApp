import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class MedicationSchedulePage extends StatefulWidget {
  const MedicationSchedulePage({super.key});

  @override
  State<MedicationSchedulePage> createState() => _MedicationSchedulePageState();
}

class _MedicationSchedulePageState extends State<MedicationSchedulePage> {
  // References for Patients and MedicationSchedules nodes.
  final DatabaseReference _patientsRef =
      FirebaseDatabase.instance.ref('Patients');
  final DatabaseReference _scheduleRef =
      FirebaseDatabase.instance.ref('MedicationSchedules');

  // Controllers for adding new medication schedule.
  final TextEditingController _medicationController = TextEditingController();
  final TextEditingController _dosageController = TextEditingController();
  final TextEditingController _frequencyController = TextEditingController();
  final TextEditingController _timeController = TextEditingController();

  // Selected patient id and data.
  String? _selectedPatientId;

  // Show dialog for adding a new medication schedule for the selected patient.
  void _showAddMedicationDialog(Map<String, dynamic> currentSchedules) {
    _medicationController.clear();
    _dosageController.clear();
    _frequencyController.clear();
    _timeController.clear();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Medication'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: _medicationController,
                  decoration:
                      const InputDecoration(labelText: 'Medication Name'),
                ),
                TextField(
                  controller: _dosageController,
                  decoration: const InputDecoration(labelText: 'Dosage'),
                ),
                TextField(
                  controller: _frequencyController,
                  decoration: const InputDecoration(labelText: 'Frequency'),
                ),
                TextField(
                  controller: _timeController,
                  decoration:
                      const InputDecoration(labelText: 'Time (HH:MM AM/PM)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                String medication = _medicationController.text.trim();
                String dosage = _dosageController.text.trim();
                String frequency = _frequencyController.text.trim();
                String time = _timeController.text.trim();

                if (medication.isEmpty ||
                    dosage.isEmpty ||
                    frequency.isEmpty ||
                    time.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please fill all fields.')),
                  );
                  return;
                }

                // Check for schedule conflict in the current patient's schedules.
                bool conflict = false;
                currentSchedules.forEach((key, value) {
                  final schedule = Map<String, dynamic>.from(value);
                  if (schedule['time'] == time) {
                    conflict = true;
                  }
                });

                if (conflict) {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Conflict Detected'),
                      content: Text(
                          'There is already a medication scheduled at $time. Please choose a different time or adjust the existing schedule.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('OK'),
                        ),
                      ],
                    ),
                  );
                } else {
                  // Add new medication schedule under the selected patient.
                  Map<String, dynamic> newSchedule = {
                    'medication': medication,
                    'dosage': dosage,
                    'frequency': frequency,
                    'time': time,
                    'timestamp': ServerValue.timestamp,
                  };
                  await _scheduleRef
                      .child(_selectedPatientId!)
                      .push()
                      .set(newSchedule);
                  Navigator.pop(context);
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _medicationController.dispose();
    _dosageController.dispose();
    _frequencyController.dispose();
    _timeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Medication Schedules'),
      ),
      body: Column(
        children: [
          // Patients Dropdown for selection.
          StreamBuilder<DatabaseEvent>(
            stream: _patientsRef.onValue,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
                return const Center(child: Text('No patients found.'));
              }
              final patientsData = Map<String, dynamic>.from(
                  snapshot.data!.snapshot.value as Map);
              List<DropdownMenuItem<String>> patientItems = patientsData.entries
                  .map((e) {
                    final patient = Map<String, dynamic>.from(e.value);
                    return DropdownMenuItem<String>(
                      value: e.key,
                      child: Text(patient['firstName'] ?? 'No Name'),
                    );
                  })
                  .toList()
                  .cast<DropdownMenuItem<String>>();
              return Padding(
                padding: const EdgeInsets.all(8.0),
                child: DropdownButton<String>(
                  hint: const Text('Select Patient'),
                  value: _selectedPatientId,
                  items: patientItems,
                  onChanged: (value) {
                    setState(() {
                      _selectedPatientId = value;
                    });
                  },
                  isExpanded: true,
                ),
              );
            },
          ),
          const Divider(),
          // Medication Schedules for the selected patient.
          Expanded(
            child: _selectedPatientId == null
                ? const Center(child: Text('Please select a patient.'))
                : StreamBuilder<DatabaseEvent>(
                    stream: _scheduleRef.child(_selectedPatientId!).onValue,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(child: Text('Error: ${snapshot.error}'));
                      }
                      if (!snapshot.hasData ||
                          snapshot.data?.snapshot.value == null) {
                        return const Center(
                            child:
                                Text('No schedules found for this patient.'));
                      }
                      final schedules = Map<String, dynamic>.from(
                          snapshot.data!.snapshot.value as Map);
                      return ListView(
                        children: schedules.entries.map((entry) {
                          final schedule =
                              Map<String, dynamic>.from(entry.value);
                          return ListTile(
                            title: Text(schedule['medication'] ?? 'Medication'),
                            subtitle: Text(
                              'Dosage: ${schedule['dosage'] ?? ''} | Frequency: ${schedule['frequency'] ?? ''} | Time: ${schedule['time'] ?? ''}',
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: _selectedPatientId == null
          ? null
          : StreamBuilder<DatabaseEvent>(
              stream: _scheduleRef.child(_selectedPatientId!).onValue,
              builder: (context, snapshot) {
                // Pass current schedules to the add dialog.
                Map<String, dynamic> currentSchedules = {};
                if (snapshot.hasData && snapshot.data?.snapshot.value != null) {
                  currentSchedules = Map<String, dynamic>.from(
                      snapshot.data!.snapshot.value as Map);
                }
                return FloatingActionButton(
                  child: const Icon(Icons.add),
                  onPressed: () {
                    _showAddMedicationDialog(currentSchedules);
                  },
                );
              },
            ),
    );
  }
}
