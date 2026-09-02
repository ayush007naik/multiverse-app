import 'package:db_compat/db_compat.dart';
import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import '../../core/theme/app_theme.dart';
import '../../services/storage_service.dart';

class AddPropertyDialog extends StatefulWidget {
  final String brokerId;
  final Map<String, dynamic>? propertyData;
  final String? propertyId;

  const AddPropertyDialog({
    super.key,
    required this.brokerId,
    this.propertyData,
    this.propertyId,
  });

  @override
  State<AddPropertyDialog> createState() => _AddPropertyDialogState();
}

class _AddPropertyDialogState extends State<AddPropertyDialog> {
  final _formKey = GlobalKey<FormState>();
  final StorageService _storageService = StorageService();
  final ImagePicker _picker = ImagePicker();
  
  late TextEditingController _titleController;
  late TextEditingController _priceController;
  late TextEditingController _locationController;
  late TextEditingController _descriptionController;
  late TextEditingController _areaController;
  late TextEditingController _bedsController;
  late TextEditingController _bathsController;
  late TextEditingController _propertyStatusController;
  
  String _propertyType = 'Residential';
  String _listingType = 'For Sale';
  bool _isLoading = false;
  final List<XFile> _newImages = [];
  List<String> _existingImages = [];

  bool get _isEditing => widget.propertyId != null;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.propertyData?['title'] ?? '');
    _priceController = TextEditingController(text: widget.propertyData?['price']?.toString() ?? '');
    _locationController = TextEditingController(text: widget.propertyData?['location'] ?? '');
    _descriptionController = TextEditingController(text: widget.propertyData?['description'] ?? '');
    _areaController = TextEditingController(text: widget.propertyData?['area']?.toString() ?? '');
    _bedsController = TextEditingController(text: widget.propertyData?['bedrooms']?.toString() ?? '');
    _bathsController = TextEditingController(text: widget.propertyData?['bathrooms']?.toString() ?? '');
    _propertyStatusController = TextEditingController(text: widget.propertyData?['propertyStatus'] ?? 'Ready To Move');
    
    if (widget.propertyData != null) {
      _propertyType = widget.propertyData!['propertyType'] ?? 'Residential';
      _listingType = widget.propertyData!['listingType'] ?? 'For Sale';
      _existingImages = List<String>.from(widget.propertyData!['images'] ?? []);
    }
  }

  Future<void> _pickImages() async {
    final List<XFile> selectedImages = await _picker.pickMultiImage();
    if (selectedImages.isNotEmpty) {
      setState(() {
        _newImages.addAll(selectedImages);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.darkSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.7,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
        padding: const EdgeInsets.all(32),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_isEditing ? 'Edit Property' : 'List New Property', 
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.accentOrange)),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ],
              ),
              const SizedBox(height: 24),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildImageSection(),
                      const SizedBox(height: 32),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _titleController,
                              decoration: const InputDecoration(labelText: 'Property Title', hintText: 'e.g. Modern 3BHK Apartment'),
                              validator: (v) => v!.isEmpty ? 'Required' : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _priceController,
                              decoration: const InputDecoration(labelText: 'Price (₹)', hintText: 'e.g. 8500000'),
                              keyboardType: TextInputType.number,
                              validator: (v) => v!.isEmpty ? 'Required' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _propertyType,
                              decoration: const InputDecoration(labelText: 'Property Type'),
                              items: ['Residential', 'Commercial', 'Land', 'Industrial'].map((type) {
                                return DropdownMenuItem(value: type, child: Text(type));
                              }).toList(),
                              onChanged: (v) => setState(() => _propertyType = v!),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _listingType,
                              decoration: const InputDecoration(labelText: 'Listing Type'),
                              items: ['For Sale', 'For Rent', 'Lease'].map((type) {
                                return DropdownMenuItem(value: type, child: Text(type));
                              }).toList(),
                              onChanged: (v) => setState(() => _listingType = v!),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      
                      TextFormField(
                        controller: _locationController,
                        decoration: const InputDecoration(labelText: 'Location / Address', prefixIcon: Icon(Icons.location_on, color: AppTheme.accentOrange)),
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 20),
                      
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _areaController,
                              decoration: const InputDecoration(labelText: 'Area (sq ft)', hintText: 'e.g. 1200'),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _bedsController,
                              decoration: const InputDecoration(labelText: 'Bedrooms'),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _bathsController,
                              decoration: const InputDecoration(labelText: 'Bathrooms'),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      
                      TextFormField(
                        controller: _descriptionController,
                        maxLines: 4,
                        decoration: const InputDecoration(labelText: 'Description', hintText: 'Describe the property features, amenities, etc.'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitProperty,
                  child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.black) 
                    : Text(_isEditing ? 'UPDATE LISTING' : 'SUBMIT LISTING'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Property Images', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            TextButton.icon(
              onPressed: _pickImages,
              icon: const Icon(Icons.add_photo_alternate, color: AppTheme.accentOrange),
              label: const Text('Add More', style: TextStyle(color: AppTheme.accentOrange)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 120,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              ..._existingImages.map((url) => _ImageTile(
                imageUrl: url,
                onDelete: () => setState(() => _existingImages.remove(url)),
              )),
              ..._newImages.map((file) => _ImageTile(
                file: file,
                onDelete: () => setState(() => _newImages.remove(file)),
              )),
              if (_existingImages.isEmpty && _newImages.isEmpty)
                GestureDetector(
                  onTap: _pickImages,
                  child: Container(
                    width: 120,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white12, style: BorderStyle.solid),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.camera_alt_outlined, color: Colors.white24, size: 32),
                        SizedBox(height: 8),
                        Text('Upload', style: TextStyle(color: Colors.white24, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _submitProperty() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      String propertyId = widget.propertyId ?? FirebaseFirestore.instance.collection('properties').doc().id;
      
      List<String> uploadedUrls = await _storageService.uploadPropertyImages(propertyId, _newImages);
      List<String> allImages = [..._existingImages, ...uploadedUrls];

                  final data = {
        'title': _titleController.text,
        'price': double.tryParse(_priceController.text) ?? 0,
        'location': _locationController.text,
        'description': _descriptionController.text,
        'area': double.tryParse(_areaController.text) ?? 0,
        'beds': _bedsController.text,
        'bedrooms': int.tryParse(_bedsController.text) ?? 0,
        'bathrooms': int.tryParse(_bathsController.text) ?? 0,
        'propertyStatus': _propertyStatusController.text,
        'propertyType': _propertyType,
        'listingType': _listingType,
        'sellerId': widget.brokerId,
        'brokerId': widget.brokerId,
        'images': allImages,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (_isEditing) {
        await FirebaseFirestore.instance.collection('properties').doc(propertyId).update(data);
      } else {
        await FirebaseFirestore.instance.collection('properties').doc(propertyId).set({
          ...data,
          'status': 'pending_approval',
          'isActive': false,
          'views': 0,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEditing ? 'Property updated successfully!' : 'Property listed successfully! Pending admin approval.'), 
          backgroundColor: Colors.green
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
}

class _ImageTile extends StatelessWidget {
  final String? imageUrl;
  final XFile? file;
  final VoidCallback onDelete;

  const _ImageTile({this.imageUrl, this.file, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        image: imageUrl != null 
          ? DecorationImage(image: NetworkImage(imageUrl!), fit: BoxFit.cover)
          : null,
      ),
      child: Stack(
        children: [
          if (file != null)
            FutureBuilder<Uint8List>(
              future: file!.readAsBytes(),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(snapshot.data!, fit: BoxFit.cover, width: 120, height: 120),
                  );
                }
                return const Center(child: CircularProgressIndicator(strokeWidth: 2));
              },
            ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: onDelete,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                child: const Icon(Icons.close, size: 16, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

