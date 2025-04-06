import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FarmerScreen extends StatefulWidget {
  @override
  _FarmerScreenState createState() => _FarmerScreenState();
}

class _FarmerScreenState extends State<FarmerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _cropName = TextEditingController();
  final TextEditingController _price = TextEditingController();
  final TextEditingController _quantity = TextEditingController();
  final TextEditingController _harvestDate = TextEditingController();
  final TextEditingController _location = TextEditingController();
  final TextEditingController _description = TextEditingController();
  final List<String> _predefinedTags = [
    'vegetable',
    'fruit',
    'grain',
    'organic',
    'seasonal'
  ];
  List<String> _selectedTags = [];
  final Color primaryGreen = Color(0xFF4CAF50);
  final Color backgroundGrey = Color(0xFFF5F5F5);
  String _pricingType = 'fixed';
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _cropName.dispose();
    _price.dispose();
    _quantity.dispose();
    _harvestDate.dispose();
    _location.dispose();
    _description.dispose();
    super.dispose();
  }

  void _logout() async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushReplacementNamed(context, '/login');
  }

  Future<void> _submitCrop() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      await FirebaseFirestore.instance.collection('crops').add({
        'farmerId': uid,
        'name': _cropName.text.trim(),
        'price': double.parse(_price.text),
        'quantity': int.parse(_quantity.text),
        'harvestDate': _harvestDate.text,
        'location': _location.text.trim(),
        'description': _description.text.trim(),
        'pricingType': _pricingType,
        'tags': _selectedTags,
        'timestamp': Timestamp.now(),
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Crop added successfully!')),
      );
      _formKey.currentState!.reset();
      setState(() {
        _pricingType = 'fixed';
        _selectedTags.clear();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding crop: $e')),
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  void _showDatePicker() async {
    DateTime? picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDate: DateTime.now(),
    );
    if (picked != null) {
      _harvestDate.text = picked.toIso8601String().split('T').first;
    }
  }

  void _showAddTagDialog() {
    final TextEditingController _newTagController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Add Custom Tag'),
        content: TextField(
          controller: _newTagController,
          decoration: InputDecoration(hintText: 'Enter new tag'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final newTag = _newTagController.text.trim();
              if (newTag.isNotEmpty && !_selectedTags.contains(newTag)) {
                setState(() => _selectedTags.add(newTag));
              }
              Navigator.pop(ctx);
            },
            child: Text('Add'),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboard() {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final user = FirebaseAuth.instance.currentUser;
    return Container(
      color: backgroundGrey,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Dashboard',
                style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: primaryGreen)),
            SizedBox(height: 20),
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15)),
              elevation: 4,
              child: ListTile(
                title: Text('Farmer Info'),
                subtitle: Text('Email: ${user?.email ?? "N/A"}'),
              ),
            ),
            SizedBox(height: 16),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('crops')
                  .where('farmerId', isEqualTo: uid)
                  .snapshots(),
              builder: (context, snap) {
                final totalCrops = snap.hasData ? snap.data!.docs.length : 0;
                return Card(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15)),
                  elevation: 4,
                  child: ListTile(
                    title: Text('Total Crops'),
                    trailing: Text('$totalCrops',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                );
              },
            ),
            SizedBox(height: 10),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('purchases')
                  .where('farmerId', isEqualTo: uid)
                  .snapshots(),
              builder: (context, snap) {
                double earnings = 0;
                if (snap.hasData) {
                  for (var doc in snap.data!.docs) {
                    earnings += (doc['total'] as num).toDouble();
                  }
                }
                return Card(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15)),
                  elevation: 4,
                  child: ListTile(
                    title: Text('Estimated Earnings'),
                    trailing: Text('₹${earnings.toStringAsFixed(2)}',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                );
              },
            ),
            SizedBox(height: 20),
            Text('Your Crops',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('crops')
                  .where('farmerId', isEqualTo: uid)
                  .snapshots(),
              builder: (context, snap) {
                if (!snap.hasData)
                  return Center(child: CircularProgressIndicator());
                final crops = snap.data!.docs;
                return Column(
                  children: crops.map((doc) => _buildCropCard(doc)).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddCropForm() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            _buildTextField(_cropName, 'Crop Name'),
            SizedBox(height: 10),
            _buildTextField(_price, 'Price (per unit)', isNumber: true),
            SizedBox(height: 10),
            _buildTextField(_quantity, 'Quantity (in kg)', isNumber: true),
            SizedBox(height: 10),
            GestureDetector(
              onTap: _showDatePicker,
              child: AbsorbPointer(
                child:
                _buildTextField(_harvestDate, 'Harvest Date (YYYY-MM-DD)'),
              ),
            ),
            SizedBox(height: 10),
            _buildTextField(_location, 'Location'),
            SizedBox(height: 10),
            _buildTextField(_description, 'Description'),
            SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _pricingType,
              items: ['fixed', 'bidding', 'negotiable']
                  .map((type) =>
                  DropdownMenuItem(value: type, child: Text(type.toUpperCase())))
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _pricingType = value);
              },
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                labelText: 'Pricing Type',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 20),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Tags',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _selectedTags
                  .map((tag) => Chip(
                label: Text(tag),
                deleteIcon: Icon(Icons.close),
                onDeleted: () {
                  setState(() => _selectedTags.remove(tag));
                },
              ))
                  .toList(),
            ),
            SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    hint: Text('Select a tag'),
                    items: _predefinedTags
                        .where((t) => !_selectedTags.contains(t))
                        .map((t) =>
                        DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedTags.add(value));
                      }
                    },
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(width: 10),
                IconButton(
                  icon: Icon(Icons.add, color: primaryGreen),
                  onPressed: _showAddTagDialog,
                ),
              ],
            ),
            SizedBox(height: 30),
            _isSubmitting
                ? CircularProgressIndicator()
                : ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryGreen,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding:
                EdgeInsets.symmetric(vertical: 16, horizontal: 32),
              ),
              onPressed: _submitCrop,
              child:
              Text('Submit Crop', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildYourCropsTab() {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return Container(
      color: backgroundGrey,
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('crops')
            .where('farmerId', isEqualTo: uid)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (!snap.hasData || snap.data!.docs.isEmpty) {
            return Center(
                child: Text('No crops added yet.',
                    style: TextStyle(fontSize: 16)));
          }
          return ListView.builder(
            padding: EdgeInsets.all(12),
            itemCount: snap.data!.docs.length,
            itemBuilder: (ctx, i) => _buildCropCard(snap.data!.docs[i]),
          );
        },
      ),
    );
  }

  Widget _buildBidsTab() {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return Container(
      color: backgroundGrey,
      padding: EdgeInsets.all(12),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('bids')
            .where('farmerId', isEqualTo: uid)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error loading bids: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return Center(child: Text('No bids received yet.'));
          }
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final bidDoc = docs[index];
              final data = bidDoc.data() as Map<String, dynamic>;
              return Card(
                margin: EdgeInsets.symmetric(vertical: 6),
                child: ListTile(
                  title: Text('Bid: ₹${data['bid']}'),
                  subtitle: Text('Buyer: ${data['buyerId']}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: () => _acceptBid(bidDoc),
                        child: Text('Accept'),
                      ),
                      TextButton(
                        onPressed: () => _stopBid(bidDoc),
                        child: Text('Stop'),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _acceptBid(DocumentSnapshot bidDoc) async {
    await FirebaseFirestore.instance
        .collection('bids')
        .doc(bidDoc.id)
        .update({'status': 'accepted'});
    final data = bidDoc.data() as Map<String, dynamic>;
    await FirebaseFirestore.instance.collection('notifications').add({
      'farmerId': data['farmerId'],
      'title': 'Bid Accepted',
      'body':
      'Your bid of ₹${data['bid']} on crop ${data['cropId']} has been accepted.',
      'timestamp': Timestamp.now(),
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Bid accepted.')),
    );
  }

  Future<void> _stopBid(DocumentSnapshot bidDoc) async {
    await FirebaseFirestore.instance
        .collection('bids')
        .doc(bidDoc.id)
        .update({'status': 'stopped'});
    final data = bidDoc.data() as Map<String, dynamic>;
    await FirebaseFirestore.instance.collection('notifications').add({
      'farmerId': data['farmerId'],
      'title': 'Bid Stopped',
      'body':
      'The bid of ₹${data['bid']} on crop ${data['cropId']} has been stopped.',
      'timestamp': Timestamp.now(),
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Bid stopped.')),
    );
  }

  Widget _buildChatsTab() {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return Container(
      color: backgroundGrey,
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('chats')
            .where('farmerId', isEqualTo: uid)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error loading chats: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return Center(child: Text('No chats available.'));
          }
          return ListView.builder(
            padding: EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final chatDoc = docs[index];
              final data = chatDoc.data() as Map<String, dynamic>;
              return Card(
                margin: EdgeInsets.symmetric(vertical: 6),
                child: ListTile(
                  title: Text('Crop: ${data['cropId']}'),
                  subtitle: Text(data['message']),
                  trailing: Text(
                    data['timestamp'] != null
                        ? (data['timestamp'] as Timestamp)
                        .toDate()
                        .toString()
                        : '',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildNotificationsTab() {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return Container(
      color: backgroundGrey,
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .where('farmerId', isEqualTo: uid)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('Error loading notifications.'));
          }
          if (snap.connectionState == ConnectionState.waiting)
            return Center(child: CircularProgressIndicator());
          final notes = snap.data!.docs;
          if (notes.isEmpty)
            return Center(child: Text('No notifications.'));
          return ListView.builder(
            padding: EdgeInsets.all(12),
            itemCount: notes.length,
            itemBuilder: (ctx, i) {
              final data = notes[i].data() as Map<String, dynamic>;
              return Card(
                child: ListTile(
                  title: Text(data['title'] ?? 'Notification'),
                  subtitle: Text(data['body'] ?? ''),
                  trailing: Text(
                    data['timestamp'] != null
                        ? (data['timestamp'] as Timestamp)
                        .toDate()
                        .toString()
                        : '',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildCropCard(DocumentSnapshot crop) {
    final cropData = crop.data() as Map<String, dynamic>;
    return Card(
      margin: EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        title: Text(cropData['name']),
        subtitle: Text(
            '₹${cropData['price']} × ${cropData['quantity']}kg\nHarvest: ${cropData['harvestDate']} | ${cropData['pricingType'].toUpperCase()}'),
        trailing: PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'delete') {
              FirebaseFirestore.instance
                  .collection('crops')
                  .doc(crop.id)
                  .delete();
            } else if (v == 'edit') {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EditCropScreen(crop: crop),
                ),
              );
            }
          },
          itemBuilder: (_) => [
            PopupMenuItem(value: 'edit', child: Text('Edit')),
            PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label,
      {bool isNumber = false}) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      validator: (value) =>
      value == null || value.isEmpty ? 'Please enter $label' : null,
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundGrey,
      appBar: AppBar(
        backgroundColor: primaryGreen,
        title: Text('Farmer Dashboard'),
        actions: [IconButton(icon: Icon(Icons.logout), onPressed: _logout)],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.white,
          indicatorSize: TabBarIndicatorSize.label,
          tabs: [
            Tab(
              child: Text('Dashboard',
                  style: _tabController.index == 0
                      ? TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
                      : TextStyle(fontSize: 14)),
            ),
            Tab(
              child: Text('Add Crop',
                  style: _tabController.index == 1
                      ? TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
                      : TextStyle(fontSize: 14)),
            ),
            Tab(
              child: Text('Your Crops',
                  style: _tabController.index == 2
                      ? TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
                      : TextStyle(fontSize: 14)),
            ),
            Tab(
              child: Text('Bids',
                  style: _tabController.index == 3
                      ? TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
                      : TextStyle(fontSize: 14)),
            ),
            Tab(
              child: Text('Chats',
                  style: _tabController.index == 4
                      ? TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
                      : TextStyle(fontSize: 14)),
            ),
            Tab(
              child: Text('Notifications',
                  style: _tabController.index == 5
                      ? TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
                      : TextStyle(fontSize: 14)),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDashboard(),
          _buildAddCropForm(),
          _buildYourCropsTab(),
          _buildBidsTab(),
          _buildChatsTab(),
          _buildNotificationsTab(),
        ],
      ),
    );
  }
}

class EditCropScreen extends StatefulWidget {
  final DocumentSnapshot crop;
  EditCropScreen({required this.crop});
  @override
  _EditCropScreenState createState() => _EditCropScreenState();
}

class _EditCropScreenState extends State<EditCropScreen> {
  late TextEditingController _name;
  late TextEditingController _price;
  late TextEditingController _quantity;
  late TextEditingController _harvestDate;
  late TextEditingController _location;
  late TextEditingController _description;
  String _pricingType = 'fixed';
  final List<String> _predefinedTags = [
    'vegetable',
    'fruit',
    'grain',
    'organic',
    'seasonal'
  ];
  late List<String> _selectedTags;

  @override
  void initState() {
    super.initState();
    final data = widget.crop.data() as Map<String, dynamic>;
    _name = TextEditingController(text: data['name']);
    _price = TextEditingController(text: data['price'].toString());
    _quantity = TextEditingController(text: data['quantity'].toString());
    _harvestDate = TextEditingController(text: data['harvestDate']);
    _location = TextEditingController(text: data['location']);
    _description = TextEditingController(text: data['description']);
    _pricingType = data['pricingType'];
    _selectedTags = List<String>.from(data['tags'] ?? []);
  }

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _quantity.dispose();
    _harvestDate.dispose();
    _location.dispose();
    _description.dispose();
    super.dispose();
  }

  void _showAddTagDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Add Custom Tag'),
        content: TextField(
          controller: ctrl,
          decoration: InputDecoration(hintText: 'Enter tag'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final t = ctrl.text.trim();
              if (t.isNotEmpty && !_selectedTags.contains(t)) {
                setState(() => _selectedTags.add(t));
              }
              Navigator.pop(context);
            },
            child: Text('Add'),
          ),
        ],
      ),
    );
  }

  Widget _buildTagSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Tags', style: TextStyle(fontWeight: FontWeight.bold)),
        SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: _selectedTags.map((tag) {
            return Chip(
              label: Text(tag),
              onDeleted: () => setState(() => _selectedTags.remove(tag)),
            );
          }).toList(),
        ),
        SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                hint: Text('Select a tag'),
                items: _predefinedTags
                    .where((t) => !_selectedTags.contains(t))
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (t) {
                  if (t != null) setState(() => _selectedTags.add(t));
                },
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            SizedBox(width: 8),
            IconButton(icon: Icon(Icons.add), onPressed: _showAddTagDialog),
          ],
        ),
      ],
    );
  }

  void _updateCrop() async {
    await FirebaseFirestore.instance
        .collection('crops')
        .doc(widget.crop.id)
        .update({
      'name': _name.text,
      'price': double.parse(_price.text),
      'quantity': int.parse(_quantity.text),
      'harvestDate': _harvestDate.text,
      'location': _location.text,
      'description': _description.text,
      'pricingType': _pricingType,
      'tags': _selectedTags,
    });
    Navigator.pop(context);
  }

  Widget _buildEditField(TextEditingController c, String label,
      {bool isNumber = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: TextFormField(
          controller: c,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          decoration: InputDecoration(labelText: label, border: OutlineInputBorder()),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Edit Crop')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            _buildEditField(_name, 'Crop Name'),
            _buildEditField(_price, 'Price', isNumber: true),
            _buildEditField(_quantity, 'Quantity', isNumber: true),
            GestureDetector(
              onTap: () async {
                DateTime? d = await showDatePicker(
                  context: context,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                  initialDate: DateTime.parse(_harvestDate.text),
                );
                if (d != null)
                  setState(() => _harvestDate.text = d.toIso8601String().split('T').first);
              },
              child: AbsorbPointer(
                  child: _buildEditField(_harvestDate, 'Harvest Date')),
            ),
            _buildEditField(_location, 'Location'),
            _buildEditField(_description, 'Description'),
            DropdownButtonFormField<String>(
              value: _pricingType,
              items: ['fixed', 'bidding', 'negotiable']
                  .map((t) => DropdownMenuItem(value: t, child: Text(t.toUpperCase())))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _pricingType = v);
              },
              decoration: InputDecoration(labelText: 'Pricing Type', border: OutlineInputBorder()),
            ),
            SizedBox(height: 20),
            _buildTagSection(),
            SizedBox(height: 30),
            ElevatedButton(
              onPressed: _updateCrop,
              child: Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }
}
