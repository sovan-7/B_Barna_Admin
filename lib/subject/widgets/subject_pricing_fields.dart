import 'package:bbarna/core/widgets/form/form_fields.dart';
import 'package:bbarna/resources/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Grey note under the price fields that spells out what students will
/// pay, e.g. "Students pay ₹450.00 — 10% off ₹500.00."
///
/// Hidden while either field is not a valid number, the price is not
/// positive, or the selling price is above the price.
class SubjectPriceSummary extends StatelessWidget {
  /// Raw text of the "Price" field.
  final String priceText;

  /// Raw text of the "Selling price" field.
  final String sellingPriceText;

  const SubjectPriceSummary({
    required this.priceText,
    required this.sellingPriceText,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final double? price = double.tryParse(priceText.trim());
    final double? selling = double.tryParse(sellingPriceText.trim());
    if (price == null || selling == null || price <= 0 || selling > price) {
      return const SizedBox.shrink();
    }

    final bool discounted = selling < price;
    return _NoteBox(
      icon: Icons.sell_outlined,
      text: discounted
          ? "Students pay ₹${selling.toStringAsFixed(2)} — "
              "${(((price - selling) / price) * 100).round()}% off ₹${price.toStringAsFixed(2)}."
          : "Students pay ₹${selling.toStringAsFixed(2)}. No discount is shown.",
    );
  }
}

/// Grey note under the coupon fields explaining the two non-obvious rules:
/// the discount is a flat ₹ amount (as the student app applies it), and
/// clearing every field removes an existing coupon.
class CouponNote extends StatelessWidget {
  const CouponNote({super.key});

  @override
  Widget build(BuildContext context) {
    return const _NoteBox(
      icon: Icons.info_outline,
      text: "A flat ₹ amount off the selling price, not a percentage. "
          "The coupon works up to the end of its valid-till date. "
          "Leave all fields blank to remove an existing coupon.",
    );
  }
}

/// A grey rounded box with an icon and a line of bold grey text, spaced
/// below the field above it.
class _NoteBox extends StatelessWidget {
  final IconData icon;
  final String text;

  const _NoteBox({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppTokens.gapMd),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppTokens.surfaceMuted,
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          border: Border.all(color: AppTokens.hairline),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: AppTokens.inkMuted),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppTokens.inkMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Valid till" for the coupon: a tappable box showing the chosen date
/// (or a prompt), with a clear (×) button once a date is set.
class CouponValidTillField extends StatelessWidget {
  static final DateFormat _format = DateFormat("d MMM yyyy");

  /// The last day the coupon works, or null.
  final DateTime? date;

  /// Validation message; turns the border red.
  final String? error;

  /// False while saving.
  final bool enabled;

  /// Opens the date picker.
  final VoidCallback onTap;

  /// Clears the date.
  final VoidCallback onClear;

  const CouponValidTillField({
    required this.date,
    required this.error,
    required this.enabled,
    required this.onTap,
    required this.onClear,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final String? error = this.error;
    final DateTime? date = this.date;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Valid till", style: AppTokens.fieldLabel),
        const SizedBox(height: 6),
        Material(
          color: AppTokens.surface,
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          child: InkWell(
            key: const Key('subject_coupon_valid_till'),
            onTap: enabled ? onTap : null,
            borderRadius: BorderRadius.circular(AppTokens.radiusMd),
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
              constraints: const BoxConstraints(minHeight: 46),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                border: Border.all(
                    color:
                        error != null ? AppTokens.danger : AppTokens.hairline),
              ),
              child: Row(
                children: [
                  const Icon(Icons.event_outlined,
                      size: 16, color: AppTokens.inkFaint),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      date == null
                          ? "Pick the last day this coupon works"
                          : _format.format(date),
                      style: date == null
                          ? const TextStyle(
                              fontSize: 13, color: AppTokens.inkFaint)
                          : const TextStyle(
                              fontSize: 13.5, color: AppTokens.ink),
                    ),
                  ),
                  if (date != null)
                    IconButton(
                      tooltip: "Clear date",
                      onPressed: enabled ? onClear : null,
                      icon: const Icon(Icons.close, size: 16),
                      color: AppTokens.inkMuted,
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ),
          ),
        ),
        if (error != null) FieldErrorText(error),
      ],
    );
  }
}
