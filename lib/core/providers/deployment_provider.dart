import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/deployment_model.dart';
import 'schedule_provider.dart'; // For deploymentServiceProvider

class DeploymentState {
  final List<DeploymentModel> deployments;
  final bool isLoading;
  final String? error;

  const DeploymentState({
    this.deployments = const [],
    this.isLoading = false,
    this.error,
  });

  DeploymentState copyWith({
    List<DeploymentModel>? deployments,
    bool? isLoading,
    String? error,
  }) {
    return DeploymentState(
      deployments: deployments ?? this.deployments,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

class DeploymentNotifier extends Notifier<DeploymentState> {
  @override
  DeploymentState build() => const DeploymentState();

  Future<void> loadDeploymentsByBot(String botId) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final deploymentService = ref.read(deploymentServiceProvider);
      
      // First get the deployments to find owner
      final deployments = await deploymentService.getDeploymentsByBot(botId);
      
      // Auto-update statuses if there are deployments
      if (deployments.isNotEmpty) {
        await deploymentService.autoUpdateDeploymentStatuses(deployments.first.ownerAdminId);
        // Reload after update
        final updatedDeployments = await deploymentService.getDeploymentsByBot(botId);
        updatedDeployments.sort((a, b) => b.scheduledStartTime.compareTo(a.scheduledStartTime));
        state = state.copyWith(deployments: updatedDeployments, isLoading: false);
      } else {
        deployments.sort((a, b) => b.scheduledStartTime.compareTo(a.scheduledStartTime));
        state = state.copyWith(deployments: deployments, isLoading: false);
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }


  Future<void> loadDeploymentsByRiver(String riverId) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final deploymentService = ref.read(deploymentServiceProvider);
      
      // Get deployments by river
      final deployments = await deploymentService.getDeploymentsByRiver(riverId);
      deployments.sort((a, b) => b.scheduledStartTime.compareTo(a.scheduledStartTime));
      
      state = state.copyWith(deployments: deployments, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<DeploymentModel?> getDeploymentById(String deploymentId) async {
    try {
      final deploymentService = ref.read(deploymentServiceProvider);
      return await deploymentService.getById(deploymentId);
    } catch (e) {
      return null;
    }
  }
}

final deploymentProvider = NotifierProvider<DeploymentNotifier, DeploymentState>(() {
  return DeploymentNotifier();
});

// Real-time stream provider for deployments by bot
final deploymentsByBotStreamProvider = StreamProvider.autoDispose.family<List<DeploymentModel>, String>((ref, botId) {
  final deploymentService = ref.watch(deploymentServiceProvider);
  return deploymentService.watchDeploymentsByBot(botId);
});
