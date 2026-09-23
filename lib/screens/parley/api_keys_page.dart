import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:parley_android/design_system/ds_button.dart';
import 'package:parley_android/design_system/ds_form_page.dart';
import 'package:parley_android/design_system/ds_pinned_action_bar.dart';
import 'package:parley_android/design_system/ds_card.dart';
import 'package:parley_android/design_system/ds_list_tile.dart';
import 'package:parley_android/design_system/ds_text.dart';
import 'package:parley_android/design_system/ds_snack_bar.dart';
import 'package:parley_android/design_system/ds_text_field.dart';
import 'package:parley_android/providers/parley_providers.dart';
import 'package:parley_android/theme/spec/design_spec.dart';
import 'package:parley_android/utils/error_copy.dart';

/// API keys — the **Form** archetype.
///
/// Two fields and one pinned action. Nothing is saved until every key typed
/// here has been checked with its provider, so a typo never replaces a key
/// that worked. Leaving a field empty keeps the stored key; the MiniMax field
/// has a Remove, because voice edit is optional.
class ApiKeysPage extends ConsumerStatefulWidget {
  const ApiKeysPage({super.key});

  @override
  ConsumerState<ApiKeysPage> createState() => _ApiKeysPageState();
}

class _ApiKeysPageState extends ConsumerState<ApiKeysPage> {
  final _groq = TextEditingController();
  final _minimax = TextEditingController();
  bool _saving = false;
  bool _removeMinimax = false;
  Map<String, String> _errors = const {};

  @override
  void dispose() {
    _groq.dispose();
    _minimax.dispose();
    super.dispose();
  }

  bool get _dirty =>
      _groq.text.trim().isNotEmpty ||
      _minimax.text.trim().isNotEmpty ||
      _removeMinimax;

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _errors = const {};
    });
    try {
      final groq = _groq.text.trim();
      final minimax = _minimax.text.trim();
      final result = await ref
          .read(parleyBridgeProvider)
          .setKeys(
            groq: groq.isEmpty ? null : groq,
            minimax: _removeMinimax ? '' : (minimax.isEmpty ? null : minimax),
          );
      if (!mounted) return;
      if (!result.ok) {
        setState(() => _errors = result.errors);
        return;
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
    final groqSaved = config?.groqKeyLast4;
    final minimaxSaved = config?.minimaxKeyLast4;

    return DSFormPage(
      title: 'API keys',
      footer: DSPinnedActionBar(
        loading: _saving,
        children: [
          DSButton(
            label: 'Check and save',
            onPressed: _dirty && !_saving ? _save : null,
            loading: _saving,
            fullWidth: true,
          ),
        ],
      ),
      children: [
        DSTextField(
          controller: _groq,
          label: 'Groq API key',
          hintText: groqSaved == null ? 'gsk_…' : 'Paste a new key',
          helperText: groqSaved == null
              ? 'Required for transcription.'
              : 'Saved ••$groqSaved. Empty keeps it.',
          errorText: _errors['groq'],
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
        const DSCard(
          variant: DSCardVariant.outlined,
          padding: EdgeInsets.zero,
          child: DSListTileGroup(
            children: [
              DSListTile(
                title: 'Groq',
                subtitle: 'Turns what you say into text (Whisper).',
              ),
              DSListTile(
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
