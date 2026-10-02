import 'package:flutter/material.dart';
import 'package:parley_android/design_system/design_system.dart';
import 'package:parley_android/screens/design_system/form_data.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// The booking demo — the **Sequence** archetype
/// (`docs/principles/screen-archetypes.md`).
///
/// It used to call itself a Form drawn as a stepped flow, which was the shape
/// smuggled in under another name that made Sequence worth declaring: a Form
/// asks for a record in one column, and this walks the user through an order
/// somebody chose. Every rule below is a Sequence rule — one decision per
/// screen, honest progress at the top, a back that costs nothing, and a last
/// step that hands over.
///
/// Lives in `screens/design_system/` because it is a demo, and it is the
/// worked example the `add-form` skill points at. It was one screen first,
/// and one screen was the wrong answer: ten questions in a column reached
/// four of them in the first screenful and put the rest behind a scroll with
/// a single button at the bottom. The skill's rule is that a form which
/// cannot be made shorter becomes steps, so this is four of them — who, when,
/// where, and a review — each one a screenful, each one answerable on its own.
///
/// What it proves: every kind of input the kit owns, chosen by what the answer
/// is rather than by what is quickest to type; validation scoped to the step
/// the user is on; a back that never loses what was typed; and a review that
/// names what is about to happen before it happens.
///
/// Delete this file and `form_data.dart` with the rest of the design-system
/// demo surface when the app ships a real form.
class FormPage extends StatefulWidget {
  const FormPage({super.key, this.initialStep = 0});

  /// Which step to open on. Zero in the app; the gates mount each step by
  /// index, because a paged flow needs a fixture per page and a flow that
  /// only ever renders its first page is a flow nothing measures.
  final int initialStep;

  @override
  State<FormPage> createState() => _FormPageState();
}

/// The four steps, in order. One decision domain each: a step that only
/// carried one field would be a page turn charged for nothing, so the zone
/// and the extras share the third.
enum _Step { who, when, desk, review }

extension _StepCopy on _Step {
  String get label => switch (this) {
    _Step.who => 'Who',
    _Step.when => 'When',
    _Step.desk => 'Desk',
    _Step.review => 'Review',
  };

  /// The step's own question, carried by the header's subtitle — so the page
  /// has one headline and the thing being asked is under it.
  String get question => switch (this) {
    _Step.who => 'Who is the desk for, and how many of you?',
    _Step.when => 'Which day, and when do you arrive?',
    _Step.desk => 'Where should the desk be, and what comes with it?',
    _Step.review => 'One last look before it is booked.',
  };
}

class _FormPageState extends State<FormPage> {
  final _stepKeys = <GlobalKey<FormState>>[
    for (final _ in _Step.values) GlobalKey<FormState>(),
  ];

  late final TextEditingController _name;
  late final TextEditingController _email;
  final _notes = TextEditingController();

  DateTime _day = demoBookingDays.first;
  ArrivalSlot _slot = ArrivalSlot.morning;
  DeskZone? _zone;
  int _people = 2;
  final Set<String> _extras = <String>{};

  late int _index;

  /// The steps the user has tried to leave.
  ///
  /// Validation is on Next first and on interaction only afterwards: a field
  /// that turns red while the user is typing the first half of their email
  /// has decided they are wrong before they finished. The set is per step
  /// because the answer is per step — arriving at step three must not find
  /// step one's mistakes already painted.
  final Set<_Step> _attempted = <_Step>{};

  bool _submitting = false;
  bool _confirmed = false;

  _Step get _step => _Step.values[_index];
  bool get _isLast => _step == _Step.review;

  @override
  void initState() {
    super.initState();
    _index = widget.initialStep.clamp(0, _Step.values.length - 1);
    // Defaults, not answers. The app knows who is signed in, so the first
    // step opens filled in and the user confirms it.
    _name = TextEditingController(text: demoBookingName);
    _email = TextEditingController(text: demoBookingEmail);
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _notes.dispose();
    super.dispose();
  }

  // ── Validation ──────────────────────────────────────────────────────────

