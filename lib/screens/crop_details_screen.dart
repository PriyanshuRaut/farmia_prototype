import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CropDetailsScreen extends StatefulWidget {
  final String cropId;
  final Map<String, dynamic> cropData;

  CropDetailsScreen({required this.cropId, required this.cropData});

  @override
  _CropDetailsScreenState createState() => _CropDetailsScreenState();
}

class _CropDetailsScreenState extends State<CropDetailsScreen> {
  int _quantity = 1;
  final _messageController = TextEditingController();
  final _bidController = TextEditingController();
  final _negotiateController = TextEditingController();
  Map<String, dynamic>? farmerData;

  @override
  void initState() {
    super.initState();
    fetchFarmerData();
  }

  Future<void> fetchFarmerData() async {
    final farmerId = widget.cropData['farmerId'];
    final doc = await FirebaseFirestore.instance.collection('users').doc(farmerId).get();
    if (doc.exists) {
      setState(() => farmerData = doc.data());
    }
  }

  Future<void> sendMessage(String message) async {
    final buyerId = FirebaseAuth.instance.currentUser!.uid;
    final chatRef = FirebaseFirestore.instance.collection('chats').doc();
    await chatRef.set({
      'cropId': widget.cropId,
      'farmerId': widget.cropData['farmerId'],
      'buyerId': buyerId,
      'message': message,
      'timestamp': Timestamp.now(),
    });
  }

  Future<void> placeBid(double bid) async {
    final buyerId = FirebaseAuth.instance.currentUser!.uid;
    await FirebaseFirestore.instance.collection('bids').add({
      'cropId': widget.cropId,
      'farmerId': widget.cropData['farmerId'],
      'buyerId': buyerId,
      'bid': bid,
      'timestamp': Timestamp.now(),
    });

    await FirebaseFirestore.instance.collection('notifications').add({
      'farmerId': widget.cropData['farmerId'],
      'title': 'New Bid',
      'body': 'A buyer placed a bid of ₹$bid on ${widget.cropData['name']}',
      'timestamp': Timestamp.now(),
    });
  }

  Future<void> negotiatePrice(double offer) async {
    final buyerId = FirebaseAuth.instance.currentUser!.uid;
    await FirebaseFirestore.instance.collection('negotiations').add({
      'cropId': widget.cropId,
      'farmerId': widget.cropData['farmerId'],
      'buyerId': buyerId,
      'offer': offer,
      'timestamp': Timestamp.now(),
    });

    await FirebaseFirestore.instance.collection('notifications').add({
      'farmerId': widget.cropData['farmerId'],
      'title': 'Negotiation Request',
      'body': 'A buyer offered ₹$offer for ${widget.cropData['name']}',
      'timestamp': Timestamp.now(),
    });
  }

  Future<void> buyCrop() async {
    final newQty = widget.cropData['quantity'] - _quantity;
    if (newQty < 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Not enough quantity available')));
      return;
    }

    await FirebaseFirestore.instance.collection('crops').doc(widget.cropId).update({
      'quantity': newQty,
    });

    await FirebaseFirestore.instance.collection('purchases').add({
      'cropId': widget.cropId,
      'farmerId': widget.cropData['farmerId'],
      'buyerId': FirebaseAuth.instance.currentUser!.uid,
      'quantity': _quantity,
      'price': widget.cropData['price'],
      'total': _quantity * widget.cropData['price'],
      'timestamp': Timestamp.now(),
    });

    await FirebaseFirestore.instance.collection('notifications').add({
      'farmerId': widget.cropData['farmerId'],
      'title': 'New Purchase',
      'body': 'A buyer bought $_quantity kg of ${widget.cropData['name']}',
      'timestamp': Timestamp.now(),
    });

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Purchase successful!')));
  }

  @override
  Widget build(BuildContext context) {
    final crop = widget.cropData;

    return Scaffold(
      appBar: AppBar(title: Text(crop['name'])),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.indigo.shade800, Colors.indigo.shade400],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        padding: EdgeInsets.all(16),
        child: ListView(
          children: [
            Card(
              color: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(crop['name'], style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    Text("Price: ₹${crop['price']}"),
                    Text("Available: ${crop['quantity']} kg"),
                    Text("Harvest Date: ${crop['harvestDate']}"),
                    Text("Location: ${crop['location']}"),
                    Text("Description: ${crop['description']}"),
                    Text("Pricing Type: ${crop['pricingType']}"),
                    SizedBox(height: 16),
                    if (farmerData != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Farmer Details", style: TextStyle(fontWeight: FontWeight.bold)),
                          Text("Name: ${farmerData!['name']}"),
                          Text("Email: ${farmerData!['email']}"),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
            Card(
              color: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _messageController,
                      decoration: InputDecoration(labelText: 'Send a message'),
                    ),
                    SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: () => sendMessage(_messageController.text),
                      child: Text('Send Message'),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
            if (crop['pricingType'] == 'fixed') ...[
              Card(
                color: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Text('Quantity:'),
                          SizedBox(width: 10),
                          DropdownButton<int>(
                            value: _quantity,
                            onChanged: (val) => setState(() => _quantity = val!),
                            items: List.generate(crop['quantity'], (i) => i + 1)
                                .map((e) => DropdownMenuItem(value: e, child: Text('$e kg')))
                                .toList(),
                          ),
                        ],
                      ),
                      ElevatedButton(
                        onPressed: buyCrop,
                        child: Text('Buy Now'),
                      ),
                    ],
                  ),
                ),
              ),
            ] else if (crop['pricingType'] == 'bidding') ...[
              Card(
                color: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _bidController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(labelText: 'Enter your bid (₹)'),
                      ),
                      SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: () => placeBid(double.parse(_bidController.text)),
                        child: Text('Place Bid'),
                      ),
                    ],
                  ),
                ),
              ),
            ] else if (crop['pricingType'] == 'negotiable') ...[
              Card(
                color: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _negotiateController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(labelText: 'Propose your price (₹)'),
                      ),
                      SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: () => negotiatePrice(double.parse(_negotiateController.text)),
                        child: Text('Send Offer'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
