import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/models/schedule_model.dart';
import '../../../core/models/river_model.dart';
import '../../../core/models/bot_model.dart';
import '../../../core/providers/schedule_provider.dart';
import '../../../core/providers/river_provider.dart';
import '../../../core/providers/bot_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/color_palette.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/utils/snackbar_util.dart';
import '../../../core/services/reverse_geocoding_service.dart';
import 'map_selection_page.dart';

class CreateSchedulePage extends ConsumerStatefulWidget {
  const CreateSchedulePage({super.key});

  @override
  ConsumerState<CreateSchedulePage> createState() => _CreateSchedulePageState();
}

class _CreateSchedulePageState extends ConsumerState<CreateSchedulePage> {
  final _formKey = GlobalKey<FormState>();
  final _riverNameController = TextEditingController();
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
  
  String? _selectedBotId;
  String? _selectedRiverId;
  DateTime _startDate = DateTime.now();
  TimeOfDay _startTime = TimeOfDay.now();
  DateTime _endDate = DateTime.now();
  TimeOfDay _endTime = TimeOfDay.now();
  
  bool _isLoading = false;
  bool _showRiverSuggestions = false;
  List<RiverModel> _riverSuggestions = [];
  String _loadingMessage = 'Creating schedule...';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(botProvider.notifier).loadBots();
      ref.read(riverProvider.notifier).loadRivers();
    });
    
    // Set default end time to 2 hours after start with day rollover
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
    
    // Set default radius
    _operationRadiusController.text = '100';
  }

  @override
  void dispose() {
    _riverNameController.dispose();
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
    final authState = ref.watch(authProvider);
    final currentUser = authState.userProfile;
    final botState = ref.watch(botProvider);
    
    // Filter bots assigned to current field operator
    final availableBots = botState.bots.where((bot) {
      return bot.assignedTo == currentUser?.id;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Create Cleanup Schedule'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildRiverNameSection(),
            const SizedBox(height: 20),
            _buildBotSelectionSection(availableBots),
            const SizedBox(height: 20),
            _buildDateTimeSection(),
            const SizedBox(height: 20),
            _buildOperationAreaSection(),
            const SizedBox(height: 20),
            _buildDockingPointSection(),
            const SizedBox(height: 20),
            _buildNotesSection(),
            const SizedBox(height: 24),
            _buildCreateButton(),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildRiverNameSection() {
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
            'River Name',
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _riverNameController,
            decoration: InputDecoration(
              hintText: 'Enter or select river name',
              prefixIcon: const Icon(Icons.water),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppColors.border),
              ),
            ),
            onChanged: (value) {
              _searchRivers(value);
            },
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a river name';
              }
              return null;
            },
          ),
          if (_showRiverSuggestions)
            Container(
              margin: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Existing river suggestions
                  if (_riverSuggestions.isNotEmpty)
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _riverSuggestions.length,
                      separatorBuilder: (_, __) => Divider(height: 1, color: AppColors.border),
                      itemBuilder: (context, index) {
                        final river = _riverSuggestions[index];
                        return ListTile(
                          dense: true,
                          leading: Icon(Icons.water, size: 20, color: AppColors.primary),
                          title: Text(river.name),
                          subtitle: river.description != null
                              ? Text(
                                  river.description!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                )
                              : null,
                          onTap: () {
                            setState(() {
                              _riverNameController.text = river.name;
                              _selectedRiverId = river.id;
                              _showRiverSuggestions = false;
                            });
                          },
                        );
                      },
                    ),
                  // "Create New River" option
                  if (_riverNameController.text.trim().isNotEmpty)
                    Column(
                      children: [
                        if (_riverSuggestions.isNotEmpty)
                          Divider(height: 1, color: AppColors.border),
                        Container(
                          color: AppColors.primary.withOpacity(0.05),
                          child: ListTile(
                            dense: true,
                            leading: Icon(
                              Icons.add_circle_outline,
                              size: 20,
                              color: AppColors.primary,
                            ),
                            title: Text(
                              'Create "${_riverNameController.text.trim()}"',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              'Add as a new river',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            onTap: () => _showCreateRiverDialog(context, _riverNameController.text.trim()),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBotSelectionSection(List<BotModel> availableBots) {
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
            'Select Bot',
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _selectedBotId,
            decoration: InputDecoration(
              hintText: 'Choose a bot for this cleanup',
              prefixIcon: const Icon(Icons.directions_boat),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppColors.border),
              ),
            ),
            items: availableBots.map((bot) {
              return DropdownMenuItem(
                value: bot.id,
                child: Text(bot.name),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedBotId = value;
              });
            },
            validator: (value) {
              if (value == null) {
                return 'Please select a bot';
              }
              return null;
            },
          ),
          if (availableBots.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'No bots assigned to you',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.warning,
                ),
              ),
            ),
        ],
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
              color: AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.primary.withOpacity(0.2)),
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

  Widget _buildCreateButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _createSchedule,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isLoading
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _loadingMessage,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ],
              )
            : const Text(
                'Create Schedule',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  Future<void> _searchRivers(String query) async {
    if (query.isEmpty) {
      setState(() {
        _showRiverSuggestions = false;
        _riverSuggestions = [];
      });
      return;
    }

    final suggestions = await ref.read(riverProvider.notifier).searchRivers(query);
    setState(() {
      _riverSuggestions = suggestions;
      // Show suggestions dropdown if there's text (even if no matches)
      _showRiverSuggestions = true;
    });
  }

  void _showCreateRiverDialog(BuildContext context, String suggestedName) {
    final nameController = TextEditingController(text: suggestedName);
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.water, color: AppColors.primary),
            const SizedBox(width: 8),
            const Text('Create New River'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'River Name *',
                hintText: 'e.g., Pasig River',
                border: OutlineInputBorder(),
              ),
              autofocus: false,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (Optional)',
                hintText: 'Brief description...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) {
                SnackbarUtil.showError(dialogContext, 'Please enter a river name');
                return;
              }

              final currentUser = ref.read(authProvider).userProfile;
              if (currentUser == null) return;

              try {
                final riverId = await ref.read(riverProvider.notifier).createRiverByName(
                  nameController.text.trim(),
                  description: descriptionController.text.trim(),
                );
                await ref.read(riverProvider.notifier).loadRivers();
                
                if (riverId != null && dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                  // Update the schedule form with the new river
                  setState(() {
                    _riverNameController.text = nameController.text.trim();
                    _selectedRiverId = riverId;
                    _showRiverSuggestions = false;
                  });
                  SnackbarUtil.showSuccess(context, 'River created successfully');
                }
              } catch (e) {
                if (dialogContext.mounted) {
                  SnackbarUtil.showError(dialogContext, 'Failed to create river: $e');
                }
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Future<void> _createSchedule() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Prevent duplicate submission
    if (_isLoading) {
      return;
    }

    setState(() {
      _isLoading = true;
      _loadingMessage = 'Preparing schedule...';
    });

    try {
      final authState = ref.read(authProvider);
      final currentUser = authState.userProfile;

      if (currentUser == null) {
        throw Exception('User not logged in');
      }

      // Check if river exists, create if not
      String riverId = _selectedRiverId ?? '';
      String riverName = _riverNameController.text;

      if (riverId.isEmpty) {
        setState(() {
          _loadingMessage = 'Setting up river...';
        });
        // Create or reuse river by name (dedupe + share within admin group)
        final riverIdNew = await ref.read(riverProvider.notifier).createRiverByName(riverName);
        if (riverIdNew == null) {
          throw Exception('Failed to create or resolve river');
        }
        riverId = riverIdNew;
      }

      final botState = ref.read(botProvider);
      final selectedBot = botState.bots.firstWhere((bot) => bot.id == _selectedBotId);

      final startDateTime = DateTime(
        _startDate.year,
        _startDate.month,
        _startDate.day,
        _startTime.hour,
        _startTime.minute,
      );
      
      final endDateTime = DateTime(
        _endDate.year,
        _endDate.month,
        _endDate.day,
        _endTime.hour,
        _endTime.minute,
      );

      if (!endDateTime.isAfter(startDateTime)) {
        throw Exception('End time must be after start time');
      }

      // Prevent creating schedules whose entire window is already over.
      // It's okay if the start is in the past as long as the end is still in the future,
      // so the bot can still run for the remaining time.
      final now = DateTime.now();
      if (!endDateTime.isAfter(now)) {
        throw Exception('End time must be in the future');
      }

      final schedule = ScheduleModel(
        id: '',
        name: 'Cleanup at $riverName',
        botId: _selectedBotId!,
        botName: selectedBot.name,
        riverId: riverId,
        riverName: riverName,
        ownerAdminId: currentUser.isAdmin ? currentUser.id : (currentUser.createdBy ?? currentUser.id),
        assignedOperatorId: currentUser.isAdmin ? null : currentUser.id,
        assignedOperatorName: currentUser.isAdmin ? null : currentUser.fullName,
        operationArea: OperationArea(
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
        ),
        dockingPoint: LocationPoint(
          latitude: double.parse(_dockingLatController.text),
          longitude: double.parse(_dockingLngController.text),
          locationName: _dockingLocationController.text.isEmpty 
              ? null 
              : _dockingLocationController.text,
        ),
        scheduledDate: startDateTime,
        scheduledEndDate: endDateTime,
        status: 'scheduled',
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      setState(() {
        _loadingMessage = 'Creating schedule...';
      });

      // Add 30-second timeout to prevent indefinite loading
      await ref.read(scheduleProvider.notifier).createSchedule(schedule).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Schedule creation timed out. Please check your connection and try again.');
        },
      );

      if (mounted) {
        SnackbarUtil.showSuccess(context, 'Schedule created successfully');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        // Show more specific error message
        final errorMsg = e.toString().contains('Exception:') 
            ? e.toString().replaceAll('Exception: ', '')
            : 'Failed to create schedule: $e';
        SnackbarUtil.showError(context, errorMsg);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
