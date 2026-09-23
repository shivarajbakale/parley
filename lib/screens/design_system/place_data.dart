import 'package:flutter/material.dart' show Alignment;

/// The fixtures the Canvas demo is drawn from.
///
/// A canvas is a *space*, so the fixture is positions: where each pin sits on
/// the ground, and what the sheet says about the one that is selected. See
/// `docs/principles/screen-archetypes.md`, "Canvas".
///
/// Delete this file with `place_page.dart` when the app ships a real map.
class DemoPlace {
  const DemoPlace({
    required this.name,
    required this.kind,
    required this.address,
    required this.distance,
    required this.open,
    required this.at,
  });

  final String name;

  /// What kind of place it is — the line under the name in the sheet.
  final String kind;

  /// The ground is silent: a pin says *there*, never *what*. The address and
  /// the distance are text in the sheet for the same reason the archetype
  /// gives — a map that is the only statement of the state has no statement
  /// a screen reader can read.
  final String address;
  final String distance;
  final String open;

  /// Where the pin sits on the ground, in the -1..1 alignment space.
  final Alignment at;
}

const demoPlaces = <DemoPlace>[
  DemoPlace(
    name: 'Rocketship Studio',
    kind: 'Recording studio',
    address: '14 Bellweather Lane',
    distance: '400 m away',
    open: 'Open until 18:00',
    at: Alignment(-0.35, -0.2),
  ),
  DemoPlace(
    name: 'The Kit Room',
    kind: 'Rehearsal space',
    address: '2 Founders Yard',
    distance: '1.1 km away',
    open: 'Open until 22:00',
    at: Alignment(0.45, 0.15),
  ),
  DemoPlace(
    name: 'Bellweather Coffee',
    kind: 'Café',
    address: '9 Bellweather Lane',
    distance: '350 m away',
    open: 'Closes at 16:00',
    at: Alignment(0.1, 0.55),
  ),
];
