import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:parley_android/design_system/ds_button.dart';
import 'package:parley_android/design_system/ds_card.dart';
import 'package:parley_android/design_system/ds_list_tile.dart';
import 'package:parley_android/design_system/ds_page.dart';
import 'package:parley_android/design_system/ds_pinned_action_bar.dart';
import 'package:parley_android/design_system/ds_scope.dart';
import 'package:parley_android/design_system/ds_segmented_progress.dart';
import 'package:parley_android/design_system/ds_text.dart';
import 'package:parley_android/design_system/ds_text_field.dart';
import 'package:parley_android/models/parley.dart';
import 'package:parley_android/providers/parley_providers.dart';
import 'package:parley_android/providers/settings_provider.dart';
import 'package:parley_android/screens/parley/aurora_orb.dart';
import 'package:parley_android/theme/parley_modes.dart';
import 'package:parley_android/theme/spec/design_spec.dart';
import 'package:parley_android/utils/app_routes.dart';

/// First run — the **Sequence** archetype.
///
/// Six steps, each with one job and one pinned action: say what Parley is,
/// take the transcription key (Groq unless the user switches to Deepgram
/// on that step), the microphone, the accessibility grant, the battery
/// exemption, then one practice dictation in a field on this screen. Grants
/// are given in system Settings, so the page re-reads status whenever the app
/// comes back to the front and advances on its own when the grant landed.
/// Back keeps every answer: a typed key stays typed.
class SetupPage extends ConsumerStatefulWidget {
  const SetupPage({super.key, this.initialStep});

  /// Where to open. Null starts at the first step that is not done yet.
  final int? initialStep;

  static const stepCount = 6;

  @override
  ConsumerState<SetupPage> createState() => _SetupPageState();
}

enum _Step { welcome, key, mic, accessibility, battery, practice }

