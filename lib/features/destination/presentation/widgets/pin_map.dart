import 'dart:math' as math;

import 'package:chocomousse/app/theme/tokens.dart';
import 'package:chocomousse/features/destination/data/models.dart';
import 'package:flutter/material.dart';

/// Lightweight map preview: places plotted around the city centre on a soft canvas.
/// Replaced by Google Maps once a Maps key is configured (see the Sprint 1 notes).
class PinMap extends StatelessWidget {
  const PinMap({required this.centerLat, required this.centerLng, required this.places, this.height = 220, super.key});

  final double centerLat;
  final double centerLng;
  final List<Place> places;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Map preview with ${places.length} places',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.lg + 4),
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: CustomPaint(painter: _PinMapPainter(centerLat, centerLng, places)),
        ),
      ),
    );
  }
}

class _PinMapPainter extends CustomPainter {
  _PinMapPainter(this.centerLat, this.centerLng, this.places);

  final double centerLat;
  final double centerLng;
  final List<Place> places;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = AppColors.canvas);

    final grid = Paint()
      ..color = AppColors.border
      ..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += 40) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (var y = 0.0; y < size.height; y += 40) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    // Fit every point (and the centre) in the box with padding; longitude scaled by latitude.
    final lngScale = math.cos(centerLat * math.pi / 180);
    final points = [(centerLat, centerLng), ...places.map((p) => (p.lat, p.lng))];
    var span = 0.01;
    for (final (lat, lng) in points) {
      span = math.max(span, math.max((lat - centerLat).abs(), ((lng - centerLng) * lngScale).abs()));
    }
    const padding = 24.0;
    final half = math.min(size.width, size.height) / 2 - padding;
    Offset project(double lat, double lng) => Offset(
      size.width / 2 + (lng - centerLng) * lngScale / span * half,
      size.height / 2 - (lat - centerLat) / span * half,
    );

    canvas.drawCircle(project(centerLat, centerLng), 6, Paint()..color = AppColors.text.withValues(alpha: 0.25));

    for (final place in places) {
      final at = project(place.lat, place.lng);
      final color = place.category == PlaceCategory.restaurant ? AppColors.accent : AppColors.primary;
      canvas
        ..drawCircle(at, 9, Paint()..color = AppColors.surface)
        ..drawCircle(at, 6, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_PinMapPainter old) =>
      old.places != places || old.centerLat != centerLat || old.centerLng != centerLng;
}
