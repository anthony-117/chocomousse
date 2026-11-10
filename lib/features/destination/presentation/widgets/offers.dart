import 'package:chocomousse/app/theme/palette.dart';
import 'package:chocomousse/app/theme/tokens.dart';
import 'package:chocomousse/core/network/api_client.dart';
import 'package:chocomousse/features/destination/presentation/widgets/common.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// Pieces shared by the hotel and car screens: prices, photos, scores, tags, notes and paging.

/// An amount in a currency, without cents for large amounts ("$812", "$1,108").
String formatMoney(num amount, String currency) =>
    NumberFormat.simpleCurrency(name: currency, decimalDigits: 0).format(amount);

String formatReviews(int count) => count == 1 ? '1 review' : '${NumberFormat.decimalPattern().format(count)} reviews';

/// A photo from a listing (a hotel, a car), or the gradient placeholder when there is none or it fails to load.
class OfferPhoto extends StatelessWidget {
  const OfferPhoto({required this.url, this.fit = BoxFit.cover, super.key});

  final String? url;

  /// Hotel photos fill their box; car photos are cut-outs and fit inside it.
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final placeholder = DecoratedBox(
      decoration: BoxDecoration(gradient: photoGradient(context)),
      child: Center(child: Icon(Icons.image_outlined, color: context.palette.brandOnPrimary, size: 32)),
    );
    final src = url;
    if (src == null) return placeholder;
    return Image.network(
      src,
      fit: fit,
      // Booking.com's image server may not allow the web build to read the image; a plain <img> still shows it.
      webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
      errorBuilder: (_, _, _) => placeholder,
    );
  }
}

/// Indigo score badge, as on Booking.com.
class ReviewScore extends StatelessWidget {
  const ReviewScore(this.score, {super.key});

  final double score;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: context.palette.brandPrimary, borderRadius: BorderRadius.circular(AppRadius.sm)),
      child: Text(
        score.toStringAsFixed(1),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: context.palette.brandOnPrimary),
      ),
    );
  }
}

/// Green pill such as "Free cancellation".
class OfferTag extends StatelessWidget {
  const OfferTag({required this.icon, required this.label, super.key});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: context.palette.statusSuccess.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: context.palette.statusSuccess),
          const SizedBox(width: AppSpacing.xs),
          Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: context.palette.statusSuccess)),
        ],
      ),
    );
  }
}

/// "today at 09:40", or "1 Mar at 09:40" for another day, in the device's time.
String describeCheckedAt(DateTime at, {DateTime? now}) {
  final today = now ?? DateTime.now();
  final sameDay = at.year == today.year && at.month == today.month && at.day == today.day;
  return '${sameDay ? 'today' : DateFormat('d MMM').format(at)} at ${DateFormat('HH:mm').format(at)}';
}

/// Amber note for warnings such as "showing saved prices" (hotels H4, cars).
class OfferWarning extends StatelessWidget {
  const OfferWarning(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: context.palette.statusWarning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, size: 18, color: context.palette.statusWarning),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.palette.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

/// The API's reason for a 400 (Problem Details `errors`), or the usual wording for other failures.
String describeProblem(Object error) {
  if (error is DioException && error.response?.statusCode == 400) {
    final data = error.response?.data;
    final errors = data is Map<String, dynamic> ? data['errors'] : null;
    if (errors is Map<String, dynamic>) {
      for (final messages in errors.values) {
        if (messages is List && messages.isNotEmpty) return '${messages.first}';
      }
    }
  }
  return describeApiError(error);
}

class Pager extends StatelessWidget {
  const Pager({required this.page, required this.totalPages, required this.onPage, super.key});

  final int page;
  final int totalPages;
  final ValueChanged<int> onPage;

  @override
  Widget build(BuildContext context) {
    // The theme's wide button padding doesn't fit three items on a phone.
    final compact = OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg));
    return Row(
      children: [
        OutlinedButton(
          style: compact,
          onPressed: page > 1 ? () => onPage(page - 1) : null,
          child: const Text('Previous'),
        ),
        Expanded(
          child: Text(
            'Page $page of $totalPages',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ),
        OutlinedButton(
          style: compact,
          onPressed: page < totalPages ? () => onPage(page + 1) : null,
          child: const Text('Next'),
        ),
      ],
    );
  }
}
