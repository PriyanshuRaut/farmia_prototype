import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'register_screen.dart';
import 'farmer_screen.dart';
import 'buyer_screen.dart';

class AuthScreen extends StatefulWidget {
  @override
  _AuthScreenState createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  bool _isLoading = false;
  void _login() async {
    setState(() {
      _isLoading = true;
    });
    try {
      UserCredential user = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: _email.text, password: _password.text);
      DocumentSnapshot snap = await FirebaseFirestore.instance.collection("users").doc(user.user!.uid).get();
      if (snap.exists && snap.data() != null) {
        Map data = snap.data() as Map;
        if (data['role'] == 'farmer') {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => FarmerScreen()));
        } else {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => BuyerScreen()));
        }
      }
    } catch (e) {
      showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
                title: Text('Error'),
                content: Text(e.toString()),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context), child: Text('OK'))
                ]);
          });
    }
    setState(() {
      _isLoading = false;
    });
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.green.shade800, Colors.greenAccent], begin: Alignment.topLeft, end: Alignment.bottomRight)),
        padding: EdgeInsets.all(24),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              children: [
                Text('Farmia', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
                SizedBox(height: 20),
                TextField(
                  controller: _email,
                  style: TextStyle(color: Colors.white),
                  decoration: InputDecoration(hintText: 'Email', hintStyle: TextStyle(color: Colors.white70), enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white70)), focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white))),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: _password,
                  obscureText: true,
                  style: TextStyle(color: Colors.white),
                  decoration: InputDecoration(hintText: 'Password', hintStyle: TextStyle(color: Colors.white70), enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white70)), focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white))),
                ),
                SizedBox(height: 16),
                _isLoading ? CircularProgressIndicator() : ElevatedButton(
                  style: ElevatedButton.styleFrom(foregroundColor: Colors.green, backgroundColor: Colors.white, padding: EdgeInsets.symmetric(horizontal: 50, vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
                  onPressed: _login,
                  child: Text('Login', style: TextStyle(fontSize: 18)),
                ),
                SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => RegisterScreen()));
                  },
                  child: Text('Register', style: TextStyle(color: Colors.white70, fontSize: 16)),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
