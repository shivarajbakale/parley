import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:parley_android/models/parley.dart';
import 'package:parley_android/providers/parley_providers.dart';
import 'package:parley_android/theme/parley_modes.dart';
import 'package:parley_android/utils/app_routes.dart';

/// What is in the way, in the order the user has to fix it.
({
  String title,
  String message,
  OrbMode mode,
  String? action,
  String short,
  SystemSettingsTarget? target,
})
blockerOf(ParleyStatus s) {
  if (!s.serviceBound) {
    return (
      title: 'Off',
      message: 'Turn on Parley in Accessibility settings to show the orb.',
      mode: OrbMode.idle,
      action: 'Open Accessibility settings',
      short: 'Turn on',
      target: SystemSettingsTarget.accessibility,
    );
  }
  if (!s.micGranted) {
    return (
      title: 'Needs the microphone',
      message: 'Parley only listens while you hold the orb.',
      mode: OrbMode.idle,
      action: 'Allow microphone',
      short: 'Allow mic',
      target: null,
    );
  }
  if (!s.transcriptionKeySet) {
    final company = s.transcriptionProvider.company;
    return (
      title: 'Add your $company key',
      message: 'Transcription runs on your own $company account.',
      mode: OrbMode.idle,
      action: 'Add key',
      short: 'Add key',
      target: null,
    );
  }
  if (s.paused) {
    return (
      title: 'Paused',
      message: 'The orb is hidden and the volume gesture is off.',
      mode: OrbMode.idle,
      action: null,
      short: 'Resume',
      target: null,
    );
  }
  return (
    title: 'Ready',
    message: s.volumeGestureEnabled
        ? 'Hold the orb, or press volume-down twice and hold.'
        : 'Hold the orb in any app to talk.',
    mode: OrbMode.dictation,
    action: null,
    short: 'Try it',
    target: null,
  );
}

/// Clears the first thing [blockerOf] names: opens the system screen, asks
/// for the grant, pushes the key form, or resumes a paused Parley.
Future<void> fixBlocker(
  BuildContext context,
  WidgetRef ref,
  ParleyStatus status,
) async {
  final target = blockerOf(status).target;
  if (target != null) {
    await ref.read(parleyBridgeProvider).openSystemSettings(target);
  } else if (!status.micGranted) {
    await ref.read(parleyStatusProvider.notifier).requestMic();
  } else if (!status.transcriptionKeySet) {
    if (context.mounted) context.push(AppRoutes.apiKeys);
  } else if (status.paused) {
    await ref.read(parleyStatusProvider.notifier).setPaused(false);
  }
}
