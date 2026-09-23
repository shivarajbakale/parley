import 'package:flutter/material.dart';
import 'package:parley_android/design_system/design_system.dart';
import 'package:parley_android/screens/design_system/catalog/story.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// Things the user changes the value of.
///
/// Every story here is stateful, because an input rendered at a fixed value is
/// a screenshot: the thing worth seeing is what it does when it is used.
final inputCategory = DSCatalogCategory(
  name: 'Input',
  icon: Icons.edit_outlined,
  components: [
    DSComponentDemo(
      name: 'DSTimeGrid',
      summary: 'A day as a column of hours, with what is booked on it.',
      stories: [
        DSStory(
          title: 'A working day, with a clash',
          note:
              'The two ten o\u2019clock bookings are side by side, not stacked: a '
              'booking hidden under another is the one that gets '
              'double-booked. The clash carries the error tone on its leading '
              'edge, and "Now" is drawn only because the caller passed a time '
              '\u2014 the grid never reads the clock, so a golden of it is the '
              'same picture twice.',
          builder: (context) => const DSTimeGrid(
            startHour: 9,
            endHour: 13,
            now: TimeOfDay(hour: 11, minute: 20),
            slots: [
              DSTimeSlot(
                start: TimeOfDay(hour: 9, minute: 0),
                end: TimeOfDay(hour: 9, minute: 45),
                title: 'Stand-up',
                subtitle: 'Room 2',
              ),
              DSTimeSlot(
                start: TimeOfDay(hour: 10, minute: 0),
                end: TimeOfDay(hour: 11, minute: 0),
                title: 'Design review',
                subtitle: 'With Ada',
              ),
              DSTimeSlot(
                start: TimeOfDay(hour: 10, minute: 30),
                end: TimeOfDay(hour: 11, minute: 30),
                title: 'Dentist',
                tone: DSTone.error,
              ),
              DSTimeSlot(
                start: TimeOfDay(hour: 12, minute: 0),
                end: TimeOfDay(hour: 12, minute: 30),
                title: 'Lunch',
                tone: DSTone.success,
              ),
            ],
          ),
        ),
        DSStory(
          title: 'A slot outside the window',
          note:
              'The window is a hint, not a crop. An 8pm booking on a grid that '
              'ends at 6 moves the edge \u2014 an event drawn nowhere is worse '
              'than a grid that scrolls further than it meant to.',
          builder: (context) => const DSTimeGrid(
            startHour: 16,
            endHour: 18,
            slots: [
              DSTimeSlot(
                start: TimeOfDay(hour: 20, minute: 0),
                end: TimeOfDay(hour: 21, minute: 0),
                title: 'Dinner',
              ),
            ],
          ),
        ),
      ],
    ),
    DSComponentDemo(
      name: 'DSComposer',
      fullBleed: true,
      summary: 'The bar a conversation is written in.',
      stories: [
        DSStory(
          title: 'Empty, and with something to send',
          note:
              'The send affordance is dead until there is text, so nobody is '
              'asked to discover that by tapping. The bar owns the page '
              'gutter, which is why this story is full bleed.',
          builder: (context) => const _ComposerDemo(),
        ),
        DSStory(
          title: 'Sending, and closed',
          note:
              'While a send is in flight the field stays live \u2014 only the '
              'affordance waits. A conversation that has ended disables the '
              'whole bar rather than removing it, so the transcript keeps its '
              'shape.',
          builder: (context) => const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ComposerDemo(sending: true, seed: 'Sending this one'),
              _ComposerDemo(enabled: false, hint: 'This chat is archived'),
            ],
          ),
        ),
      ],
    ),
    DSComponentDemo(
      name: 'DSStepper',
      summary: 'A small bounded quantity, adjusted rather than typed.',
      stories: [
        DSStory(
          title: 'Default, and at a bound',
          note:
              'At a bound the button is genuinely disabled and looks it. The '
              'commonest defect in a stepper is no feedback there: the user '
              'taps, nothing happens, and they tap harder.',
          builder: (context) => const _StepperDemo(),
        ),
        DSStory(
          title: 'Labelled, with a unit',
          note:
              'The value formatter is what keeps "2 guests", a currency and '
              'a localised plural all reachable without a branch inside '
              'the widget.',
          builder: (context) =>
              const _StepperDemo(labelled: true, unit: 'guests'),
        ),
        DSStory(
          title: 'Compact, in a row',
          note:
              'The visual is 36 points and the target is still 48. Shrinking '
              'the target with the visual is the commonest accessibility '
              'regression in a dense list.',
          builder: (context) => const _StepperDemo(size: DSStepperSize.compact),
        ),
      ],
    ),
    DSComponentDemo(
      name: 'DSDateStrip',
      summary: 'A run of days with one selected, for a date near today.',
      stories: [
        DSStory(
          title: 'Two weeks around today',
          note:
              'Today is an outline and a dot; selected is a fill. When a day '
              'is both, the fill wins and the dot stays in the on-colour.',
          builder: (context) => const _DateStripDemo(),
        ),
        DSStory(
          title: 'Compact, for an app bar',
          note:
              'No weekday row, 40dp cells — and the tap target is still 48. '
              'The two are decoupled by construction.',
          builder: (context) => const _DateStripDemo(compact: true),
        ),
        DSStory(
          title: 'Sold-out days, and a count badge',
          note:
              'isDayEnabled is how a booking app greys out a day without '
              'this component ever learning what a booking is.',
          builder: (context) => const _DateStripDemo(availability: true),
        ),
      ],
    ),
    DSComponentDemo(
      name: 'DSTextField',
      summary: 'Free text, and the validation contract that comes with it.',
      stories: [
        DSStory(
          title: 'Three sizes',
          note:
              'One skin. The three variants this replaces were the same '
              'control painted three ways, and filled had no visible '
              'boundary at all — 1.09:1 against the page.',
          builder: (context) => Column(
            children: [
              const DSTextField(
                label: 'Compact',
                hintText: 'sm',
                size: DSTextFieldSize.sm,
              ),
              context.design.space.verticalMd,
              const DSTextField(
                label: 'Default',
                hintText: 'md',
                leadingIcon: Icons.mail_outline,
              ),
              context.design.space.verticalMd,
              const DSTextField(
                label: 'Roomy',
                hintText: 'lg',
                size: DSTextFieldSize.lg,
              ),
            ],
          ),
        ),
        DSStory(
          title: 'Every state',
          note:
              'The helper slot is reserved whether or not it holds '
              'anything, so an error replaces the helper in place and '
              'nothing below the field moves.',
          builder: (context) => Column(
            children: [
              const DSTextField(
                label: 'Email',
                hintText: 'you@example.com',
                helperText: 'We only use this to sign you in.',
                leadingIcon: Icons.mail_outline,
              ),
              context.design.space.verticalMd,
              const DSTextField(
                label: 'Email',
                helperText: 'We only use this to sign you in.',
                errorText: 'That address is missing an @.',
                leadingIcon: Icons.mail_outline,
              ),
              context.design.space.verticalMd,
              const DSTextField(
                label: 'Checking',
                hintText: 'ada@example.com',
                loading: true,
                helperText: 'The field stays editable while it checks.',
              ),
              context.design.space.verticalMd,
              const DSTextField(
                label: 'Disabled',
                hintText: 'Not available yet',
                enabled: false,
              ),
              context.design.space.verticalMd,
              const DSTextField(
                label: 'Read only',
                helperText: 'Still selectable, still copyable.',
                affordances: DSFieldAffordances(readOnly: true),
              ),
            ],
          ),
        ),
        DSStory(
          title: 'Password, and required',
          note:
              'DSFieldInput.password() sets the obscuring, the keyboard, '
              'the autofill hint and the capitalisation together — the pair '
              'of overlapping booleans it replaces could disagree.',
          builder: (context) => const DSTextField(
            label: 'Password',
            leadingIcon: Icons.lock_outline,
            input: DSFieldInput.password(),
            validation: DSFieldValidation(required: true),
            helperText: 'At least 8 characters.',
          ),
        ),
        DSStory(
          title: 'Multiline and affixes',
          note:
              'The counter shares the reserved slot with the helper, and '
              'turns amber at nine tenths of the limit.',
          builder: (context) => Column(
            children: [
              const DSTextField(
                label: 'Notes',
                hintText: 'What happened?',
                input: DSFieldInput.multiline(maxLength: 280),
                affordances: DSFieldAffordances(showCharCount: true),
                helperText: 'Grows with the text.',
              ),
              context.design.space.verticalMd,
              const DSTextField(
                label: 'Amount',
                hintText: '0.00',
                input: DSFieldInput.number(),
                prefix: Text(r'$ '),
                suffix: Text(' kg'),
              ),
              context.design.space.verticalMd,
              const DSTextField(
                label: 'Display name',
                affordances: DSFieldAffordances(showClearButton: true),
              ),
            ],
          ),
        ),
      ],
    ),
    DSComponentDemo(
      name: 'DSSelect',
      summary: 'One value from four to twenty — a list you scan.',
      stories: [
        DSStory(
          title: 'Plain',
          note: 'A label above, the selected value in the field.',
          builder: (context) => const _SelectDemo(),
        ),
        DSStory(
          title: 'With icons',
          note:
              'An icon per row when the options are categories the user '
              'already recognises by glyph.',
          builder: (context) => const _SelectDemo(withIcons: true),
        ),
        DSStory(
          title: 'Disabled',
          note:
              'Disabled when another field decides it — never as the only '
              'explanation of why it cannot be used.',
          builder: (context) => DSSelect<String>(
            label: 'Region',
            options: const [
              DSSelectOption<String>(value: 'Europe', label: 'Europe'),
            ],
            value: 'Europe',
            enabled: false,
            onChanged: (_) {},
          ),
        ),
      ],
    ),
    DSComponentDemo(
      name: 'DSSegmentedButton',
      summary:
          'Two to five options, all of them visible, switching a value '
          'in place.',
      stories: [
        DSStory(
          title: 'Equal width',
          note:
              'The default, and the one that survives a long label. One '
              'indicator travels; two fills never cross-fade.',
          builder: (context) => const _SegmentedDemo(),
        ),
        DSStory(
          title: 'With icons and counts, hugging its content',
          note:
              'A count is the commonest thing this control holds, and the '
              'closed model it replaced had nowhere to put one.',
          builder: (context) => const _SegmentedDemo(
            withIcons: true,
            counts: true,
            sizing: DSSegmentedSizing.content,
          ),
        ),
        DSStory(
          title: 'Filling the row, weighted by content',
          note:
              'The third sizing, and the one with no story until now. Every '
              'segment stretches to fill the row, but keeps a share '
              'proportional to its own label, so "Day" takes less of it than '
              '"Month" — and never a share below the tap-target floor.',
          builder: (context) =>
              const _SegmentedDemo(sizing: DSSegmentedSizing.fill),
        ),
        DSStory(
          title: 'Nothing selected, and a disabled segment',
          note:
              'A filter row that starts with nothing chosen is a real '
              'state. A disabled segment keeps its width, so the indicator\'s '
              'travel does not change when an option becomes unavailable.',
          builder: (context) =>
              const _SegmentedDemo(startEmpty: true, disableLast: true),
        ),
        DSStory(
          title: 'Multiple selection',
          note:
              'Bold, italic, underline: independent toggles that belong '
              'together. No indicator travels — it cannot be in two places.',
          builder: (context) => const _SegmentedMultipleDemo(),
        ),
        DSStory(
          title: 'Three heights',
          note:
              'sm, md and lg, in a kit where three sizes existed and no '
              'story ever showed them. The track shrinks with the size; the '
              'tap target does not, and stays at the 48-point floor.',
          builder: (context) => const Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SegmentedDemo(size: DSSegmentedButtonSize.sm),
              _SegmentedDemo(size: DSSegmentedButtonSize.md),
              _SegmentedDemo(size: DSSegmentedButtonSize.lg),
            ],
          ),
        ),
        DSStory(
          title: 'Disabled',
          note:
              'The whole control, when the choice belongs to something the '
              'user has not done yet. The selection stays visible — a '
              'disabled control still has to say what it is set to.',
          builder: (context) => const _SegmentedDemo(disabled: true),
        ),
        DSStory(
          title: 'Loading',
          note:
              'The same segment count at the same height, so the row does '
              'not resize when the labels arrive. Driven through the '
              'control\'s own loading flag rather than the skeleton widget '
              'directly, because that is how a screen reaches this state.',
          builder: (context) => const _SegmentedDemo(loading: true),
        ),
      ],
    ),
    DSComponentDemo(
      name: 'DSSwitch',
      summary: 'A setting that applies the instant it flips.',
      stories: [
        DSStory(
          title: 'Bare',
          note:
              'On, off and disabled. The thumb grows under the finger, which '
              'is the press feedback both platforms ship and this one lacked.',
          builder: (context) => const Align(
            alignment: AlignmentDirectional.centerStart,
            child: _SwitchDemo(),
          ),
        ),
        DSStory(
          title: 'With a thumb glyph',
          note:
              'The injected strategy, not a variant: a house that marks its '
              'thumbs passes a function from value to glyph.',
          builder: (context) => const Align(
            alignment: AlignmentDirectional.centerStart,
            child: _SwitchDemo(glyphs: true),
          ),
        ),
      ],
    ),
    DSComponentDemo(
      name: 'DSCheckbox',
      summary: 'A selection something else commits — not a switch.',
      stories: [
        DSStory(
          title: 'Every state',
          note:
              'Unticked, ticked, mixed, disabled and in error. null is the '
              'third value, which is the box a "select all" over a partial '
              'selection needs.',
          builder: (context) => const _CheckboxDemo(),
        ),
      ],
    ),
    DSComponentDemo(
      name: 'DSRadio',
      fullBleed: true,
      summary: 'One of a few options, all of which stay visible.',
      stories: [
        DSStory(
          title: 'A group',
          note:
              'Exclusivity is a property of the set, so a radio outside a '
              'DSRadioGroup asserts. The group is what makes a screen reader '
              'say "2 of 3".',
          builder: (context) => const _RadioDemo(),
        ),
      ],
    ),
    DSComponentDemo(
      name: 'DSControlTile',
      fullBleed: true,
      summary:
          'The labelled control row — one implementation, where there '
          'were four.',
      stories: [
        DSStory(
          title: 'A settings list',
          note:
              'A switch row, a checkbox row and a radio group, all at one '
              'height because all four read the list row\'s own tokens.',
          builder: (context) => const _ControlTilesDemo(),
        ),
        DSStory(
          title: 'With a helper and an error',
          note:
              'The line under the row belongs to the control and is '
              'announced with it, rather than floating somewhere else.',
          builder: (context) => const _ControlTileMessagesDemo(),
        ),
      ],
    ),
    DSComponentDemo(
      name: 'DSSlider',
      summary:
          'A continuous value where the position matters more than the '
          'number.',
      stories: [
        DSStory(
          title: 'Continuous',
          note:
              'No divisions: the user is aiming at a feel, not at a figure. '
              'Without a formatter the readout still stops at the precision '
              'the range deserves.',
          builder: (context) => const _SliderDemo(showValue: true),
        ),
        DSStory(
          title: 'Stepped, formatted, bounded',
          note:
              'divisions + a formatter that feeds the announcement as well '
              'as the readout, so the two cannot disagree.',
          builder: (context) => const _SliderDemo(
            divisions: 4,
            showValue: true,
            formatted: true,
            bounds: true,
          ),
        ),
        DSStory(
          title: 'In a control tile',
          // The one story on this page whose widget owns the gutter: a slider
          // does not, and `DSControlTile` does. Untagged it paid the frame's
          // gutter as well as its own, and the probe found the row's title
          // rendered eight points wide.
          fullBleed: true,
          note:
              'The row is the tile\'s. The slider stopped drawing one of its '
              'own, which is why it and a switch finally line up.',
          builder: (context) => const _SliderTileDemo(),
        ),
        DSStory(
          title: 'A range, two thumbs',
          note:
              'DSRangeSlider — a window on a continuum: a price filter, a '
              'date range. Neither end may cross the other, and whichever one '
              'moved is the one that gives way.',
          builder: (context) => const _RangeSliderDemo(),
        ),
      ],
    ),
  ],
);

