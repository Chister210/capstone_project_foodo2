import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'dart:io';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/donation_service.dart';
import '../models/food_category.dart';
import '../models/donation_specification.dart';
import 'food_safety_guideline.dart';

class DonationForm extends StatefulWidget {
  final VoidCallback onSuccess;
  final LatLng? marketLocation;

  const DonationForm({super.key, required this.onSuccess, this.marketLocation});

  @override
  State<DonationForm> createState() => _DonationFormState();
}

class _DonationFormState extends State<DonationForm> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();
  final _expirationDateController = TextEditingController();
  final _preparationDateController = TextEditingController();
  final _ingredientsController = TextEditingController();
  final _allergensController = TextEditingController();
  final _quantityController = TextEditingController();
  final _maxRecipientsController = TextEditingController();
  final DonationService _donationService = DonationService();
  final ImagePicker _imagePicker = ImagePicker();

  // Controller for adding custom allergen
  final TextEditingController _customAllergenController = TextEditingController();

  File? _selectedImage;
  DateTime? _selectedPickupTime;
  DateTime? _selectedExpirationDate;
  DateTime? _selectedPreparationDate;
  String _deliveryType = 'pickup';
  String _foodQuality = 'fresh';
  String _foodTemperature = 'hot'; // 'hot', 'cold', 'room_temp'
  String? _selectedFoodCategory;
  String? _selectedSpecification;
  bool _isLoading = false;
  bool _safetyGuidelinesCompleted = false;
  // market location removed from form

  // Allergens list
  final List<String> _commonAllergens = [
    'Milk',
    'Eggs',
    'Fish',
    'Shellfish',
    'Tree Nuts',
    'Peanuts',
    'Wheat',
    'Soybeans',
    'Sesame',
    'Gluten'
  ];
  final List<String> _selectedAllergens = [];

  @override
  void initState() {
    super.initState();
    // market location handling removed
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _expirationDateController.dispose();
    _preparationDateController.dispose();
    _ingredientsController.dispose();
    _allergensController.dispose();
    _customAllergenController.dispose();
    super.dispose();
  }

  // Image selection methods
  Future<void> _pickImage() async {
    final XFile? image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 80,
    );
    
    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
      });
    }
  }

  Future<void> _takePhoto() async {
    final XFile? image = await _imagePicker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 80,
    );
    
    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
      });
    }
  }

  // Add this new method for selecting preparation time
  Future<void> _selectPreparationTime() async {
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF22c55e),
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (pickedTime != null && _selectedPreparationDate != null) {
      final selected = DateTime(
        _selectedPreparationDate!.year,
        _selectedPreparationDate!.month,
        _selectedPreparationDate!.day,
        pickedTime.hour,
        pickedTime.minute,
      );
      
      setState(() {
        _selectedPreparationDate = selected;
        _preparationDateController.text = DateFormat('MMM dd, yyyy - h:mm a').format(selected);
      });
    }
  }

  // Update the _selectPreparationDate method to include time
  Future<void> _selectPreparationDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 2)),
      lastDate: DateTime.now(),
    );
    
    if (picked != null) {
      // If we already have a time from previous selection, keep it
      if (_selectedPreparationDate != null) {
        final existingTime = _selectedPreparationDate!;
        final newDateTime = DateTime(
          picked.year,
          picked.month,
          picked.day,
          existingTime.hour,
          existingTime.minute,
        );
        setState(() {
          _selectedPreparationDate = newDateTime;
          _preparationDateController.text = DateFormat('MMM dd, yyyy - h:mm a').format(newDateTime);
        });
      } else {
        // First time selection - set to current time and then ask for time
        final now = DateTime.now();
        final initialDateTime = DateTime(
          picked.year,
          picked.month,
          picked.day,
          now.hour,
          now.minute,
        );
        setState(() {
          _selectedPreparationDate = initialDateTime;
          _preparationDateController.text = DateFormat('MMM dd, yyyy - h:mm a').format(initialDateTime);
        });
        // Optionally ask for time confirmation
        await _selectPreparationTime();
      }
    }
  }

