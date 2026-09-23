import 'package:flutter/material.dart';
import 'package:parley_android/screens/design_system/catalog/story.dart';
import 'package:parley_android/screens/design_system/catalog/ds_chat_bubble_demo.dart';
import 'package:parley_android/screens/design_system/catalog/ds_dismissible_tile_demo.dart';
import 'package:parley_android/screens/design_system/catalog/ds_divider_demo.dart';
import 'package:parley_android/screens/design_system/catalog/ds_expansion_demo.dart';
import 'package:parley_android/screens/design_system/catalog/ds_field_group_demo.dart';
import 'package:parley_android/screens/design_system/catalog/ds_form_page_demo.dart';
import 'package:parley_android/screens/design_system/catalog/ds_hero_demo.dart';
import 'package:parley_android/screens/design_system/catalog/ds_list_tile_demo.dart';
import 'package:parley_android/screens/design_system/catalog/ds_media_hero_demo.dart';
import 'package:parley_android/screens/design_system/catalog/ds_media_row_demo.dart';
import 'package:parley_android/screens/design_system/catalog/ds_media_surface_demo.dart';
import 'package:parley_android/screens/design_system/catalog/ds_media_tile_demo.dart';
import 'package:parley_android/screens/design_system/catalog/ds_page_demo.dart';
import 'package:parley_android/screens/design_system/catalog/ds_page_header_demo.dart';
import 'package:parley_android/screens/design_system/catalog/ds_section_header_demo.dart';
import 'package:parley_android/screens/design_system/catalog/ds_settings_section_demo.dart';
import 'package:parley_android/screens/design_system/catalog/ds_stat_tile_demo.dart';
import 'package:parley_android/screens/design_system/catalog/ds_theme_mode_picker_demo.dart';

/// Rows, groups and headers — the parts that give a screen its skeleton.
///
/// Each component's [DSComponentDemo] lives in its own `ds_*_demo.dart` file
/// in this directory — this file only assembles them. Split out when this
/// held all eighteen inline and ran past 1500 lines; kept flat rather than
/// nested in a subdirectory because `ui_lint`'s gutter-ownership check reads
/// this directory with a non-recursive listing, and a subdirectory would be
/// invisible to it. A widget shared by more than one story (`StoryStage`,
/// `ThemeModeDemo`) lives in `structure_shared_widgets.dart` rather than
/// being duplicated.
final structureCategory = DSCatalogCategory(
  name: 'List & structure',
  icon: Icons.view_agenda_outlined,
  components: [
    dsDividerDemo,
    dsExpansionDemo,
    dsStatTileDemo,
    dsMediaSurfaceDemo,
    dsMediaRowDemo,
    dsMediaTileDemo,
    dsMediaHeroDemo,
    dsListTileDemo,
    dsDismissibleTileDemo,
    dsSectionHeaderDemo,
    dsPageDemo,
    dsFormPageDemo,
    dsPageHeaderDemo,
    dsHeroDemo,
    dsFieldGroupDemo,
    dsSettingsSectionDemo,
    dsChatBubbleDemo,
    dsThemeModePickerDemo,
  ],
);
