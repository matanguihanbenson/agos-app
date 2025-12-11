import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/models/schedule_model.dart';
import '../../../core/providers/schedule_provider.dart';
import '../../../core/theme/color_palette.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/services/reverse_geocoding_service.dart';
import 'map_selection_page.dart';

class EditSchedulePage extends ConsumerStatefulWidget {
  final ScheduleModel schedule;

  const EditSchedulePage({
    super.key,
    required this.schedule,
  });

  @override
  ConsumerState<EditSchedulePage> createState() => _EditSchedulePageState();
}

class _EditSchedulePageState extends ConsumerState<EditSchedulePage> {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();
  
  // Lat/Lng controllers for operation area
  final _operationLatController = TextEditingController();
  final _operationLngController = TextEditingController();
  final _operationRadiusController = TextEditingController();
  final _operationLocationController = TextEditingController();
  
  // Lat/Lng controllers for docking point
  final _dockingLatController = TextEditingController();
  final _dockingLngController = TextEditingController();
  final _dockingLocationController = TextEditingController();
  
  late DateTime _startDate;
  late TimeOfDay _startTime;
  late DateTime _endDate;
  late TimeOfDay _endTime;
  
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    
    // Initialize with schedule data
    _notesController.text = widget.schedule.notes ?? '';
    
    // Operation area
    _operationLatController.text = widget.schedule.operationArea.center.latitude.toString();
    _operationLngController.text = widget.schedule.operationArea.center.longitude.toString();
    _operationRadiusController.text = widget.schedule.operationArea.radiusInMeters.toString();
    _operationLocationController.text = widget.schedule.operationArea.locationName ?? '';
    
    // Docking point
    _dockingLatController.text = widget.schedule.dockingPoint.latitude.toString();
    _dockingLngController.text = widget.schedule.dockingPoint.longitude.toString();
    _dockingLocationController.text = widget.schedule.dockingPoint.locationName ?? '';
    
    // Schedule dates
    _startDate = widget.schedule.scheduledDate;
    _startTime = TimeOfDay.fromDateTime(widget.schedule.scheduledDate);
    
    if (widget.schedule.scheduledEndDate != null) {
      _endDate = widget.schedule.scheduledEndDate!;
      _endTime = TimeOfDay.fromDateTime(widget.schedule.scheduledEndDate!);
    } else {
      final startCombined = DateTime(
        _startDate.year,
        _startDate.month,
        _startDate.day,
        _startTime.hour,
        _startTime.minute,
      );
      final adjusted = startCombined.add(const Duration(hours: 2));
      _endDate = DateTime(adjusted.year, adjusted.month, adjusted.day);
      _endTime = TimeOfDay(hour: adjusted.hour, minute: adjusted.minute);
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    _operationLatController.dispose();
    _operationLngController.dispose();
    _operationRadiusController.dispose();
    _operationLocationController.dispose();
    _dockingLatController.dispose();
    _dockingLngController.dispose();
    _dockingLocationController.dispose();
    super.dispose();
  }

  String _calculateDuration() {
    final start = DateTime(
      _startDate.year,
      _startDate.month,
      _startDate.day,
      _startTime.hour,
      _startTime.minute,
    );
    final end = DateTime(
      _endDate.year,
      _endDate.month,
      _endDate.day,
      _endTime.hour,
      _endTime.minute,
    );
    
    final duration = end.difference(start);
    
    if (duration.isNegative) {
      return 'Invalid duration';
    }
    
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    
    if (hours == 0) {
      return '$minutes minutes';
    } else if (minutes == 0) {
      return '$hours ${hours == 1 ? 'hour' : 'hours'}';
    } else {
      return '$hours ${hours == 1 ? 'hour' : 'hours'} $minutes ${minutes == 1 ? 'minute' : 'minutes'}';
    }
  }