// FIXED: Pickup time selection - allow even 1 minute after preparation
Future<void> _selectPickupTime() async {
  final now = DateTime.now();
  
  // VALIDATION: Must have preparation date set first
  if (_selectedPreparationDate == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please set preparation date first'),
        backgroundColor: Colors.orange,
      ),
    );
    return;
  }

  // Calculate food safety deadlines based on preparation time
  Duration safetyDuration;
  switch (_foodTemperature) {
    case 'hot':
      safetyDuration = const Duration(hours: 4);
      break;
    case 'cold':
      safetyDuration = const Duration(hours: 2);
      break;
    case 'room_temp':
    default:
      safetyDuration = const Duration(hours: 4);
      break;
  }
  
  // Food safety deadline (when food becomes unsafe)
  final safetyDeadline = _selectedPreparationDate!.add(safetyDuration);
  
  // Minimum pickup time - can be IMMEDIATELY after preparation (1 minute buffer)
  final minimumPickupTime = _selectedPreparationDate!.add(const Duration(minutes: 1));
  
  // Maximum pickup time (safety deadline)
  final maximumPickupTime = safetyDeadline;

  // Debug information
  print('Preparation Time: $_selectedPreparationDate');
  print('Minimum Pickup Time (1 min after prep): $minimumPickupTime');
  print('Safety Deadline: $safetyDeadline');
  print('Maximum Pickup Time: $maximumPickupTime');

  // First pick a date
  final DateTime? pickedDate = await showDatePicker(
    context: context,
    initialDate: minimumPickupTime.isAfter(now) ? minimumPickupTime : now,
    firstDate: now,
    lastDate: maximumPickupTime,
    selectableDayPredicate: (DateTime day) {
      return !day.isAfter(maximumPickupTime);
    },
  );
  
  if (pickedDate != null) {
    // Determine time constraints for the selected date
    TimeOfDay initialTime;
    TimeOfDay minTime;
    TimeOfDay maxTime;
    
    if (pickedDate.day == _selectedPreparationDate!.day && 
        pickedDate.month == _selectedPreparationDate!.month && 
        pickedDate.year == _selectedPreparationDate!.year) {
      // Same day as preparation - pickup can start 1 minute after preparation
      minTime = TimeOfDay.fromDateTime(minimumPickupTime);
      maxTime = TimeOfDay.fromDateTime(maximumPickupTime);
      initialTime = minTime;
    } else if (pickedDate.day == maximumPickupTime.day && 
               pickedDate.month == maximumPickupTime.month && 
               pickedDate.year == maximumPickupTime.year) {
      // Last possible day - respect maximum time only
      minTime = const TimeOfDay(hour: 0, minute: 0);
      maxTime = TimeOfDay.fromDateTime(maximumPickupTime);
      initialTime = const TimeOfDay(hour: 8, minute: 0);
    } else {
      // Middle days - full day available
      minTime = const TimeOfDay(hour: 0, minute: 0);
      maxTime = const TimeOfDay(hour: 23, minute: 59);
      initialTime = const TimeOfDay(hour: 8, minute: 0);
    }
    
    // Then pick a time
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF22c55e),
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (pickedTime != null) {
      final selected = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
      
      // Final validation - SIMPLIFIED
      final isAfterPreparation = selected.isAfter(_selectedPreparationDate!);
      final isWithinSafetyWindow = selected.isBefore(maximumPickupTime.add(const Duration(minutes: 1)));
      
      if (isAfterPreparation && isWithinSafetyWindow) {
        setState(() {
          _selectedPickupTime = selected;
        });
        
        // Calculate time until safety deadline
        final timeUntilDeadline = maximumPickupTime.difference(selected);
        final hoursLeft = timeUntilDeadline.inHours;
        final minutesLeft = timeUntilDeadline.inMinutes % 60;
        
        String message = '✅ Pickup time set: ${DateFormat('MMM dd, yyyy - h:mm a').format(selected)}\n'
                        'Food prepared: ${DateFormat('MMM dd - h:mm a').format(_selectedPreparationDate!)}\n'
                        'Safe for: ${hoursLeft}h ${minutesLeft}m';
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: const Color(0xFF22c55e),
            duration: const Duration(seconds: 5),
          ),
        );
      } else {
        String errorMessage;
        if (!isAfterPreparation) {
          errorMessage = '❌ Pickup time must be AFTER preparation time\n'
                        'Preparation: ${DateFormat('MMM dd - h:mm a').format(_selectedPreparationDate!)}\n'
                        'Selected: ${DateFormat('MMM dd - h:mm a').format(selected)}';
        } else {
          errorMessage = '❌ Food safety violation!\n'
                        '${_foodTemperature == 'hot' ? 'Hot' : _foodTemperature == 'cold' ? 'Cold' : 'Room temperature'} '
                        'foods must be picked up within ${safetyDuration.inHours} hours of preparation.\n'
                        'Safety deadline: ${DateFormat('MMM dd - h:mm a').format(maximumPickupTime)}';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    }
  }
}

  Future<void> _selectExpirationDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    
    if (picked != null) {
      setState(() {
        _selectedExpirationDate = picked;
        _expirationDateController.text = DateFormat('MMM dd, yyyy').format(picked);
        _updateFoodQualityStatus();
      });
    }
  }

  // Adds a custom allergen from the input field into the selected allergens list.
  void _addCustomAllergen() {
    final raw = _customAllergenController.text.trim();
    if (raw.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an allergen to add'), backgroundColor: Colors.orange),
      );
      return;
    }

    final normalized = raw[0].toUpperCase() + raw.substring(1);
    if (_selectedAllergens.contains(normalized)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Allergen already added'), backgroundColor: Colors.grey),
      );
    } else {
      setState(() {
        _selectedAllergens.add(normalized);
      });
    }
    _customAllergenController.clear();
  }

  void _toggleAllergen(String allergen) {
    setState(() {
      if (_selectedAllergens.contains(allergen)) {
        _selectedAllergens.remove(allergen);
      } else {
        _selectedAllergens.add(allergen);
      }
    });
  }

  // Food quality methods
  void _updateFoodQualityStatus() {
    if (_selectedExpirationDate == null) return;
    
    final now = DateTime.now();
    final daysUntilExpiry = _selectedExpirationDate!.difference(now).inDays;
    
    if (daysUntilExpiry < 0) {
      setState(() {
        _foodQuality = 'expired';
      });
    } else if (daysUntilExpiry <= 1) {
      setState(() {
        _foodQuality = 'expiring_soon';
      });
    } else if (daysUntilExpiry <= 3) {
      setState(() {
        _foodQuality = 'fresh_but_soon';
      });
    } else {
      setState(() {
        _foodQuality = 'fresh';
      });
    }
  }

  String _getFoodQualityDescription() {
    switch (_foodQuality) {
      case 'fresh':
        return 'Fresh - Good for several days';
      case 'fresh_but_soon':
        return 'Fresh - Best consumed soon';
      case 'expiring_soon':
        return 'Expiring soon - Consume today';
      case 'expired':
        return 'Expired - Not recommended';
      default:
        return 'Unknown quality';
    }
  }

  Color _getFoodQualityColor() {
    switch (_foodQuality) {
      case 'fresh':
        return const Color(0xFF22c55e);
      case 'fresh_but_soon':
        return const Color(0xFFeab308);
      case 'expiring_soon':
        return const Color(0xFFf97316);
      case 'expired':
        return const Color(0xFFef4444);
      default:
        return Colors.grey;
    }
  }

  // Helper method to get food safety guidance based on preparation time and temperature
  String _getPreparationTimeGuidance() {
    if (_selectedPreparationDate == null) return '';
    
    final now = DateTime.now();
    final timeSincePreparation = now.difference(_selectedPreparationDate!);
    
    if (_foodTemperature == 'hot') {
      if (timeSincePreparation.inHours >= 4) {
        return '⚠️ Hot food should be consumed within 4 hours of preparation';
      } else {
        final hoursLeft = 4 - timeSincePreparation.inHours;
        return '✅ Safe to consume for $hoursLeft more hours';
      }
    } else if (_foodTemperature == 'cold') {
      if (timeSincePreparation.inHours >= 2) {
        return '⚠️ Cold food should be consumed within 2 hours if above 4°C';
      } else {
        final hoursLeft = 2 - timeSincePreparation.inHours;
        return '✅ Safe to consume for $hoursLeft more hours';
      }
    } else {
      if (timeSincePreparation.inHours >= 4) {
        return '⚠️ Room temperature food should be consumed within 4 hours';
      } else {
        final hoursLeft = 4 - timeSincePreparation.inHours;
        return '✅ Safe to consume for $hoursLeft more hours';
      }
    }
  }

 // Safety guidelines method - FIXED
