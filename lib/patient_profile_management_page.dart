import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class PatientProfileManagementPage extends StatefulWidget {
  const PatientProfileManagementPage({super.key});

  @override
  State<PatientProfileManagementPage> createState() =>
      _PatientProfileManagementPageState();
}

class _PatientProfileManagementPageState
    extends State<PatientProfileManagementPage> {
  final DatabaseReference patientsRef =
      FirebaseDatabase.instance.ref().child('Patients');

  final _formKey = GlobalKey<FormState>();

  // Controllers for the patient form.
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _historyController = TextEditingController();
  final TextEditingController _medicationNeedsController =
      TextEditingController();

  // Show dialog for adding or editing a patient.
  void _showPatientDialog({String? key, Map<String, dynamic>? data}) {
    if (data != null) {
      _nameController.text = data['firstName'] ?? '';
      _ageController.text = data['age'] ?? '';
      _dobController.text = data['dob'] ?? '';
      _phoneController.text = data['phoneNumber'] ?? '';
      _historyController.text = data['medicalHistory'] ?? '';
      _medicationNeedsController.text = data['medicationNeeds'] ?? '';
    } else {
      _nameController.clear();
      _ageController.clear();
      _dobController.clear();
      _phoneController.clear();
      _historyController.clear();
      _medicationNeedsController.clear();
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(key == null ? 'Add New Patient' : 'Edit Patient'),
          content: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(labelText: 'Name *'),
                    validator: (value) => value == null || value.isEmpty
                        ? 'Name is required'
                        : null,
                  ),
                  TextFormField(
                    controller: _ageController,
                    decoration: InputDecoration(labelText: 'Age *'),
                    keyboardType: TextInputType.number,
                    validator: (value) => value == null || value.isEmpty
                        ? 'Age is required'
                        : null,
                  ),
                  TextFormField(
                    controller: _dobController,
                    decoration:
                        InputDecoration(labelText: 'Date of Birth (optional)'),
                  ),
                  TextFormField(
                    controller: _phoneController,
                    decoration:
                        InputDecoration(labelText: 'Phone Number (optional)'),
                  ),
                  TextFormField(
                    controller: _historyController,
                    decoration: InputDecoration(labelText: 'Medical History'),
                  ),
                  TextFormField(
                    controller: _medicationNeedsController,
                    decoration: InputDecoration(labelText: 'Medication Needs'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                if (_formKey.currentState!.validate()) {
                  Map<String, dynamic> patientData = {
                    'firstName': _nameController.text,
                    'age': _ageController.text,
                    'dob': _dobController.text,
                    'phoneNumber': _phoneController.text,
                    'medicalHistory': _historyController.text,
                    'medicationNeeds': _medicationNeedsController.text,
                    'timestamp': ServerValue.timestamp,
                  };

                  if (key == null) {
                    // Add new patient.
                    await patientsRef.push().set(patientData);
                  } else {
                    // Update existing patient.
                    await patientsRef.child(key).update(patientData);
                  }
                  Navigator.pop(context);
                }
              },
              child: Text(key == null ? 'Add' : 'Save'),
            ),
          ],
        );
      },
    );
  }

  // Delete a patient profile using its key.
  void _deletePatient(String key) async {
    await patientsRef.child(key).remove();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _dobController.dispose();
    _phoneController.dispose();
    _historyController.dispose();
    _medicationNeedsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Manage Patient Profiles'),
      ),
      body: StreamBuilder<DatabaseEvent>(
        stream: patientsRef.onValue,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData) {
            return Center(child: Text('No patient profiles found.'));
          }
          final dbEvent = snapshot.data!;
          if (dbEvent.snapshot.value == null) {
            return Center(child: Text('No patient profiles found.'));
          }
          final data = dbEvent.snapshot.value as Map<dynamic, dynamic>;
          return ListView(
            children: data.entries.map((entry) {
              final patientKey = entry.key.toString();
              final patientData = Map<String, dynamic>.from(
                  entry.value as Map<dynamic, dynamic>);
              return ListTile(
                title: Text(patientData['firstName'] ?? 'No Name'),
                subtitle:
                    Text('Age: ${patientData['age']?.toString() ?? 'N/A'}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.edit),
                      onPressed: () => _showPatientDialog(
                        key: patientKey,
                        data: patientData,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.delete),
                      onPressed: () => _deletePatient(patientKey),
                    ),
                  ],
                ),
              );
            }).toList(),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.add),
        onPressed: () => _showPatientDialog(),
      ),
    );
  }
}
