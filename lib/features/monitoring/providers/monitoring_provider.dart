import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/water_quality_data.dart';
import '../models/trash_collection_data.dart';
import '../models/monitoring_filters.dart';
import '../../../core/providers/auth_provider.dart';

enum MonitoringScope {
  individual, // For field operators - their assigned bots only
  organization, // For field operators and admins - all organization data
}

class MonitoringState {
  final List<WaterQualityData> waterQualityData;
  final List<TrashCollectionData> trashCollectionData;
  final MonitoringFilters filters;
  final MonitoringScope scope;
  final bool isLoading;
  final String? error;

  const MonitoringState({
    this.waterQualityData = const [],
    this.trashCollectionData = const [],
    this.filters = const MonitoringFilters(),
    this.scope = MonitoringScope.individual,
    this.isLoading = false,
    this.error,
  });

  MonitoringState copyWith({
    List<WaterQualityData>? waterQualityData,
    List<TrashCollectionData>? trashCollectionData,
    MonitoringFilters? filters,
    MonitoringScope? scope,
    bool? isLoading,
    String? error,
  }) {
    return MonitoringState(
      waterQualityData: waterQualityData ?? this.waterQualityData,
      trashCollectionData: trashCollectionData ?? this.trashCollectionData,
      filters: filters ?? this.filters,
      scope: scope ?? this.scope,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  // Filter data based on current filters
  List<WaterQualityData> get filteredWaterQuality {
    var filtered = waterQualityData;
    final dateRange = filters.getEffectiveDateRange();

    // Filter by date range
    filtered = filtered.where((data) {
      return data.timestamp.isAfter(dateRange.start) &&
          data.timestamp.isBefore(dateRange.end);
    }).toList();

    // Filter by river
    if (filters.selectedRiverId != null) {
      filtered = filtered
          .where((data) => data.riverId == filters.selectedRiverId)
          .toList();
    }

    // Filter by bot
    if (filters.selectedBotId != null) {
      filtered = filtered
          .where((data) => data.botId == filters.selectedBotId)
          .toList();
    }

    return filtered;
  }

  List<TrashCollectionData> get filteredTrashCollection {
    var filtered = trashCollectionData;
    final dateRange = filters.getEffectiveDateRange();

    // Filter by date range
    filtered = filtered.where((data) {
      return data.timestamp.isAfter(dateRange.start) &&
          data.timestamp.isBefore(dateRange.end);
    }).toList();

    // Filter by river
    if (filters.selectedRiverId != null) {
      filtered = filtered
          .where((data) => data.riverId == filters.selectedRiverId)
          .toList();
    }

    // Filter by bot
    if (filters.selectedBotId != null) {
      filtered = filtered
          .where((data) => data.botId == filters.selectedBotId)
          .toList();
    }

    return filtered;
  }

  // Get unique river IDs from data
  List<String> get availableRivers {
    final rivers = <String>{};
    for (final data in waterQualityData) {
      rivers.add(data.riverId);
    }
    for (final data in trashCollectionData) {
      rivers.add(data.riverId);
    }
    return rivers.toList()..sort();
  }

  // Get unique bot IDs filtered by river if selected
  List<String> get availableBots {
    final bots = <String>{};
    final dataToCheck = filters.selectedRiverId != null
        ? waterQualityData
            .where((d) => d.riverId == filters.selectedRiverId)
            .toList()
        : waterQualityData;

    for (final data in dataToCheck) {
      bots.add(data.botId);
    }
    return bots.toList()..sort();
  }
}

class MonitoringNotifier extends Notifier<MonitoringState> {
  @override
  MonitoringState build() {
    // Determine initial scope based on user role
    final auth = ref.read(authProvider);
    final isAdmin = auth.userProfile?.isAdmin ?? false;
    final initialScope = isAdmin ? MonitoringScope.organization : MonitoringScope.individual;
    
    // Load data AFTER the provider finished building
    Future.microtask(() => _loadFirebaseData(initialScope));
    
    // Return initial loading state
    return MonitoringState(isLoading: true, scope: initialScope);
  }

  Future<void> _loadFirebaseData(MonitoringScope scope) async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      
      final auth = ref.read(authProvider);
      final userId = auth.currentUser?.uid;
      final isAdmin = auth.userProfile?.isAdmin ?? false;
      
      if (userId == null) {
        state = state.copyWith(
          isLoading: false,
          error: 'User not authenticated',
        );
        return;
      }

      final fs = FirebaseFirestore.instance;
      final dateRange = state.filters.getEffectiveDateRange();
      
      // Get deployments based on scope
      Query<Map<String, dynamic>> deploymentsQuery = fs.collection('deployments')
          .where('created_at', isGreaterThanOrEqualTo: Timestamp.fromDate(dateRange.start))
          .where('created_at', isLessThanOrEqualTo: Timestamp.fromDate(dateRange.end));
      
      // For individual scope (field operators), filter by assigned bots
      if (scope == MonitoringScope.individual && !isAdmin) {
        // Get user's assigned bots
        final botsSnapshot = await fs.collection('bots')
            .where('assigned_to', isEqualTo: userId)
            .get();
        
        if (botsSnapshot.docs.isEmpty) {
          state = state.copyWith(
            isLoading: false,
            waterQualityData: [],
            trashCollectionData: [],
          );
          return;
        }
        
        final botIds = botsSnapshot.docs.map((doc) => doc.id).toList();
        // Firestore 'in' query limit is 10 items
        if (botIds.isNotEmpty) {
          final chunks = <List<String>>[];
          for (var i = 0; i < botIds.length; i += 10) {
            chunks.add(botIds.sublist(i, (i + 10 > botIds.length) ? botIds.length : i + 10));
          }
          
          final List<WaterQualityData> allWaterQuality = [];
          final List<TrashCollectionData> allTrashCollection = [];
          
          for (final chunk in chunks) {
            final chunkQuery = fs.collection('deployments')
                .where('bot_id', whereIn: chunk)
                .where('created_at', isGreaterThanOrEqualTo: Timestamp.fromDate(dateRange.start))
                .where('created_at', isLessThanOrEqualTo: Timestamp.fromDate(dateRange.end));
            
            final snapshot = await chunkQuery.get();
            _processDeployments(snapshot.docs, allWaterQuality, allTrashCollection);
          }
          
          state = state.copyWith(
            waterQualityData: allWaterQuality,
            trashCollectionData: allTrashCollection,
            isLoading: false,
            scope: scope,
          );
          return;
        }
      }
      
      // For organization scope (admins or field operators viewing org-wide)
      final deploymentsSnapshot = await deploymentsQuery.get();
      
      final List<WaterQualityData> waterQualityList = [];
      final List<TrashCollectionData> trashCollectionList = [];
      
      _processDeployments(deploymentsSnapshot.docs, waterQualityList, trashCollectionList);
      
      state = state.copyWith(
        waterQualityData: waterQualityList,
        trashCollectionData: trashCollectionList,
        isLoading: false,
        scope: scope,
      );
      
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }
  
  void _processDeployments(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    List<WaterQualityData> waterQualityList,
    List<TrashCollectionData> trashCollectionList,
  ) {
    for (final doc in docs) {
      final data = doc.data();
      final deploymentId = doc.id;
      final botId = data['bot_id'] as String?;
      final riverId = data['river_name'] as String? ?? data['river_id'] as String? ?? 'Unknown River';
      final createdAt = (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now();
      
      // Extract water quality data
      final waterQuality = data['water_quality'] as Map<String, dynamic>?;
      if (waterQuality != null) {
        final avgPh = (waterQuality['avg_ph_level'] as num?)?.toDouble();
        final avgTemp = (waterQuality['avg_temperature'] as num?)?.toDouble();
        final avgTurbidity = (waterQuality['avg_turbidity'] as num?)?.toDouble();
        final avgDo = (waterQuality['avg_dissolved_oxygen'] as num?)?.toDouble();
        
        if (avgPh != null && avgTemp != null && avgTurbidity != null && avgDo != null) {
          waterQualityList.add(WaterQualityData(
            id: deploymentId,
            botId: botId ?? 'Unknown Bot',
            riverId: riverId,
            timestamp: createdAt,
            turbidity: avgTurbidity,
            waterTemp: avgTemp,
            phLevel: avgPh,
            dissolvedOxygen: avgDo,
          ));
        }
      }
      
      // Extract trash collection data
      final trashCollection = data['trash_collection'] as Map<String, dynamic>?;
      if (trashCollection != null) {
        final totalWeight = (trashCollection['total_weight'] as num?)?.toDouble() ?? 0.0;
        final trashByType = trashCollection['trash_by_type'] as Map<String, dynamic>?;
        
        final Map<String, double> composition = {};
        if (trashByType != null) {
          trashByType.forEach((key, value) {
            final type = _mapTrashTypeString(key);
            if (type != null) {
              composition[type] = (value as num?)?.toDouble() ?? 0.0;
            }
          });
        }
        
        if (totalWeight > 0) {
          trashCollectionList.add(TrashCollectionData(
            id: deploymentId,
            botId: botId ?? 'Unknown Bot',
            riverId: riverId,
            timestamp: createdAt,
            totalWeight: totalWeight,
            trashComposition: composition,
          ));
        }
      }
    }
  }
  
  String? _mapTrashTypeString(String typeString) {
    switch (typeString.toLowerCase()) {
      case 'plastic':
        return TrashTypes.plastic;
      case 'paper':
        return TrashTypes.paper;
      case 'biodegradable':
      case 'organic':
        return TrashTypes.biodegradable;
      case 'cardboard':
        return TrashTypes.cardboard;
      case 'metal':
        return TrashTypes.metal;
      case 'glass':
        return TrashTypes.other; // Map glass to other for now
      default:
        return TrashTypes.other;
    }
  }

  Future<void> setScope(MonitoringScope scope) async {
    if (state.scope != scope) {
      await _loadFirebaseData(scope);
    }
  }

  void updateFilters(MonitoringFilters filters) {
    state = state.copyWith(filters: filters);
    Future.microtask(() => _loadFirebaseData(state.scope));
  }

  void setRiverFilter(String? riverId) {
    state = state.copyWith(
      filters: riverId != null
          ? state.filters.copyWith(selectedRiverId: riverId)
          : state.filters.clearRiver(),
    );
  }

  void setBotFilter(String? botId) {
    state = state.copyWith(
      filters: botId != null
          ? state.filters.copyWith(selectedBotId: botId)
          : state.filters.clearBot(),
    );
  }

  void setTimePeriod(TimePeriod period) {
    state = state.copyWith(
      filters: state.filters.copyWith(timePeriod: period),
    );
    Future.microtask(() => _loadFirebaseData(state.scope));
  }

  void clearFilters() {
    state = state.copyWith(filters: const MonitoringFilters());
    Future.microtask(() => _loadFirebaseData(state.scope));
  }
}

final monitoringProvider = NotifierProvider<MonitoringNotifier, MonitoringState>(
  () => MonitoringNotifier(),
);