class _SelectDemo extends StatefulWidget {
  final bool withIcons;

  const _SelectDemo({this.withIcons = false});

  @override
  State<_SelectDemo> createState() => _SelectDemoState();
}

const _selectItems = ['Inbox', 'Starred', 'Archive', 'Trash'];
const _selectIcons = {
  'Inbox': Icons.inbox_outlined,
  'Starred': Icons.star_outline,
  'Archive': Icons.archive_outlined,
  'Trash': Icons.delete_outline,
};

class _SelectDemoState extends State<_SelectDemo> {
  String? _value = _selectItems.first;

  @override
  Widget build(BuildContext context) {
    return DSSelect<String>(
      label: 'Folder',
      // A row is a widget now, so a glyph is a slot rather than a fourth
      // builder function over the value type.
      options: [
        for (final item in _selectItems)
          DSSelectOption<String>(
            value: item,
            label: item,
            leading: widget.withIcons ? Icon(_selectIcons[item]) : null,
          ),
      ],
      value: _value,
      onChanged: (value) => setState(() => _value = value),
    );
  }
}

class _SegmentedDemo extends StatefulWidget {
  const _SegmentedDemo({
    this.withIcons = false,
    this.counts = false,
    this.sizing = DSSegmentedSizing.equal,
    this.size = DSSegmentedButtonSize.md,
    this.startEmpty = false,
    this.disableLast = false,
    this.disabled = false,
    this.loading = false,
  });

