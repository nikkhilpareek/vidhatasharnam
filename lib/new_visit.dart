import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'services/camera_service.dart';


class NewVisitScreen extends StatefulWidget {
  const NewVisitScreen({super.key});

  @override
  State<NewVisitScreen> createState() => _NewVisitScreenState();
}

class _NewVisitScreenState extends State<NewVisitScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _associateNameController = TextEditingController();
  final TextEditingController _reraNumberController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _timeController = TextEditingController();
  
  String? _photoUrl;
  bool _isLoadingLocation = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _initializeDateTime();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _associateNameController.dispose();
    _reraNumberController.dispose();
    _locationController.dispose();
    _dateController.dispose();
    _timeController.dispose();
    super.dispose();
  }

  void _initializeDateTime() {
    final now = DateTime.now();
    _dateController.text = "${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}";
    _timeController.text = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
      _locationController.text = 'Automatically detecting your current location...';
    });

    try {
      // Request location permission
      final locationPermission = await Permission.location.request();
      if (locationPermission != PermissionStatus.granted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Location permission is required for accurate location detection')),
        );
        setState(() {
          _isLoadingLocation = false;
          _locationController.text = '';
        });
        return;
      }

      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please enable location services')),
        );
        setState(() {
          _isLoadingLocation = false;
          _locationController.text = '';
        });
        return;
      }

      // Get current position with high accuracy
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 10),
      );

      // Get detailed address from coordinates
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude, 
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        String address = '';
        
        // Build detailed address
        if (place.subThoroughfare != null && place.subThoroughfare!.isNotEmpty) {
          address += '${place.subThoroughfare} ';
        }
        if (place.thoroughfare != null && place.thoroughfare!.isNotEmpty) {
          address += '${place.thoroughfare}, ';
        }
        if (place.subLocality != null && place.subLocality!.isNotEmpty) {
          address += '${place.subLocality}, ';
        }
        if (place.locality != null && place.locality!.isNotEmpty) {
          address += '${place.locality}, ';
        }
        if (place.subAdministrativeArea != null && place.subAdministrativeArea!.isNotEmpty) {
          address += '${place.subAdministrativeArea}, ';
        }
        if (place.administrativeArea != null && place.administrativeArea!.isNotEmpty) {
          address += '${place.administrativeArea}, ';
        }
        if (place.postalCode != null && place.postalCode!.isNotEmpty) {
          address += '${place.postalCode}, ';
        }
        if (place.country != null && place.country!.isNotEmpty) {
          address += place.country!;
        }
        
        // Remove trailing comma and space
        if (address.endsWith(', ')) {
          address = address.substring(0, address.length - 2);
        }
        
        // Add coordinates for precision
        String preciseLocation = '$address\n(${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)})';
        
        setState(() {
          _locationController.text = preciseLocation;
          _isLoadingLocation = false;
        });
        
        print('Precise location detected: $preciseLocation');
        print('Accuracy: ${position.accuracy} meters');
      }
    } catch (e) {
      print('Error getting precise location: $e');
      setState(() {
        _isLoadingLocation = false;
        _locationController.text = '';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to get precise location. Please check your GPS and internet connection.'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _takePicture() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not authenticated')),
      );
      return;
    }

    // Generate a temporary visit ID for the photo
    final tempVisitId = DateTime.now().millisecondsSinceEpoch.toString();

    try {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CameraScreen(
            userId: currentUser.uid,
            visitId: tempVisitId,
            onPhotoTaken: (photoUrl) {
              setState(() {
                _photoUrl = photoUrl;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Photo captured successfully!'),
                  backgroundColor: Colors.green,
                ),
              );
            },
          ),
        ),
      );
    } catch (e) {
      print('Error opening camera: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to open camera')),
      );
    }
  }

  Future<void> _submitForm() async {
  if (_formKey.currentState!.validate()) {
    try {
      // Prepare datetime from date & time controllers
      final now = DateTime.now();
      final selectedDateTime = DateTime(
        now.year,
        now.month,
        now.day,
        int.parse(_timeController.text.split(":")[0]),
        int.parse(_timeController.text.split(":")[1]),
      );

      setState(() {
        _isSubmitting = true;
      });

      // Save visit to Firestore
      await FirebaseFirestore.instance.collection('visits').add({
        'userId': FirebaseAuth.instance.currentUser!.uid,
        'associateName': _associateNameController.text.trim(),
        'reraNumber': _reraNumberController.text.trim(),
        'location': _locationController.text.trim(),
        'photoUrl': _photoUrl ?? "", // Include photo URL if available
        'dateTime': Timestamp.fromDate(selectedDateTime),
        'status': "Pending",
        'scheme': null,
        'createdAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Visit submitted successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      print("Error submitting visit: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to submit visit. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Visit'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Camera preview or photo
              Container(
                height: 200,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _photoUrl != null
                    ? Container(
                        width: double.infinity,
                        height: 200,
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green),
                        ),
                        child: Stack(
                          children: [
                            const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.check_circle, size: 50, color: Colors.green),
                                  SizedBox(height: 8),
                                  Text(
                                    'Photo captured successfully',
                                    style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: CircleAvatar(
                                backgroundColor: Colors.red,
                                radius: 15,
                                child: IconButton(
                                  icon: const Icon(Icons.close, size: 15, color: Colors.white),
                                  onPressed: () {
                                    setState(() {
                                      _photoUrl = null;
                                    });
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : InkWell(
                        onTap: _takePicture,
                        child: Container(
                          width: double.infinity,
                          height: 200,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey),
                          ),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.camera_alt, size: 50, color: Colors.grey),
                              SizedBox(height: 8),
                              Text('Tap to take photo', style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                        ),
                      ),
              ),
              const SizedBox(height: 20),
              
              // Associate Name
              TextFormField(
                controller: _associateNameController,
                decoration: const InputDecoration(
                  labelText: 'Associate Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter associate name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // RERA Number
              TextFormField(
                controller: _reraNumberController,
                decoration: const InputDecoration(
                  labelText: 'RERA Number',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter RERA number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // Location (Auto-detected)
              TextFormField(
                controller: _locationController,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'Location (Auto-detected)',
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  suffixIcon: _isLoadingLocation 
                    ? Container(
                        width: 20,
                        height: 20,
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      )
                    : IconButton(
                        icon: const Icon(Icons.my_location),
                        onPressed: _getCurrentLocation,
                        tooltip: 'Refresh location',
                      ),
                  helperText: 'Location is automatically detected from your current position',
                  helperMaxLines: 2,
                ),
                maxLines: 2,
                minLines: 1,
                validator: (value) {
                  if (value == null || value.isEmpty || value.contains('Automatically detecting') || value == 'Detecting precise location...') {
                    return 'Please wait for automatic location detection to complete';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // Date
              TextFormField(
                controller: _dateController,
                decoration: const InputDecoration(
                  labelText: 'Date',
                  border: OutlineInputBorder(),
                ),
                readOnly: true,
              ),
              const SizedBox(height: 16),
              
              // Time
              TextFormField(
                controller: _timeController,
                decoration: const InputDecoration(
                  labelText: 'Time',
                  border: OutlineInputBorder(),
                ),
                readOnly: true,
              ),
              const SizedBox(height: 24),
              
              // Submit Button
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submitForm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isSubmitting 
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          SizedBox(width: 8),
                          Text('Submitting...'),
                        ],
                      )
                    : const Text('Submit Visit'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}