import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/logger/app_logger.dart';
import '../../core/viewmodels/base_view_model.dart';
import '../../core/viewmodels/view_state.dart';
import '../../data/datasources/camera/camera_service.dart';

class VisitViewModel extends BaseViewModel {
  VisitViewModel();

  final TextEditingController associateNameController = TextEditingController();
  final TextEditingController customerNameController = TextEditingController();
  final TextEditingController upperlineNameController = TextEditingController();
  final TextEditingController teamleaderNameController = TextEditingController();
  final TextEditingController reraNumberController = TextEditingController();
  final TextEditingController schemeNameController = TextEditingController();
  final TextEditingController locationController = TextEditingController();
  final TextEditingController dateController = TextEditingController();
  final TextEditingController timeController = TextEditingController();

  String? _photoUrl;
  String? get photoUrl => _photoUrl;

  // Allow UI to set the photo url after navigation-based capture
  void setPhotoUrl(String url) {
    _photoUrl = url;
    notifyListeners();
  }

  bool _isLoadingLocation = false;
  bool get isLoadingLocation => _isLoadingLocation;

  bool _isSubmitting = false;
  bool get isSubmitting => _isSubmitting;

  void initializeDateTime() {
    final now = DateTime.now();
    dateController.text = "${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}";
    timeController.text = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
  }

  Future<void> getCurrentLocation() async {
    _isLoadingLocation = true;
    locationController.text = 'Automatically detecting your current location...';
    notifyListeners();

    try {
      // Check iOS/Android location permission via Geolocator API
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        _isLoadingLocation = false;
        locationController.text = '';
        notifyListeners();
        throw const PermissionDeniedException('Location permission permanently denied');
      }
      if (permission == LocationPermission.denied) {
        _isLoadingLocation = false;
        locationController.text = '';
        notifyListeners();
        throw const PermissionDeniedException('Location permission denied');
      }

      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _isLoadingLocation = false;
        locationController.text = '';
        notifyListeners();
        throw Exception('Location services disabled');
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      final placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      if (placemarks.isNotEmpty) {
        final place = placemarks[0];
        String address = '';
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
        if (address.endsWith(', ')) {
          address = address.substring(0, address.length - 2);
        }
        final preciseLocation = '$address\n(${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)})';
        locationController.text = preciseLocation;
        AppLogger.info('Precise location detected: $preciseLocation');
        AppLogger.info('Location accuracy: ${position.accuracy} meters');
      }
    } catch (e, stackTrace) {
      AppLogger.error('Error getting precise location', error: e, stackTrace: stackTrace);
      locationController.text = '';
      rethrow;
    } finally {
      _isLoadingLocation = false;
      notifyListeners();
    }
  }

  void clearPhoto() {
    _photoUrl = null;
    notifyListeners();
  }

  Future<void> takePicture({required void Function(String photoUrl) onPhotoTaken}) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      throw StateError('User not authenticated');
    }
    final tempVisitId = DateTime.now().millisecondsSinceEpoch.toString();
    try {
      await CameraServiceNavigator.open(
        userId: currentUser.uid,
        visitId: tempVisitId,
        onPhotoTaken: (url) {
          _photoUrl = url;
          notifyListeners();
          onPhotoTaken(url);
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('Error opening camera', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<void> submitVisit() async {
    if (_isSubmitting) return;
    _isSubmitting = true;
    setState(ViewState.loading);
    try {
      final now = DateTime.now();
      final selectedDateTime = DateTime(
        now.year,
        now.month,
        now.day,
        int.parse(timeController.text.split(":")[0]),
        int.parse(timeController.text.split(":")[1]),
      );

      await FirebaseFirestore.instance.collection('visits').add({
        'userId': FirebaseAuth.instance.currentUser!.uid,
        'associateName': associateNameController.text.trim(),
        'customerName': customerNameController.text.trim(),
        'upperlineName': upperlineNameController.text.trim(),
        'teamleaderName': teamleaderNameController.text.trim(),
        'reraNumber': reraNumberController.text.trim(),
        'schemeName': schemeNameController.text.trim(),
        'location': locationController.text.trim(),
        'photoUrl': _photoUrl ?? "",
        'dateTime': Timestamp.fromDate(selectedDateTime),
        'status': "Pending",
        'scheme': null,
        'createdAt': FieldValue.serverTimestamp(),
      });

      setState(ViewState.success);
    } catch (e, stackTrace) {
      AppLogger.error('Error submitting visit data', error: e, stackTrace: stackTrace);
      setState(ViewState.error);
      rethrow;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    associateNameController.dispose();
    customerNameController.dispose();
    upperlineNameController.dispose();
    teamleaderNameController.dispose();
    reraNumberController.dispose();
    schemeNameController.dispose();
    locationController.dispose();
    dateController.dispose();
    timeController.dispose();
    super.dispose();
  }
}

/// A small helper to decouple navigation to CameraScreen from the View
class CameraServiceNavigator {
  static Future<void> open({
    required String userId,
    required String visitId,
    required void Function(String photoUrl) onPhotoTaken,
  }) async {
    throw UnimplementedError('Provide navigation from the UI when calling takePicture');
  }
}
