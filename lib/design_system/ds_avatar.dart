// ds-tier: 1 — atom

import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:parley_android/design_system/ds_component_style.dart';
import 'package:parley_android/design_system/ds_image.dart';
import 'package:parley_android/design_system/ds_pressable.dart';
import 'package:parley_android/design_system/ds_skeleton.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

enum DSAvatarSize { sm, md, lg, xl }

/// How an avatar looks, at every layer of the resolution chain.
@immutable
class DSAvatarStyle extends DSComponentStyle<DSAvatarStyle> {
  const DSAvatarStyle({
    this.size,
    this.shape,
    this.ringWidth,
    this.ringColor,
    this.initialsStyle,
    this.fallbackIcon,
    this.iconSize,
  });

  final double? size;
  final AppShape? shape;

  /// The ring an overlapping stack draws, in the colour *behind the group*.
  final double? ringWidth;
  final Color? ringColor;

  final TextStyle? initialsStyle;
  final IconData? fallbackIcon;
  final double? iconSize;

  @override
  DSAvatarStyle merge(DSAvatarStyle? other) {
    if (other == null) return this;
    return DSAvatarStyle(
      size: other.size ?? size,
      shape: other.shape ?? shape,
      ringWidth: other.ringWidth ?? ringWidth,
      ringColor: other.ringColor ?? ringColor,
      initialsStyle: other.initialsStyle ?? initialsStyle,
      fallbackIcon: other.fallbackIcon ?? fallbackIcon,
      iconSize: other.iconSize ?? iconSize,
    );
  }

  @override
  DSAvatarStyle copyWith({
    double? size,
    AppShape? shape,
    double? ringWidth,
    Color? ringColor,
    TextStyle? initialsStyle,
    IconData? fallbackIcon,
    double? iconSize,
  }) => DSAvatarStyle(
    size: size ?? this.size,
    shape: shape ?? this.shape,
    ringWidth: ringWidth ?? this.ringWidth,
    ringColor: ringColor ?? this.ringColor,
    initialsStyle: initialsStyle ?? this.initialsStyle,
    fallbackIcon: fallbackIcon ?? this.fallbackIcon,
    iconSize: iconSize ?? this.iconSize,
  );

  @override
  DSAvatarStyle lerp(DSAvatarStyle? other, double t) {
    if (other == null) return this;
    return DSAvatarStyle(
      // Three fields with no midpoint: a corner role, a glyph and a strategy.
      shape: t < 0.5 ? shape : other.shape,
      fallbackIcon: t < 0.5 ? fallbackIcon : other.fallbackIcon,
      size: lerpDouble(size, other.size, t),
      ringWidth: lerpDouble(ringWidth, other.ringWidth, t),
      ringColor: Color.lerp(ringColor, other.ringColor, t),
      initialsStyle: TextStyle.lerp(initialsStyle, other.initialsStyle, t),
      iconSize: lerpDouble(iconSize, other.iconSize, t),
    );
  }

  static DSAvatarStyle resolve(
    BuildContext context, [
    DSAvatarSize size = DSAvatarSize.md,
    DSAvatarStyle? own,
  ]) {
    final design = context.design;
    final component = design.component;
    final palette = context.palette;
    final text = Theme.of(context).textTheme;

    final (double box, TextStyle? initials, double glyph) = switch (size) {
      DSAvatarSize.sm => (
        component.avatarSizeSm,
        text.labelSmall,
        component.iconSizeMicro,
      ),
      DSAvatarSize.md => (
        component.avatarSizeMd,
        text.labelMedium,
        component.iconSizeSmall,
      ),
      DSAvatarSize.lg => (
        component.avatarSizeLg,
        text.titleSmall,
        component.iconSizeInline,
      ),
      DSAvatarSize.xl => (
        component.avatarSizeXl,
        text.titleLarge,
        component.iconSizeLarge,
      ),
    };

    return resolveStyle(
      context: context,
      specDefaults: DSAvatarStyle(
        size: box,
        shape: component.wellShape,
        ringWidth: component.avatarRing,
        ringColor: palette.card,
        initialsStyle: initials?.copyWith(
          fontWeight: context.design.type.labelWeight,
        ),
        fallbackIcon: Icons.person,
        iconSize: glyph,
      ),
      own: own,
    );
  }
}

/// What a [DSAvatarGroup] tells the avatars inside it.
@immutable
class DSAvatarGroupScope extends InheritedWidget {
  const DSAvatarGroupScope({
    super.key,
    required this.ringColor,
    required this.size,
    required super.child,
  });