class _SetupPageState extends ConsumerState<SetupPage>
    with WidgetsBindingObserver {
  late int _index = widget.initialStep ?? 0;
  bool _placed = false;
  bool _busy = false;
  String? _keyError;
  final _key = TextEditingController();
  final _practice = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _key.dispose();
    _practice.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(parleyStatusProvider.notifier).refresh();
    }
  }

  _Step get _step => _Step.values[_index];

  bool _done(_Step step, ParleyStatus s) => switch (step) {
    _Step.welcome => false,
    _Step.key => s.transcriptionKeySet,
    _Step.mic => s.micGranted,
    _Step.accessibility => s.serviceBound,
    _Step.battery => s.batteryUnrestricted,
    _Step.practice => false,
  };

  /// On a cold open, skip to the first step that still needs the user.
  void _place(ParleyStatus s) {
    if (_placed || widget.initialStep != null) return;
    _placed = true;
    final anyDone = _Step.values.any((step) => _done(step, s));
    if (!anyDone) return;
    final next = _Step.values.indexWhere(
      (step) => step != _Step.welcome && !_done(step, s),
    );
    _index = next == -1 ? _Step.practice.index : next;
  }

  void _next() {
    if (_index < SetupPage.stepCount - 1) setState(() => _index++);
  }

  void _back() {
    if (_index > 0) setState(() => _index--);
  }

  Future<void> _finish() async {
    await ref.read(settingsProvider.notifier).completeOnboarding();
    if (mounted) context.go(AppRoutes.home);
  }

  Future<void> _saveKey(TranscriptionProvider provider) async {
    setState(() {
      _busy = true;
      _keyError = null;
    });
    final key = _key.text.trim();
    final result = await ref
        .read(parleyBridgeProvider)
        .setKeys(
          groq: provider == TranscriptionProvider.groq ? key : null,
          deepgram: provider == TranscriptionProvider.deepgram ? key : null,
        );
    if (!mounted) return;
    if (result.ok) {
      await ref.read(parleyStatusProvider.notifier).refresh();
      ref.invalidate(parleyConfigProvider);
      // The status listener may already have advanced on the grant event.
      if (mounted && _step == _Step.key) _next();
    } else {
      setState(
        () => _keyError = result.errors[provider.name] ?? 'Key rejected',
      );
    }
    if (mounted) setState(() => _busy = false);
  }

  /// The key step's other answer: transcribe on the other provider instead.
  Future<void> _switchProvider(TranscriptionProvider to) async {
    setState(() {
      _busy = true;
      _keyError = null;
      _key.clear();
    });
    await ref.read(parleyBridgeProvider).setTranscriptionProvider(to);
    ref.invalidate(parleyConfigProvider);
    await ref.read(parleyStatusProvider.notifier).refresh();
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    // Advance on its own when a grant arrives while the step is showing.
    ref.listen(parleyStatusProvider, (prev, next) {
      final s = next.valueOrNull;
      final before = prev?.valueOrNull;
      if (s == null || before == null) return;
      if (_done(_step, s) && !_done(_step, before)) _next();
    });

    final status =
        ref.watch(parleyStatusProvider).valueOrNull ?? const ParleyStatus();
    if (ref.watch(parleyStatusProvider).hasValue) _place(status);
    final space = context.design.space;
    final gutter = DSGutter.of(context);

    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: DSPage.surface(
        title: 'Set up Parley',
        leading: _index == 0 ? null : BackButton(onPressed: _back),
        footer: DSPinnedActionBar(loading: _busy, children: _actions(status)),
        // The orb takes whatever height the step's words leave, and the words
        // sit just over the pinned action: the eye goes orb → sentence →
        // button, and a short step never leaves a band of nothing above the
        // bar.
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(gutter, space.sm, gutter, space.lg),
              sliver: SliverFillRemaining(
                hasScrollBody: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DSSegmentedProgress(
                      currentStep: _index + 1,
                      totalSteps: SetupPage.stepCount,
                      label: 'Setup',
                    ),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: space.lg),
                        child: Center(
                          child: FittedBox(
                            child: AuroraOrb(
                              diameter: space.xxxl * 3,
                              mode: _done(_step, status)
                                  ? OrbMode.done
                                  : OrbMode.dictation,
                            ),
                          ),
                        ),
                      ),
                    ),
                    AnimatedSwitcher(
                      duration: context.design.motion.scaled(
                        context.design.motion.normal,
                      ),
                      child: KeyedSubtree(
                        key: ValueKey(_step),
                        child: _body(status),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _actions(ParleyStatus s) {
    final bridge = ref.read(parleyBridgeProvider);
    DSButton primary(String label, VoidCallback? onPressed) =>
        DSButton(label: label, onPressed: onPressed, fullWidth: true);
    DSButton quiet(String label, VoidCallback onPressed) => DSButton(
      label: label,
      onPressed: onPressed,
      variant: DSButtonVariant.ghost,
      fullWidth: true,
    );

    return switch (_step) {
      _Step.welcome => [primary('Get started', _next)],
      _Step.key =>
        s.transcriptionKeySet && _key.text.trim().isEmpty
            ? [primary('Continue', _next)]
            : [
                primary(
                  'Check key',
                  _key.text.trim().isEmpty || _busy
                      ? null
                      : () => _saveKey(s.transcriptionProvider),
                ),
              ],
      _Step.mic =>
        s.micGranted
            ? [primary('Continue', _next)]
            : [
                primary(
                  'Allow microphone',
                  () => ref.read(parleyStatusProvider.notifier).requestMic(),
                ),
              ],
      _Step.accessibility =>
        s.serviceBound
            ? [primary('Continue', _next)]
            : [
                primary(
                  'Open Accessibility settings',
                  () => bridge.openSystemSettings(
                    SystemSettingsTarget.accessibility,
                  ),
                ),
              ],
      _Step.battery =>
        s.batteryUnrestricted
            ? [primary('Continue', _next)]
            : [
                primary(
                  'Let Parley run in the background',
                  () => bridge.openSystemSettings(SystemSettingsTarget.battery),
                ),
                quiet('Not now', _next),
              ],
      _Step.practice => [
        primary(
          _practice.text.trim().isEmpty ? 'Skip for now' : 'Done',
          _finish,
        ),
      ],
    };
  }

  Widget _body(ParleyStatus s) {
    final space = context.design.space;
    Widget header(String title, String message) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DSText(title, role: DSTextRole.display, maxLines: 4),
        space.verticalSm,
        DSText(message, role: DSTextRole.bodyLead),
      ],
    );

    Widget grantedNote(String text) => Padding(
      padding: EdgeInsets.only(top: space.md),
      child: DSListTile(
        leading: const Icon(Icons.check_circle_outline),
        title: text,
        tone: DSTone.success,
      ),
    );

    return switch (_step) {
      _Step.welcome => header(
        'Talk, and it types — in any app',
        'Hold the orb, or press volume-down twice and hold. Let go, and your '
            'words land where the cursor is.',
      ),
      _Step.key => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header(
            'Your ${s.transcriptionProvider.company} key',
            'Parley transcribes on your own '
                '${s.transcriptionProvider.company} account. The key is '
                'checked with one request, then stored encrypted on this '
                'phone.',
          ),
          space.verticalLg,
          DSTextField(
            key: ValueKey('setup-key-${s.transcriptionProvider.name}'),
            controller: _key,
            label: '${s.transcriptionProvider.company} API key',
            hintText: s.transcriptionKeySet
                ? 'A key is saved — paste to replace'
                : s.transcriptionProvider.keyHint,
            errorText: _keyError,
            input: const DSFieldInput.password(),
            onChanged: (_) => setState(() {}),
          ),
          if (s.transcriptionKeySet && _key.text.trim().isEmpty)
            grantedNote('A ${s.transcriptionProvider.company} key is saved'),
          // The other provider is an answer to this step, not a second
          // primary: it sits under the field so Check key keeps the bar.
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: DSButton(
              label: 'Use ${s.transcriptionProvider.other.label} instead',
              variant: DSButtonVariant.ghost,
              onPressed: _busy
                  ? null
                  : () => _switchProvider(s.transcriptionProvider.other),
            ),
          ),
        ],
      ),
      _Step.mic => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header(
            'Microphone',
            'Parley listens only while you hold the orb or the volume key. '
                'Android shows the green dot whenever it does.',
          ),
          if (s.micGranted) grantedNote('Microphone allowed'),
        ],
      ),
      _Step.accessibility => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header(
            'Turn on Parley in Accessibility',
            'Android asks for this once. It lets Parley do three things, and '
                'nothing else:',
          ),
          space.verticalLg,
          const DSCard(
            padding: EdgeInsets.zero,
            child: DSListTileGroup(
              children: [
                DSListTile(
                  leading: Icon(Icons.radio_button_unchecked),
                  title: 'Show the orb over your apps',
                ),
                DSListTile(
                  leading: Icon(Icons.notes),
                  title: "Read the field you're typing in",
                ),
                DSListTile(
                  leading: Icon(Icons.add),
                  title: 'Insert your words at the cursor',
                ),
              ],
            ),
          ),
          space.verticalMd,
          const DSText(
            'Password fields are never read.',
            role: DSTextRole.bodyDetail,
          ),
          if (s.serviceBound) grantedNote('Parley is on in Accessibility'),
        ],
      ),
      _Step.battery => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header(
            'Keep Parley running',
            'Some phones stop background services to save battery. Setting '
                'Parley to Unrestricted keeps the orb there when you need it.',
          ),
          if (s.batteryUnrestricted) grantedNote('Battery set to Unrestricted'),
        ],
      ),
      _Step.practice => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header(
            'Try it',
            'Tap the box, then hold the orb and say "testing one two three". '
                'Let go, and it lands here.',
          ),
          space.verticalLg,
          DSTextField(
            controller: _practice,
            label: 'Practice',
            hintText: 'Your words appear here',
            input: const DSFieldInput(maxLines: 3, minLines: 2),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
    };
  }
}