  String? _validateName(String? value) =>
      (value == null || value.trim().isEmpty)
      ? 'Enter the name the desk is for'
      : null;

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Enter your work email';
    if (!email.contains('@') || !email.contains('.')) {
      return 'Enter a valid email';
    }
    return null;
  }

  bool get _zoneMissing => _attempted.contains(_Step.desk) && _zone == null;

  /// How full the chosen day is. Indexed by the day's position in
  /// `demoBookingDays` rather than by its date, so the two lists cannot
  /// drift; a day off the end falls back to the first, which is what a demo
  /// with ten days and ten loads never reaches.
  BookingDayLoad get _dayLoad {
    final index = demoBookingDays.indexOf(_day);
    return demoBookingLoad[index < 0 ? 0 : index % demoBookingLoad.length];
  }

  AutovalidateMode _autovalidate(_Step step) => _attempted.contains(step)
      ? AutovalidateMode.onUserInteraction
      : AutovalidateMode.disabled;

  /// Whether the step the user is on can be left. Only Next asks.
  bool _stepIsValid(_Step step) => switch (step) {
    _Step.who => _stepKeys[step.index].currentState?.validate() ?? false,
    _Step.when => true,
    _Step.desk => _zone != null,
    _Step.review => true,
  };

  // ── Moving between steps ────────────────────────────────────────────────

  Future<void> _next() async {
    setState(() => _attempted.add(_step));
    if (!_stepIsValid(_step)) return;
    FocusScope.of(context).unfocus();

    if (_isLast) {
      await _confirm();
      return;
    }
    _goTo(_index + 1);
  }

  void _back() {
    if (_index == 0) return;
    FocusScope.of(context).unfocus();
    _goTo(_index - 1);
  }

  /// Nothing is lost moving either way: every answer lives here, not in the
  /// step bodies, so a step rebuilt on the way back rebuilds from the same
  /// state.
  void _goTo(int next) => setState(() => _index = next);

  Future<void> _confirm() async {
    setState(() => _submitting = true);
    // The demo has no repository, and a submit that resolves in the same
    // frame never shows the button's loading state. One shimmer period is
    // the wait: the token already means "long enough to be worth showing a
    // loading state for", so the pause moves with the identity.
    await Future<void>.delayed(context.design.motion.shimmer);
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _confirmed = true;
    });
  }

  void _bookAnother() {
    _name.text = demoBookingName;
    _email.text = demoBookingEmail;
    _notes.clear();
    setState(() {
      _day = demoBookingDays.first;
      _slot = ArrivalSlot.morning;
      _zone = null;
      _people = 2;
      _extras.clear();
      _attempted.clear();
      _confirmed = false;
      _index = 0;
    });
  }

  void _toggleExtra(String id, {required bool on}) {
    setState(() => on ? _extras.add(id) : _extras.remove(id));
  }

  // ── Copy ────────────────────────────────────────────────────────────────

  String _dayLabel(BuildContext context, DateTime day) =>
      MaterialLocalizations.of(context).formatMediumDate(day);

  String get _peopleLabel => _people == 1 ? '1 person' : '$_people people';

  String get _extrasLabel => _extras.isEmpty
      ? 'Nothing extra'
      : demoBookingExtras
            .where((e) => _extras.contains(e.id))
            .map((e) => e.label)
            .join(', ');

  /// The line under the primary: what pressing it is about to book.
  String _summaryLine(BuildContext context) =>
      '${_dayLabel(context, _day)} · ${_slot.label}';

  String _bookingSentence(BuildContext context) =>
      '${_summaryLine(context)} · $_peopleLabel · '
      '${_zone?.label ?? 'no zone yet'}';

  // ── Frame ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final space = context.design.space;

    return DSBottomInsetsHost(
      child: Scaffold(
        body: Column(
          children: [
            DSPageHeader(
              eyebrow: 'WORKSPACE',
              title: 'Book a desk',
              subtitle: _confirmed ? null : _step.question,
              leading: const BackButton(),
            ),
            if (!_confirmed)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  DSGutter.of(context),
                  space.md,
                  DSGutter.of(context),
                  space.md,
                ),
                child: DSSegmentedProgress.labelled(
                  currentStep: _index + 1,
                  stepLabels: [for (final s in _Step.values) s.label],
                ),
              ),
            Expanded(
              // Inside the host, so anything below can read the bar's height.
              child: Builder(
                builder: (context) => _confirmed
                    ? DSEmptyState.done(
                        title: 'Desk booked',
                        message:
                            '${_bookingSentence(context)}. The invite is on '
                            'its way to ${_email.text.trim()}.',
                        actionLabel: 'Book another',
                        onAction: _bookAnother,
                      )
                    // One step is on screen at a time, swapped rather than
                    // paged. A `PageView` of steps would make the flow scroll
                    // sideways as well as down, and `ui-probe`'s `dual-axis`
                    // rule fails that on sight: a page with two axes is a
                    // page whose reader does not know which one moves. The
                    // buttons move the flow, not the finger.
                    : AnimatedSwitcher(
                        duration: MediaQuery.disableAnimationsOf(context)
                            ? Duration.zero
                            : context.design.motion.scaled(
                                context.design.motion.normal,
                              ),
                        switchInCurve: context.design.motion.standard,
                        switchOutCurve: context.design.motion.standard,
                        child: KeyedSubtree(
                          key: ValueKey<_Step>(_step),
                          child: _stepBody(context, _step),
                        ),
                      ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: _confirmed ? null : _actions(context),
      ),
    );
  }

  Widget _actions(BuildContext context) {
    final primary = DSButton(
      variant: DSButtonVariant.primary,
      label: _isLast ? 'Confirm booking' : 'Next',
      fullWidth: true,
      loading: _submitting,
      onPressed: _next,
    );

    // On the first step the way out is the header's chevron, not a second
    // Back beside the primary — two ways back on one screen is one too many.
    if (_index == 0) {
      return DSPinnedActionBar(
        helperText: _summaryLine(context),
        children: [primary],
      );
    }
    // Spread, not `leadingAndAction`: the ghost keeps its own width on the
    // leading edge and the primary takes the whole of the rest, so the two
    // sit apart and the primary still reaches the trailing edge. Handing the
    // ghost to `leading` left both of them huddled on the left with a third
    // of the bar empty beside them.
    return DSPinnedActionBar(
      layout: DSActionBarLayout.spread,
      helperText: _summaryLine(context),
      children: [
        DSButton(
          variant: DSButtonVariant.ghost,
          label: 'Back',
          onPressed: _submitting ? null : _back,
        ),
        primary,
      ],
    );
  }

  /// One field, inside the page gutter. The gutter belongs to the page, and a
  /// field is the one thing here that does not carry its own.
  Widget _gutter(BuildContext context, Widget child) =>
      Padding(padding: context.design.space.pageHorizontal, child: child);

  Widget _stepBody(BuildContext context, _Step step) {
    final space = context.design.space;

    // A sliver list with one field per child, not one box holding a column of
    // them: a viewport clips its own children, which is what lets `ui-probe`
    // tell a control the fold cut from a control that is too small.
    return Form(
      key: _stepKeys[step.index],
      child: CustomScrollView(
        slivers: [
          SliverList.list(children: _fields(context, step)),
          SliverToBoxAdapter(child: SizedBox(height: space.xl)),
        ],
      ),
    );
  }

  List<Widget> _fields(BuildContext context, _Step step) {
    final space = context.design.space;

    return switch (step) {
      _Step.who => [
        _gutter(
          context,
          DSTextField(
            controller: _name,
            label: 'Name',
            hintText: 'Ada Lovelace',
            leadingIcon: Icons.person_outline,
            input: const DSFieldInput(
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
            ),
            validation: DSFieldValidation(
              required: true,
              autovalidateMode: _autovalidate(step),
              validator: _validateName,
            ),
          ),
        ),
        SizedBox(height: space.md),
        _gutter(
          context,
          DSTextField(
            controller: _email,
            label: 'Work email',
            hintText: 'you@example.com',
            helperText: 'The invite goes here.',
            leadingIcon: Icons.alternate_email,
            input: const DSFieldInput.email(
              textInputAction: TextInputAction.done,
            ),
            validation: DSFieldValidation(
              required: true,
              autovalidateMode: _autovalidate(step),
              validator: _validateEmail,
            ),
          ),
        ),
        SizedBox(height: space.md),
        _gutter(
          context,
          DSStepper.labelled(
            label: 'People',
            helperText: 'Up to eight to a pod.',
            value: _people,
            min: 1,
            max: 8,
            semanticUnit: 'people',
            onChanged: (value) => setState(() => _people = value),
          ),
        ),
        SizedBox(height: space.lg),
        // The question this step raises and used to leave unanswered: do I
        // already have a desk? Three fields and 223pt of white under them is
        // what `dead-band` measured before this panel existed.
        const DSSectionHeader(label: 'You already have'),
        for (final held in demoBookingsHeld)
          DSListTile(
            leading: const DSWell(icon: Icons.event_available_outlined),
            title: held.day,
            subtitle: '${held.zone} · ${held.slot.label}',
          ),
      ],
      _Step.when => [
        _gutter(
          context,
          DSSelect<DateTime>.fromValues(
            label: 'Day',
            helperText: 'The next ten days the office is open.',
            values: demoBookingDays,
            value: _day,
            optionBuilder: (day) => DSSelectOption<DateTime>(
              value: day,
              label: _dayLabel(context, day),
            ),
            onChanged: (value) =>
                setState(() => _day = value ?? demoBookingDays.first),
          ),
        ),
        SizedBox(height: space.md),
        // Radios, not a segmented control: each slot carries the hours it
        // means, and options that need a sentence need a row each. Three
        // segments sharing a 320-point width cut "Afternoon" in half.
        DSRadioGroup<ArrivalSlot>(
          label: 'Arrival',
          value: _slot,
          onChanged: (value) =>
              setState(() => _slot = value ?? ArrivalSlot.morning),
          children: [
            for (final slot in ArrivalSlot.values)
              DSRadioTile<ArrivalSlot>(
                value: slot,
                label: slot.label,
                subtitle: slot.hours,
              ),
          ],
        ),
        SizedBox(height: space.lg),
        // A date on its own makes the reader choose blind. The bar is the
        // choice's actual subject — how full the day already is — and it
        // moves with the select above it.
        const DSSectionHeader(label: 'That day'),
        SizedBox(height: space.sm),
        _gutter(
          context,
          DSMetricBar(
            value: _dayLoad.taken.toDouble(),
            max: _dayLoad.total.toDouble(),
            label: _dayLoad.mood,
            valueText: '${_dayLoad.taken} of ${_dayLoad.total} desks',
          ),
        ),
        SizedBox(height: space.xs),
        _gutter(
          context,
          DSText(
            '${_dayLoad.teammates} of your team are in.',
            role: DSTextRole.bodySupport,
          ),
        ),
      ],
      _Step.desk => [
        _gutter(
          context,
          DSSelect<DeskZone>.fromValues(
            label: 'Zone',
            hintText: 'Pick a zone',
            helperText: 'Six zones, each with its own noise rule.',
            errorText: _zoneMissing ? 'Pick a zone' : null,
            values: DeskZone.values,
            value: _zone,
            optionBuilder: (zone) => DSSelectOption<DeskZone>(
              value: zone,
              label: zone.label,
              subtitle: zone.detail,
              enabled: zone.available,
              disabledReason: zone.available ? null : 'Rewiring until April',
            ),
            onChanged: (value) => setState(() => _zone = value),
          ),
        ),
        SizedBox(height: space.md),
        const DSSectionHeader(label: 'Extras'),
        // Checkboxes, not switches: a switch says the change already
        // happened, and nothing here happens until the booking is confirmed.
        // The tiles own the page gutter themselves.
        for (final extra in demoBookingExtras)
          DSCheckboxTile(
            label: extra.label,
            subtitle: extra.detail,
            value: _extras.contains(extra.id),
            onChanged: (value) => _toggleExtra(extra.id, on: value ?? false),
          ),
        SizedBox(height: space.md),
        _gutter(
          context,
          DSTextField(
            controller: _notes,
            label: 'Anything we should know?',
            hintText: 'Step-free route, early arrival, a delivery…',
            helperText: 'Optional. Reception reads this on the day.',
            input: const DSFieldInput.multiline(
              maxLength: 140,
              textInputAction: TextInputAction.done,
            ),
          ),
        ),
      ],
      _Step.review => [
        _reviewRow(
          icon: Icons.person_outline,
          label: _name.text.trim(),
          value: '${_email.text.trim()} · $_peopleLabel',
          step: _Step.who,
        ),
        _reviewRow(
          icon: Icons.event_outlined,
          label: _dayLabel(context, _day),
          value: '${_slot.label} · ${_slot.hours}',
          step: _Step.when,
        ),
        _reviewRow(
          icon: Icons.chair_outlined,
          label: _zone?.label ?? 'No zone picked',
          value: _extrasLabel,
          step: _Step.desk,
        ),
        if (_notes.text.trim().isNotEmpty)
          _reviewRow(
            icon: Icons.sticky_note_2_outlined,
            label: 'Note for reception',
            value: _notes.text.trim(),
            step: _Step.desk,
          ),
        SizedBox(height: space.lg),
        // The review said what was chosen and nothing about what Confirm
        // does. 311pt of white is where that question was sitting.
        const DSSectionHeader(label: 'What happens next'),
        for (final step in demoBookingNextSteps)
          DSListTile(
            leading: const DSWell(icon: Icons.arrow_forward),
            title: step.title,
            subtitle: step.detail,
            // A sentence, not a label: `wrap` gives it its lines instead of
            // the ellipsis `clipped-text` fails a row for.
            wrap: true,
          ),
      ],
    };
  }

  /// One line of the review, and the way back to the step that set it. A
  /// review the user cannot correct from is a summary, not a review.
  Widget _reviewRow({
    required IconData icon,
    required String label,
    required String value,
    required _Step step,
  }) => DSListTile(
    leading: DSWell(icon: icon),
    title: label,
    subtitle: value,
    onTap: () => _goTo(step.index),
  );
}
