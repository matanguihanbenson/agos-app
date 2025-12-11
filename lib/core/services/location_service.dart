import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'logging_service.dart';

class LocationService {
  static final LoggingService _loggingService = LoggingService();

  /// Check if location services are enabled
  static Future<bool> isLocationServiceEnabled() async {
    try {
      return await Geolocator.isLocationServiceEnabled();
    } catch (e) {
      _loggingService.logError(
        error: 'Error checking location service: $e',
        context: 'isLocationServiceEnabled',
      );
      return false;
    }
  }

  /// Check location permission status
  static Future<LocationPermission> checkPermission() async {
    try {
      return await Geolocator.checkPermission();
    } catch (e) {
      _loggingService.logError(
        error: 'Error checking location permission: $e',
        context: 'checkPermission',
      );
      return LocationPermission.denied;
    }
  }

  /// Request location permission
  static Future<LocationPermission> requestPermission() async {
    try {
      // First check if location services are enabled
      bool serviceEnabled = await isLocationServiceEnabled();
      if (!serviceEnabled) {
        _loggingService.logEvent(
          event: 'location_services_disabled',
        );
        return LocationPermission.denied;
      }

      // Check current permission status
      LocationPermission permission = await checkPermission();
      
      // If permission is denied, request it (this will show the system dialog)
      if (permission == LocationPermission.denied) {
        _loggingService.logEvent(
          event: 'requesting_location_permission',
        );
        permission = await Geolocator.requestPermission();
        
        if (permission == LocationPermission.denied) {
          _loggingService.logEvent(
            event: 'location_permissions_denied',
          );
          return permission;
        }
      }

      // If permission is permanently denied, we can't request it again
      if (permission == LocationPermission.deniedForever) {
        _loggingService.logEvent(
          event: 'location_permissions_permanently_denied',
        );
        return permission;
      }

      _loggingService.logEvent(
        event: 'location_permission_granted',
      );
      return permission;
    } catch (e) {
      _loggingService.logError(
        error: 'Error requesting location permission: $e',
        context: 'requestPermission',
      );
      return LocationPermission.denied;
    }
  }

  /// Get current position
  static Future<Position?> getCurrentPosition() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await isLocationServiceEnabled();
      if (!serviceEnabled) {
        _loggingService.logEvent(
          event: 'location_services_disabled',
        );
        return null;
      }

      // Check and request permission
      LocationPermission permission = await requestPermission();
      if (permission != LocationPermission.whileInUse && 
          permission != LocationPermission.always) {
        _loggingService.logEvent(
          event: 'location_permission_not_granted',
        );
        return null;
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      _loggingService.logEvent(
        event: 'current_position_obtained',
        parameters: {
          'latitude': position.latitude.toString(),
          'longitude': position.longitude.toString(),
        },
      );

      return position;
    } catch (e) {
      _loggingService.logError(
        error: 'Error getting current position: $e',
        context: 'getCurrentPosition',
      );
      return null;
    }
  }

  /// Get current position as LatLng
  static Future<LatLng?> getCurrentLatLng() async {
    try {
      Position? position = await getCurrentPosition();
      if (position != null) {
        return LatLng(position.latitude, position.longitude);
      }
      return null;
    } catch (e) {
      _loggingService.logError(
        error: 'Error getting current LatLng: $e',
        context: 'getCurrentLatLng',
      );
      return null;
    }
  }

  /// Open location settings
  static Future<void> openLocationSettings() async {
    try {
      await Geolocator.openLocationSettings();
    } catch (e) {
      _loggingService.logError(
        error: 'Error opening location settings: $e',
        context: 'openLocationSettings',
      );
    }
  }

  /// Open app settings
  static Future<void> openAppSettings() async {
    try {
      await Geolocator.openAppSettings();
    } catch (e) {
      _loggingService.logError(
        error: 'Error opening app settings: $e',
        context: 'openAppSettings',
      );
    }
  }

  /// Get location permission status as string
  static String getPermissionStatusString(LocationPermission permission) {
    switch (permission) {
      case LocationPermission.denied:
        return 'Location permission denied';
      case LocationPermission.deniedForever:
        return 'Location permission permanently denied';
      case LocationPermission.whileInUse:
        return 'Location permission granted (while in use)';
      case LocationPermission.always:
        return 'Location permission granted (always)';
      case LocationPermission.unableToDetermine:
        return 'Unable to determine location permission';
    }
  }
}

