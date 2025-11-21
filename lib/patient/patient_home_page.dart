import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:practice/doctor/doctor_list_page.dart';
import 'package:practice/patient/caregiver_request_page.dart';
import 'package:practice/patient/chat_list_page.dart';
import 'package:practice/profile_page.dart';

class PatientHomePage extends StatefulWidget {
  const PatientHomePage({super.key});

  @override
  State<PatientHomePage> createState() => _PatientHomePageState();
}

class _PatientHomePageState extends State<PatientHomePage> {
  int _selectedIndex = 0;

  final List<Widget> _children = const [
    DoctorListPage(),
    CaregiverRequestPage(),
    ChatListPage(),
    ProfilePage(),
  ];

  void _onItmTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<bool> _onWilPop() async {
    return await showDialog(
        context: context,
        builder: (context) => AlertDialog(
              title: Text('Are you sure?'),
              content: Text('Do you want to exit the app?'),
              actions: <Widget>[
                TextButton(
                    onPressed: () {
                      Navigator.of(context).pop(false);
                    },
                    child: Text('No')),
                TextButton(
                    onPressed: () {
                      Navigator.of(context).pop(true);
                      SystemNavigator.pop();
                    },
                    child: Text('Yes')),
              ],
            ));
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWilPop,
      child: Scaffold(
        body: _children.elementAt(_selectedIndex),
        bottomNavigationBar: BottomNavigationBar(
          backgroundColor: const Color(0xff0F172A),
          unselectedItemColor: const Color(0xffBEBEBE),
          type: BottomNavigationBarType.fixed,
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(
                icon: Icon(
                  Icons.home_filled,
                ),
                label: 'Home'),
            BottomNavigationBarItem(
                icon: Icon(
                  Icons.volunteer_activism,
                ),
                label: 'Requests'),
            BottomNavigationBarItem(
                icon: Icon(
                  Icons.chat,
                ),
                label: 'Chat'),
            BottomNavigationBarItem(
                icon: Icon(
                  Icons.person,
                ),
                label: 'Profile'),
          ],
          currentIndex: _selectedIndex,
          selectedItemColor: Colors.white,
          onTap: _onItmTapped,
        ),
      ),
    );
  }
}