void _showSafetyGuidelines() {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => FoodSafetyGuideline(
      onCompleted: () {
        setState(() {
          _safetyGuidelinesCompleted = true;
        });
        // DON'T call Navigator.pop(context) here - let the FoodSafetyGuideline handle it
        // This will only update the state and keep the donation form open
      },
    ),
  );
}

  // Helper methods for donation creation
  String _getFoodTypeFromTitle() {
    final title = _titleController.text.toLowerCase();
    if (title.contains('vegetable') || title.contains('fruit')) {
      return 'Produce';
    } else if (title.contains('bread') || title.contains('pastry')) {
      return 'Bakery';
    } else if (title.contains('meat') || title.contains('chicken') || title.contains('fish')) {
      return 'Protein';
    } else if (title.contains('dairy') || title.contains('milk') || title.contains('cheese')) {
      return 'Dairy';
    } else if (title.contains('cooked') || title.contains('meal')) {
      return 'Prepared Food';
    } else {
      return 'Other';
    }
  }

  String _estimateQuantity() {
    final description = _descriptionController.text.toLowerCase();
    if (description.contains('large') || description.contains('lot') || description.contains('bulk')) {
      return 'Large';
    } else if (description.contains('medium') || description.contains('some')) {
      return 'Medium';
    } else {
      return 'Small';
    }
  }

  Future<void> _submitDonation() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_safetyGuidelinesCompleted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please complete the food safety guidelines first'),
          backgroundColor: Colors.orange,
        ),
      );
      _showSafetyGuidelines();
      return;
    }
    // Require at least one allergen to be specified
    if (_selectedAllergens.isEmpty) {
      // show dialog prompting user to add at least one allergen
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Allergen information required'),
          content: const Text('Please add at least one allergen or a custom allergen so recipients can be informed.'),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK')),
          ],
        ),
      );
      return;
    }
    if (_selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an image')),
      );
      return;
    }
    if (_selectedPickupTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select pickup time')),
      );
      return;
    }
    if (_selectedExpirationDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select expiration date')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _donationService.createDonation(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        imageFile: _selectedImage!,
        pickupTime: _selectedPickupTime!,
        deliveryType: _deliveryType,
        address: _deliveryType == 'delivery' ? _addressController.text.trim() : null,
        // market location/address removed from donation form
        foodType: _getFoodTypeFromTitle(),
        foodCategory: _selectedFoodCategory,
        quantity: _quantityController.text.trim(),
        specification: _selectedSpecification,
        maxRecipients: int.tryParse(_maxRecipientsController.text.trim()),
        allergens: _selectedAllergens.isNotEmpty ? _selectedAllergens : null,
      );

      _showSuccessPopup();
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating donation: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showSuccessPopup() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Lottie.asset(
                  'assets/lottie_files/food_donated.json',
                  width: 120,
                  height: 120,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Donation Created!',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF22c55e),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Your food donation has been successfully listed and is now available for recipients.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      widget.onSuccess();
                      _resetForm();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF22c55e),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text(
                      'Great!',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    setState(() {
      _selectedImage = null;
      _selectedPickupTime = null;
      _selectedExpirationDate = null;
      _selectedPreparationDate = null;
      _deliveryType = 'pickup';
      _foodQuality = 'fresh';
      _foodTemperature = 'hot';
      _safetyGuidelinesCompleted = false;
      _selectedAllergens.clear();
      // market location state reset removed
    });
    _titleController.clear();
    _descriptionController.clear();
    _addressController.clear();
    _expirationDateController.clear();
    _preparationDateController.clear();
    _ingredientsController.clear();
    _allergensController.clear();
  }

  // UI Builder methods
  Widget _buildSafetyGuidelinesSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _safetyGuidelinesCompleted ? const Color(0xFF22c55e) : Colors.orange,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.food_bank_rounded,
                color: _safetyGuidelinesCompleted ? const Color(0xFF22c55e) : Colors.orange,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Food Safety Guidelines',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _safetyGuidelinesCompleted ? const Color(0xFF22c55e) : Colors.orange,
                  ),
                ),
              ),
              if (_safetyGuidelinesCompleted)
                const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF22c55e),
                  size: 24,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _safetyGuidelinesCompleted
                ? 'You have completed the food safety guidelines. Thank you for ensuring food safety!'
                : 'Please review and complete the food safety guidelines before creating your donation.',
            style: TextStyle(
              fontSize: 14,
              color: _safetyGuidelinesCompleted ? const Color(0xFF22c55e) : Colors.black54,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _showSafetyGuidelines,
              style: ElevatedButton.styleFrom(
                backgroundColor: _safetyGuidelinesCompleted ? const Color(0xFF22c55e) : Colors.orange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                _safetyGuidelinesCompleted ? 'Review Guidelines' : 'Start Safety Guidelines',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Food Image',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add a clear photo of the food items',
            style: TextStyle(
              fontSize: 14,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 16),
          if (_selectedImage == null)
            Row(
              children: [
                Expanded(
                  child: _buildImageOption(
                    icon: Icons.photo_library_rounded,
                    title: 'Gallery',
                    onTap: _pickImage,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildImageOption(
                    icon: Icons.camera_alt_rounded,
                    title: 'Camera',
                    onTap: _takePhoto,
                  ),
                ),
              ],
            )
          else
            Column(
              children: [
                Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    image: DecorationImage(
                      image: FileImage(_selectedImage!),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => setState(() => _selectedImage = null),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Remove Image'),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildImageOption({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: const Color(0xFF22c55e)),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            maxLines: maxLines,
            validator: validator,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.grey.withOpacity(0.6)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF22c55e)),
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpirationDateSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Expiration Date',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'When does this food expire?',
            style: TextStyle(
              fontSize: 14,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: _selectExpirationDate,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.calendar_today_rounded,
                    color: Color(0xFF22c55e),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _selectedExpirationDate != null
                          ? DateFormat('MMM dd, yyyy').format(_selectedExpirationDate!)
                          : 'Select expiration date',
                      style: TextStyle(
                        color: _selectedExpirationDate != null ? Colors.black : Colors.grey,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.arrow_drop_down_rounded,
                    color: Colors.grey,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Updated preparation date section with time picker
  Widget _buildPreparationDateSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Preparation Date & Time',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'When was this food prepared? This helps determine safe pickup times.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: _selectPreparationDate,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.withOpacity(0.3)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.calendar_today_rounded,
                          color: Color(0xFF22c55e),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _selectedPreparationDate != null
                                ? DateFormat('MMM dd, yyyy').format(_selectedPreparationDate!)
                                : 'Select preparation date',
                            style: TextStyle(
                              color: _selectedPreparationDate != null ? Colors.black : Colors.grey,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.arrow_drop_down_rounded,
                          color: Colors.grey,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              if (_selectedPreparationDate != null)
                Expanded(
                  child: InkWell(
                    onTap: _selectPreparationTime,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.withOpacity(0.3)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.access_time_rounded,
                            color: Color(0xFF22c55e),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _selectedPreparationDate != null
                                  ? DateFormat('h:mm a').format(_selectedPreparationDate!)
                                  : 'Select time',
                              style: TextStyle(
                                color: _selectedPreparationDate != null ? Colors.black : Colors.grey,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.arrow_drop_down_rounded,
                            color: Colors.grey,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          if (_selectedPreparationDate != null) ...[
            const SizedBox(height: 8),
            Text(
              'Food prepared: ${DateFormat('MMM dd, yyyy - h:mm a').format(_selectedPreparationDate!)}',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF22c55e),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _getPreparationTimeGuidance(),
              style: const TextStyle(
                fontSize: 12,
                color: Colors.orange,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTemperatureSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Temperature Control',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Maintain proper temperature: Hot foods hot (above 60°C), Cold foods cold (below 4°C)',
            style: TextStyle(
              fontSize: 14,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildTemperatureOption(
                  title: 'Hot Food',
                  subtitle: 'Above 60°C',
                  icon: Icons.local_fire_department_rounded,
                  isSelected: _foodTemperature == 'hot',
                  onTap: () => setState(() {
                    _foodTemperature = 'hot';
                  }),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTemperatureOption(
                  title: 'Cold Food',
                  subtitle: 'Below 4°C',
                  icon: Icons.ac_unit_rounded,
                  isSelected: _foodTemperature == 'cold',
                  onTap: () => setState(() {
                    _foodTemperature = 'cold';
                  }),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTemperatureOption(
                  title: 'Room Temp',
                  subtitle: 'Stable foods',
                  icon: Icons.thermostat_rounded,
                  isSelected: _foodTemperature == 'room_temp',
                  onTap: () => setState(() {
                    _foodTemperature = 'room_temp';
                  }),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTemperatureOption({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final width = MediaQuery.of(context).size.width;
    // responsive sizes
    final double titleSize = width < 360 ? 11 : (width < 420 ? 12 : 14);
    final double subtitleSize = width < 360 ? 9 : (width < 420 ? 10 : 12);

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF22c55e).withOpacity(0.1) : Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF22c55e) : Colors.grey.withOpacity(0.3),
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFF22c55e) : Colors.grey,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? const Color(0xFF22c55e) : Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: titleSize,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                color: isSelected ? const Color(0xFF22c55e) : Colors.grey,
                fontSize: subtitleSize,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIngredientsSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ingredients List',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'List all ingredients used in preparation',
            style: TextStyle(
              fontSize: 14,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _ingredientsController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'e.g., Flour, eggs, milk, sugar, vanilla extract...',
              hintStyle: TextStyle(color: Colors.grey.withOpacity(0.6)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF22c55e)),
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFoodCategorySection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Food Category',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Select the category that best describes your food donation',
            style: TextStyle(
              fontSize: 14,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _selectedFoodCategory,
            decoration: InputDecoration(
              hintText: 'Select food category',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF22c55e)),
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
            items: FoodCategory.categories.map((category) {
              return DropdownMenuItem<String>(
                value: category.id,
                child: Row(
                  children: [
                    Text(category.icon, style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 12),
                    Text(category.name),
                  ],
                ),
              );
            }).toList(),
            onChanged: (value) => setState(() => _selectedFoodCategory = value),
            validator: (value) => value == null ? 'Please select a food category' : null,
          ),
        ],
      ),
    );
  }

  Widget _buildDonationSpecificationSection() {
  return Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.grey.withOpacity(0.2)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 10,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Donation Specification',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Specify how the food will be distributed to recipients',
          style: TextStyle(
            fontSize: 14,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _selectedSpecification,
          isExpanded: true,
          itemHeight: 50,
          menuMaxHeight: 250,
          decoration: InputDecoration(
            hintText: 'Select specification',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF22c55e)),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          items: DonationSpecification.specifications.map((spec) {
            return DropdownMenuItem<String>(
              value: spec.id,
              child: SizedBox(
                height: 40,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    spec.name, // Only show the name, no description
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            );
          }).toList(),
          onChanged: (value) => setState(() => _selectedSpecification = value),
          validator: (value) => value == null ? 'Please select a specification' : null,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _quantityController,
                decoration: InputDecoration(
                  labelText: 'Quantity',
                  hintText: 'e.g., 10 pieces, 2kg, 5 packs',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF22c55e)),
                  ),
                  contentPadding: const EdgeInsets.all(16),
                ),
                validator: (value) => value?.isEmpty == true ? 'Please enter quantity' : null,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _maxRecipientsController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Max Recipients',
                  hintText: 'e.g., 5',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF22c55e)),
                  ),
                  contentPadding: const EdgeInsets.all(16),
                ),
                validator: (value) => value?.isEmpty == true ? 'Please enter max recipients' : null,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

  Widget _buildAllergensSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Allergen Information',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Select all allergens present in the food',
            style: TextStyle(
              fontSize: 14,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 12),
          // Common allergen chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _commonAllergens.map((allergen) {
              final isSelected = _selectedAllergens.contains(allergen);
              return FilterChip(
                label: Text(allergen),
                selected: isSelected,
                onSelected: (selected) => _toggleAllergen(allergen),
                selectedColor: const Color(0xFF22c55e).withOpacity(0.2),
                checkmarkColor: const Color(0xFF22c55e),
                labelStyle: TextStyle(
                  color: isSelected ? const Color(0xFF22c55e) : Colors.black,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          // Custom allergen input
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _customAllergenController,
                  decoration: InputDecoration(
                    hintText: 'Add custom allergen (e.g., "Mustard")',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _addCustomAllergen(),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _addCustomAllergen,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF22c55e)),
                child: const Text('Add'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_selectedAllergens.isNotEmpty)
            Text(
              'Selected allergens: ${_selectedAllergens.join(', ')}',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.red,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFoodQualitySection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _getFoodQualityColor().withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _getFoodQualityColor()),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_rounded,
            color: _getFoodQualityColor(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _getFoodQualityDescription(),
              style: TextStyle(
                color: _getFoodQualityColor(),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPickupTimeSection() {
  String pickupInfo = 'When can the food be picked up?';
  
  if (_selectedPreparationDate != null) {
    // Calculate food safety deadlines
    Duration safetyDuration;
    switch (_foodTemperature) {
      case 'hot':
        safetyDuration = const Duration(hours: 4);
        break;
      case 'cold':
        safetyDuration = const Duration(hours: 2);
        break;
      case 'room_temp':
      default:
        safetyDuration = const Duration(hours: 4);
        break;
    }
    
    final safetyDeadline = _selectedPreparationDate!.add(safetyDuration);
    final minimumPickupTime = _selectedPreparationDate!.add(const Duration(minutes: 1));
    
    pickupInfo = 'Food prepared: ${DateFormat('MMM dd - h:mm a').format(_selectedPreparationDate!)}\n'
                 'Pickup available from: ${DateFormat('MMM dd - h:mm a').format(minimumPickupTime)}\n'
                 'Must be picked up by: ${DateFormat('MMM dd - h:mm a').format(safetyDeadline)}';
  }
  
  return Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.grey.withOpacity(0.2)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 10,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Pickup Date & Time',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          pickupInfo,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: _selectPickupTime,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.withOpacity(0.3)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_today_rounded,
                  color: Color(0xFF22c55e),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _selectedPickupTime != null
                        ? DateFormat('MMM dd, yyyy - h:mm a').format(_selectedPickupTime!)
                        : 'Select pickup date & time',
                    style: TextStyle(
                      color: _selectedPickupTime != null ? Colors.black : Colors.grey,
                      fontSize: 16,
                    ),
                  ),
                ),
                const Icon(
                  Icons.arrow_drop_down_rounded,
                  color: Colors.grey,
                ),
              ],
            ),
          ),
        ),
        if (_selectedPickupTime != null) ...[
          const SizedBox(height: 8),
          Text(
            'Pickup scheduled: ${DateFormat('EEEE, MMMM dd, yyyy').format(_selectedPickupTime!)} at ${DateFormat('h:mm a').format(_selectedPickupTime!)}',
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF22c55e),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    ),
  );
}

  Widget _buildDeliveryTypeSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Delivery Option',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'How would you like to distribute the food?',
            style: TextStyle(
              fontSize: 14,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildDeliveryOption(
                  title: 'Pickup',
                  subtitle: 'Recipients collect from location',
                  icon: Icons.storefront_rounded,
                  isSelected: _deliveryType == 'pickup',
                  onTap: () => setState(() => _deliveryType = 'pickup'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDeliveryOption(
                  title: 'Delivery',
                  subtitle: 'You deliver to recipients',
                  icon: Icons.delivery_dining_rounded,
                  isSelected: _deliveryType == 'delivery',
                  onTap: () => setState(() => _deliveryType = 'delivery'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryOption({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF22c55e).withOpacity(0.1) : Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF22c55e) : Colors.grey.withOpacity(0.3),
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFF22c55e) : Colors.grey,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? const Color(0xFF22c55e) : Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: isSelected ? const Color(0xFF22c55e) : Colors.grey,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white,
                Color(0xFFF1F5F9),
                Color(0xFFE0F7FA),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        title: const Text(
          'Create Donation',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.white,
              Color(0xFFF1F5F9),
              Color(0xFFE0F7FA),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Safety Guidelines Section
                  _buildSafetyGuidelinesSection(),
                  const SizedBox(height: 24),
                  
                  // Image Selection
                  _buildImageSection(),
                  const SizedBox(height: 24),
                  
                  // Title Field
                  _buildTextField(
                    controller: _titleController,
                    label: 'Food Title',
                    hint: 'e.g., Fresh Vegetables, Bread, etc.',
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a title';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Description Field
                  _buildTextField(
                    controller: _descriptionController,
                    label: 'Description',
                    hint: 'Describe the food items, quantity, condition, etc.',
                    maxLines: 3,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a description';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Expiration Date Section
                  _buildExpirationDateSection(),
                  const SizedBox(height: 16),
                  
                  // Preparation Date Section
                  _buildPreparationDateSection(),
                  const SizedBox(height: 16),
                  
                  // Food Quality Status
                  if (_selectedExpirationDate != null) _buildFoodQualitySection(),
                  
                  // Temperature Control Section
                  _buildTemperatureSection(),
                  const SizedBox(height: 16),
                  
                  // Ingredients Section
                  _buildIngredientsSection(),
                  const SizedBox(height: 16),
                  
                  // Allergens Section
                  _buildAllergensSection(),
                  const SizedBox(height: 16),
                  
                  // Food Category Section
                  _buildFoodCategorySection(),
                  const SizedBox(height: 16),
                  
                  // Donation Specification Section
                  _buildDonationSpecificationSection(),
                  const SizedBox(height: 16),
                  
                  // Pickup Time
                  _buildPickupTimeSection(),
                  const SizedBox(height: 16),
                  
                  // Delivery Type
                  _buildDeliveryTypeSection(),
                  const SizedBox(height: 16),
                  
                  // Address Field (if delivery)
                  if (_deliveryType == 'delivery') ...[
                    _buildTextField(
                      controller: _addressController,
                      label: 'Delivery Address',
                      hint: 'Enter the delivery address',
                      validator: (value) {
                        if (_deliveryType == 'delivery' && (value == null || value.trim().isEmpty)) {
                          return 'Please enter delivery address';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                  
                  // Submit Button - ENHANCED
                  SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _safetyGuidelinesCompleted ? (_isLoading ? null : _submitDonation) : _showSafetyGuidelines,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _safetyGuidelinesCompleted 
                            ? (_isLoading ? Colors.grey : const Color(0xFF22c55e))
                            : Colors.orange,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _safetyGuidelinesCompleted ? Icons.add_circle_rounded : Icons.lock_rounded,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _safetyGuidelinesCompleted 
                                      ? 'Create Donation'
                                      : 'Complete Safety Guidelines First',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}