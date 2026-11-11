import 'package:bbarna/books/model/book_model.dart';
import 'package:bbarna/books/viewModel/book_view_model.dart';
import 'package:bbarna/core/widgets/form/admin_form_scaffold.dart';
import 'package:bbarna/core/widgets/form/form_action_bar.dart';
import 'package:bbarna/core/widgets/form/form_fields.dart';
import 'package:bbarna/core/widgets/form/form_page_body.dart';
import 'package:bbarna/core/widgets/remove_alert.dart';
import 'package:bbarna/resources/app_tokens.dart';
import 'package:bbarna/resources/constant.dart';
import 'package:bbarna/utils/helper.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

/// The Add/Edit Book page (one responsive form for both; the screens in
/// `books/screen/` just choose the mode).
///
/// Sections: details (name, author, description), price (MRP, selling
/// price, display priority), cover image, and availability (shown in app /
/// in stock).
class BookForm extends StatefulWidget {
  /// The book being edited; null means "Add".
  final BookModel? existing;
  const BookForm({this.existing, super.key});

  /// True when editing an existing book.
  bool get isEdit => existing != null;

  @override
  State<BookForm> createState() => _BookFormState();
}

/// The fields that can carry an inline error.
enum _Field { name, mrp, sellingPrice, priority, image }

class _BookFormState extends State<BookForm> {
  /// Text of the name field.
  final TextEditingController nameController = TextEditingController();

  /// Text of the author field.
  final TextEditingController authorController = TextEditingController();

  /// Text of the description field.
  final TextEditingController descriptionController = TextEditingController();

  /// Text of the MRP field.
  final TextEditingController mrpController = TextEditingController();

  /// Text of the selling price field.
  final TextEditingController sellingPriceController = TextEditingController();

  /// Text of the display priority field.
  final TextEditingController priorityController = TextEditingController();

  /// Newly picked cover (null until one is chosen) and its file name.
  Uint8List? selectedImageBytes;

  /// File name of the newly picked file.
  String imageName = "";

  /// "Show in the app" switch.
  bool willDisplay = true;

  /// "In stock" switch.
  bool inStock = true;

  /// True while saving or deleting; disables every control.
  bool _isSaving = false;

  /// Inline error per field. Filled on a failed submit, then refreshed on
  /// every change so each message disappears as its field is fixed.
  final Map<_Field, String> _errors = <_Field, String>{};

