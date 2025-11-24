import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import 'model/booking.dart';

class DoctorRequestsPage extends StatefulWidget {
  const DoctorRequestsPage({super.key});

  @override
  State<DoctorRequestsPage> createState() => _DoctorRequestsPageState();
}

class _DoctorRequestsPageState extends State<DoctorRequestsPage>
    with SingleTickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _requestDatabase =
      FirebaseDatabase.instance.ref().child('Requests');
  final DatabaseReference _caregiverRequestsRef =
      FirebaseDatabase.instance.ref().child('CaregiverRequests');
  final DatabaseReference _patientsRef =
      FirebaseDatabase.instance.ref().child('Patients');

  List<Booking> _bookings = [];
  List<Map<String, dynamic>> _caregiverRequests = [];
  bool _isLoading = true;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _fetchBookings(),
      _fetchCaregiverRequests(),
    ]);
    setState(() => _isLoading = false);
  }

  Future<void> _fetchBookings() async {
    String? currentUserId = _auth.currentUser?.uid;
    if (currentUserId != null) {
      final event = await _requestDatabase
          .orderByChild('receiver')
          .equalTo(currentUserId)
          .once();
      if (event.snapshot.value != null) {
        Map<dynamic, dynamic> bookingMap =
            event.snapshot.value as Map<dynamic, dynamic>;
        _bookings.clear();
        bookingMap.forEach((key, value) {
          _bookings.add(Booking.fromMap(Map<String, dynamic>.from(value)));
        });
      }
    }
  }

  Future<void> _fetchCaregiverRequests() async {
    final event = await _caregiverRequestsRef.once();
    if (event.snapshot.value != null) {
      Map<dynamic, dynamic> allRequests =
          event.snapshot.value as Map<dynamic, dynamic>;
      List<Map<String, dynamic>> tempRequests = [];

      // Fetch patient details to map names
      final patientsEvent = await _patientsRef.once();
      Map<String, String> patientNames = {};
      if (patientsEvent.snapshot.value != null) {
        Map<dynamic, dynamic> patients =
            patientsEvent.snapshot.value as Map<dynamic, dynamic>;
        patients.forEach((key, value) {
          final p = Map<String, dynamic>.from(value);
          patientNames[key] = '${p['firstName']} ${p['lastName']}';
        });
      }

      allRequests.forEach((patientId, requests) {
        Map<dynamic, dynamic> patientRequests =
            requests as Map<dynamic, dynamic>;
        patientRequests.forEach((requestId, requestData) {
          final data = Map<String, dynamic>.from(requestData);
          data['requestId'] = requestId;
          data['patientId'] = patientId;
          data['patientName'] = patientNames[patientId] ?? 'Unknown Patient';
          tempRequests.add(data);
        });
      });

      // Sort by timestamp descending
      tempRequests.sort((a, b) {
        int timeA = a['timestamp'] ?? 0;
        int timeB = b['timestamp'] ?? 0;
        return timeB.compareTo(timeA);
      });

      _caregiverRequests = tempRequests;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Doctor Requests'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Appointments'),
            Tab(text: 'Patient Requests'),
          ],
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildAppointmentsList(),
                _buildCaregiverRequestsList(),
              ],
            ),
    );
  }

  Widget _buildAppointmentsList() {
    return _bookings.isEmpty
        ? Center(child: Text('No appointments available'))
        : ListView.builder(
            itemCount: _bookings.length,
            itemBuilder: (context, index) {
              final booking = _bookings[index];
              return ListTile(
                title: Text(booking.description),
                subtitle: Text('Date: ${booking.date} Time: ${booking.time}'),
                trailing: Text(booking.status),
                onTap: () => _showStatusDialog(booking.id, booking.status),
              );
            });
  }

  Widget _buildCaregiverRequestsList() {
    return _caregiverRequests.isEmpty
        ? Center(child: Text('No patient requests available'))
        : ListView.builder(
            itemCount: _caregiverRequests.length,
            itemBuilder: (context, index) {
              final request = _caregiverRequests[index];
              return Card(
                margin: EdgeInsets.all(8),
                child: ListTile(
                  title: Text(request['message'] ?? 'No message'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Patient: ${request['patientName']}'),
                      if (request['medication'] != null)
                        Text(
                            'Medication: ${request['medication']['medication']}'),
                      Text(
                          'Date: ${DateTime.fromMillisecondsSinceEpoch(request['timestamp'] ?? 0).toString().split('.')[0]}'),
                    ],
                  ),
                  trailing: Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(request['status']),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      request['status'] ?? 'pending',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                  onTap: () => _showCaregiverRequestStatusDialog(request),
                ),
              );
            });
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'resolved':
        return Colors.green;
      case 'in-progress':
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }

  void _showStatusDialog(String requestId, String currentStatus) {
    List<String> statuses = ['Accepted', 'Rejected', 'Completed'];
    String selectedStatus = currentStatus;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Update Appointment Status'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Please select the status for this appointment.'),
                  SizedBox(height: 16.0),
                  Column(
                    children: List.generate(statuses.length, (index) {
                      return RadioListTile<String>(
                        title: Text(statuses[index]),
                        value: statuses[index],
                        groupValue: selectedStatus,
                        onChanged: (value) {
                          setState(() {
                            selectedStatus = value!;
                          });
                        },
                      );
                    }),
                  ),
                ],
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
                    await _updateRequestStatus(requestId, selectedStatus);
                    Navigator.pop(context);
                  },
                  child: Text('Update'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showCaregiverRequestStatusDialog(Map<String, dynamic> request) {
    List<String> statuses = ['pending', 'in-progress', 'resolved'];
    String selectedStatus = request['status'] ?? 'pending';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Update Request Status'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Please select the status for this request.'),
                  SizedBox(height: 16.0),
                  Column(
                    children: List.generate(statuses.length, (index) {
                      return RadioListTile<String>(
                        title: Text(statuses[index].toUpperCase()),
                        value: statuses[index],
                        groupValue: selectedStatus,
                        onChanged: (value) {
                          setState(() {
                            selectedStatus = value!;
                          });
                        },
                      );
                    }),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel'),
                ),
                TextButton(
                  onPressed: () async {
                    await _caregiverRequestsRef
                        .child(request['patientId'])
                        .child(request['requestId'])
                        .update({'status': selectedStatus});
                    _fetchData(); // Refresh
                    Navigator.pop(context);
                  },
                  child: Text('Update'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _updateRequestStatus(String requestId, String status) async {
    await _requestDatabase.child(requestId).update({
      'status': status,
    });
    await _fetchBookings();
  }
}