  Future<void> _loadLocationFromCoordinates(bool isOperationArea) async {
    try {
      final lat = double.tryParse(isOperationArea ? _operationLatController.text : _dockingLatController.text);
      final lng = double.tryParse(isOperationArea ? _operationLngController.text : _dockingLngController.text);
      
      if (lat == null || lng == null) return;
      
      final address = await ReverseGeocodingService.getAddressFromCoordinates(
        latitude: lat,
        longitude: lng,
      );
      
      if (address != null) {
        setState(() {
          if (isOperationArea) {
            _operationLocationController.text = address;
          } else {
            _dockingLocationController.text = address;
          }
        });
      }
    } catch (e) {
      print('Error loading location: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Edit Cleanup Schedule'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Info message
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.info, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'You can update the schedule date, location, and notes.',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            
            _buildDateTimeSection(),
            const SizedBox(height: 20),
            _buildOperationAreaSection(),
            const SizedBox(height: 20),
            _buildDockingPointSection(),
            const SizedBox(height: 20),
            _buildNotesSection(),
            const SizedBox(height: 24),
            _buildSaveButton(),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildDateTimeSection() {
    final duration = _calculateDuration();
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Schedule Date & Time',
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          
          // Start Date & Time
          Text(
            'Start',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _startDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date != null) {
                      setState(() {
                        _startDate = date;
                        final newStart = DateTime(
                          _startDate.year,
                          _startDate.month,
                          _startDate.day,
                          _startTime.hour,
                          _startTime.minute,
                        );
                        final currentEnd = DateTime(
                          _endDate.year,
                          _endDate.month,
                          _endDate.day,
                          _endTime.hour,
                          _endTime.minute,
                        );
                        if (!currentEnd.isAfter(newStart)) {
                          final adjusted = newStart.add(const Duration(hours: 2));
                          _endDate = DateTime(adjusted.year, adjusted.month, adjusted.day);
                          _endTime = TimeOfDay(hour: adjusted.hour, minute: adjusted.minute);
                        }
                      });
                    }
                  },
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text(
                    DateFormat('MMM d, yyyy').format(_startDate),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: _startTime,
                    );
                    if (time != null) {
                      setState(() {
                        _startTime = time;
                        final newStart = DateTime(
                          _startDate.year,
                          _startDate.month,
                          _startDate.day,
                          _startTime.hour,
                          _startTime.minute,
                        );
                        final currentEnd = DateTime(
                          _endDate.year,
                          _endDate.month,
                          _endDate.day,
                          _endTime.hour,
                          _endTime.minute,
                        );
                        if (!currentEnd.isAfter(newStart)) {
                          final adjusted = newStart.add(const Duration(hours: 2));
                          _endDate = DateTime(adjusted.year, adjusted.month, adjusted.day);
                          _endTime = TimeOfDay(hour: adjusted.hour, minute: adjusted.minute);
                        }
                      });
                    }
                  },
                  icon: const Icon(Icons.access_time, size: 16),
                  label: Text(
                    _startTime.format(context),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // End Date & Time
          Text(
            'End',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _endDate,
                      firstDate: _startDate,
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date != null) {
                      setState(() {
                        _endDate = date;
                      });
                    }
                  },
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text(
                    DateFormat('MMM d, yyyy').format(_endDate),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: _endTime,
                    );
                    if (time != null) {
                      setState(() {
                        _endTime = time;
                        final startCombined = DateTime(
                          _startDate.year,
                          _startDate.month,
                          _startDate.day,
                          _startTime.hour,
                          _startTime.minute,
                        );
                        final endCombined = DateTime(
                          _endDate.year,
                          _endDate.month,
                          _endDate.day,
                          _endTime.hour,
                          _endTime.minute,
                        );
                        if (!endCombined.isAfter(startCombined)) {
                          final adjusted = startCombined.add(const Duration(hours: 2));
                          _endDate = DateTime(adjusted.year, adjusted.month, adjusted.day);
                          _endTime = TimeOfDay(hour: adjusted.hour, minute: adjusted.minute);
                        }
                      });
                    }
                  },
                  icon: const Icon(Icons.access_time, size: 16),
                  label: Text(
                    _endTime.format(context),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Duration Display
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.timer, size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  'Duration: ',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  duration,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOperationAreaSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Operation Area',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () async {
                  final lat = double.tryParse(_operationLatController.text);
                  final lng = double.tryParse(_operationLngController.text);
                  final radius = double.tryParse(_operationRadiusController.text) ?? 100;
                  
                  final result = await Navigator.push<Map<String, dynamic>>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MapSelectionPage(
                        title: 'Select Operation Area',
                        initialLat: lat,
                        initialLng: lng,
                        initialRadius: radius,
                        showRadius: true,
                      ),
                    ),
                  );
                  if (result != null) {
                    setState(() {
                      _operationLatController.text = result['latitude'].toString();
                      _operationLngController.text = result['longitude'].toString();
                      _operationRadiusController.text = (result['radius'] ?? 100).toString();
                      _operationLocationController.text = result['locationName'] ?? '';
                    });
                  }
                },
                icon: const Icon(Icons.map, size: 16),
                label: const Text('View on Map', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Latitude Input
          TextFormField(
            controller: _operationLatController,
            decoration: InputDecoration(
              labelText: 'Latitude',
              hintText: 'e.g., 14.5995',
              prefixIcon: const Icon(Icons.location_on, size: 20),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^-?\d*\.?\d*')),
            ],
            onChanged: (_) => _loadLocationFromCoordinates(true),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Required';
              }
              final lat = double.tryParse(value);
              if (lat == null || lat < -90 || lat > 90) {
                return 'Invalid latitude';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          
          // Longitude Input
          TextFormField(
            controller: _operationLngController,
            decoration: InputDecoration(
              labelText: 'Longitude',
              hintText: 'e.g., 120.9842',
              prefixIcon: const Icon(Icons.location_on, size: 20),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^-?\d*\.?\d*')),
            ],
            onChanged: (_) => _loadLocationFromCoordinates(true),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Required';
              }
              final lng = double.tryParse(value);
              if (lng == null || lng < -180 || lng > 180) {
                return 'Invalid longitude';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          
          // Coverage Area (Radius) Input
          TextFormField(
            controller: _operationRadiusController,
            decoration: InputDecoration(
              labelText: 'Coverage Area (meters)',
              hintText: 'e.g., 100',
              prefixIcon: const Icon(Icons.radio_button_checked, size: 20),
              suffixText: 'm',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Required';
              }
              final radius = double.tryParse(value);
              if (radius == null || radius < 50 || radius > 10000) {
                return 'Range: 50-10000m';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          
          // Location Display (Read-only)
          TextFormField(
            controller: _operationLocationController,
            decoration: InputDecoration(
              labelText: 'Location',
              hintText: 'Detected location will appear here',
              prefixIcon: const Icon(Icons.place, size: 20),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            readOnly: true,
            maxLines: 2,
            minLines: 1,
          ),
        ],
      ),
    );
  }

  Widget _buildDockingPointSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Docking Point',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () async {
                  final lat = double.tryParse(_dockingLatController.text);
                  final lng = double.tryParse(_dockingLngController.text);
                  
                  final result = await Navigator.push<Map<String, dynamic>>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MapSelectionPage(
                        title: 'Select Docking Point',
                        initialLat: lat,
                        initialLng: lng,
                        showRadius: false,
                      ),
                    ),
                  );
                  if (result != null) {
                    setState(() {
                      _dockingLatController.text = result['latitude'].toString();
                      _dockingLngController.text = result['longitude'].toString();
                      _dockingLocationController.text = result['locationName'] ?? '';
                    });
                  }
                },
                icon: const Icon(Icons.map, size: 16),
                label: const Text('View on Map', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Latitude Input
          TextFormField(
            controller: _dockingLatController,
            decoration: InputDecoration(
              labelText: 'Latitude',
              hintText: 'e.g., 14.5995',
              prefixIcon: const Icon(Icons.location_on, size: 20),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^-?\d*\.?\d*')),
            ],
            onChanged: (_) => _loadLocationFromCoordinates(false),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Required';
              }
              final lat = double.tryParse(value);
              if (lat == null || lat < -90 || lat > 90) {
                return 'Invalid latitude';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          
          // Longitude Input
          TextFormField(
            controller: _dockingLngController,
            decoration: InputDecoration(
              labelText: 'Longitude',
              hintText: 'e.g., 120.9842',
              prefixIcon: const Icon(Icons.location_on, size: 20),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^-?\d*\.?\d*')),
            ],
            onChanged: (_) => _loadLocationFromCoordinates(false),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Required';
              }
              final lng = double.tryParse(value);
              if (lng == null || lng < -180 || lng > 180) {
                return 'Invalid longitude';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          
          // Location Display (Read-only)
          TextFormField(
            controller: _dockingLocationController,
            decoration: InputDecoration(
              labelText: 'Location',
              hintText: 'Detected location will appear here',
              prefixIcon: const Icon(Icons.place, size: 20),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            readOnly: true,
            maxLines: 2,
            minLines: 1,
          ),
        ],
      ),
    );
  }

  Widget _buildNotesSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Notes (Optional)',
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _notesController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Add any additional notes or instructions...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppColors.border),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _saveSchedule,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
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
                'Save Changes',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  Future<void> _saveSchedule() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Prevent duplicate submission
    if (_isLoading) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Build scheduled date and end date
      final scheduledDate = DateTime(
        _startDate.year,
        _startDate.month,
        _startDate.day,
        _startTime.hour,
        _startTime.minute,
      );
      
      final scheduledEndDate = DateTime(
        _endDate.year,
        _endDate.month,
        _endDate.day,
        _endTime.hour,
        _endTime.minute,
      );

      // Validate duration
      if (!scheduledEndDate.isAfter(scheduledDate)) {
        throw Exception('End time must be after start time');
      }

      // Build operation area
      final operationArea = OperationArea(
        center: LocationPoint(
          latitude: double.parse(_operationLatController.text),
          longitude: double.parse(_operationLngController.text),
          locationName: _operationLocationController.text.isEmpty 
              ? null 
              : _operationLocationController.text,
        ),
        radiusInMeters: double.parse(_operationRadiusController.text),
        locationName: _operationLocationController.text.isEmpty 
            ? null 
            : _operationLocationController.text,
      );

      // Build docking point
      final dockingPoint = LocationPoint(
        latitude: double.parse(_dockingLatController.text),
        longitude: double.parse(_dockingLngController.text),
        locationName: _dockingLocationController.text.isEmpty 
            ? null 
            : _dockingLocationController.text,
      );

      // Update schedule data
      final updates = {
        'scheduled_date': scheduledDate,
        'scheduled_end_date': scheduledEndDate,
        'operation_area': operationArea.toMap(),
        'docking_point': dockingPoint.toMap(),
        'notes': _notesController.text.isEmpty ? null : _notesController.text,
      };

      await ref.read(scheduleProvider.notifier).updateSchedule(
        widget.schedule.id,
        updates,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Schedule updated successfully'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update schedule: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}
