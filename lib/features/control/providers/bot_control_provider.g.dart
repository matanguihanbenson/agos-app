// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bot_control_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(BotControl)
const botControlProvider = BotControlFamily._();

final class BotControlProvider
    extends $NotifierProvider<BotControl, BotControlState> {
  const BotControlProvider._(
      {required BotControlFamily super.from, required String super.argument})
      : super(
          retry: null,
          name: r'botControlProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$botControlHash();

  @override
  String toString() {
    return r'botControlProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  BotControl create() => BotControl();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BotControlState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BotControlState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is BotControlProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$botControlHash() => r'db2c74e6fcde69bd282e6ed981e86319e6269373';

final class BotControlFamily extends $Family
    with
        $ClassFamilyOverride<BotControl, BotControlState, BotControlState,
            BotControlState, String> {
  const BotControlFamily._()
      : super(
          retry: null,
          name: r'botControlProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  BotControlProvider call(
    String botId,
  ) =>
      BotControlProvider._(argument: botId, from: this);

  @override
  String toString() => r'botControlProvider';
}

abstract class _$BotControl extends $Notifier<BotControlState> {
  late final _$args = ref.$arg as String;
  String get botId => _$args;

  BotControlState build(
    String botId,
  );
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build(
      _$args,
    );
    final ref = this.ref as $Ref<BotControlState, BotControlState>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<BotControlState, BotControlState>,
        BotControlState,
        Object?,
        Object?>;
    element.handleValue(ref, created);
  }
}
