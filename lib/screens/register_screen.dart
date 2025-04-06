import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'farmer_screen.dart';
import 'buyer_screen.dart';
import 'auth_screen.dart';

class RegisterScreen extends StatefulWidget {
  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _name = TextEditingController();
  String _role = 'farmer';
  bool _isLoading = false;

  void _register() async {
    setState(() {
      _isLoading = true;
    });
    try {
      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
          email: _email.text.trim(), password: _password.text);

      await userCredential.user!.sendEmailVerification();

      String uid = userCredential.user!.uid;
      Map<String, dynamic> userData = {
        'name': _name.text,
        'email': _email.text.trim(),
        'role': _role,
        'createdAt': FieldValue.serverTimestamp()
      };

      await FirebaseFirestore.instance.collection('users').doc(uid).set(userData);

      if (_role == 'farmer') {
        await FirebaseFirestore.instance.collection('farmer').doc(uid).set(userData);
      } else {
        await FirebaseFirestore.instance.collection('buyers').doc(uid).set(userData);
      }

      await FirebaseAuth.instance.signOut();
      showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: Text('Email Verification'),
              content: Text(
                  'A verification email has been sent to your email address. Please verify your email before logging in.'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pop(context);
                  },
                  child: Text('OK'),
                )
              ],
            );
          });
    } catch (e) {
      showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: Text('Error'),
              content: Text(e.toString()),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('OK'))
              ],
            );
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
        decoration: BoxDecoration(
            gradient: LinearGradient(
                colors: [Colors.teal.shade800, Colors.tealAccent],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft)),
        padding: EdgeInsets.all(24),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              children: [
                Text('Register',
                    style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
                SizedBox(height: 20),
                TextField(
                  controller: _name,
                  style: TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                      hintText: 'Name',
                      hintStyle: TextStyle(color: Colors.white70),
                      enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white70)),
                      focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white))),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: _email,
                  style: TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                      hintText: 'Email',
                      hintStyle: TextStyle(color: Colors.white70),
                      enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white70)),
                      focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white))),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: _password,
                  obscureText: true,
                  style: TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                      hintText: 'Password',
                      hintStyle: TextStyle(color: Colors.white70),
                      enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white70)),
                      focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white))),
                ),
                SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ChoiceChip(
                      label: Text('Farmer',
                          style: TextStyle(
                              color: _role == 'farmer'
                                  ? Colors.black
                                  : Colors.black38)),
                      selected: _role == 'farmer',
                      selectedColor: Colors.white,
                      onSelected: (selected) {
                        setState(() {
                          _role = 'farmer';
                        });
                      },
                    ),
                    SizedBox(width: 16),
                    ChoiceChip(
                      label: Text('Buyer',
                          style: TextStyle(
                              color: _role == 'buyer'
                                  ? Colors.black
                                  : Colors.black38)),
                      selected: _role == 'buyer',
                      selectedColor: Colors.white,
                      onSelected: (selected) {
                        setState(() {
                          _role = 'buyer';
                        });
                      },
                    )
                  ],
                ),
                SizedBox(height: 16),
                _isLoading
                    ? CircularProgressIndicator()
                    : ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.teal,
                      backgroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                          horizontal: 50, vertical: 15),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30))),
                  onPressed: _register,
                  child: Text('Register',
                      style: TextStyle(fontSize: 18)),
                ),
                SizedBox(height: 16),
                TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: Text('Back to Login',
                        style: TextStyle(
                            color: Colors.white70, fontSize: 16)))
              ],
            ),
          ),
        ),
      ),
    );
  }
}