  final bool withIcons;
  final bool counts;
  final DSSegmentedSizing sizing;
  final DSSegmentedButtonSize size;
  final bool startEmpty;
  final bool disableLast;
  final bool disabled;
  final bool loading;

  @override
  State<_SegmentedDemo> createState() => _SegmentedDemoState();
}

class _SegmentedDemoState extends State<_SegmentedDemo> {
  String? _value;

  @override
  void initState() {
    super.initState();
    _value = widget.startEmpty ? null : 'week';
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: DSSegmentedButton<String>(
        sizing: widget.sizing,
        size: widget.size,
        enabled: !widget.disabled,
        loading: widget.loading,
        selected: _value,
        onChanged: (value) => setState(() => _value = value),
        segments: [
          for (final (String value, String label, IconData icon, int count)
              in const [
                ('day', 'Day', Icons.today_outlined, 12),
                ('week', 'Week', Icons.date_range_outlined, 3),
                ('month', 'Month', Icons.calendar_month_outlined, 41),
              ])
            DSSegment<String>(
              value: value,
              label: label,
              icon: widget.withIcons ? icon : null,
              count: widget.counts ? count : null,
              enabled: !(widget.disableLast && value == 'month'),
            ),
        ],
      ),
    );
  }
}

class _SegmentedMultipleDemo extends StatefulWidget {
  const _SegmentedMultipleDemo();

