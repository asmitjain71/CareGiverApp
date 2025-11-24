import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:practice/auth/login_page.dart';

import 'doctor/model/booking.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _requestDatabase =
      FirebaseDatabase.instance.ref().child('Requests');
  final DatabaseReference _patientsRef =
      FirebaseDatabase.instance.ref().child('Patients');
  final DatabaseReference _doctorsRef =
      FirebaseDatabase.instance.ref().child('Doctors');

  List<Booking> _bookings = [];
  Map<String, dynamic>? _userDetails;
  bool _isLoading = true;
  String? _userRole;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    await Future.wait([
      _fetchUserDetails(),
      _fetchBookings(),
    ]);
  }

  Future<void> _fetchUserDetails() async {
    String? currentUserId = _auth.currentUser?.uid;
    if (currentUserId != null) {
      // Try fetching from Patients
      final patientSnapshot = await _patientsRef.child(currentUserId).get();
      if (patientSnapshot.exists) {
        setState(() {
          _userDetails = Map<String, dynamic>.from(
              patientSnapshot.value as Map<dynamic, dynamic>);
          _userRole = 'Patient';
        });
        return;
      }

      // Try fetching from Doctors
      final doctorSnapshot = await _doctorsRef.child(currentUserId).get();
      if (doctorSnapshot.exists) {
        setState(() {
          _userDetails = Map<String, dynamic>.from(
              doctorSnapshot.value as Map<dynamic, dynamic>);
          _userRole = 'Doctor';
        });
      }
    }
  }

  Future<void> _fetchBookings() async {
    String? currentUserId = _auth.currentUser?.uid;
    if (currentUserId != null) {
      await _requestDatabase
          .orderByChild('sender')
          .equalTo(currentUserId)
          .once()
          .then((DatabaseEvent event) {
        if (event.snapshot.value != null) {
          Map<dynamic, dynamic> bookingMap =
              event.snapshot.value as Map<dynamic, dynamic>;
          List<Booking> tempBookings = [];
          bookingMap.forEach((key, value) {
            tempBookings.add(Booking.fromMap(Map<String, dynamic>.from(value)));
          });
          setState(() {
            _bookings = tempBookings;
          });
        }
        setState(() {
          _isLoading = false;
        });
      });
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _logout() async {
    await _auth.signOut();
    Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => LoginPage()),
        (Route<dynamic> route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Profile'),
        actions: [IconButton(onPressed: _logout, icon: Icon(Icons.logout))],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_userDetails != null) ...[
                    Center(
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundImage: _userDetails!['profileImageUrl'] !=
                                        null &&
                                    _userDetails!['profileImageUrl'].isNotEmpty
                                ? NetworkImage(_userDetails!['profileImageUrl'])
                                : null,
                            child: _userDetails!['profileImageUrl'] == null ||
                                    _userDetails!['profileImageUrl'].isEmpty
                                ? Icon(Icons.person, size: 50)
                                : null,
                          ),
                          SizedBox(height: 16),
                          Text(
                            '${_userDetails!['firstName']} ${_userDetails!['lastName']}',
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            _userRole ?? 'User',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 24),
                    _buildInfoCard(),
                    SizedBox(height: 24),
                  ],
                  Text(
                    'My Bookings',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  _bookings.isEmpty
                      ? Center(
                          child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text('No booking available'),
                        ))
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: NeverScrollableScrollPhysics(),
                          itemCount: _bookings.length,
                          itemBuilder: (context, index) {
                            final booking = _bookings[index];
                            return Card(
                              margin: EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                title: Text(booking.description),
                                subtitle: Text(
                                    'Date: ${booking.date} Time: ${booking.time}'),
                                trailing: Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: booking.status == 'Accepted'
                                        ? Colors.green.withOpacity(0.1)
                                        : Colors.orange.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: booking.status == 'Accepted'
                                          ? Colors.green
                                          : Colors.orange,
                                    ),
                                  ),
                                  child: Text(
                                    booking.status,
                                    style: TextStyle(
                                      color: booking.status == 'Accepted'
                                          ? Colors.green
                                          : Colors.orange,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                ],
              ),
            ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildInfoRow(Icons.email, 'Email', _userDetails!['email']),
            Divider(),
            _buildInfoRow(
                Icons.phone, 'Phone', _userDetails!['phoneNumber'] ?? 'N/A'),
            Divider(),
            _buildInfoRow(
                Icons.location_city, 'City', _userDetails!['city'] ?? 'N/A'),
            if (_userRole == 'Doctor') ...[
              Divider(),
              _buildInfoRow(Icons.medical_services, 'Category',
                  _userDetails!['category'] ?? 'N/A'),
              Divider(),
              _buildInfoRow(Icons.school, 'Qualification',
                  _userDetails!['qualification'] ?? 'N/A'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.grey),
        SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            Text(value, style: TextStyle(fontSize: 16)),
          ],
        ),
      ],
    );
  }
}
