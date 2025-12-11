import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/theme/color_palette.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/services/reverse_geocoding_service.dart';
import '../../../core/services/location_service.dart';

class MapSelectionPage extends StatefulWidget {
  final String title;
  final double? initialLat;
  final double? initialLng;
  final double? initialRadius;
  final bool showRadius;

  const MapSelectionPage({
    super.key,
    required this.title,
    this.initialLat,
    this.initialLng,
    this.initialRadius,
    this.showRadius = false,
  });

  @override
  State<MapSelectionPage> createState() => _MapSelectionPageState();
}

class _MapSelectionPageState extends State<MapSelectionPage> {
  final MapController _mapController = MapController();
  
  late double _selectedLat;
  late double _selectedLng;
  late double _radius;
  String _locationName = 'Loading...';
  bool _isLoadingLocation = true;
  double _zoom = 15.0;

  @override
  void initState() {
    super.initState();
    _selectedLat = widget.initialLat ?? 14.5995; // Default to Manila
    _selectedLng = widget.initialLng ?? 120.9842;
    _radius = widget.initialRadius ?? 100;
    _loadLocationName();
  }

  Future<void> _loadLocationName() async {
    setState(() {
      _isLoadingLocation = true;
    });
    
    try {
      final name = await ReverseGeocodingService.getShortAddressFromCoordinates(
        latitude: _selectedLat,
        longitude: _selectedLng,
      );
      if (mounted) {
        setState(() {
          _locationName = name ?? 'Location: $_selectedLat, $_selectedLng';
          _isLoadingLocation = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _locationName = 'Location: $_selectedLat, $_selectedLng';
          _isLoadingLocation = false;
        });
      }
    }
  }

  Future<void> _goToCurrentLocation() async {
    try {
      final position = await LocationService.getCurrentPosition();
      if (position != null) {
        setState(() {
          _selectedLat = position.latitude;
          _selectedLng = position.longitude;
        });
        _mapController.move(LatLng(_selectedLat, _selectedLng), _zoom);
        _loadLocationName();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to get current location')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to get current location: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Stack(
        children: [
          // Map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: LatLng(_selectedLat, _selectedLng),
              initialZoom: _zoom,
              onTap: (tapPosition, point) {
                setState(() {
                  _selectedLat = point.latitude;
                  _selectedLng = point.longitude;
                });
                _loadLocationName();
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.agos_app',
              ),
              // Radius circle (if showRadius is true)
              if (widget.showRadius)
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: LatLng(_selectedLat, _selectedLng),
                      radius: _radius,
                      useRadiusInMeter: true,
                      color: AppColors.primary.withOpacity(0.2),
                      borderColor: AppColors.primary,
                      borderStrokeWidth: 2,
                    ),
                  ],
                ),
              // Center marker
              MarkerLayer(
                markers: [
                  Marker(
                    point: LatLng(_selectedLat, _selectedLng),
                    width: 40,
                    height: 40,
                    child: Icon(
                      widget.showRadius ? Icons.my_location : Icons.place,
                      color: AppColors.primary,
                      size: 40,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Top info panel
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildInfoPanel(),
          ),

          // Zoom controls
          Positioned(
            right: 16,
            bottom: widget.showRadius ? 200 : 100,
            child: _buildZoomControls(),
          ),

          // Current location button
          Positioned(
            left: 16,
            bottom: widget.showRadius ? 200 : 100,
            child: FloatingActionButton(
              heroTag: 'current_location',
              onPressed: _goToCurrentLocation,
              backgroundColor: AppColors.surface,
              child: Icon(Icons.my_location, color: AppColors.primary),
            ),
          ),

          // Radius slider (if showRadius is true)
          if (widget.showRadius)
            Positioned(
              left: 0,
              right: 0,
              bottom: 100,
              child: _buildRadiusSlider(),
            ),

          // Done button
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: _buildDoneButton(),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoPanel() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Selected Location',
            style: AppTextStyles.bodySmall.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.location_on, size: 16, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lat: ${_selectedLat.toStringAsFixed(6)}, Lng: ${_selectedLng.toStringAsFixed(6)}',
                      style: AppTextStyles.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _locationName,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (widget.showRadius) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.radio_button_checked, size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  'Coverage: ${_radius.toStringAsFixed(0)}m radius',
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildZoomControls() {
    return Column(
      children: [
        FloatingActionButton.small(
          heroTag: 'zoom_in',
          onPressed: () {
            setState(() {
              _zoom = (_zoom + 1).clamp(3.0, 18.0);
            });
            _mapController.move(LatLng(_selectedLat, _selectedLng), _zoom);
          },
          backgroundColor: AppColors.surface,
          child: Icon(Icons.add, color: AppColors.primary),
        ),
        const SizedBox(height: 8),
        FloatingActionButton.small(
          heroTag: 'zoom_out',
          onPressed: () {
            setState(() {
              _zoom = (_zoom - 1).clamp(3.0, 18.0);
            });
            _mapController.move(LatLng(_selectedLat, _selectedLng), _zoom);
          },
          backgroundColor: AppColors.surface,
          child: Icon(Icons.remove, color: AppColors.primary),
        ),
      ],
    );
  }

  Widget _buildRadiusSlider() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Adjust Coverage Radius',
                style: AppTextStyles.bodySmall.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${_radius.toStringAsFixed(0)}m',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          Slider(
            value: _radius,
            min: 50,
            max: 1000,
            divisions: 19,
            label: '${_radius.toStringAsFixed(0)}m',
            onChanged: (value) {
              setState(() {
                _radius = value;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDoneButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
        onPressed: _isLoadingLocation ? null : () {
          Navigator.pop(context, {
            'latitude': _selectedLat,
            'longitude': _selectedLng,
            'radius': _radius,
            'locationName': _locationName,
          });
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: _isLoadingLocation ? AppColors.border : AppColors.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: _isLoadingLocation 
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Icon(Icons.check),
        label: Text(
          _isLoadingLocation ? 'Loading Location...' : 'Confirm Location',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
