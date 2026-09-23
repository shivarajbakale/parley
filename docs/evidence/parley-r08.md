# parley-r08 — Launcher icon matches the Mac app

Verified 2026-09-24 on `main`.

- Source: `parley/build/icon.svg` (the Mac app's icon), copied to
  `assets/icon/icon.svg`; `assets/icon/icon.png` is the Mac app's own render.
- Adaptive layers (`assets/icon/adaptive-{background,foreground,monochrome}.svg`)
  split the same artwork: gradient full-bleed; pill and bars scaled so the Mac
  squircle's 824px body fills the 72dp visible area; bars alone for themed
  icons. `dart run flutter_launcher_icons` generated the Android mipmaps.
- `parley-r08/adaptive-masks.png`: the icon under circle and squircle masks,
  and the monochrome layer.
- `parley-r08/launcher.png`: emulator-5554 (API 36) launcher search showing
  the installed icon.
- `test/design_system/ds_illustration_test.dart` now allows `assets/icon/`,
  the launcher-icon source the template's `rename_app.sh` and
  `docs/MODULES.md` name; it is not in the Flutter asset bundle.
