import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'crop_details_screen.dart';

class BuyerScreen extends StatefulWidget {
  const BuyerScreen({Key? key}) : super(key: key);

  @override
  _BuyerScreenState createState() => _BuyerScreenState();
}

class _BuyerScreenState extends State<BuyerScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  String? selectedTag;

  Future<void> _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushReplacementNamed(context, '/login');
  }

  String _normalizeTag(String tag) {
    tag = tag.trim().toLowerCase();
    return (tag.endsWith('s') && tag.length > 3) ? tag.substring(0, tag.length - 1) : tag;
  }

  bool _filterCrop(Map<String, dynamic> crop) {
    final searchText = _searchController.text.toLowerCase();
    final cropName = (crop['name'] ?? '').toString().toLowerCase();
    final cropLocation = (crop['location'] ?? '').toString().toLowerCase();
    if (searchText.isNotEmpty && !cropName.contains(searchText)) return false;
    if (selectedTag != null) {
      final normSelectedTag = _normalizeTag(selectedTag!);
      List<dynamic> cropTags = crop['tags'] ?? [];
      bool tagFound = cropTags.any((tag) {
        String normTag = _normalizeTag(tag.toString());
        return normTag == normSelectedTag;
      });
      if (!tagFound) return false;
    }
    if (_locationController.text.isNotEmpty &&
        !cropLocation.contains(_locationController.text.toLowerCase())) return false;
    if (_quantityController.text.isNotEmpty) {
      int? filterQty = int.tryParse(_quantityController.text);
      int cropQty = crop['availableQuantity'] ?? 0;
      if (filterQty != null && cropQty < filterQty) return false;
    }
    return true;
  }

  String capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1).toLowerCase();
  }

  Widget _buildTagChips() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('crops').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return SizedBox.shrink();
        Set<String> distinctTags = {};
        for (var doc in snapshot.data!.docs) {
          var crop = doc.data() as Map<String, dynamic>;
          if (crop['tags'] != null) {
            for (var tag in crop['tags']) {
              distinctTags.add(tag.toString());
            }
          }
        }
        List<String> tagsList = distinctTags.toList();
        if (tagsList.isEmpty) return SizedBox.shrink();
        return Container(
          height: 50,
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: tagsList.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final tag = tagsList[index];
              return ChoiceChip(
                label: Text(
                  tag.toUpperCase(),
                  style: TextStyle(
                    color: selectedTag == tag ? Colors.white : Colors.deepPurpleAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                selected: selectedTag == tag,
                selectedColor: Colors.deepPurpleAccent,
                onSelected: (bool selected) {
                  setState(() {
                    selectedTag = selected ? tag : null;
                  });
                },
              );
            },
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _locationController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Buyer Panel', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        backgroundColor: Colors.deepPurpleAccent,
        elevation: 2,
        actions: [
          IconButton(
            onPressed: () => _logout(context),
            icon: Icon(Icons.logout),
            tooltip: 'Logout',
            style: IconButton.styleFrom(backgroundColor: Colors.white),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search crops...',
                prefixIcon: Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                contentPadding: EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.deepPurple.shade50, Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            _buildTagChips(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      TextField(
                        controller: _locationController,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          labelText: 'Filter by Location',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      SizedBox(height: 10),
                      TextField(
                        controller: _quantityController,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          labelText: 'Minimum Available Quantity',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('crops').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator());
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(child: Text('No crops available', style: TextStyle(color: Colors.black87, fontSize: 18)));
                  }
                  final filteredDocs = snapshot.data!.docs.where((doc) {
                    final crop = doc.data() as Map<String, dynamic>;
                    return _filterCrop(crop);
                  }).toList();
                  if (filteredDocs.isEmpty) {
                    return Center(child: Text('No matching crops found', style: TextStyle(color: Colors.black87, fontSize: 18)));
                  }
                  return ListView.builder(
                    padding: EdgeInsets.all(12),
                    itemCount: filteredDocs.length,
                    itemBuilder: (context, index) {
                      final doc = filteredDocs[index];
                      Map<String, dynamic> crop = doc.data() as Map<String, dynamic>;
                      return Card(
                        margin: EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 6,
                        child: ListTile(
                          contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          title: Text(capitalize(crop['name'])),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('₹${crop['price']} - ${capitalize(crop['pricingType'].toString())}', style: TextStyle(fontSize: 15, color: Colors.grey[700])),
                              if (crop.containsKey('location'))
                                Text('Location: ${crop['location']}', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                              if (crop.containsKey('availableQuantity'))
                                Text('Available: ${crop['availableQuantity']} units', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                              if (crop.containsKey('tags'))
                                Text('Tags: ${(crop['tags'] as List).join(', ')}', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                            ],
                          ),
                          trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[600]),
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => CropDetailsScreen(cropId: doc.id, cropData: crop)));
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
