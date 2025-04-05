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
    final cropRef = FirebaseFirestore.instance.collection('crops').doc(widget.cropId);
    final buyerId = FirebaseAuth.instance.currentUser!.uid;

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final cropSnapshot = await transaction.get(cropRef);

        if (!cropSnapshot.exists) throw Exception("Crop not found");

        final cropData = cropSnapshot.data()!;
        final currentQty = cropData['quantity'];
        final price = cropData['price'];
        final farmerId = cropData['farmerId'];
        final cropName = cropData['name'];

        if (_quantity > currentQty) {
          throw Exception("Not enough quantity available");
        }

        final newQty = currentQty - _quantity;
        final total = price * _quantity;

        transaction.update(cropRef, {'quantity': newQty});

        final purchaseRef = FirebaseFirestore.instance.collection('purchases').doc();
        transaction.set(purchaseRef, {
          'cropId': widget.cropId,
          'farmerId': farmerId,
          'buyerId': buyerId,
          'quantity': _quantity,
          'price': price,
          'total': total,
          'timestamp': Timestamp.now(),
        });

        final notifRef = FirebaseFirestore.instance.collection('notifications').doc();
        transaction.set(notifRef, {
          'farmerId': farmerId,
          'title': 'New Purchase',
          'body': 'A buyer bought $_quantity kg of $cropName',
          'timestamp': Timestamp.now(),
        });

        setState(() {
          widget.cropData['quantity'] = newQty;
        });
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Purchase successful!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final crop = widget.cropData;

    return Scaffold(
      appBar: AppBar(
        title: Text(crop['name'], style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.teal.shade600,
        elevation: 3,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.teal.shade50, Colors.blueGrey.shade50],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: ListView(
          children: [
            buildCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(crop['name'], style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
                  SizedBox(height: 10),
                  detailRow("Price", "₹${crop['price']}"),
                  detailRow("Available", "${crop['quantity']} kg"),
                  detailRow("Harvest Date", "${crop['harvestDate']}"),
                  detailRow("Location", "${crop['location']}"),
                  SizedBox(height: 10),
                  Text("Description", style: TextStyle(fontWeight: FontWeight.w600)),
                  Text(crop['description'], style: TextStyle(color: Colors.black87)),
                  SizedBox(height: 10),
                  Text("Pricing Type: ${crop['pricingType']}", style: TextStyle(color: Colors.grey.shade700)),
                  if (farmerData != null) ...[
                    Divider(height: 30),
                    Text("Farmer Info", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                    Text("Name: ${farmerData!['name']}"),
                    Text("Email: ${farmerData!['email']}"),
                  ]
                ],
              ),
            ),
            buildCard(
              child: Column(
                children: [
                  TextFormField(
                    controller: _messageController,
                    decoration: inputDecoration("Send a message"),
                  ),
                  SizedBox(height: 12),
                  buildButton("Send Message", Colors.teal, () {
                    sendMessage(_messageController.text);
                  }),
                ],
              ),
            ),
            if (crop['pricingType'] == 'fixed') buildFixedPricingCard(crop),
            if (crop['pricingType'] == 'bidding') buildBidCard(),
            if (crop['pricingType'] == 'negotiable') buildNegotiationCard(),
          ],
        ),
      ),
    );
  }

  Widget buildCard({required Widget child}) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 3,
      margin: EdgeInsets.only(bottom: 20),
      child: Padding(
        padding: EdgeInsets.all(18),
        child: child,
      ),
    );
  }

  Widget detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text("$label: ", style: TextStyle(fontWeight: FontWeight.w500)),
          Text(value),
        ],
      ),
    );
  }

  InputDecoration inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    );
  }

  Widget buildButton(String label, Color color, VoidCallback onPressed) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: EdgeInsets.symmetric(vertical: 14, horizontal: 24),
      ),
      onPressed: onPressed,
      child: Text(label, style: TextStyle(fontSize: 16, color: Colors.white)),
    );
  }

  Widget buildFixedPricingCard(Map<String, dynamic> crop) {
    return buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Quantity:', style: TextStyle(fontSize: 16)),
              SizedBox(width: 12),
              DropdownButton<int>(
                value: _quantity,
                onChanged: crop['quantity'] == 0 ? null : (val) => setState(() => _quantity = val!),
                items: List.generate(crop['quantity'], (i) => i + 1)
                    .map((e) => DropdownMenuItem(value: e, child: Text('$e kg')))
                    .toList(),
              ),
            ],
          ),
          SizedBox(height: 12),
          buildButton(
            crop['quantity'] == 0 ? 'Sold Out' : 'Buy Now',
            crop['quantity'] == 0 ? Colors.grey : Colors.green.shade600,
            crop['quantity'] == 0 ? () {} : buyCrop,
          ),
        ],
      ),
    );
  }

  Widget buildBidCard() {
    return buildCard(
      child: Column(
        children: [
          TextFormField(
            controller: _bidController,
            keyboardType: TextInputType.number,
            decoration: inputDecoration("Enter your bid (₹)"),
          ),
          SizedBox(height: 12),
          buildButton("Place Bid", Colors.orange.shade700, () {
            placeBid(double.parse(_bidController.text));
          }),
        ],
      ),
    );
  }

  Widget buildNegotiationCard() {
    return buildCard(
      child: Column(
        children: [
          TextFormField(
            controller: _negotiateController,
            keyboardType: TextInputType.number,
            decoration: inputDecoration("Propose your price (₹)"),
          ),
          SizedBox(height: 12),
          buildButton("Send Offer", Colors.purple.shade600, () {
            negotiatePrice(double.parse(_negotiateController.text));
          }),
        ],
      ),
    );
  }
}
