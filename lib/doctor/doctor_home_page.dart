import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:practice/doctor/doctor_chatlist_page.dart';
import 'package:practice/medication_schedule_page.dart';
import 'package:practice/patient_profile_management_page.dart';

import 'doctor_profile.dart';
import 'doctor_requests_page.dart';
import '../inventory_management_page.dart';

class DoctorHomePage extends StatefulWidget {
  const DoctorHomePage({super.key});

  @override
  State<DoctorHomePage> createState() => _DoctorHomePageState();
}

class _DoctorHomePageState extends State<DoctorHomePage> {
  int _selectedIndex = 0;

  final List<Widget> _children = [
    DoctorRequestsPage(),
    PatientProfileManagementPage(),
    MedicationSchedulePage(),
    DoctorChatlistPage(),
    DoctorProfile(),
    InventoryManagementPage(),
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
    // ignore: deprecated_member_use
    return WillPopScope(
      onWillPop: _onWilPop,
      child: Scaffold(
        body: _children.elementAt(_selectedIndex),
        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed, // add this line
          backgroundColor: Color(0xff0064FA),
          unselectedItemColor: Color.fromARGB(255, 206, 5, 5),
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(
                icon: Icon(
                  Icons.home_filled,
                ),
                label: 'Home'),
            BottomNavigationBarItem(
                icon: Icon(
                  Icons.medication_liquid_sharp,
                ),
                label: 'Patients'),
            BottomNavigationBarItem(
                icon: Icon(
                  Icons.content_paste_search_rounded,
                ),
                label: 'medication'),
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
            BottomNavigationBarItem(
                icon: Icon(
                  Icons.inventory,
                ),
                label: 'Inventory'),
          ],
          currentIndex: _selectedIndex,
          selectedItemColor: const Color.fromARGB(255, 23, 35, 255),
          onTap: _onItmTapped,
        ),
      ),
    );
  }
}
