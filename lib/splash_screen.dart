import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:practice/auth/login_page.dart';
import 'package:practice/doctor/doctor_home_page.dart';
import 'package:practice/patient/patient_home_page.dart';

class SplashScreen extends StatefulWidget {
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    User? user = _auth.currentUser;

    if (user == null) {
      await Future.delayed(Duration(seconds: 2));
      _navigateToLogin();
    } else {
      DatabaseReference userRef = _database.child('Doctors').child(user.uid);
      DataSnapshot snapshot = await userRef.get();

      if (snapshot.exists) {
        await Future.delayed(Duration(seconds: 2));
        _navigateToDoctorHome();
      } else {
        userRef = _database.child('Patients').child(user.uid);
        snapshot = await userRef.get();
        if (snapshot.exists) {
          await Future.delayed(Duration(seconds: 2));
          _navigateToPatientHome();
        } else {
          await Future.delayed(Duration(seconds: 2));
          _navigateToLogin();
        }
      }
    }
  }

  void _navigateToLogin() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (context) => LoginPage()));
  }

  void _navigateToDoctorHome() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (context) => DoctorHomePage()));
  }

  void _navigateToPatientHome() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (context) => PatientHomePage()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xff0F172A), Color(0xff2563EB)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Hero(
                  tag: 'splash-hero',
                  child: Image.asset(
                    'assets/images/login_bg.png',
                    width: MediaQuery.of(context).size.width * 0.75,
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'Guardian Health',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Personalized care for patients and seamless coordination for doctors.',
                  style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
