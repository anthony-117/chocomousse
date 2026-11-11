import 'dart:math' as math;

import 'package:chocomousse/app/theme/app_text.dart';
import 'package:chocomousse/app/theme/palette.dart';
import 'package:chocomousse/app/theme/tokens.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

enum PinKind { hotel, place, event, car, planDay }

/// One pin: a card, or an item of a plan's day ([number] is the day).
@immutable
class MapPin {
  const MapPin({
    required this.id,
    required this.lat,
    required this.lng,
    required this.kind,
    required this.label,
    this.approximate = false,
    this.number,
  });

  final String id;
  final double lat;
  final double lng;
  final PinKind kind;
  final String label;

  /// At the city centre, not the place itself: drawn hollow.
  final bool approximate;
  final int? number;
}

/// The box the pins are drawn in: their bounds with 12 % padding, and at least 0.01° each way.
@immutable
class PinBounds {
  const PinBounds(this.minLat, this.maxLat, this.minLng, this.maxLng);

  factory PinBounds.of(List<MapPin> pins) {
    var minLat = pins.map((p) => p.lat).reduce(math.min);
    var maxLat = pins.map((p) => p.lat).reduce(math.max);
    var minLng = pins.map((p) => p.lng).reduce(math.min);
    var maxLng = pins.map((p) => p.lng).reduce(math.max);
    double grow(double span) => math.max(span, minSpan);
    final latSpan = grow(maxLat - minLat);
    final lngSpan = grow(maxLng - minLng);
    final midLat = (minLat + maxLat) / 2;
    final midLng = (minLng + maxLng) / 2;
    minLat = midLat - latSpan / 2 * (1 + 2 * padding);
    maxLat = midLat + latSpan / 2 * (1 + 2 * padding);
    minLng = midLng - lngSpan / 2 * (1 + 2 * padding);
    maxLng = midLng + lngSpan / 2 * (1 + 2 * padding);
    return PinBounds(minLat, maxLat, minLng, maxLng);
  }

  static const padding = 0.12;
  static const minSpan = 0.01;

  final double minLat;
  final double maxLat;
  final double minLng;
  final double maxLng;

  /// Equirectangular: longitude left to right, latitude top to bottom.
  Offset project(double lat, double lng, Size size) =>
      Offset((lng - minLng) / (maxLng - minLng) * size.width, (maxLat - lat) / (maxLat - minLat) * size.height);

  /// Kilometres across the box, at its middle latitude.
  double widthKm() => (maxLng - minLng) * 111.32 * math.cos((minLat + maxLat) / 2 * math.pi / 180);
}

/// A pin map without tiles (research R-7): the pins by kind over a plain box, a scale bar, and the pins listed under
/// it. A tap on a pin or a row calls [onSelect].
class PinPreview extends StatelessWidget {
  const PinPreview({required this.pins, required this.onSelect, this.height = 260, super.key});

  final List<MapPin> pins;
  final ValueChanged<String> onSelect;
  final double height;

  static Color colorOf(PinKind kind, AppPalette palette) => switch (kind) {
    PinKind.hotel => palette.brandPrimary,
    PinKind.place => palette.statusSuccess,
    PinKind.event => palette.brandAccent,
    PinKind.car => palette.textSecondary,
    PinKind.planDay => palette.textPrimary,
  };

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    if (pins.isEmpty) return const SizedBox.shrink();
    final bounds = PinBounds.of(pins);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: SizedBox(
            height: height,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size = Size(constraints.maxWidth, height);
                return GestureDetector(
                  onTapUp: (details) {
                    final hit = _nearest(details.localPosition, bounds, size);
                    if (hit != null) onSelect(hit.id);
                  },
                  child: CustomPaint(
                    size: size,
                    painter: _PinPainter(pins: pins, bounds: bounds, palette: palette),
                  ),
                );
              },
            ),
          ),
        ),
        if (pins.any((p) => p.approximate)) ...[
          const SizedBox(height: AppSpacing.sm),
          Text('Some places show the city centre', style: AppText.small.copyWith(color: palette.textSecondary)),
        ],
        const SizedBox(height: AppSpacing.sm),
        for (final pin in pins)
          InkWell(
            onTap: () => onSelect(pin.id),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Row(
                children: [
                  _Dot(color: colorOf(pin.kind, palette), hollow: pin.approximate, number: pin.number),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(pin.label, style: AppText.small.copyWith(color: palette.textPrimary)),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  MapPin? _nearest(Offset at, PinBounds bounds, Size size) {
    MapPin? best;
    var bestDistance = 20.0;
    for (final pin in pins) {
      final d = (bounds.project(pin.lat, pin.lng, size) - at).distance;
      if (d <= bestDistance) {
        best = pin;
        bestDistance = d;
      }
    }
    return best;
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color, required this.hollow, this.number});

  final Color color;
  final bool hollow;
  final int? number;

  @override
  Widget build(BuildContext context) => Container(
    width: 18,
    height: 18,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: hollow ? Colors.transparent : color,
      shape: BoxShape.circle,
      border: Border.all(color: color, width: 2),
    ),
    child: number == null
        ? null
        : Text('$number', style: AppText.micro.copyWith(color: context.palette.bgSurface, letterSpacing: 0)),
  );
}

class _PinPainter extends CustomPainter {
  _PinPainter({required this.pins, required this.bounds, required this.palette});

  final List<MapPin> pins;
  final PinBounds bounds;
  final AppPalette palette;

  static const _nice = [0.1, 0.2, 0.5, 1.0, 2.0, 5.0, 10.0, 20.0, 50.0, 100.0, 200.0, 500.0, 1000.0];

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = palette.bgSubtle);
    for (final pin in pins) {
      final at = bounds.project(pin.lat, pin.lng, size);
      final color = PinPreview.colorOf(pin.kind, palette);
      if (pin.approximate) {
        canvas.drawCircle(
          at,
          7,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      } else {
        canvas
          ..drawCircle(at, 8, Paint()..color = palette.bgSurface)
          ..drawCircle(at, 6, Paint()..color = color);
      }
      final number = pin.number;
      if (number != null && !pin.approximate) {
        final text = TextPainter(
          text: TextSpan(
            text: '$number',
            style: TextStyle(fontSize: 8, color: palette.bgSurface),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        text.paint(canvas, at - Offset(text.width / 2, text.height / 2));
      }
    }

    // The scale bar: the longest round distance that fits a quarter of the width.
    final kmPerPx = bounds.widthKm() / size.width;
    final km = _nice.lastWhere((d) => d / kmPerPx <= size.width / 4, orElse: () => _nice.first);
    final length = km / kmPerPx;
    final y = size.height - 12;
    final paint = Paint()
      ..color = palette.textSecondary
      ..strokeWidth = 2;
    canvas.drawLine(Offset(12, y), Offset(12 + length, y), paint);
    final label = TextPainter(
      text: TextSpan(
        text: km < 1 ? '${(km * 1000).round()} m' : '${km.round()} km',
        style: TextStyle(fontSize: 10, color: palette.textSecondary),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    label.paint(canvas, Offset(12, y - label.height - 2));
  }

  @override
  bool shouldRepaint(_PinPainter oldDelegate) => !listEquals(oldDelegate.pins, pins) || oldDelegate.palette != palette;
}