  @override
  State<_SegmentedMultipleDemo> createState() => _SegmentedMultipleDemoState();
}

class _SegmentedMultipleDemoState extends State<_SegmentedMultipleDemo> {
  Set<String> _chosen = {'bold'};

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: DSSegmentedButton<String>.multiple(
        selected: _chosen,
        onChanged: (value) => setState(() => _chosen = value),
        segments: const [
          DSSegment<String>(
            value: 'bold',
            icon: Icons.format_bold,
            tooltip: 'Bold',
          ),
          DSSegment<String>(
            value: 'italic',
            icon: Icons.format_italic,
            tooltip: 'Italic',
          ),
          DSSegment<String>(
            value: 'underline',
            icon: Icons.format_underlined,
            tooltip: 'Underline',
          ),
        ],
      ),
    );
  }
}

class _SwitchDemo extends StatefulWidget {
  const _SwitchDemo({this.glyphs = false});

  final bool glyphs;

  @override
  State<_SwitchDemo> createState() => _SwitchDemoState();
}

class _SwitchDemoState extends State<_SwitchDemo> {
  bool _on = true;

  @override
  Widget build(BuildContext context) {
    final style = widget.glyphs
        ? DSSwitchStyle(thumbIcon: (value) => value ? Icons.check : Icons.close)
        : null;
    return Row(
      children: [
        DSSwitch(
          value: _on,
          semanticLabel: 'Notifications',
          style: style,
          onChanged: (value) => setState(() => _on = value),
        ),
        context.design.space.horizontalMd,
        DSSwitch(
          value: !_on,
          semanticLabel: 'The other position',
          style: style,
          onChanged: (value) => setState(() => _on = !value),
        ),
        context.design.space.horizontalMd,
        DSSwitch(
          value: true,
          semanticLabel: 'Locked on',
          style: style,
          onChanged: null,
        ),
      ],
    );
  }
}