  @override
  void initState() {
    super.initState();
    final BookModel? existing = widget.existing;
    if (existing != null) {
      nameController.text = existing.name;
      authorController.text = existing.author;
      descriptionController.text = existing.description;
      mrpController.text = _moneyText(existing.mrp);
      sellingPriceController.text =
          existing.sellingPrice > 0 ? _moneyText(existing.sellingPrice) : "";
      priorityController.text = existing.displayPriority.toString();
      willDisplay = existing.willDisplay;
      inStock = existing.inStock;
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    authorController.dispose();
    descriptionController.dispose();
    mrpController.dispose();
    sellingPriceController.dispose();
    priorityController.dispose();
    super.dispose();
  }

  /// 499.0 -> "499", 499.5 -> "499.5".
  String _moneyText(double value) =>
      value == value.roundToDouble() ? value.toInt().toString() : "$value";

  // ---- Validation -----------------------------------------------------

  /// Checks every field and returns the problems (empty when valid).
  Map<_Field, String> _validate() {
    final Map<_Field, String> errors = <_Field, String>{};
    if (nameController.text.trim().isEmpty) {
      errors[_Field.name] = "Give the book a name";
    }

    final double? mrp = double.tryParse(mrpController.text.trim());
    if (mrpController.text.trim().isEmpty) {
      errors[_Field.mrp] = "Set the printed price (MRP)";
    } else if (mrp == null || mrp <= 0) {
      errors[_Field.mrp] = "MRP must be more than 0";
    }

    // Optional: empty means "sell at MRP".
    final String sellingText = sellingPriceController.text.trim();
    if (sellingText.isNotEmpty) {
      final double? selling = double.tryParse(sellingText);
      if (selling == null || selling <= 0) {
        errors[_Field.sellingPrice] = "Selling price must be more than 0";
      } else if (mrp != null && selling > mrp) {
        errors[_Field.sellingPrice] = "Selling price can't be above the MRP";
      }
    }

    final String priority = priorityController.text.trim();
    if (priority.isEmpty) {
      errors[_Field.priority] = "Set a display priority";
    } else if (int.tryParse(priority) == null) {
      errors[_Field.priority] = "Priority must be a whole number";
    }

    // A cover is only mandatory when creating: an edit keeps the one the
    // book already has.
    if (!widget.isEdit && selectedImageBytes == null) {
      errors[_Field.image] = "Choose a cover image";
    }
    return errors;
  }

  /// Re-runs validation after an edit, but only once a submit has failed
  /// (so errors never appear while the user is still filling the form).
  void _revalidate() {
    if (_errors.isEmpty) return;
    final Map<_Field, String> fresh = _validate();
    setState(() {
      _errors
        ..clear()
        ..addAll(fresh);
    });
  }

  /// Opens the file picker for an image.
  Future<void> _pickImage() async {
    final FilePickerResult? picked =
        await FilePicker.platform.pickFiles(type: FileType.image);
    if (picked == null || !mounted) return;
    setState(() {
      selectedImageBytes = picked.files.first.bytes;
      imageName = picked.files.first.name;
    });
    _revalidate();
  }

  /// Validates, then creates or updates the book. Closes the page on
  /// success; on failure the view model has already shown why.
  Future<void> _onSubmit(BookViewModel bookViewModel) async {
    final Map<_Field, String> errors = _validate();
    if (errors.isNotEmpty) {
      setState(() {
        _errors
          ..clear()
          ..addAll(errors);
      });
      Helper.showSnackBarMessage(
          msg: errors.length == 1
              ? "Check the highlighted field"
              : "Check the ${errors.length} highlighted fields",
          isSuccess: false);
      return;
    }

    setState(() {
      _errors.clear();
      _isSaving = true;
    });

    final BookModel model = BookModel(
      name: nameController.text.trim(),
      author: authorController.text.trim(),
      description: descriptionController.text.trim(),
      image: widget.existing?.image ?? "",
      mrp: double.parse(mrpController.text.trim()),
      sellingPrice:
          double.tryParse(sellingPriceController.text.trim()) ?? 0,
      inStock: inStock,
      willDisplay: willDisplay,
      displayPriority: int.parse(priorityController.text.trim()),
      timeStamp:
          widget.existing?.timeStamp ?? DateTime.now().millisecondsSinceEpoch,
    );

    final bool success = widget.isEdit
        ? await bookViewModel.updateBook(model, widget.existing!.docId,
            image: selectedImageBytes)
        : await bookViewModel.createBook(model, selectedImageBytes!);

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (success) {
      Helper.showSnackBarMessage(
          msg: widget.isEdit
              ? "Book updated successfully"
              : "Book added successfully",
          isSuccess: true);
      Navigator.pop(context, true);
    }
  }

  /// Asks for confirmation, deletes the book and closes the page.
  void _onDelete(BookViewModel bookViewModel) {
    final BookModel existing = widget.existing!;
    RemoveAlert.showRemoveAlert(
      title: existing.name,
      description: "Are you sure want to delete ?",
      onPressYes: () async {
        Navigator.pop(navigatorKey.currentContext!);
        if (mounted) setState(() => _isSaving = true);
        final bool success = await bookViewModel.deleteBook(existing.docId);
        if (!mounted) return;
        setState(() => _isSaving = false);
        if (success) {
          Helper.showInfoMessage(msg: "Book deleted successfully");
          Navigator.pop(context, true);
        }
      },
    );
  }

  // ---- Layout ---------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return AdminFormScaffold(
      headerTitle: "Books",
      sidebarIndex: bookModuleIndex,
      body: (context, width) => Consumer<BookViewModel>(
        builder: (context, bookViewModel, child) => _page(bookViewModel, width),
      ),
    );
  }

  /// The scrolling form (header + sections) and the action bar.
  Widget _page(BookViewModel bookViewModel, double width) {
    return FormPageBody(
      width: width,
      actionBar: FormActionBar(
        width: width,
        isSaving: _isSaving,
        onDelete: widget.isEdit ? () => _onDelete(bookViewModel) : null,
        deleteTooltip: "Delete book",
        saveKey: const Key('book_save_button'),
        saveLabel: widget.isEdit ? "Update book" : "Save book",
        onSave: () => _onSubmit(bookViewModel),
      ),
      children: [
        FormPageHeader(
          title: widget.isEdit ? "Edit book" : "Add a book",
          subtitle: widget.isEdit
              ? "Update this book's details, price and availability."
              : "Books are sold in the app's Books tab and delivered by you.",
          onBack: _isSaving ? null : () => Navigator.pop(context),
        ),
        const SizedBox(height: AppTokens.gapLg),
        _detailsSection(),
        const SizedBox(height: AppTokens.gapMd),
        _priceSection(width),
        const SizedBox(height: AppTokens.gapMd),
        FormSection(title: "COVER IMAGE", children: [
          FormImagePickerField(
            bytes: selectedImageBytes,
            fileName: imageName,
            existingUrl: widget.existing?.image ?? "",
            error: _errors[_Field.image],
            enabled: !_isSaving,
            onPick: _pickImage,
            onRemove: () => setState(() {
              selectedImageBytes = null;
              imageName = "";
            }),
          ),
        ]),
        const SizedBox(height: AppTokens.gapMd),
        _availabilitySection(),
        const SizedBox(height: AppTokens.gapXl),
      ],
    );
  }

  /// Name, author and description.
  Widget _detailsSection() {
    return FormSection(title: "BOOK DETAILS", children: [
      _textField(
        label: "Book name",
        hint: "e.g. WBCS Prelims Complete Guide",
        controller: nameController,
        error: _errors[_Field.name],
        onChanged: _revalidate,
      ),
      const SizedBox(height: AppTokens.gapMd),
      _textField(
        label: "Author",
        hint: "Author or publisher (optional)",
        controller: authorController,
      ),
      const SizedBox(height: AppTokens.gapMd),
      _textField(
        label: "Description",
        hint: "What is in this book? (optional)",
        controller: descriptionController,
        maxLines: 4,
      ),
    ]);
  }

  /// MRP, selling price and display priority.
  Widget _priceSection(double width) {
    return FormSection(title: "PRICE", children: [
      FormTwoUp(
        width: width,
        left: _textField(
          label: "MRP (₹)",
          hint: "Printed price, e.g. 499",
          controller: mrpController,
          error: _errors[_Field.mrp],
          onChanged: _revalidate,
          money: true,
        ),
        right: _textField(
          label: "Selling price (₹)",
          hint: "Leave empty to sell at MRP",
          controller: sellingPriceController,
          error: _errors[_Field.sellingPrice],
          onChanged: _revalidate,
          money: true,
        ),
      ),
      const SizedBox(height: AppTokens.gapMd),
      _textField(
        label: "Display priority",
        hint: "Lower numbers come first",
        controller: priorityController,
        error: _errors[_Field.priority],
        onChanged: _revalidate,
        wholeNumber: true,
      ),
    ]);
  }

  /// "Show in the app" and "In stock" switches.
  Widget _availabilitySection() {
    return FormSection(title: "AVAILABILITY", children: [
      FormToggleRow(
        title: "Show in the app",
        subtitle: "Hidden books stay here but students never see them.",
        value: willDisplay,
        onChanged:
            _isSaving ? null : (value) => setState(() => willDisplay = value),
      ),
      const FormToggleDivider(),
      FormToggleRow(
        title: "In stock",
        subtitle:
            "Students can see an out-of-stock book but can't add it to the cart.",
        value: inStock,
        onChanged:
            _isSaving ? null : (value) => setState(() => inStock = value),
      ),
    ]);
  }

  /// A [FormTextField] configured the way this form's fields need:
  /// [wholeNumber] allows digits only, [money] digits with up to two
  /// decimals.
  Widget _textField({
    required String label,
    required String hint,
    required TextEditingController controller,
    int maxLines = 1,
    String? error,
    VoidCallback? onChanged,
    bool wholeNumber = false,
    bool money = false,
  }) {
    return FormTextField(
      label: label,
      hint: hint,
      controller: controller,
      maxLines: maxLines,
      error: error,
      onChanged: onChanged,
      labelStyle: AppTokens.navItemSelected.copyWith(fontSize: 12.5),
      keyboardType: money
          ? const TextInputType.numberWithOptions(decimal: true)
          : wholeNumber
              ? TextInputType.number
              : TextInputType.text,
      inputFormatters: [
        if (wholeNumber) FilteringTextInputFormatter.digitsOnly,
        if (money)
          FilteringTextInputFormatter.allow(RegExp(r'^\d{0,7}(\.\d{0,2})?')),
      ],
    );
  }
}
