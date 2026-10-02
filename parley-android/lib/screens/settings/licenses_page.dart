import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:parley_android/design_system/design_system.dart';
import 'package:parley_android/theme/spec/design_spec.dart';
import 'package:parley_android/utils/app_routes.dart';
import 'package:parley_android/utils/error_copy.dart';

/// One package's worth of license text, grouped the way [LicenseRegistry]
/// reports it — the same source Flutter's stock `LicensePage` reads.
class PackageLicense {
  const PackageLicense({required this.package, required this.paragraphs});

  final String package;
  final List<LicenseParagraph> paragraphs;
}

Future<List<PackageLicense>> _loadPackageLicenses() async {
  final byPackage = <String, List<LicenseParagraph>>{};
  await for (final entry in LicenseRegistry.licenses) {
    for (final package in entry.packages) {
      byPackage.putIfAbsent(package, () => <LicenseParagraph>[]);
      byPackage[package]!.addAll(entry.paragraphs);
    }
  }
  final packages = [
    for (final e in byPackage.entries)
      PackageLicense(package: e.key, paragraphs: e.value),
  ]..sort((a, b) => a.package.toLowerCase().compareTo(b.package.toLowerCase()));
  return packages;
}

/// The **Collection** archetype — every open-source package this build
/// ships with, one row each.
///
/// Reskins `showLicensePage`, Flutter's own stock screen: it reads the same
/// [LicenseRegistry] this does, but draws with Material's unthemed defaults
/// rather than this kit's — an unstyled screen a user reaches from Settings
/// and notices as an unstyled screen. `LicenseRegistry.licenses` is a stream
/// rather than a list because packages register their license lazily, so the
/// four states apply here exactly as they would to a network call: the
/// stream can still be draining (loading), can finish with nothing in it
/// (empty, unlikely but not impossible in a stripped build), or a package's
/// entry can throw while enumerating its own text (error).
class LicensesPage extends StatefulWidget {
  const LicensesPage({super.key});

  @override
  State<LicensesPage> createState() => _LicensesPageState();
}

class _LicensesPageState extends State<LicensesPage> {
  late Future<List<PackageLicense>> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadPackageLicenses();
  }

  void _retry() => setState(() => _future = _loadPackageLicenses());

  @override
  Widget build(BuildContext context) {
    return DSPage(
      title: 'Licenses',
      leading: const BackButton(),
      slivers: [
        FutureBuilder<List<PackageLicense>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return SliverToBoxAdapter(
                child: DSGutter(
                  child: Column(
                    children: [
                      for (var i = 0; i < 8; i++)
                        const DSListTileSkeleton(showSubtitle: true),
                    ],
                  ),
                ),
              );
            }

            if (snapshot.hasError) {
              final copy = errorCopyFor(snapshot.error!);
              return SliverFillRemaining(
                hasScrollBody: false,
                child: DSErrorState(
                  message: copy.message,
                  icon: copy.icon,
                  actionLabel: copy.actionLabel,
                  onRetry: _retry,
                ),
              );
            }

            final packages = snapshot.data!;
            if (packages.isEmpty) {
              return const SliverFillRemaining(
                hasScrollBody: false,
                child: DSEmptyState(
                  title: 'Nothing to show',
                  message:
                      'No open-source licenses were bundled with this build.',
                  icon: Icons.description_outlined,
                ),
              );
            }

            return DSGutter.sliver(
              sliver: SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.only(bottom: context.design.space.xl),
                  child: DSSection(
                    label: '${packages.length} packages',
                    child: DSCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          for (final package in packages)
                            DSListTile(
                              title: package.package,
                              subtitle: package.paragraphs.length == 1
                                  ? '1 license'
                                  : '${package.paragraphs.length} licenses',
                              divider: package != packages.last,
                              onTap: () => context.push(
                                AppRoutes.licenseDetail,
                                extra: package,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