class _CheckboxDemo extends StatefulWidget {
  const _CheckboxDemo();

  @override
  State<_CheckboxDemo> createState() => _CheckboxDemoState();
}

class _CheckboxDemoState extends State<_CheckboxDemo> {
  bool _plain = true;
  bool? _mixed;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        DSCheckbox(
          value: _plain,
          semanticLabel: 'Plain',
          onChanged: (value) => setState(() => _plain = value ?? false),
        ),
        context.design.space.horizontalMd,
        DSCheckbox(
          value: _mixed,
          tristate: true,
          semanticLabel: 'Select all',
          onChanged: (value) => setState(() => _mixed = value),
        ),
        context.design.space.horizontalMd,
        const DSCheckbox(
          value: false,
          error: true,
          semanticLabel: 'Required and unticked',
          onChanged: _noop,
        ),
        context.design.space.horizontalMd,
        const DSCheckbox(
          value: true,
          semanticLabel: 'Locked on',
          onChanged: null,
        ),
      ],
    );
  }
}

void _noop(bool? _) {}

class _RadioDemo extends StatefulWidget {
  const _RadioDemo();

  @override
  State<_RadioDemo> createState() => _RadioDemoState();
}

class _RadioDemoState extends State<_RadioDemo> {
  String _chosen = 'Standard';

