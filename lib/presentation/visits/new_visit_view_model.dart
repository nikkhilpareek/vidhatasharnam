import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/viewmodels/base_view_model.dart';
import '../../../core/viewmodels/view_state.dart';
import '../../../core/logger/app_logger.dart';
import '../../../core/exceptions/app_exception.dart';

class NewVisitViewModel extends BaseViewModel {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _photoUrl;
  String _location = '';
  bool _isLoadingLocation = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  String? get photoUrl => _photoUrl;
  String get location => _location;
  bool get isLoadingLocation => _isLoadingLocation;
  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;

  void setPhotoUrl(String? url) {
    _photoUrl = url;
    notifyListeners();
  }

  void clearPhotoUrl() {
    _photoUrl = null;
    notifyListeners();
  }

  Future<void> getCurrentLocation() async {
    _isLoadingLocation = true;
    _location = 'Automatically detecting your current location...';
    notifyListeners();

    try {
      var locationPermission = await Permission.location.status;

      if (locationPermission.isDenied) {
        locationPermission = await Permission.location.request();
      }

      if (locationPermission.isPermanentlyDenied) {
        _isLoadingLocation = false;
        _location = '';
        _errorMessage = 'Location permission is permanently denied. Please enable it in app settings.';
        notifyListeners();
        return;
      }

      if (!locationPermission.isGranted) {
        _isLoadingLocation = false;
        _location = '';
        _errorMessage = 'Location permission is required for accurate location detection';
        notifyListeners();
        return;
      }

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _isLoadingLocation = false;
        _location = '';
        _errorMessage = 'Please enable location services';
        notifyListeners();
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
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

        String preciseLocation = '$address\n(${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)})';

        _location = preciseLocation;
        _isLoadingLocation = false;
        _errorMessage = null;
        notifyListeners();

        AppLogger.info('Precise location detected: $preciseLocation');
      }
    } catch (e, stackTrace) {
      AppLogger.error('Error getting precise location', error: e, stackTrace: stackTrace);
      _isLoadingLocation = false;
      _location = '';
      _errorMessage = 'Failed to get precise location. Please check your GPS and internet connection.';
      notifyListeners();
    }
  }

  Future<bool> submitVisit({
    required String associateName,
    required String customerName,
    required String upperlineName,
    required String teamleaderName,
    required String reraNumber,
    required String schemeName,
    required DateTime dateTime,
  }) async {
    setState(ViewState.loading);
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) {
        throw const UnauthorizedException('Not authenticated. Please log in again.');
      }

      await _firestore.collection('visits').add({
        'userId': uid,
        'associateName': associateName.trim(),
        'customerName': customerName.trim(),
        'upperlineName': upperlineName.trim(),
        'teamleaderName': teamleaderName.trim(),
        'reraNumber': reraNumber.trim(),
        'schemeName': schemeName.trim(),
        'location': _location.trim(),
        'photoUrl': _photoUrl ?? '',
        'dateTime': Timestamp.fromDate(dateTime),
        'status': 'Pending',
        'scheme': null,
        'createdAt': FieldValue.serverTimestamp(),
      });

      _isSubmitting = false;
      setState(ViewState.success);
      return true;
    } catch (error, stackTrace) {
      AppLogger.error('Error submitting visit data', error: error, stackTrace: stackTrace);
      _isSubmitting = false;
      _errorMessage = 'Failed to submit visit. Please try again.';
      setState(ViewState.error);
      return false;
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}

