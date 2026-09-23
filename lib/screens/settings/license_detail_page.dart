import 'package:flutter/material.dart';
import 'package:parley_android/design_system/design_system.dart';
import 'package:parley_android/screens/settings/licenses_page.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// The **Detail** archetype — one package's license text, selectable so it
/// can be pasted into a support message or a compliance document, which is
/// the entire reason a person opens this screen.
class LicenseDetailPage extends StatelessWidget {
  const LicenseDetailPage({super.key, required this.license});

  final PackageLicense license;

  @override
  Widget build(BuildContext context) {
    final space = context.design.space;
    final theme = Theme.of(context);

    return DSPage(
      title: license.package,
      leading: const BackButton(),
      slivers: [
        DSGutter.sliver(
          sliver: SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(bottom: space.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final paragraph in license.paragraphs)
                    Padding(
                      padding: EdgeInsetsDirectional.only(
                        // `LicenseParagraph.indent` is `-1` for a centred
                        // line (a heading or a copyright banner) and
                        // otherwise the nesting level the license's own text
                        // carries — a numbered clause under a heading, for
                        // instance. Multiplying it onto the gutter step is
                        // the same idea `DSListTile`'s divider indent uses:
                        // structure in the source becomes structure on
                        // screen instead of one flat block of legal text.
                        start: paragraph.indent > 0
                            ? space.md * paragraph.indent
                            : 0,
                        bottom: space.md,
                      ),
                      child: SelectableText(
                        paragraph.text,
                        textAlign: paragraph.indent == -1
                            ? TextAlign.center
                            : TextAlign.start,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
