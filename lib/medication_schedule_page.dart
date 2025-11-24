import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:practice/services/notification_service.dart';

class MedicationSchedulePage extends StatefulWidget {
  const MedicationSchedulePage({super.key});

  @override
  State<MedicationSchedulePage> createState() => _MedicationSchedulePageState();
}

class _MedicationSchedulePageState extends State<MedicationSchedulePage> {
  final DatabaseReference _patientsRef =
      FirebaseDatabase.instance.ref('Patients');
  final DatabaseReference _scheduleRef =
      FirebaseDatabase.instance.ref('MedicationSchedules');

  final TextEditingController _medicationController = TextEditingController();
  final TextEditingController _dosageController = TextEditingController();
  final TextEditingController _frequencyController = TextEditingController();
  TimeOfDay? _selectedTime;

  String? _selectedPatientId;

  @override
  void dispose() {
    _medicationController.dispose();
    _dosageController.dispose();
    _frequencyController.dispose();
    super.dispose();
  }

  void _showAddMedicationDialog(Map<String, dynamic> currentSchedules) {
    _medicationController.clear();
    _dosageController.clear();
    _frequencyController.clear();
    _selectedTime = null;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Add Medication'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _medicationController,
                      decoration: const InputDecoration(
                        labelText: 'Medication Name',
                        prefixIcon: Icon(Icons.medication),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _dosageController,
                      decoration: const InputDecoration(
                        labelText: 'Dosage',
                        prefixIcon: Icon(Icons.numbers),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _frequencyController,
                      decoration: const InputDecoration(
                        labelText: 'Frequency',
                        prefixIcon: Icon(Icons.repeat),
                      ),
                    ),
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: () async {
                        final TimeOfDay? picked = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.now(),
                        );
                        if (picked != null) {
                          setState(() {
                            _selectedTime = picked;
                          });
                        }
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Time',
                          prefixIcon: Icon(Icons.access_time),
                          border: OutlineInputBorder(),
                        ),
                        child: Text(
                          _selectedTime?.format(context) ?? 'Select Time',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    String medication = _medicationController.text.trim();
                    String dosage = _dosageController.text.trim();
                    String frequency = _frequencyController.text.trim();

                    if (medication.isEmpty ||
                        dosage.isEmpty ||
                        frequency.isEmpty ||
                        _selectedTime == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Please fill all fields.')),
                      );
                      return;
                    }

                    String timeString = _selectedTime!.format(context);

                    // Check for conflict
                    bool conflict = false;
                    currentSchedules.forEach((key, value) {
                      final schedule = Map<String, dynamic>.from(value);
                      if (schedule['time'] == timeString) {
                        conflict = true;
                      }
                    });

                    if (conflict) {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Conflict Detected'),
                          content: Text(
                              'There is already a medication scheduled at $timeString.'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('OK'),
                            ),
                          ],
                        ),
                      );
                    } else {
                      final newRef =
                          _scheduleRef.child(_selectedPatientId!).push();

                      Map<String, dynamic> newSchedule = {
                        'medication': medication,
                        'dosage': dosage,
                        'frequency': frequency,
                        'time': timeString,
                        'timestamp': ServerValue.timestamp,
                      };

                      await newRef.set(newSchedule);

                      // Schedule Notification
                      await NotificationService().scheduleDailyNotification(
                        id: newRef.key.hashCode,
                        title: 'Medication Reminder',
                        body: 'Time to take $medication ($dosage)',
                        time: _selectedTime!,
                      );

                      if (context.mounted) Navigator.pop(context);
                    }
                  },
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditMedicationDialog(String key, Map<String, dynamic> schedule,
      Map<String, dynamic> currentSchedules) {
    _medicationController.text = schedule['medication'] ?? '';
    _dosageController.text = schedule['dosage'] ?? '';
    _frequencyController.text = schedule['frequency'] ?? '';

    // Parse time
    String timeString = schedule['time'] ?? '';
    TimeOfDay? initialTime;
    if (timeString.isNotEmpty) {
      final parts = timeString.split(' '); // "10:30 AM"
      if (parts.length == 2) {
        final timeParts = parts[0].split(':');
        int hour = int.tryParse(timeParts[0]) ?? 0;
        int minute = int.tryParse(timeParts[1]) ?? 0;
        if (parts[1] == 'PM' && hour != 12) hour += 12;
        if (parts[1] == 'AM' && hour == 12) hour = 0;
        initialTime = TimeOfDay(hour: hour, minute: minute);
      }
    }
    _selectedTime = initialTime;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Edit Medication'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _medicationController,
                      decoration: const InputDecoration(
                        labelText: 'Medication Name',
                        prefixIcon: Icon(Icons.medication),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _dosageController,
                      decoration: const InputDecoration(
                        labelText: 'Dosage',
                        prefixIcon: Icon(Icons.numbers),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _frequencyController,
                      decoration: const InputDecoration(
                        labelText: 'Frequency',
                        prefixIcon: Icon(Icons.repeat),
                      ),
                    ),
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: () async {
                        final TimeOfDay? picked = await showTimePicker(
                          context: context,
                          initialTime: _selectedTime ?? TimeOfDay.now(),
                        );
                        if (picked != null) {
                          setState(() {
                            _selectedTime = picked;
                          });
                        }
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Time',
                          prefixIcon: Icon(Icons.access_time),
                          border: OutlineInputBorder(),
                        ),
                        child: Text(
                          _selectedTime?.format(context) ?? 'Select Time',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    String medication = _medicationController.text.trim();
                    String dosage = _dosageController.text.trim();
                    String frequency = _frequencyController.text.trim();

                    if (medication.isEmpty ||
                        dosage.isEmpty ||
                        frequency.isEmpty ||
                        _selectedTime == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Please fill all fields.')),
                      );
                      return;
                    }

                    String newTimeString = _selectedTime!.format(context);

                    // Check for conflict (exclude current item)
                    bool conflict = false;
                    currentSchedules.forEach((k, value) {
                      if (k != key) {
                        final s = Map<String, dynamic>.from(value);
                        if (s['time'] == newTimeString) {
                          conflict = true;
                        }
                      }
                    });

                    if (conflict) {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Conflict Detected'),
                          content: Text(
                              'There is already a medication scheduled at $newTimeString.'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('OK'),
                            ),
                          ],
                        ),
                      );
                    } else {
                      Map<String, dynamic> updatedSchedule = {
                        'medication': medication,
                        'dosage': dosage,
                        'frequency': frequency,
                        'time': newTimeString,
                        'timestamp': ServerValue.timestamp,
                      };

                      await _scheduleRef
                          .child(_selectedPatientId!)
                          .child(key)
                          .update(updatedSchedule);

                      // Update Notification (cancel old, schedule new? or just schedule new with same ID hash?)
                      // Ideally we should cancel the old one, but we used hashcode of key.
                      // Since key is same, hashcode is same. Overwriting might work or duplicate depending on implementation.
                      // flutter_local_notifications overwrites if ID is same.
                      await NotificationService().scheduleDailyNotification(
                        id: key.hashCode, // Use key hashcode for ID
                        title: 'Medication Reminder',
                        body: 'Time to take $medication ($dosage)',
                        time: _selectedTime!,
                      );

                      if (context.mounted) Navigator.pop(context);
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Medication Schedules'),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: StreamBuilder<DatabaseEvent>(
              stream: _patientsRef.onValue,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Text('Error: ${snapshot.error}');
                }
                if (!snapshot.hasData ||
                    snapshot.data?.snapshot.value == null) {
                  return const Text('No patients found.');
                }
                final patientsData = Map<String, dynamic>.from(
                    snapshot.data!.snapshot.value as Map);
                List<DropdownMenuItem<String>> patientItems =
                    patientsData.entries
                        .map((e) {
                          final patient = Map<String, dynamic>.from(e.value);
                          return DropdownMenuItem<String>(
                            value: e.key,
                            child: Text(patient['firstName'] ?? 'No Name'),
                          );
                        })
                        .toList()
                        .cast<DropdownMenuItem<String>>();
                return DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Select Patient',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                  value: _selectedPatientId,
                  items: patientItems,
                  onChanged: (value) {
                    setState(() {
                      _selectedPatientId = value;
                    });
                  },
                );
              },
            ),
          ),
          Expanded(
            child: _selectedPatientId == null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person_search,
                            size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(
                          'Please select a patient to view schedules',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  )
                : StreamBuilder<DatabaseEvent>(
                    stream: _scheduleRef.child(_selectedPatientId!).onValue,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(child: Text('Error: ${snapshot.error}'));
                      }
                      if (!snapshot.hasData ||
                          snapshot.data?.snapshot.value == null) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.event_busy,
                                  size: 64, color: Colors.grey.shade400),
                              const SizedBox(height: 16),
                              Text(
                                'No schedules found for this patient.',
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        );
                      }
                      final schedules = Map<String, dynamic>.from(
                          snapshot.data!.snapshot.value as Map);
                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: schedules.length,
                        itemBuilder: (context, index) {
                          final entry = schedules.entries.elementAt(index);
                          final scheduleKey = entry.key;
                          final schedule =
                              Map<String, dynamic>.from(entry.value);
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(16),
                              leading: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primaryContainer,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.medication,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              title: Text(
                                schedule['medication'] ?? 'Medication',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(Icons.numbers,
                                          size: 16,
                                          color: Colors.grey.shade600),
                                      const SizedBox(width: 4),
                                      Text(
                                          'Dosage: ${schedule['dosage'] ?? ''}'),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(Icons.repeat,
                                          size: 16,
                                          color: Colors.grey.shade600),
                                      const SizedBox(width: 4),
                                      Text(
                                          'Freq: ${schedule['frequency'] ?? ''}'),
                                    ],
                                  ),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .secondaryContainer,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      schedule['time'] ?? '',
                                      style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSecondaryContainer,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.edit),
                                    onPressed: () => _showEditMedicationDialog(
                                        scheduleKey, schedule, schedules),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
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
                Map<String, dynamic> currentSchedules = {};
                if (snapshot.hasData && snapshot.data?.snapshot.value != null) {
                  currentSchedules = Map<String, dynamic>.from(
                      snapshot.data!.snapshot.value as Map);
                }
                return FloatingActionButton.extended(
                  onPressed: () => _showAddMedicationDialog(currentSchedules),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Schedule'),
                );
              },
            ),
    );
  }
}
