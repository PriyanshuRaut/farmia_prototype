import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/auth_screen.dart';
import 'screens/register_screen.dart';
import 'screens/farmer_screen.dart';
import 'screens/buyer_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(FarmiaPrototype());
}

class FarmiaPrototype extends StatelessWidget {
  Future<Widget> _getLandingScreen() async {
    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      DocumentSnapshot snap = await FirebaseFirestore.instance
          .collection("users")
          .doc(currentUser.uid)
          .get();
      if (snap.exists && snap.data() != null) {
        Map data = snap.data() as Map;
        if (data['role'] == 'farmer') return FarmerScreen();
        return BuyerScreen();
      }
    }
    return AuthScreen();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Farmia Prototype',
      theme: ThemeData(primarySwatch: Colors.green),
      home: FutureBuilder<Widget>(
        future: _getLandingScreen(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Scaffold(
                body: Center(child: CircularProgressIndicator()));
          }
          if (snapshot.hasError) {
            return Scaffold(
                body: Center(child: Text('Error: ${snapshot.error}')));
          }
          return snapshot.data ?? AuthScreen();
        },
      ),
      routes: {
        '/register': (context) => RegisterScreen(),
        '/farmer': (context) => FarmerScreen(),
        '/buyer': (context) => BuyerScreen(),
        '/login': (context) => AuthScreen(),
      },
    );
  }
}
