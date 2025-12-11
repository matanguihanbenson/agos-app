import 'package:flutter/material.dart';
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
  
  String? _selectedBotId;
  String? _selectedRiverId;
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  
  // Operation Area
  double? _operationLat;
  double? _operationLng;
  double _operationRadius = 100; // meters
  String? _operationLocationName;
  
  // Docking Point
  double? _dockingLat;
  double? _dockingLng;
  String? _dockingLocationName;
  
  bool _isLoading = false;
  bool _showRiverSuggestions = false;
  List<RiverModel> _riverSuggestions = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(botProvider.notifier).loadBots();
      ref.read(riverProvider.notifier).loadRivers();
    });
  }

  @override
  void dispose() {
    _riverNameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final botState = ref.watch(botProvider);
    final availableBots = botState.bots.where((bot) => !bot.isAssigned).toList();

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
          if (_showRiverSuggestions && _riverSuggestions.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: ListView.separated(
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
              prefixIcon: const Icon(Icons.smart_toy),
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
        ],
      ),
    );
  }

  Widget _buildDateTimeSection() {
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
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date != null) {
                      setState(() {
                        _selectedDate = date;
                      });
                    }
                  },
                  icon: const Icon(Icons.calendar_today),
                  label: Text(DateFormat('MMM d, yyyy').format(_selectedDate)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: _selectedTime,
                    );
                    if (time != null) {
                      setState(() {
                        _selectedTime = time;
                      });
                    }
                  },
                  icon: const Icon(Icons.access_time),
                  label: Text(_selectedTime.format(context)),
                ),
              ),
            ],
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
                  final result = await Navigator.push<Map<String, dynamic>>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MapSelectionPage(
                        title: 'Select Operation Area',
                        initialLat: _operationLat,
                        initialLng: _operationLng,
                        initialRadius: _operationRadius,
                        showRadius: true,
                      ),
                    ),
                  );
                  if (result != null) {
                    setState(() {
                      _operationLat = result['latitude'];
                      _operationLng = result['longitude'];
                      _operationRadius = result['radius'] ?? 100;
                      _operationLocationName = result['locationName'];
                    });
                  }
                },
                icon: const Icon(Icons.map),
                label: const Text('View on Map'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_operationLat == null || _operationLng == null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.warning.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.warning, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tap "View on Map" to select operation area',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.warning,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            _buildLocationDisplay(
              'Latitude',
              _operationLat!.toStringAsFixed(6),
              Icons.location_on,
            ),
            const SizedBox(height: 8),
            _buildLocationDisplay(
              'Longitude',
              _operationLng!.toStringAsFixed(6),
              Icons.location_on,
            ),
            const SizedBox(height: 8),
            _buildLocationDisplay(
              'Location',
              _operationLocationName ?? 'Loading...',
              Icons.place,
            ),
            const SizedBox(height: 8),
            _buildLocationDisplay(
              'Coverage Area',
              '${_operationRadius.toStringAsFixed(0)}m radius',
              Icons.radio_button_checked,
            ),
          ],
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
                  final result = await Navigator.push<Map<String, dynamic>>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MapSelectionPage(
                        title: 'Select Docking Point',
                        initialLat: _dockingLat,
                        initialLng: _dockingLng,
                        showRadius: false,
                      ),
                    ),
                  );
                  if (result != null) {
                    setState(() {
                      _dockingLat = result['latitude'];
                      _dockingLng = result['longitude'];
                      _dockingLocationName = result['locationName'];
                    });
                  }
                },
                icon: const Icon(Icons.map),
                label: const Text('View on Map'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_dockingLat == null || _dockingLng == null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.warning.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.warning, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tap "View on Map" to select docking point',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.warning,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            _buildLocationDisplay(
              'Latitude',
              _dockingLat!.toStringAsFixed(6),
              Icons.location_on,
            ),
            const SizedBox(height: 8),
            _buildLocationDisplay(
              'Longitude',
              _dockingLng!.toStringAsFixed(6),
              Icons.location_on,
            ),
            const SizedBox(height: 8),
            _buildLocationDisplay(
              'Location',
              _dockingLocationName ?? 'Loading...',
              Icons.place,
            ),
          ],
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

  Widget _buildLocationDisplay(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: AppTextStyles.bodySmall.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
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
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
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
      _showRiverSuggestions = suggestions.isNotEmpty;
    });
  }

  Future<void> _createSchedule() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_operationLat == null || _operationLng == null) {
      SnackbarUtil.showError(context, 'Please select an operation area');
      return;
    }

    if (_dockingLat == null || _dockingLng == null) {
      SnackbarUtil.showError(context, 'Please select a docking point');
      return;
    }

    setState(() {
      _isLoading = true;
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
        // Create new river
        final riverService = ref.read(riverServiceProvider);
        final newRiver = RiverModel(
          id: '',
          name: riverName,
          ownerAdminId: currentUser.id,
          organizationId: currentUser.organizationId,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        riverId = await riverService.create(newRiver);
      }

      final botState = ref.read(botProvider);
      final selectedBot = botState.bots.firstWhere((bot) => bot.id == _selectedBotId);

      final scheduledDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      final schedule = ScheduleModel(
        id: '',
        name: 'Cleanup at $riverName',
        botId: _selectedBotId!,
        botName: selectedBot.name,
        riverId: riverId,
        riverName: riverName,
        ownerAdminId: currentUser.id,
        operationArea: OperationArea(
          center: LocationPoint(
            latitude: _operationLat!,
            longitude: _operationLng!,
            locationName: _operationLocationName,
          ),
          radiusInMeters: _operationRadius,
          locationName: _operationLocationName,
        ),
        dockingPoint: LocationPoint(
          latitude: _dockingLat!,
          longitude: _dockingLng!,
          locationName: _dockingLocationName,
        ),
        scheduledDate: scheduledDateTime,
        status: 'scheduled',
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await ref.read(scheduleProvider.notifier).createSchedule(schedule);

      if (mounted) {
        SnackbarUtil.showSuccess(context, 'Schedule created successfully');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        SnackbarUtil.showError(context, 'Failed to create schedule: $e');
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