  @override
  Widget build(BuildContext context) {
    return DSRadioGroup<String>(
      label: 'Delivery',
      value: _chosen,
      onChanged: (value) => setState(() => _chosen = value ?? _chosen),
      direction: Axis.horizontal,
      children: [
        for (final option in const ['Standard', 'Express', 'Overnight'])
          Padding(
            padding: EdgeInsetsDirectional.only(end: context.design.space.sm),
            child: DSRadio<String>(value: option, semanticLabel: option),
          ),
      ],
    );
  }
}

class _ControlTilesDemo extends StatefulWidget {
  const _ControlTilesDemo();

  @override
  State<_ControlTilesDemo> createState() => _ControlTilesDemoState();
}

class _ControlTilesDemoState extends State<_ControlTilesDemo> {
  bool _sync = true;
  bool? _terms = false;
  String _plan = 'Monthly';

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DSSwitchTile(
          label: 'Sync over cellular',
          subtitle: 'Uses your data plan',
          icon: Icons.cloud_sync_outlined,
          value: _sync,
          onChanged: (value) => setState(() => _sync = value),
        ),
        DSCheckboxTile(
          label: 'Notify me about replies',
          subtitle: 'Includes mentions and direct messages',
          value: _terms,
          onChanged: (value) => setState(() => _terms = value),
        ),
        DSRadioGroup<String>(
          value: _plan,
          onChanged: (value) => setState(() => _plan = value ?? _plan),
          children: [
            for (final plan in const ['Monthly', 'Yearly'])
              DSRadioTile<String>(label: plan, value: plan),
          ],
        ),
      ],
    );
  }
}

