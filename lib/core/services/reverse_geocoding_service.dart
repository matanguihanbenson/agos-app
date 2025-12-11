import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class ReverseGeocodingService {
  static const String _nominatimBaseUrl = 'https://nominatim.openstreetmap.org/reverse';
  
  /// Reverse geocodes a latitude and longitude to get the address
  /// Returns null if the geocoding fails or if coordinates are invalid
  static Future<String?> getAddressFromCoordinates({
    required double latitude,
    required double longitude,
  }) async {
    try {
      // Validate coordinates
      if (latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) {
        return null;
      }

      final url = Uri.parse(_nominatimBaseUrl).replace(queryParameters: {
        'format': 'json',
        'lat': latitude.toString(),
        'lon': longitude.toString(),
        'zoom': '18',
        'addressdetails': '1',
      });

      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'AGOS-App/1.0',
        },
      ).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          throw Exception('Request timeout');
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data is Map<String, dynamic> && data['display_name'] != null) {
          return _formatAddress(data);
        }
      }
      
      return null;
    } catch (e) {
      print('Reverse geocoding error: $e');
      return null;
    }
  }

  /// Formats the address from Nominatim response
  /// Returns detailed address with street, locality, city, state, country
  static String _formatAddress(Map<String, dynamic> data) {
    final address = data['address'] as Map<String, dynamic>?;
    if (address == null) {
      return data['display_name'] as String? ?? 'Unknown location';
    }

    // Build a readable address from available components
    final components = <String>[];
    
    // Add house number and street if available
    if (address['house_number'] != null && address['road'] != null) {
      components.add('${address['house_number']} ${address['road']}');
    } else if (address['road'] != null) {
      components.add(address['road'] as String);
    }
    
    // Add specific locality (suburb, neighbourhood, hamlet)
    if (address['suburb'] != null) {
      components.add(address['suburb'] as String);
    } else if (address['neighbourhood'] != null) {
      components.add(address['neighbourhood'] as String);
    } else if (address['hamlet'] != null) {
      components.add(address['hamlet'] as String);
    }
    
    // Add municipality/city/town/village
    if (address['municipality'] != null) {
      components.add(address['municipality'] as String);
    } else if (address['city'] != null) {
      components.add(address['city'] as String);
    } else if (address['town'] != null) {
      components.add(address['town'] as String);
    } else if (address['village'] != null) {
      components.add(address['village'] as String);
    }
    
    // Add state/province/region
    if (address['state'] != null) {
      components.add(address['state'] as String);
    } else if (address['province'] != null) {
      components.add(address['province'] as String);
    } else if (address['region'] != null) {
      components.add(address['region'] as String);
    }
    
    // Add country
    if (address['country'] != null) {
      components.add(address['country'] as String);
    }

    if (components.isNotEmpty) {
      return components.join(', ');
    }

    // Fallback to display_name if no components found
    return data['display_name'] as String? ?? 'Unknown location';
  }

  /// Gets a short but specific address for display purposes
  /// Includes: municipality/city/town, state/province, country
  /// More specific than just "Philippines"
  static Future<String?> getShortAddressFromCoordinates({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final url = Uri.parse(_nominatimBaseUrl).replace(queryParameters: {
        'format': 'json',
        'lat': latitude.toString(),
        'lon': longitude.toString(),
        'zoom': '14', // Increased zoom for more specific location
        'addressdetails': '1',
      });

      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'AGOS-App/1.0',
        },
      ).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          throw Exception('Request timeout');
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data is Map<String, dynamic>) {
          final address = data['address'] as Map<String, dynamic>?;
          if (address != null) {
            final components = <String>[];
            
            // Add most specific locality available (suburb, neighbourhood, or hamlet)
            if (address['suburb'] != null) {
              components.add(address['suburb'] as String);
            } else if (address['neighbourhood'] != null) {
              components.add(address['neighbourhood'] as String);
            } else if (address['hamlet'] != null) {
              components.add(address['hamlet'] as String);
            }
            
            // Add municipality/city/town/village
            if (address['municipality'] != null) {
              components.add(address['municipality'] as String);
            } else if (address['city'] != null) {
              components.add(address['city'] as String);
            } else if (address['town'] != null) {
              components.add(address['town'] as String);
            } else if (address['village'] != null) {
              components.add(address['village'] as String);
            }
            
            // Add state/province/region
            if (address['state'] != null) {
              components.add(address['state'] as String);
            } else if (address['province'] != null) {
              components.add(address['province'] as String);
            } else if (address['region'] != null) {
              components.add(address['region'] as String);
            }
            
            // Only add country if we don't have enough components
            if (components.length < 2 && address['country'] != null) {
              components.add(address['country'] as String);
            }

            if (components.isNotEmpty) {
              return components.join(', ');
            }
          }
        }
      }
      
      return null;
    } catch (e) {
      print('Short address geocoding error: $e');
      return null;
    }
  }

  /// Checks if coordinates are valid
  static bool isValidCoordinates(double latitude, double longitude) {
    return latitude >= -90 && latitude <= 90 && longitude >= -180 && longitude <= 180;
  }

  /// Gets distance between two coordinates in kilometers
  static double getDistanceInKm(LatLng point1, LatLng point2) {
    const Distance distance = Distance();
    return distance.as(LengthUnit.Kilometer, point1, point2);
  }
}
