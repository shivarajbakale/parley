import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:parley_android/design_system/ds_page.dart';
import 'package:parley_android/design_system/ds_settings.dart';
import 'package:parley_android/theme/app_typography.dart';
import 'package:parley_android/theme/spec/design_spec.dart';
import 'package:parley_android/design_system/ds_text.dart';
import 'package:parley_android/utils/app_routes.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final schemePalette = context.palette;

    return DSPage(
      title: 'Rocketship',
      leading: const BackButton(),
      slivers: [
        SliverToBoxAdapter(
          child: DSGutter(
            child: Padding(
              padding: EdgeInsets.only(
                top: context.design.space.md,
                bottom: context.design.space.xl,
              ),
              child: Row(
                children: [
                  Container(
                    width: context.design.component.leadingSlotSize,
                    height: context.design.component.leadingSlotSize,
                    decoration: BoxDecoration(
                      color: schemePalette.secondary,
                      borderRadius: BorderRadius.circular(
                        context.radiusOf(AppShape.tile),
                      ),
                    ),
                    child: Icon(
                      Icons.rocket_launch_rounded,
                      color: schemePalette.secondaryForeground,
                      size: context.design.component.iconSizeLarge,
                    ),
                  ),
                  SizedBox(width: context.design.space.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Rocketship',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: context.design.type.emphasisWeight,
                          ),
                        ),
                        SizedBox(height: context.design.space.hairline),
                        const DSText(
                          'A premium Flutter boilerplate',
                          role: DSTextRole.bodySupport,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        const SliverToBoxAdapter(
          child: DSSettingsSection(
            eyebrow: 'Build',
            children: [
              DSSettingsRow(label: 'Version', value: '1.0.0'),
              DSSettingsRow(label: 'Framework', value: 'Flutter · Riverpod'),
            ],
          ),
        ),

        SliverToBoxAdapter(child: SizedBox(height: context.design.space.xl)),

        SliverToBoxAdapter(
          child: DSSettingsSection(
            eyebrow: 'Legal',
            children: [
              DSSettingsRow(
                label: 'Open Source Licenses',
                description: 'Acknowledgements for libraries we use',
                onTap: () => context.push(AppRoutes.licenses),
              ),
            ],
          ),
        ),

        SliverToBoxAdapter(
          child: DSGutter(
            child: Padding(
              padding: EdgeInsets.only(top: context.design.space.xxl),
              child: Center(
                child: Text(
                  'Built with care.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: schemePalette.mutedForeground)
                      .tabular,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