  /// The ground the stack is drawn on. The ring has to match whatever is
  /// behind the group, which the caller knows and an avatar does not.
  final Color ringColor;

  final DSAvatarSize size;

  static DSAvatarGroupScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DSAvatarGroupScope>();

  @override
  bool updateShouldNotify(DSAvatarGroupScope old) =>
      ringColor != old.ringColor || size != old.size;
}

/// A person or an entity's likeness.
///
/// See `docs/plans/28-ds-avatar-badge-well.plan.md`. The fallback is a chain,
/// not a flag: image, then initials, then an icon — and the colour behind the
/// initials is the palette's `secondary` well, the same fixed colour on every
/// avatar. [identity] is kept on the constructor for callers that still pass
/// a name or id, but the 15-role palette has one well, not a colour per
/// person.
///
/// A 404 on an avatar URL is routine, so an image that fails falls through the
/// chain rather than showing a broken box.
class DSAvatar extends StatelessWidget {
  const DSAvatar({
    super.key,
    this.imageUrl,
    this.initials,
    this.identity,
    this.fallbackIcon,
    this.fallback,
    this.size = DSAvatarSize.md,
    this.semanticLabel,
    this.onTap,
    this.badgeSlot,
    this.showRing = false,
    this.style,
  });

  /// An avatar from a full name: the first letters of the first two words,
  /// and the name itself as the identity carried through for callers that
  /// still key off it, though the fill colour itself is the fixed
  /// `secondary` well.
  factory DSAvatar.fromName({
    Key? key,
    required String name,
    String? imageUrl,
    DSAvatarSize size = DSAvatarSize.md,
    VoidCallback? onTap,
    Widget? badgeSlot,
    DSAvatarStyle? style,
  }) {
    final parts = name.trim().split(RegExp(r'\s+'));
    final initials = parts.length >= 2
        ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
        : parts.isNotEmpty && parts[0].isNotEmpty
        ? parts[0][0].toUpperCase()
        : '';
    return DSAvatar(
      key: key,
      imageUrl: imageUrl,
      initials: initials,
      identity: name,
      semanticLabel: name,
      size: size,
      onTap: onTap,
      badgeSlot: badgeSlot,
      style: style,
    );
  }

  final String? imageUrl;
  final String? initials;

  /// The string the colour is derived from — a name, an id, an email.
  final String? identity;

  final IconData? fallbackIcon;

  /// Replaces the whole chain's last step.
  final Widget? fallback;

  final DSAvatarSize size;
  final String? semanticLabel;
  final VoidCallback? onTap;

  /// A [DSDot], per 00b's naming rule for a slot with a shipped occupant.
  final Widget? badgeSlot;

  /// Whether to draw the ring. Set by [DSAvatarGroup] for its children; a lone
  /// avatar has nothing to be separated from.
  final bool showRing;

  final DSAvatarStyle? style;

  @override
  Widget build(BuildContext context) {
    final group = DSAvatarGroupScope.maybeOf(context);
    final resolved = DSAvatarStyle.resolve(context, group?.size ?? size, style);
    final palette = context.palette;
    final fill = palette.secondary;
    final foreground = palette.secondaryForeground;

    Widget content = _fallback(resolved, foreground);
    if (imageUrl != null) {
      // Both waiting states are the initials, not a shimmer: the name is known
      // before the picture is, and a bone where a face goes reads as a broken
      // row rather than a loading one. The clip and the fill are the
      // container's below, so the image declines both.
      final fallback = _fallback(resolved, foreground);
      content = DSImage.network(
        imageUrl!,
        fit: BoxFit.cover,
        width: resolved.size,
        height: resolved.size,
        decorative: true,
        placeholder: fallback,
        failure: fallback,
        style: DSImageStyle(background: fill, radius: BorderRadius.zero),
      );
    }

    Widget avatar = Container(
      width: resolved.size,
      height: resolved.size,
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      decoration: ShapeDecoration(
        color: fill,
        shape: context.shapeOf(resolved.shape!),
      ),
      child: content,
    );

    if (showRing || group != null) {
      avatar = Container(
        decoration: ShapeDecoration(
          shape: CircleBorder(
            side: BorderSide(
              color: group?.ringColor ?? resolved.ringColor!,
              width: resolved.ringWidth!,
            ),
          ),
        ),
        child: avatar,
      );
    }

    if (badgeSlot != null) {
      avatar = Stack(
        clipBehavior: Clip.none,
        children: [
          avatar,
          PositionedDirectional(bottom: 0, end: 0, child: badgeSlot!),
        ],
      );
    }

    if (onTap != null) {
      avatar = DSPressable(
        focusShape: const CircleBorder(),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: avatar,
        ),
      );
    }

