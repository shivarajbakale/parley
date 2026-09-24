import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:parley_android/design_system/ds_button.dart';
import 'package:parley_android/design_system/ds_form_page.dart';
import 'package:parley_android/design_system/ds_pinned_action_bar.dart';
import 'package:parley_android/design_system/ds_card.dart';
import 'package:parley_android/design_system/ds_control_tile.dart';
import 'package:parley_android/design_system/ds_list_tile.dart';
import 'package:parley_android/design_system/ds_radio.dart';
import 'package:parley_android/design_system/ds_text.dart';
import 'package:parley_android/design_system/ds_snack_bar.dart';
import 'package:parley_android/design_system/ds_text_field.dart';
import 'package:parley_android/models/parley.dart';
import 'package:parley_android/providers/parley_providers.dart';
import 'package:parley_android/theme/spec/design_spec.dart';
import 'package:parley_android/utils/error_copy.dart';

/// API keys — the **Form** archetype.
///
/// Who transcribes, that provider's key, and the MiniMax key, with one pinned
/// action. Nothing is saved until every key typed here has been checked with
/// its provider, so a typo never replaces a key that worked, and the provider
/// only switches once it has a key. Leaving a field empty keeps the stored
/// key; the MiniMax field has a Remove, because voice edit is optional.
class ApiKeysPage extends ConsumerStatefulWidget {
  const ApiKeysPage({super.key});

  @override
  ConsumerState<ApiKeysPage> createState() => _ApiKeysPageState();
}

class _ApiKeysPageState extends ConsumerState<ApiKeysPage> {
  final _keys = {
    for (final p in TranscriptionProvider.values) p: TextEditingController(),
  };
  final _minimax = TextEditingController();
  bool _saving = false;
  bool _removeMinimax = false;

  /// The radio's answer; null until the user picks, so the saved one shows.
  TranscriptionProvider? _picked;
  Map<String, String> _errors = const {};

  @override
  void dispose() {
    for (final c in _keys.values) {
      c.dispose();
    }
    _minimax.dispose();
    super.dispose();
  }

  TranscriptionProvider _chosen(ParleyConfig? config) =>
      _picked ?? config?.transcriptionProvider ?? TranscriptionProvider.groq;

  bool _dirty(ParleyConfig? config) {
    final chosen = _chosen(config);
    return _keys[chosen]!.text.trim().isNotEmpty ||
        _minimax.text.trim().isNotEmpty ||
        _removeMinimax ||
        (config != null && chosen != config.transcriptionProvider);
  }

  Future<void> _save(ParleyConfig? config) async {
    final chosen = _chosen(config);
    final typed = _keys[chosen]!.text.trim();
    if (typed.isEmpty && config?.keyLast4Of(chosen) == null) {
      setState(
        () => _errors = {
          chosen.name: 'Add a ${chosen.company} key to use ${chosen.company}.',
        },
      );
      return;
    }
    setState(() {
      _saving = true;
      _errors = const {};
    });
    try {
      final minimax = _minimax.text.trim();
      final key = typed.isEmpty ? null : typed;
      final bridge = ref.read(parleyBridgeProvider);
      final result = await bridge.setKeys(
        groq: chosen == TranscriptionProvider.groq ? key : null,
        deepgram: chosen == TranscriptionProvider.deepgram ? key : null,
        minimax: _removeMinimax ? '' : (minimax.isEmpty ? null : minimax),
      );
      if (!mounted) return;
      if (!result.ok) {
        setState(() => _errors = result.errors);
        return;
      }
      if (chosen != config?.transcriptionProvider) {
        await bridge.setTranscriptionProvider(chosen);
      }
      await ref.read(parleyConfigProvider.notifier).reload();
      await ref.read(parleyStatusProvider.notifier).refresh();
      if (!mounted) return;
      showDSSnackBar(context, message: 'Keys saved', icon: Icons.check);
      context.pop();
    } catch (e) {
      if (mounted) {
        showDSSnackBar(context, message: errorCopyFor(e).message);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(parleyConfigProvider).valueOrNull;
    final space = context.design.space;
    final chosen = _chosen(config);
    final keySaved = config?.keyLast4Of(chosen);
    final minimaxSaved = config?.minimaxKeyLast4;

    return DSFormPage(
      title: 'API keys',
      footer: DSPinnedActionBar(
        loading: _saving,
        children: [
          DSButton(
            label: 'Check and save',
            onPressed: _dirty(config) && !_saving ? () => _save(config) : null,
            loading: _saving,
            fullWidth: true,
          ),
        ],
      ),
      children: [
        // Radios, not a segmented control: each option needs its sentence,
        // and "Deepgram Nova-3" beside "Whisper (Groq)" clips at 320pt.
        DSCard(
          variant: DSCardVariant.outlined,
          padding: EdgeInsets.zero,
          child: DSRadioGroup<TranscriptionProvider>(
            label: 'Transcription',
            value: chosen,
            enabled: !_saving,
            onChanged: (value) => setState(() {
              _picked = value ?? chosen;
              _errors = const {};
            }),
            children: [
              for (final p in TranscriptionProvider.values)
                DSRadioTile<TranscriptionProvider>(
                  value: p,
                  label: p.label,
                  subtitle: p.detail,
                ),
            ],
          ),
        ),
        space.verticalMd,
        DSTextField(
          key: ValueKey('key-${chosen.name}'),
          controller: _keys[chosen],
          label: '${chosen.company} API key',
          hintText: keySaved == null ? chosen.keyHint : 'Paste a new key',
          helperText: keySaved == null
              ? 'Required for transcription.'
              : 'Saved ••$keySaved. Empty keeps it.',
          errorText: _errors[chosen.name],
          input: const DSFieldInput.password(),
          onChanged: (_) => setState(() {}),
        ),
        space.verticalSm,
        DSTextField(
          controller: _minimax,
          label: 'MiniMax API key',
          hintText: _removeMinimax ? 'Will be removed' : 'Paste a key',
          helperText: minimaxSaved == null
              ? 'Optional. Turns on voice edit.'
              : 'Saved ••$minimaxSaved. Empty keeps it.',
          errorText: _errors['minimax'],
          enabled: !_removeMinimax,
          input: const DSFieldInput.password(),
          onChanged: (_) => setState(() {}),
        ),
        if (minimaxSaved != null)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: DSButton(
              label: _removeMinimax ? 'Keep MiniMax key' : 'Remove MiniMax key',
              variant: DSButtonVariant.ghost,
              onPressed: () => setState(() {
                _removeMinimax = !_removeMinimax;
                _minimax.clear();
              }),
            ),
          ),
        space.verticalLg,
        const DSText('How they are used', role: DSTextRole.eyebrow),
        space.verticalXs,
        DSCard(
          variant: DSCardVariant.outlined,
          padding: EdgeInsets.zero,
          child: DSListTileGroup(
            children: [
              DSListTile(
                title: chosen.company,
                subtitle: 'Turns what you say into text (${chosen.model}).',
              ),
              const DSListTile(
                title: 'MiniMax',
                subtitle: 'Rewrites a field when you ask for a voice edit.',
              ),
            ],
          ),
        ),
        space.verticalSm,
        const DSText(
          'Each key is checked with one request before it is saved, and '
          'stored encrypted on this phone. It is only ever sent to its own '
          'provider.',
          role: DSTextRole.bodyDetail,
        ),
      ],
    );
  }
}
