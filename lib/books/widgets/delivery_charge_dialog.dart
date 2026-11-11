import 'package:bbarna/books/viewModel/book_view_model.dart';
import 'package:bbarna/resources/app_tokens.dart';
import 'package:bbarna/utils/helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Popup for the one book-shop setting: the flat delivery charge added to
/// every book order (0 = free delivery).
class DeliveryChargeDialog extends StatefulWidget {
  /// Where the charge is read from and saved to.
  final BookViewModel bookViewModel;
  const DeliveryChargeDialog({required this.bookViewModel, super.key});

  /// Opens the popup.
  static Future<void> show(BuildContext context, BookViewModel bookViewModel) {
    return showDialog<void>(
      context: context,
      builder: (context) => DeliveryChargeDialog(bookViewModel: bookViewModel),
    );
  }

  @override
  State<DeliveryChargeDialog> createState() => _DeliveryChargeDialogState();
}

class _DeliveryChargeDialogState extends State<DeliveryChargeDialog> {
  /// Text of the amount field.
  late final TextEditingController _controller;

  /// True while saving; disables the buttons.
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final double current = widget.bookViewModel.deliveryCharge;
    _controller = TextEditingController(
        text: current == current.roundToDouble()
            ? current.toInt().toString()
            : "$current");
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Saves the typed amount (empty counts as 0) and closes on success.
  Future<void> _save() async {
    final double charge = double.tryParse(_controller.text.trim()) ?? 0;
    setState(() => _isSaving = true);
    final bool success = await widget.bookViewModel.saveDeliveryCharge(charge);
    if (!mounted) return;
    setState(() => _isSaving = false);
    if (success) {
      Helper.showSnackBarMessage(
          msg: "Delivery charge saved", isSuccess: true);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTokens.surface,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd)),
      title: const Text("Delivery charge", style: AppTokens.pageTitle),
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "One flat amount added to every book order, however many "
              "books are in it. Enter 0 for free delivery.",
              style: AppTokens.body,
            ),
            const SizedBox(height: AppTokens.gapMd),
            TextField(
              key: const Key('delivery_charge_field'),
              controller: _controller,
              autofocus: true,
              enabled: !_isSaving,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                    RegExp(r'^\d{0,5}(\.\d{0,2})?')),
              ],
              onSubmitted: (_) => _save(),
              decoration: InputDecoration(
                prefixText: "₹ ",
                hintText: "0",
                isDense: true,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTokens.radiusSm)),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        FilledButton(
          key: const Key('delivery_charge_save'),
          onPressed: _isSaving ? null : _save,
          child: Text(_isSaving ? "Saving…" : "Save"),
        ),
      ],
    );
  }
}