class _ControlTileMessagesDemo extends StatefulWidget {
  const _ControlTileMessagesDemo();

  @override
  State<_ControlTileMessagesDemo> createState() =>
      _ControlTileMessagesDemoState();
}

class _ControlTileMessagesDemoState extends State<_ControlTileMessagesDemo> {
  bool? _agreed = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DSCheckboxTile(
          label: 'Email me a receipt',
          value: true,
          helperText: 'Sent to the address on the account.',
          onChanged: (_) {},
        ),
        DSCheckboxTile(
          label: 'I agree to the terms',
          value: _agreed,
          errorText: _agreed ?? false ? null : 'You have to agree to continue.',
          onChanged: (value) => setState(() => _agreed = value),
        ),
      ],
    );
  }
}

class _SliderDemo extends StatefulWidget {
  const _SliderDemo({
    this.divisions,
    this.showValue = false,
    this.formatted = false,
    this.bounds = false,
  });

  final int? divisions;
  final bool showValue;
  final bool formatted;
  final bool bounds;

  @override
  State<_SliderDemo> createState() => _SliderDemoState();
}

class _SliderDemoState extends State<_SliderDemo> {
  double _value = 0.5;

  @override
  Widget build(BuildContext context) {
    return DSSlider(
      value: _value,
      divisions: widget.divisions,
      showValue: widget.showValue,
      formatter: widget.formatted
          ? (value) => '${(value * 100).round()}%'
          : null,
      minLabel: widget.bounds ? 'Small' : null,
      maxLabel: widget.bounds ? 'Large' : null,
      semanticLabel: 'Volume',
      onChanged: (value) => setState(() => _value = value),
    );
  }
}

class _SliderTileDemo extends StatefulWidget {
  const _SliderTileDemo();

  @override
  State<_SliderTileDemo> createState() => _SliderTileDemoState();
}

class _SliderTileDemoState extends State<_SliderTileDemo> {
  double _value = 0.62;

  @override
  Widget build(BuildContext context) {
    return DSControlTile(
      label: 'Brightness',
      subtitle: 'Adjusts with ambient light',
      icon: Icons.light_mode_outlined,
      controlPosition: DSControlPosition.trailing,
      onTap: () {},
      // A fraction of the row rather than a fixed 160: `ListTile` lays the
      // trailing slot out before the title and gives the title what is left,
      // so a width written for a 390-point phone cut "Brightness" down to
      // eight points on a 320-point one. The bounds keep the track usable at
      // either end.
      trailing: LayoutBuilder(
        builder: (context, constraints) => SizedBox(
          width: (constraints.maxWidth * 0.35).clamp(88.0, 160.0),
          child: DSSlider(
            value: _value,
            showValue: true,
            inTile: true,
            formatter: (value) => '${(value * 100).round()}%',
            onChanged: (value) => setState(() => _value = value),
          ),
        ),
      ),
    );
  }
}

class _RangeSliderDemo extends StatefulWidget {
  const _RangeSliderDemo();

  @override
  State<_RangeSliderDemo> createState() => _RangeSliderDemoState();
}

class _RangeSliderDemoState extends State<_RangeSliderDemo> {
  DSRange _range = const DSRange(20, 80);

  @override
  Widget build(BuildContext context) {
    return DSRangeSlider(
      value: _range,
      min: 0,
      max: 100,
      formatter: (value) => '\u00a3${value.round()}',
      showValue: true,
      startSemanticLabel: 'Minimum price',
      endSemanticLabel: 'Maximum price',
      onChanged: (value) => setState(() => _range = value),
    );
  }
}

