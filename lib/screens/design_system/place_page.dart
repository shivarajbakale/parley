import 'package:flutter/material.dart';
import 'package:parley_android/design_system/design_system.dart';
import 'package:parley_android/screens/design_system/demo_photo.dart';
import 'package:parley_android/screens/design_system/place_data.dart';
import 'package:parley_android/theme/app_haptics.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// Places on a ground — the **Canvas** archetype
/// (`docs/principles/screen-archetypes.md`).
///
/// A spatial ground under a sheet with detents. The content is a *space*
/// rather than a list, and the controls sit over it.
///
/// What to imitate when you replace it:
///
///   * the **ground stays interactive at every detent.** A sheet that blocks
///     the map it is describing is a dialog wearing a sheet's shape;
///   * the **smallest detent leaves the subject visible.** Peek exists so the
///     reader can see the pin they just tapped;
///   * **two or three detents, named.** Peek, half, full — a sheet that
///     settles anywhere is a sheet the reader has to aim;
///   * the **handle is the affordance**, and it is also the tap target that
///     cycles the detents;
///   * **floating controls sit above the sheet's top edge, never under it.**
///     A recentre button the sheet covers at half is a control that exists at
///     one detent only;
///   * the **ground is never the only statement of the state.** A map is
///     silent: the selected place's name, address and distance are text in
///     the sheet, where a screen reader can reach them.
///
/// The ground here is a photograph under an `InteractiveViewer` rather than a
/// map SDK — a demo cannot ship an API key, and what the archetype is about is
/// the arrangement, not the tiles. Swap it for the map of your choice; nothing
/// above it knows the difference.
///
/// Delete this file and `place_data.dart` with the rest of the design-system
/// demo surface when the app ships a real map.
class PlacePage extends StatefulWidget {
  const PlacePage({super.key, this.initialSnap = peek});

  /// Peek, half, full — the three the archetype allows, named here so the
  /// screen and its gates cannot disagree about them.
  static const double peek = 0.28;
  static const double half = 0.5;
  static const double full = 0.9;

  static const List<double> detents = <double>[peek, half, full];
  static const List<String> detentNames = <String>['Peek', 'Half', 'Full'];

  final double initialSnap;

  @override
  State<PlacePage> createState() => _PlacePageState();
}

class _PlacePageState extends State<PlacePage> {
  int _selected = 0;
  late double _snap = widget.initialSnap;

  DemoPlace get _place => demoPlaces[_selected];

  void _select(int index) {
    AppHaptics.selection();
    setState(() => _selected = index);
  }

  @override
  Widget build(BuildContext context) {
    final space = context.design.space;
    // A detent is a fraction of the screen; a header is type. At a doubled
    // text scale the peek could not hold its own title and the sheet's column
    // overflowed by 23 points, so the peek grows with the type it has to
    // hold — and stops short of the half detent, so three detents stay three.
    final double scale = MediaQuery.textScalerOf(context).scale(1);
    final double peek = (PlacePage.peek * scale).clamp(
      PlacePage.peek,
      PlacePage.half - 0.05,
    );
    final List<double> detents = <double>[peek, PlacePage.half, PlacePage.full];
    final double initial = widget.initialSnap == PlacePage.peek
        ? peek
        : widget.initialSnap;

    return Scaffold(
      body: Stack(
        children: [
          // The ground. Full bleed and pannable, and it stays that way at
          // every detent: nothing here is behind a barrier.
          Positioned.fill(
            child: _Ground(selected: _selected, onSelect: _select),
          ),
          // Above the sheet's top edge, always. The button's bottom is the
          // sheet's height plus a gap, so it rides the sheet rather than
          // disappearing under it at half.
          PositionedDirectional(
            start: DSGutter.of(context),
            end: DSGutter.of(context),
            bottom: MediaQuery.sizeOf(context).height * _snap + space.md,
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: DSIconButton(
                icon: Icons.my_location,
                semanticLabel: 'Recentre on ${_place.name}',
                onPressed: () => _select(_selected),
                variant: DSIconButtonVariant.filled,
              ),
            ),
          ),
          DSBottomSheet(
            snapPoints: detents,
            snapLabels: PlacePage.detentNames,
            initialSnap: initial,
            onSnap: (double at) => setState(() => _snap = at),
            header: DSSheetHeader(
              title: _place.name,
              subtitle: '${_place.kind} · ${_place.distance}',
              // No close: this sheet is part of the screen rather than a
              // thing over it, and its × pops the route — which on a canvas
              // takes the ground away with it. The handle is what moves it.
              showClose: false,
            ),
            // A list, so the sheet's own scroll controller drives it — and so
            // the rest of the places are reachable without touching the map.
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                // The ground is silent. Everything the pin means is written
                // here, where a screen reader can reach it.
                DSListTile(
                  leading: const DSWell(icon: Icons.place_outlined),
                  title: _place.address,
                  subtitle: _place.open,
                ),
                SizedBox(height: space.sm),
                DSSection(
                  label: 'Nearby',
                  child: Column(
                    children: [
                      for (var i = 0; i < demoPlaces.length; i++)
                        if (i != _selected)
                          DSListTile(
                            title: demoPlaces[i].name,
                            subtitle:
                                '${demoPlaces[i].kind} · '
                                '${demoPlaces[i].distance}',
                            onTap: () => _select(i),
                            divider: i < demoPlaces.length - 1,
                          ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The space itself: a photograph the reader can pan and zoom, with a pin per
/// place drawn over it.
class _Ground extends StatelessWidget {
  const _Ground({required this.selected, required this.onSelect});

  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      minScale: 1,
      maxScale: 3,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const DemoPhoto(
            asset: DemoPhotos.crossing,
            fallbackHue: 2,
            fallbackLabel: 'Map',
          ),
          for (var i = 0; i < demoPlaces.length; i++)
            Align(
              alignment: demoPlaces[i].at,
              child: _Pin(
                place: demoPlaces[i],
                selected: i == selected,
                onTap: () => onSelect(i),
              ),
            ),
        ],
      ),
    );
  }
}

/// One place, on the ground. A pin says *there* and never *what* — the name,
/// the address and the distance are the sheet's job.
class _Pin extends StatelessWidget {
  const _Pin({
    required this.place,
    required this.selected,
    required this.onTap,
  });

  final DemoPlace place;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final component = context.design.component;

    return DSPressable(
      focusShape: const CircleBorder(),
      child: Semantics(
        button: true,
        selected: selected,
        label: place.name,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: SizedBox(
            width: component.minTapTarget,
            height: component.minTapTarget,
            child: Center(
              child: Icon(
                selected ? Icons.place : Icons.place_outlined,
                color: selected ? palette.primary : palette.foreground,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
