import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FarmerScreen extends StatefulWidget {
  @override
  _FarmerScreenState createState() => _FarmerScreenState();
}

class _FarmerScreenState extends State<FarmerScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _cropName = TextEditingController();
  final TextEditingController _price = TextEditingController();
  final TextEditingController _quantity = TextEditingController();
  final TextEditingController _harvestDate = TextEditingController();
  final TextEditingController _location = TextEditingController();
  final TextEditingController _description = TextEditingController();
  String _pricingType = 'fixed';
  bool _isSubmitting = false;

  @override
  void initState() {
    _tabController = TabController(length: 3, vsync: this);
    super.initState();
  }

  void _logout() async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushReplacementNamed(context, '/');
  }

  void _submitCrop() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSubmitting = true);
      String uid = FirebaseAuth.instance.currentUser!.uid;

      try {
        await FirebaseFirestore.instance.collection('crops').add({
          'farmerId': uid,
          'name': _cropName.text,
          'price': double.parse(_price.text),
          'quantity': int.parse(_quantity.text),
          'harvestDate': _harvestDate.text,
          'location': _location.text,
          'description': _description.text,
          'pricingType': _pricingType,
          'timestamp': Timestamp.now(),
        });

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Crop added successfully!')));

        _cropName.clear();
        _price.clear();
        _quantity.clear();
        _harvestDate.clear();
        _location.clear();
        _description.clear();
        setState(() => _pricingType = 'fixed');
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }

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
      _harvestDate.text = picked.toString().split(' ')[0];
    }
  }

  Widget _buildDashboard() {
    String uid = FirebaseAuth.instance.currentUser!.uid;
    final user = FirebaseAuth.instance.currentUser;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('crops').where('farmerId', isEqualTo: uid).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return Center(child: CircularProgressIndicator());

        final crops = snapshot.data!.docs;
        double totalEarnings = 0;
        for (var doc in crops) {
          totalEarnings += (doc['price'] as double) * (doc['quantity'] as int);
        }

        return SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Dashboard', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              SizedBox(height: 20),
              Card(
                elevation: 3,
                child: ListTile(
                  title: Text('Farmer Info'),
                  subtitle: Text('Email: ${user?.email ?? "N/A"}\nUID: ${user?.uid}'),
                ),
              ),
              SizedBox(height: 20),
              Card(
                elevation: 3,
                child: ListTile(
                  title: Text('Total Crops'),
                  trailing: Text('${crops.length}'),
                ),
              ),
              Card(
                elevation: 3,
                child: ListTile(
                  title: Text('Estimated Earnings'),
                  trailing: Text('₹${totalEarnings.toStringAsFixed(2)}'),
                ),
              ),
              SizedBox(height: 20),
              Text('Your Crops', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ...crops.map((doc) => _buildCropCard(doc)).toList(),
            ],
          ),
        );
      },
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
                child: _buildTextField(_harvestDate, 'Harvest Date (YYYY-MM-DD)'),
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
                  .map((type) => DropdownMenuItem(value: type, child: Text(type.toUpperCase())))
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
            _isSubmitting
                ? CircularProgressIndicator()
                : ElevatedButton(
              onPressed: _submitCrop,
              child: Text('Submit Crop'),
              style: ElevatedButton.styleFrom(padding: EdgeInsets.symmetric(vertical: 16, horizontal: 32)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildYourCropsTab() {
    String uid = FirebaseAuth.instance.currentUser!.uid;
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('crops').where('farmerId', isEqualTo: uid).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator());

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text('No crops added yet.'));
        }

        return ListView(
          padding: EdgeInsets.all(8),
          children: snapshot.data!.docs.map((doc) => _buildCropCard(doc)).toList(),
        );
      },
    );
  }

  Widget _buildCropCard(DocumentSnapshot crop) {
    final cropData = crop.data() as Map<String, dynamic>;

    return Card(
      child: ListTile(
        title: Text(cropData['name']),
        subtitle: Text(
          '₹${cropData['price']} × ${cropData['quantity']}kg\n'
              'Harvest: ${cropData['harvestDate']} | ${cropData['pricingType'].toUpperCase()}',
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'edit') {
              Navigator.push(context, MaterialPageRoute(builder: (_) => EditCropScreen(crop: crop)));
            } else if (value == 'delete') {
              FirebaseFirestore.instance.collection('crops').doc(crop.id).delete();
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(value: 'edit', child: Text('Edit')),
            PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, {bool isNumber = false}) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      validator: (value) => value == null || value.isEmpty ? 'Please enter $label' : null,
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        labelText: label,
        border: OutlineInputBorder(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Farmer Dashboard'),
        actions: [
          IconButton(icon: Icon(Icons.logout), onPressed: _logout),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Dashboard'),
            Tab(text: 'Add Crop'),
            Tab(text: 'Your Crops'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDashboard(),
          _buildAddCropForm(),
          _buildYourCropsTab(),
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

  @override
  void initState() {
    final data = widget.crop.data() as Map<String, dynamic>;
    _name = TextEditingController(text: data['name']);
    _price = TextEditingController(text: data['price'].toString());
    _quantity = TextEditingController(text: data['quantity'].toString());
    _harvestDate = TextEditingController(text: data['harvestDate']);
    _location = TextEditingController(text: data['location']);
    _description = TextEditingController(text: data['description']);
    _pricingType = data['pricingType'];
    super.initState();
  }

  void _updateCrop() async {
    await FirebaseFirestore.instance.collection('crops').doc(widget.crop.id).update({
      'name': _name.text,
      'price': double.parse(_price.text),
      'quantity': int.parse(_quantity.text),
      'harvestDate': _harvestDate.text,
      'location': _location.text,
      'description': _description.text,
      'pricingType': _pricingType,
    });
    Navigator.pop(context);
  }

  void _showDatePicker() async {
    DateTime? picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDate: DateTime.now(),
    );
    if (picked != null) {
      _harvestDate.text = picked.toString().split(' ')[0];
    }
  }

  Widget _buildEditField(TextEditingController controller, String label, {bool isNumber = false}) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(labelText: label, border: OutlineInputBorder()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Edit Crop')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            _buildEditField(_name, 'Crop Name'),
            SizedBox(height: 10),
            _buildEditField(_price, 'Price', isNumber: true),
            SizedBox(height: 10),
            _buildEditField(_quantity, 'Quantity', isNumber: true),
            SizedBox(height: 10),
            GestureDetector(
              onTap: _showDatePicker,
              child: AbsorbPointer(child: _buildEditField(_harvestDate, 'Harvest Date')),
            ),
            SizedBox(height: 10),
            _buildEditField(_location, 'Location'),
            SizedBox(height: 10),
            _buildEditField(_description, 'Description'),
            SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _pricingType,
              items: ['fixed', 'bidding', 'negotiable']
                  .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _pricingType = value);
              },
              decoration: InputDecoration(labelText: 'Pricing Type', border: OutlineInputBorder()),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _updateCrop,
              child: Text('Update Crop'),
            )
          ],
        ),
      ),
    );
  }
}