/// The stepper holds no state, so the story has to.
class _StepperDemo extends StatefulWidget {
  const _StepperDemo({this.labelled = false, this.unit = '', this.size});

  final bool labelled;
  final String unit;
  final DSStepperSize? size;

  @override
  State<_StepperDemo> createState() => _StepperDemoState();
}

class _StepperDemoState extends State<_StepperDemo> {
  int _value = 3;

  @override
  Widget build(BuildContext context) {
    String format(int value) =>
        widget.unit.isEmpty ? '$value' : '$value ${widget.unit}';

    if (widget.labelled) {
      return DSStepper.labelled(
        label: 'Guests',
        helperText: 'Adults, 13 or older',
        value: _value,
        min: 1,
        max: 8,
        semanticUnit: widget.unit,
        valueFormatter: format,
        onChanged: (next) => setState(() => _value = next),
      );
    }
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: DSStepper(
        value: _value,
        min: 1,
        max: 8,
        size: widget.size,
        semanticUnit: widget.unit,
        onChanged: (next) => setState(() => _value = next),
      ),
    );
  }
}

/// The strip reports a selection outwards, so the story holds the day.
///
/// `today:` is passed rather than left to the clock, which is the same reason
/// the widget takes it: a gallery that drifts by a day every midnight is a
/// gallery nobody can screenshot.
class _DateStripDemo extends StatefulWidget {
  const _DateStripDemo({this.compact = false, this.availability = false});

  final bool compact;
  final bool availability;

  @override
  State<_DateStripDemo> createState() => _DateStripDemoState();
}

class _DateStripDemoState extends State<_DateStripDemo> {
  static final DateTime _today = DateTime(2026, 3, 11);
  DateTime _selected = _today;

  @override
  Widget build(BuildContext context) {
    if (widget.compact) {
      return DSDateStrip.compact(
        // Four days: the demo fits in the catalog page's narrow column at
        // every width and text scale the probe walks, so every cell stays
        // whole. A scrollable strip in a constrained column would always
        // show partial cells at the right edge — a real defect, not a
        // demonstration of one.
        firstDate: _today.subtract(const Duration(days: 1)),
        lastDate: _today.add(const Duration(days: 2)),
        today: _today,
        selectedDate: _selected,
        onDateSelected: (date) => setState(() => _selected = date),
      );
    }
    return DSDateStrip(
      firstDate: _today.subtract(const Duration(days: 1)),
      lastDate: _today.add(const Duration(days: 2)),
      today: _today,
      selectedDate: _selected,
      isDayEnabled: widget.availability
          ? (date) => date.weekday != DateTime.sunday
          : null,
      // No style: the strip supplies the type and, per cell, the colour. A
      // badge that brings its own colour brings the card's, and the card is
      // not what the selected day is painted in.
      dayBadge: widget.availability
          ? (context, date) => Text('${date.day % 3}')
          : null,
      onDateSelected: (date) => setState(() => _selected = date),
    );
  }
}

/// A composer that keeps its own text, so the story shows the send
/// affordance waking up as soon as there is something to send.
class _ComposerDemo extends StatefulWidget {
  const _ComposerDemo({
    this.sending = false,
    this.enabled = true,
    this.seed,
    this.hint,
  });

  final bool sending;
  final bool enabled;
  final String? seed;
  final String? hint;

  @override
  State<_ComposerDemo> createState() => _ComposerDemoState();
}

class _ComposerDemoState extends State<_ComposerDemo> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.seed ?? '',
  );
  String? _sent;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (_sent != null) ...[
        DSChatBubble(author: DSChatAuthor.me, text: _sent!, timeLabel: 'now'),
        context.design.space.verticalSm,
      ],
      DSComposer(
        controller: _controller,
        enabled: widget.enabled,
        sending: widget.sending,
        hintText: widget.hint ?? 'Message',
        onSend: (text) => setState(() {
          _sent = text;
          _controller.clear();
        }),
      ),
    ],
  );
}
