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
  Future<String> getBuyerName() async {
    final buyerId = FirebaseAuth.instance.currentUser!.uid;
    final doc = await FirebaseFirestore.instance.collection('users').doc(buyerId).get();
    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>;
      return data['name'] ?? 'Unknown Buyer';
    }
    return 'Unknown Buyer';
  }
  Future<void> sendMessage(String message) async {
    final buyerId = FirebaseAuth.instance.currentUser!.uid;
    final buyerName = await getBuyerName();
    final chatRef = FirebaseFirestore.instance.collection('chats').doc();
    await chatRef.set({
      'cropId': widget.cropId,
      'farmerId': widget.cropData['farmerId'],
      'buyerId': buyerId,
      'buyerName': buyerName,
      'message': message,
      'timestamp': Timestamp.now(),
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Message sent!')),
    );
  }
  Future<void> placeBid(double bid) async {
    final buyerId = FirebaseAuth.instance.currentUser!.uid;
    final buyerName = await getBuyerName();
    final bidQuery = await FirebaseFirestore.instance
        .collection('bids')
        .where('cropId', isEqualTo: widget.cropId)
        .orderBy('bid', descending: true)
        .limit(1)
        .get();
    double highestBid = 0;
    if (bidQuery.docs.isNotEmpty) {
      highestBid = (bidQuery.docs.first.data()['bid'] as num).toDouble();
    }
    if (bid <= highestBid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Your bid must be higher than the current highest bid of ₹$highestBid')),
      );
      return;
    }
    await FirebaseFirestore.instance.collection('bids').add({
      'cropId': widget.cropId,
      'farmerId': widget.cropData['farmerId'],
      'buyerId': buyerId,
      'buyerName': buyerName,
      'bid': bid,
      'timestamp': Timestamp.now(),
    });
    await FirebaseFirestore.instance.collection('notifications').add({
      'farmerId': widget.cropData['farmerId'],
      'title': 'New Bid',
      'body': 'A buyer placed a bid of ₹$bid on ${capitalize(widget.cropData['name'])}',
      'timestamp': Timestamp.now(),
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Bid placed successfully!')),
    );
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
      'body': 'A buyer offered ₹$offer for ${capitalize(widget.cropData['name'])}',
      'timestamp': Timestamp.now(),
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Negotiation sent successfully!')),
    );
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

        final farmerNotifRef = FirebaseFirestore.instance.collection('notifications').doc();
        transaction.set(farmerNotifRef, {
          'farmerId': farmerId,
          'title': 'New Purchase',
          'body': 'A buyer purchased $_quantity kg of ${capitalize(cropName)}.',
          'timestamp': Timestamp.now(),
        });

        final buyerNotifRef = FirebaseFirestore.instance.collection('notifications').doc();
        transaction.set(buyerNotifRef, {
          'buyerId': buyerId,
          'title': 'Purchase Successful',
          'body': 'You successfully purchased $_quantity kg of ${capitalize(cropName)} for ₹${total.toStringAsFixed(2)}.',
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
  String capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1).toLowerCase();
  }
  Widget buildBidHistory() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('bids')
          .where('cropId', isEqualTo: widget.cropId)
          .orderBy('bid', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return SizedBox.shrink();
        final bids = snapshot.data!.docs;
        if (bids.isEmpty) return Text('No bids yet.');
        return buildCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Bid History', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              SizedBox(height: 12),
              ...bids.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final buyerName = data['buyerName'] ?? data['buyerId'];
                final bidAmount = data['bid'];
                final timestamp = (data['timestamp'] as Timestamp).toDate();
                return ListTile(
                  leading: Icon(Icons.account_circle, size: 36),
                  title: Text("₹$bidAmount", style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("By $buyerName\n${timestamp.toLocal()}"),
                  isThreeLine: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 4),
                );
              }).toList(),
            ],
          ),
        );
      },
    );
  }
  @override
  Widget build(BuildContext context) {
    final crop = widget.cropData;
    return Scaffold(
      appBar: AppBar(
        title: Text(capitalize(crop['name']), style: TextStyle(fontWeight: FontWeight.bold)),
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
                  Text(capitalize(crop['name']), style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
                  SizedBox(height: 10),
                  detailRow("Price", "₹${crop['price']}"),
                  detailRow("Available", "${crop['quantity']} kg"),
                  detailRow("Harvest Date", "${crop['harvestDate']}"),
                  detailRow("Location", "${crop['location']}"),
                  SizedBox(height: 10),
                  Text("Description", style: TextStyle(fontWeight: FontWeight.w600)),
                  Text(crop['description'], style: TextStyle(color: Colors.black87)),
                  SizedBox(height: 10),
                  Text("Pricing Type: ${capitalize(crop['pricingType'].toString())}", style: TextStyle(color: Colors.grey.shade700)),
                  if (farmerData != null) ...[
                    Divider(height: 30),
                    Text("Farmer Info", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                    Text("Name: ${capitalize(farmerData!['name'])}"),
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
            if (crop['pricingType'] == 'fixed')
              buildFixedPricingCard(crop),
            if (crop['pricingType'] == 'bidding') ...[
              if (crop.containsKey('biddingClosed') && crop['biddingClosed'] == true)
                buildCard(
                  child: Text('Bidding is closed. No new bids are accepted.',
                      style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                )
              else ...[
                buildBidCard(),
                SizedBox(height: 20),
                buildBidHistory(),
              ],
            ],
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
