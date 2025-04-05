import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FarmerScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    String uid = FirebaseAuth.instance.currentUser!.uid;
    return Scaffold(
      appBar: AppBar(title: Text('Farmer Panel')),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text('Error fetching data'));
          if (!snapshot.hasData || !snapshot.data!.exists) return Center(child: Text('No data found'));
          Map<String, dynamic> data = snapshot.data!.data() as Map<String, dynamic>;
          return Container(
            decoration: BoxDecoration(
                gradient: LinearGradient(colors: [Colors.brown.shade800, Colors.brown.shade400], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
            child: Center(child: Text('Welcome ${data['name']}', style: TextStyle(fontSize: 24, color: Colors.white))),
          );
        },
      ),
    );
  }
}