    return Semantics(
      container: true,
      label: semanticLabel,
      image: imageUrl != null,
      button: onTap != null,
      onTap: onTap,
      excludeSemantics: true,
      child: avatar,
    );
  }

  Widget _fallback(DSAvatarStyle resolved, Color foreground) {
    if (fallback != null) return fallback!;
    if (initials != null && initials!.isNotEmpty) {
      return Text(
        initials!,
        style: resolved.initialsStyle?.copyWith(
          color: foreground,
          // ui-lint: allow hardcoded-box-size — a line height, not a box
          // height: initials sit on their own baseline inside a circle.
          height: 1,
        ),
      );
    }
    return Icon(
      fallbackIcon ?? resolved.fallbackIcon,
      size: resolved.iconSize,
      color: foreground,
    );
  }
}

/// A stack of overlapping avatars with a "+n" tail.
///
/// New in plan 28. It appears in every collaboration surface, and building it
/// by hand gets the overlap direction, the ring colour and the overflow count
/// wrong — the ring in particular, which has to be painted in the colour
/// *behind the group*. A group on a card, on a sheet and on the page ground
/// need three different rings, which is why [backgroundColor] survives as the
/// kit's one remaining `Color?`: it names the ground the stack is drawn on
/// rather than a tint the component picks.
class DSAvatarGroup extends StatelessWidget {
  const DSAvatarGroup({
    super.key,
    required this.children,
    this.maxVisible = 3,
    this.size = DSAvatarSize.md,
    this.backgroundColor,
    this.semanticLabel,
  });

  final List<Widget> children;
  final int maxVisible;
  final DSAvatarSize size;
  final Color? backgroundColor;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final resolved = DSAvatarStyle.resolve(context, size);
    final palette = context.palette;
    final space = context.design.space;
    final visible = children.take(maxVisible).toList();
    final hidden = children.length - visible.length;
    final overlap = space.xs;

    return Semantics(
      container: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: DSAvatarGroupScope(
        ringColor: backgroundColor ?? palette.card,
        size: size,
        child: _stack(context, resolved, palette, visible, hidden, overlap),
      ),
    );
  }

  /// Overlapping avatars, laid out by position rather than by negative
  /// padding: `RenderPadding` asserts on a negative inset, so the overlap has
  /// to come from where each avatar starts rather than from a gap that owes
  /// space back.
  Widget _stack(
    BuildContext context,
    DSAvatarStyle resolved,
    Palette palette,
    List<Widget> visible,
    int hidden,
    double overlap,
  ) {
    final box = resolved.size!;
    final step = box - overlap;
    final count = visible.length + (hidden > 0 ? 1 : 0);
    if (count == 0) return const SizedBox.shrink();

    return SizedBox(
      width: step * (count - 1) + box,
      height: box,
      child: Stack(
        children: [
          for (var i = 0; i < visible.length; i++)
            PositionedDirectional(start: i * step, child: visible[i]),
          if (hidden > 0)
            PositionedDirectional(
              start: visible.length * step,
              child: Container(
                width: box,
                height: box,
                alignment: Alignment.center,
                decoration: ShapeDecoration(
                  color: palette.muted,
                  shape: CircleBorder(
                    side: BorderSide(
                      color: backgroundColor ?? palette.card,
                      width: resolved.ringWidth!,
                    ),
                  ),
                ),
                child: Text(
                  '+$hidden',
                  style: resolved.initialsStyle?.copyWith(
                    color: palette.mutedForeground,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// An avatar's shape while its image is in flight.
class DSAvatarSkeleton extends StatelessWidget {
  const DSAvatarSkeleton({super.key, this.size = DSAvatarSize.md});

  final DSAvatarSize size;

  @override
  Widget build(BuildContext context) {
    final resolved = DSAvatarStyle.resolve(context, size);
    return DSSkeleton(
      child: Container(
        width: resolved.size,
        height: resolved.size,
        decoration: ShapeDecoration(
          color: context.palette.muted,
          shape: context.shapeOf(resolved.shape!),
        ),
      ),
    );
  }
}
