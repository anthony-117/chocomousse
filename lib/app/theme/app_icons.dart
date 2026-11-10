import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The v1 icon set (Lucide, stroke 1.75), one SVG per icon in `assets/icons/`.
enum AppIcons {
  plus,
  arrowUp('arrow-up'),
  arrowLeft('arrow-left'),
  mic,
  search,
  newChat('new-chat'),
  compass,
  map,
  plane,
  bed,
  car,
  landmark,
  ticket,
  globe,
  sliders,
  sparkles,
  chevronDown('chevron-down'),
  chevronRight('chevron-right'),
  check,
  swap,
  calendar,
  users,
  menu,
  panelLeft('panel-left'),
  paperclip,
  sun,
  bookmark,
  bookmarkFilled('bookmark-filled'),
  pin,
  share,
  x,
  clock,
  wallet,
  more,
  user,
  thumbsUp('thumbs-up'),
  copy,
  filter,
  trash,
  pencil;

  AppIcons([this._file]);

  final String? _file;

  String get asset => 'assets/icons/${_file ?? name}.svg';
}

/// Draws an [AppIcons] icon, tinted with [color] or the surrounding [IconTheme]'s colour.
class AppIcon extends StatelessWidget {
  const AppIcon(this.icon, {this.size = 20, this.color, this.semanticLabel, super.key});

  final AppIcons icon;
  final double size;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? IconTheme.of(context).color ?? DefaultTextStyle.of(context).style.color ?? Colors.black;
    return SvgPicture.asset(
      icon.asset,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(tint, BlendMode.srcIn),
      semanticsLabel: semanticLabel,
      excludeFromSemantics: semanticLabel == null,
    );
  }
}
