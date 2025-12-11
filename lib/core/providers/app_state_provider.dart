import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppState {
  final bool isInitialized;
  final String? currentRoute;
  final Map<String, dynamic> globalData;
  final bool isOnline;

  const AppState({
    this.isInitialized = false,
    this.currentRoute,
    this.globalData = const {},
    this.isOnline = true,
  });

  AppState copyWith({
    bool? isInitialized,
    String? currentRoute,
    Map<String, dynamic>? globalData,
    bool? isOnline,
  }) {
    return AppState(
      isInitialized: isInitialized ?? this.isInitialized,
      currentRoute: currentRoute ?? this.currentRoute,
      globalData: globalData ?? this.globalData,
      isOnline: isOnline ?? this.isOnline,
    );
  }
}

class AppStateNotifier extends Notifier<AppState> {
  @override
  AppState build() => const AppState();

  void initialize() {
    state = state.copyWith(isInitialized: true);
  }

  void setCurrentRoute(String route) {
    state = state.copyWith(currentRoute: route);
  }

  void updateGlobalData(String key, dynamic value) {
    final newData = Map<String, dynamic>.from(state.globalData);
    newData[key] = value;
    state = state.copyWith(globalData: newData);
  }

  void removeGlobalData(String key) {
    final newData = Map<String, dynamic>.from(state.globalData);
    newData.remove(key);
    state = state.copyWith(globalData: newData);
  }

  void setOnlineStatus(bool isOnline) {
    state = state.copyWith(isOnline: isOnline);
  }

  void reset() {
    state = const AppState();
  }
}

final appStateProvider = NotifierProvider<AppStateNotifier, AppState>(() {
  return AppStateNotifier();
});
