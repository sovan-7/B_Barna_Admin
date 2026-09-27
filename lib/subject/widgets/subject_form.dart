import 'package:bbarna/core/widgets/form/admin_form_scaffold.dart';
import 'package:bbarna/core/widgets/form/form_action_bar.dart';
import 'package:bbarna/core/widgets/form/form_fields.dart';
import 'package:bbarna/core/widgets/form/form_page_body.dart';
import 'package:bbarna/core/widgets/remove_alert.dart';
import 'package:bbarna/core/widgets/valid_till_picker.dart';
import 'package:bbarna/course/model/course_model.dart';
import 'package:bbarna/course/viewModel/course_view_model.dart';
import 'package:bbarna/resources/app_tokens.dart';
import 'package:bbarna/resources/constant.dart';
import 'package:bbarna/subject/model/subject_model.dart';
import 'package:bbarna/subject/viewModel/subject_view_model.dart';
import 'package:bbarna/utils/formatters.dart';
import 'package:bbarna/utils/helper.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

/// The whole Add/Edit Subject page. [existing] null means Add.
///
/// Add and Edit were two 936 and 962 line screens that each contained the
/// same form written out twice — once for wide windows and once for narrow
/// — so every field existed in four places and drifted in all of them.
/// There is one responsive form here, and the two screens in `screen/`
/// just choose the mode.
class SubjectForm extends StatefulWidget {
  final SubjectModel? existing;
  const SubjectForm({this.existing, super.key});

  bool get isEdit => existing != null;

  @override
  State<SubjectForm> createState() => _SubjectFormState();
}

/// The fields that can carry an inline error.
enum _Field {
  course,
  type,
  code,
  name,
  priority,
  price,
  sellingPrice,
  image,
  couponCode,
  couponDiscount,
  couponValidTill
}

class _SubjectFormState extends State<SubjectForm> {
  final TextEditingController codeController = TextEditingController();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController priorityController = TextEditingController();
  final TextEditingController priceController = TextEditingController();
  final TextEditingController sellingPriceController = TextEditingController();
  final TextEditingController couponCodeController = TextEditingController();
  final TextEditingController couponDiscountController =
      TextEditingController();

  static const List<String> courseTypeList = [
    "Full Course",
    "Part Course",
    "Mock Test",
  ];

  String? _selectedCourseName;
  String? _selectedCourseType;
  Uint8List? selectedImageBytes;
  String imageName = "";
  bool willDisplay = false;
  bool isLocked = false;
  bool isPopular = false;
  bool _isSaving = false;

  /// The last day the coupon can be used (date only); saved as the end of
  /// that day so "valid till 30 Sep" still works on 30 Sep.
  DateTime? _couponValidDate;
  static final DateFormat _validDateFormat = DateFormat("d MMM yyyy");

  final Map<_Field, String> _errors = <_Field, String>{};

