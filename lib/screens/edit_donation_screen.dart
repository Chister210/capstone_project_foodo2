import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import '../models/donation_model.dart';
import '../services/donation_service.dart';
import '../services/image_compression_service.dart';

class EditDonationScreen extends StatefulWidget {
  final DonationModel donation;

  const EditDonationScreen({
    super.key,
    required this.donation,
  });

  @override
  State<EditDonationScreen> createState() => _EditDonationScreenState();
}

class _EditDonationScreenState extends State<EditDonationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _foodTypeController = TextEditingController();
  final _quantityController = TextEditingController();
  
  final DonationService _donationService = DonationService();
  final ImagePicker _imagePicker = ImagePicker();
  
  File? _selectedImage;
  String? _selectedDeliveryType;
  DateTime? _selectedPickupTime;
  List<String> _selectedAllergens = [];
  bool _isLoading = false;

  final List<String> _allergenOptions = [
    'Nuts', 'Dairy', 'Gluten', 'Soy', 'Eggs', 'Fish', 'Shellfish', 'Sesame'
  ];

  @override
  void initState() {
    super.initState();
    _initializeFields();
  }

  void _initializeFields() {
    _titleController.text = widget.donation.title;
    _descriptionController.text = widget.donation.description;
    _foodTypeController.text = widget.donation.foodType ?? '';
    _quantityController.text = widget.donation.quantity ?? '';
    _selectedDeliveryType = widget.donation.deliveryType;
    _selectedPickupTime = widget.donation.pickupTime;
    _selectedAllergens = List.from(widget.donation.allergensList);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _foodTypeController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to pick image: $e');
    }
  }

  Future<void> _takePicture() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to take picture: $e');
    }
  }

  Future<void> _selectPickupTime() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedPickupTime ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 7)),
    );

    if (picked != null) {
      final TimeOfDay? time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_selectedPickupTime ?? DateTime.now()),
      );

      if (time != null) {
        setState(() {
          _selectedPickupTime = DateTime(
            picked.year,
            picked.month,
            picked.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedPickupTime == null) {
      Get.snackbar('Error', 'Please select pickup time');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Convert image to base64 if new image selected
      String imageUrl = widget.donation.imageUrl;
      if (_selectedImage != null) {
        imageUrl = await ImageCompressionService().compressAndEncodeImage(
          _selectedImage!,
          maxWidth: 512,
          maxHeight: 512,
          quality: 80,
        );
      }

      // Update donation in Firestore
      await FirebaseFirestore.instance
          .collection('donations')
          .doc(widget.donation.id)
          .update({
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'imageUrl': imageUrl,
        'pickupTime': Timestamp.fromDate(_selectedPickupTime!),
        'deliveryType': _selectedDeliveryType,
        'foodType': _foodTypeController.text.trim().isEmpty ? null : _foodTypeController.text.trim(),
        'quantity': _quantityController.text.trim().isEmpty ? null : _quantityController.text.trim(),
        'allergens': _selectedAllergens.isEmpty ? null : _selectedAllergens,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Notify receiver if donation was claimed
      if (widget.donation.claimedBy != null) {
        await _donationService.notifyDonationUpdated(
          widget.donation.id,
          widget.donation.claimedBy!,
          _titleController.text.trim(),
        );
      }

      Get.snackbar(
        'Success',
        'Donation updated successfully',
        backgroundColor: const Color(0xFF22c55e),
        colorText: Colors.white,
      );

      Get.back();
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to update donation: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Donation'),
        backgroundColor: const Color(0xFF22c55e),
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveChanges,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Save',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image section
              _buildImageSection(),
              const SizedBox(height: 20),

              // Title
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.title),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Description
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                ),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a description';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Food type and quantity
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _foodTypeController,
                      decoration: const InputDecoration(
                        labelText: 'Food Type',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.restaurant),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _quantityController,
                      decoration: const InputDecoration(
                        labelText: 'Quantity',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.scale),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Delivery type
              DropdownButtonFormField<String>(
                initialValue: _selectedDeliveryType,
                decoration: const InputDecoration(
                  labelText: 'Delivery Type *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.delivery_dining),
                ),
                items: const [
                  DropdownMenuItem(value: 'pickup', child: Text('Pickup')),
                  DropdownMenuItem(value: 'delivery', child: Text('Delivery')),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedDeliveryType = value;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select delivery type';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Pickup time
              InkWell(
                onTap: _selectPickupTime,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Pickup Time *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.access_time),
                  ),
                  child: Text(
                    _selectedPickupTime != null
                        ? '${_selectedPickupTime!.day}/${_selectedPickupTime!.month} ${_selectedPickupTime!.hour}:${_selectedPickupTime!.minute.toString().padLeft(2, '0')}'
                        : 'Select pickup time',
                    style: TextStyle(
                      color: _selectedPickupTime != null ? Colors.black : Colors.grey,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Allergens
              const Text(
                'Allergens (Optional)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _allergenOptions.map((allergen) {
                  final isSelected = _selectedAllergens.contains(allergen);
                  return FilterChip(
                    label: Text(allergen),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedAllergens.add(allergen);
                        } else {
                          _selectedAllergens.remove(allergen);
                        }
                      });
                    },
                    selectedColor: Colors.red.withOpacity(0.2),
                    checkmarkColor: Colors.red,
                  );
                }).toList(),
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
        const Text(
          'Food Image',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          height: 200,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(8),
          ),
          child: _selectedImage != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    _selectedImage!,
                    fit: BoxFit.cover,
                  ),
                )
              : widget.donation.hasImage
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Builder(
                        builder: (context) {
                          final uriData = Uri.dataFromString(widget.donation.imageUrl).data;
                          if (uriData != null) {
                            return Image.memory(
                              uriData.contentAsBytes(),
                              fit: BoxFit.cover,
                            );
                          } else {
                            return Container(
                              color: Colors.grey[200],
                              child: const Center(
                                child: Icon(Icons.broken_image, color: Colors.grey),
                              ),
                            );
                          }
                        },
                      ),
                    )
                  : const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate, size: 50, color: Colors.grey),
                          SizedBox(height: 8),
                          Text('No image selected'),
                        ],
                      ),
                    ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.photo_library),
                label: const Text('Gallery'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _takePicture,
                icon: const Icon(Icons.camera_alt),
                label: const Text('Camera'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