  @override
  void initState() {
    super.initState();
    final SubjectModel? existing = widget.existing;
    if (existing != null) {
      codeController.text = existing.code;
      nameController.text = existing.name;
      descriptionController.text =
          existing.description == stringDefault ? "" : existing.description;
      priorityController.text = existing.displayPriority.toString();
      priceController.text = _plain(existing.price);
      sellingPriceController.text = _plain(existing.sellingPrice);
      couponCodeController.text =
          existing.couponCode == stringDefault ? "" : existing.couponCode;
      couponDiscountController.text = existing.couponDiscount == doubleDefault
          ? ""
          : _plain(existing.couponDiscount);
      if (existing.couponValidTill > 0) {
        _couponValidDate = _dateOnly(
            DateTime.fromMillisecondsSinceEpoch(existing.couponValidTill));
      }
      _selectedCourseName =
          existing.courseName == stringDefault ? null : existing.courseName;
      _selectedCourseType = courseTypeList.contains(existing.courseType)
          ? existing.courseType
          : null;
      willDisplay = existing.willDisplay;
      isLocked = existing.isLocked;
      isPopular = existing.isPopular;
    }

    // The course picker needs the course list; this page can be reached
    // directly, not only from the subject list.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final CourseViewModel courseViewModel =
          Provider.of<CourseViewModel>(context, listen: false);
      if (courseViewModel.allCourses.isEmpty) courseViewModel.getCourseList();
    });
  }

  static String _plain(double value) =>
      value == value.roundToDouble() ? value.toInt().toString() : "$value";

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static int _endOfDayMillis(DateTime d) =>
      DateTime(d.year, d.month, d.day, 23, 59, 59, 999).millisecondsSinceEpoch;

  @override
  void dispose() {
    codeController.dispose();
    nameController.dispose();
    descriptionController.dispose();
    priorityController.dispose();
    priceController.dispose();
    sellingPriceController.dispose();
    couponCodeController.dispose();
    couponDiscountController.dispose();
    super.dispose();
  }

  // ---- Validation -----------------------------------------------------

  Map<_Field, String> _validate() {
    final Map<_Field, String> errors = <_Field, String>{};
    if ((_selectedCourseName ?? "").isEmpty) {
      errors[_Field.course] = "Choose the course this belongs to";
    }
    if ((_selectedCourseType ?? "").isEmpty) {
      errors[_Field.type] = "Choose a course type";
    }
    if (codeController.text.trim().isEmpty) {
      errors[_Field.code] = "Give the subject a code";
    }
    if (nameController.text.trim().isEmpty) {
      errors[_Field.name] = "Give the subject a name";
    }

    final String priority = priorityController.text.trim();
    if (priority.isEmpty) {
      errors[_Field.priority] = "Set a display priority";
    } else if (int.tryParse(priority) == null) {
      errors[_Field.priority] = "Priority must be a whole number";
    }

    final double? price = double.tryParse(priceController.text.trim());
    if (priceController.text.trim().isEmpty) {
      errors[_Field.price] = "Set a price";
    } else if (price == null) {
      errors[_Field.price] = "Price must be a number";
    }

    final double? selling = double.tryParse(sellingPriceController.text.trim());
    if (sellingPriceController.text.trim().isEmpty) {
      errors[_Field.sellingPrice] = "Set a selling price";
    } else if (selling == null) {
      errors[_Field.sellingPrice] = "Selling price must be a number";
    } else if (price != null && selling > price) {
      // Nothing stopped this before, and the card would then show a
      // negative discount against the list price.
      errors[_Field.sellingPrice] = "Cannot be more than the price";
    }

    // An image is only mandatory when creating: an edit keeps the one the
    // subject already has.
    if (!widget.isEdit && selectedImageBytes == null) {
      errors[_Field.image] = "Choose a subject image";
    }

    // The coupon is optional as a whole -- leaving both blank removes it --
    // but a code with no discount (or a discount with no code) is a coupon
    // that could never apply.
    final String couponCode = couponCodeController.text.trim();
    final String couponDiscountText = couponDiscountController.text.trim();
    if (couponCode.isNotEmpty && couponDiscountText.isEmpty) {
      errors[_Field.couponDiscount] = "Set a discount for this coupon";
    } else if (couponDiscountText.isNotEmpty && couponCode.isEmpty) {
      errors[_Field.couponCode] = "Give the coupon a code";
    } else if (couponDiscountText.isNotEmpty) {
      final double? discount = double.tryParse(couponDiscountText);
      final double? selling =
          double.tryParse(sellingPriceController.text.trim());
      if (discount == null) {
        errors[_Field.couponDiscount] = "Discount must be a number";
      } else if (discount < 0) {
        errors[_Field.couponDiscount] = "Discount cannot be negative";
      } else if (selling != null && discount > selling) {
        errors[_Field.couponDiscount] = "Cannot be more than the selling price";
      }
    }

    // Every coupon needs an end date, and one that has already passed is
    // another coupon that could never apply.
    final DateTime? validDate = _couponValidDate;
    if (couponCode.isNotEmpty && validDate == null) {
      errors[_Field.couponValidTill] = "Set how long this coupon is valid";
    } else if (validDate != null && couponCode.isEmpty) {
      errors.putIfAbsent(_Field.couponCode, () => "Give the coupon a code");
    } else if (validDate != null &&
        validDate.isBefore(_dateOnly(DateTime.now()))) {
      errors[_Field.couponValidTill] = "This date has already passed";
    }
    return errors;
  }

  void _revalidate() {
    if (_errors.isEmpty) return;
    final Map<_Field, String> fresh = _validate();
    setState(() {
      _errors
        ..clear()
        ..addAll(fresh);
    });
  }

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

  Future<void> _onSubmit(SubjectViewModel subjectViewModel,
      CourseViewModel courseViewModel) async {
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

    // The course code is derived from the chosen course. The old form did
    // `.where(...).first`, which throws if the course was renamed or
    // removed since; this keeps whatever the subject already had.
    final String courseCode = courseViewModel.allCourses
            .where((c) => c.name == _selectedCourseName)
            .map((c) => c.code)
            .firstOrNull ??
        widget.existing?.courseCode ??
        stringDefault;

    // Blank means "no coupon" -- pass null so the model falls back to its
    // own NA/-1 defaults, which is also how an existing coupon gets cleared.
    final String couponCodeText =
        couponCodeController.text.trim().toUpperCase();
    final double? couponDiscountValue =
        double.tryParse(couponDiscountController.text.trim());

    final SubjectModel model = SubjectModel(
      courseCode,
      _selectedCourseType ?? stringDefault,
      _selectedCourseName ?? stringDefault,
      double.parse(priceController.text.trim()),
      double.parse(sellingPriceController.text.trim()),
      codeController.text.trim().toUpperCase(),
      descriptionController.text.trim(),
      nameController.text.trim(),
      widget.existing?.image ?? "",
      int.parse(priorityController.text.trim()),
      widget.existing?.timeStamp ?? DateTime.now().millisecondsSinceEpoch,
      willDisplay,
      isLocked,
      isPopular,
      couponCode: couponCodeText.isEmpty ? null : couponCodeText,
      couponDiscount: couponCodeText.isEmpty ? null : couponDiscountValue,
      couponValidTill: couponCodeText.isEmpty || _couponValidDate == null
          ? null
          : _endOfDayMillis(_couponValidDate!),
    );

    final bool success = widget.isEdit
        ? await subjectViewModel.updateSubject(model, widget.existing!.docId,
            image: selectedImageBytes)
        : await subjectViewModel.createSubject(model, selectedImageBytes!);

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (success) {
      Helper.showSnackBarMessage(
          msg: widget.isEdit
              ? "Subject updated successfully"
              : "Subject added successfully",
          isSuccess: true);
      Navigator.pop(context);
    }
  }

  void _onDelete(SubjectViewModel subjectViewModel) {
    final SubjectModel existing = widget.existing!;
    RemoveAlert.showRemoveAlert(
      title: existing.name,
      description: "Are you sure want to delete ?",
      onPressYes: () async {
        Navigator.pop(navigatorKey.currentContext!);
        if (mounted) setState(() => _isSaving = true);
        final bool success =
            await subjectViewModel.deleteSubject(existing.docId);
        if (!mounted) return;
        setState(() => _isSaving = false);
        if (success) {
          Helper.showInfoMessage(msg: "Subject deleted successfully");
          Navigator.pop(context);
        }
      },
    );
  }

  // ---- Layout ---------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return AdminFormScaffold(
      headerTitle: "Subjects",
      sidebarIndex: 2,
      body: (context, width) => Consumer2<SubjectViewModel, CourseViewModel>(
        builder: (context, subjectViewModel, courseViewModel, child) =>
            _page(subjectViewModel, courseViewModel, width),
      ),
    );
  }

  Widget _page(SubjectViewModel subjectViewModel,
      CourseViewModel courseViewModel, double width) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
                horizontal: width < 700 ? 16 : 32, vertical: 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _pageHeader(),
                    const SizedBox(height: AppTokens.gapLg),
                    FormSection(title: "WHERE IT BELONGS", children: [
                      FormTwoUp(
                          width: width,
                          left: _courseField(courseViewModel),
                          right: _typeField()),
                    ]),
                    const SizedBox(height: AppTokens.gapMd),
                    FormSection(title: "SUBJECT DETAILS", children: [
                      FormTwoUp(
                          width: width,
                          left: _textField(
                            label: "Subject code",
                            hint: "e.g. PHY-MECH",
                            controller: codeController,
                            error: _errors[_Field.code],
                            onChanged: _revalidate,
                            uppercase: true,
                          ),
                          right: _textField(
                            label: "Display priority",
                            hint: "Lower numbers come first",
                            controller: priorityController,
                            error: _errors[_Field.priority],
                            onChanged: _revalidate,
                            numeric: true,
                          )),
                      const SizedBox(height: AppTokens.gapMd),
                      _textField(
                        label: "Subject name",
                        hint: "e.g. Mechanics",
                        controller: nameController,
                        error: _errors[_Field.name],
                        onChanged: _revalidate,
                      ),
                      const SizedBox(height: AppTokens.gapMd),
                      _textField(
                        label: "Description",
                        hint: "What does this subject cover? (optional)",
                        controller: descriptionController,
                        maxLines: 4,
                      ),
                    ]),
                    const SizedBox(height: AppTokens.gapMd),
                    FormSection(title: "PRICING", children: [
                      FormTwoUp(
                          width: width,
                          left: _textField(
                            label: "Price",
                            hint: "0.00",
                            controller: priceController,
                            error: _errors[_Field.price],
                            onChanged: _revalidate,
                            money: true,
                          ),
                          right: _textField(
                            label: "Selling price",
                            hint: "What a student actually pays",
                            controller: sellingPriceController,
                            error: _errors[_Field.sellingPrice],
                            onChanged: _revalidate,
                            money: true,
                          )),
                      _discountNote(),
                    ]),
                    const SizedBox(height: AppTokens.gapMd),
                    FormSection(title: "COUPON (OPTIONAL)", children: [
                      FormTwoUp(
                          width: width,
                          left: _textField(
                            label: "Coupon code",
                            hint: "e.g. NEWYEAR50",
                            controller: couponCodeController,
                            error: _errors[_Field.couponCode],
                            onChanged: _revalidate,
                            uppercase: true,
                          ),
                          right: _textField(
                            label: "Coupon discount",
                            hint: "Flat amount off selling price",
                            controller: couponDiscountController,
                            error: _errors[_Field.couponDiscount],
                            onChanged: _revalidate,
                            money: true,
                          )),
                      const SizedBox(height: AppTokens.gapMd),
                      _couponValidityField(),
                      _couponNote(),
                    ]),
                    const SizedBox(height: AppTokens.gapMd),
                    FormSection(
                        title: "SUBJECT IMAGE", children: [_imageField()]),
                    const SizedBox(height: AppTokens.gapMd),
                    FormSection(title: "AVAILABILITY", children: [
                      FormToggleRow(
                        title: "Show in the app",
                        subtitle:
                            "Hidden subjects stay in the catalogue but students never see them.",
                        value: willDisplay,
                        onChanged: _isSaving
                            ? null
                            : (v) => setState(() => willDisplay = v),
                      ),
                      const FormToggleDivider(),
                      FormToggleRow(
                        title: "Locked",
                        subtitle:
                            "Students can see a locked subject but cannot open its content.",
                        value: isLocked,
                        onChanged: _isSaving
                            ? null
                            : (v) => setState(() => isLocked = v),
                      ),
                      const FormToggleDivider(),
                      FormToggleRow(
                        title: "Popular",
                        subtitle:
                            "Popular subjects are highlighted on the app's home screen.",
                        value: isPopular,
                        onChanged: _isSaving
                            ? null
                            : (v) => setState(() => isPopular = v),
                      ),
                    ]),
                    const SizedBox(height: AppTokens.gapXl),
                  ],
                ),
              ),
            ),
          ),
        ),
        _actionBar(subjectViewModel, courseViewModel, width),
      ],
    );
  }

  /// Spells out what the two price fields add up to, so a discount is
  /// something you read rather than compute.
  Widget _discountNote() {
    final double? price = double.tryParse(priceController.text.trim());
    final double? selling = double.tryParse(sellingPriceController.text.trim());
    if (price == null || selling == null || price <= 0 || selling > price) {
      return const SizedBox.shrink();
    }

    final bool discounted = selling < price;
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
            const Icon(Icons.sell_outlined,
                size: 16, color: AppTokens.inkMuted),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                discounted
                    ? "Students pay ₹${selling.toStringAsFixed(2)} — "
                        "${(((price - selling) / price) * 100).round()}% off ₹${price.toStringAsFixed(2)}."
                    : "Students pay ₹${selling.toStringAsFixed(2)}. No discount is shown.",
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

  /// Explains the two things that are not obvious from the fields alone:
  /// the amount is flat rupees off the selling price (not a percentage,
  /// matching how the student app applies it), and clearing the fields is
  /// how an existing coupon is removed.
  Widget _couponNote() {
    return Padding(
      padding: const EdgeInsets.only(top: AppTokens.gapMd),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppTokens.surfaceMuted,
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          border: Border.all(color: AppTokens.hairline),
        ),
        child: const Row(
          children: [
            Icon(Icons.info_outline, size: 16, color: AppTokens.inkMuted),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                "A flat ₹ amount off the selling price, not a percentage. "
                "The coupon works up to the end of its valid-till date. "
                "Leave all fields blank to remove an existing coupon.",
                style: TextStyle(
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

  Future<void> _pickCouponValidDate() async {
    final DateTime? picked = await showValidTillPicker(
      context,
      title: "Coupon valid till",
      initial: _couponValidDate,
      presets: const [
        DatePreset.days(7, "1 week"),
        DatePreset.days(14, "2 weeks"),
        DatePreset.months(1, "1 month"),
        DatePreset.months(3, "3 months"),
      ],
    );
    if (picked == null || !mounted) return;
    setState(() => _couponValidDate = _dateOnly(picked));
    _revalidate();
  }

  Widget _couponValidityField() {
    final String? error = _errors[_Field.couponValidTill];
    final DateTime? date = _couponValidDate;

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
            onTap: _isSaving ? null : _pickCouponValidDate,
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
                          : _validDateFormat.format(date),
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
                      onPressed: _isSaving
                          ? null
                          : () {
                              setState(() => _couponValidDate = null);
                              _revalidate();
                            },
                      icon: const Icon(Icons.close, size: 16),
                      color: AppTokens.inkMuted,
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 5),
          Text(error, style: AppTokens.errorText),
        ],
      ],
    );
  }

  /// Back button, title and subtitle at the top of the page.
  Widget _pageHeader() {
    return FormPageHeader(
      title: widget.isEdit ? "Edit subject" : "Add a subject",
      subtitle: widget.isEdit
          ? "Update this subject's details, pricing and availability."
          : "Subjects sit under a course, and units hang off them.",
      onBack: _isSaving ? null : () => Navigator.pop(context),
    );
  }

  // ---- Fields ---------------------------------------------------------

  /// A [FormTextField] configured for this form.
  Widget _textField({
    required String label,
    required String hint,
    required TextEditingController controller,
    int maxLines = 1,
    String? error,
    VoidCallback? onChanged,
    bool numeric = false,
    bool money = false,
    bool uppercase = false,
  }) {
    return FormTextField(
      label: label,
      hint: hint,
      controller: controller,
      maxLines: maxLines,
      error: error,
      onChanged: onChanged,
      keyboardType: money
          ? const TextInputType.numberWithOptions(decimal: true)
          : numeric
              ? TextInputType.number
              : TextInputType.text,
      inputFormatters: [
        if (numeric) FilteringTextInputFormatter.digitsOnly,
        if (money) FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
        if (uppercase) UpperCaseTextFormatter(),
      ],
      prefixText: money ? "₹ " : null,
    );
  }

  Widget _courseField(CourseViewModel courseViewModel) {
    final List<String> names = courseViewModel.allCourses
        .map((CourseModel c) => c.name)
        .where((String name) => name.isNotEmpty)
        .toSet()
        .toList();

    // A subject may name a course that has since been renamed or removed —
    // keep that value selectable so editing doesn't silently drop it.
    final String? current = _selectedCourseName;
    if (current != null && current.isNotEmpty && !names.contains(current)) {
      names.insert(0, current);
    }

    return _dropdownField(
      key: const Key('subject_course_dropdown'),
      label: "Course",
      hint: courseViewModel.isLoading && names.isEmpty
          ? "Loading courses…"
          : "Select a course",
      value: _selectedCourseName,
      items: names,
      error: _errors[_Field.course],
      icon: Icons.menu_book_outlined,
      onChanged: (value) {
        setState(() => _selectedCourseName = value);
        _revalidate();
      },
    );
  }

  Widget _typeField() {
    return _dropdownField(
      key: const Key('subject_type_dropdown'),
      label: "Course type",
      hint: "Select a type",
      value: _selectedCourseType,
      items: courseTypeList,
      error: _errors[_Field.type],
      icon: Icons.category_outlined,
      onChanged: (value) {
        setState(() => _selectedCourseType = value);
        _revalidate();
      },
    );
  }

  /// A [FormDropdownField] wired to this form's saving state.
  Widget _dropdownField({
    required Key key,
    required String label,
    required String hint,
    required String? value,
    required List<String> items,
    required IconData icon,
    required ValueChanged<String?> onChanged,
    String? error,
  }) {
    return FormDropdownField(
      dropdownKey: key,
      label: label,
      hint: hint,
      value: value,
      items: items,
      icon: icon,
      onChanged: _isSaving ? null : onChanged,
      error: error,
    );
  }

  /// Square image well with Choose / Replace / Remove.
  Widget _imageField() {
    return FormImagePickerField(
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
    );
  }

  /// Delete / Cancel / Save bar pinned to the bottom of the page.
  Widget _actionBar(SubjectViewModel subjectViewModel,
      CourseViewModel courseViewModel, double width) {
    return FormActionBar(
      width: width,
      isSaving: _isSaving,
      onDelete: widget.isEdit ? () => _onDelete(subjectViewModel) : null,
      deleteTooltip: "Delete subject",
      saveKey: const Key('subject_save_button'),
      saveLabel: widget.isEdit ? "Update subject" : "Save subject",
      onSave: () => _onSubmit(subjectViewModel, courseViewModel),
      saveMinWidth: 145,
    );
  }
}
