import 'package:bbarna/core/widgets/app_header.dart';
import 'package:bbarna/core/widgets/remove_alert.dart';
import 'package:bbarna/core/widgets/sidebar.dart';
import 'package:bbarna/course/model/course_model.dart';
import 'package:bbarna/course/viewModel/course_view_model.dart';
import 'package:bbarna/course/widgets/course_form.dart' show UpperCaseTextFormatter;
import 'package:bbarna/resources/app_tokens.dart';
import 'package:bbarna/resources/constant.dart';
import 'package:bbarna/subject/model/subject_model.dart';
import 'package:bbarna/subject/viewModel/subject_view_model.dart';
import 'package:bbarna/utils/helper.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  couponDiscount
}

class _SubjectFormState extends State<SubjectForm> {
  final GlobalKey<ScaffoldState> key = GlobalKey();

  final TextEditingController codeController = TextEditingController();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController priorityController = TextEditingController();
  final TextEditingController priceController = TextEditingController();
  final TextEditingController sellingPriceController = TextEditingController();
  final TextEditingController couponCodeController = TextEditingController();
  final TextEditingController couponDiscountController = TextEditingController();

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
      _selectedCourseName =
          existing.courseName == stringDefault ? null : existing.courseName;
      _selectedCourseType =
          courseTypeList.contains(existing.courseType) ? existing.courseType : null;
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
      if (courseViewModel.courseList.isEmpty) courseViewModel.getCourseList();
    });
  }

  static String _plain(double value) =>
      value == value.roundToDouble() ? value.toInt().toString() : "$value";

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
      final double? selling = double.tryParse(sellingPriceController.text.trim());
      if (discount == null) {
        errors[_Field.couponDiscount] = "Discount must be a number";
      } else if (discount < 0) {
        errors[_Field.couponDiscount] = "Discount cannot be negative";
      } else if (selling != null && discount > selling) {
        errors[_Field.couponDiscount] = "Cannot be more than the selling price";
      }
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
    final String courseCode = courseViewModel.courseList
        .where((c) => c.name == _selectedCourseName)
        .map((c) => c.code)
        .firstOrNull ??
        widget.existing?.courseCode ??
        stringDefault;

    // Blank means "no coupon" -- pass null so the model falls back to its
    // own NA/-1 defaults, which is also how an existing coupon gets cleared.
    final String couponCodeText = couponCodeController.text.trim().toUpperCase();
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
    final double width = MediaQuery.of(context).size.width;
    final bool isCompact = width < AppTokens.compactBreakpoint;

    return Scaffold(
      key: key,
      backgroundColor: AppTokens.canvas,
      body: PopScope(
        canPop: true,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
        },
        child: Column(
          children: [
            AppHeader(
              onTapIcon: () => key.currentState?.openDrawer(),
              title: "Subjects",
            ),
            Expanded(
              child: Row(
                children: [
                  if (!isCompact)
                    const Expanded(child: ExtraSideBar(sidebarIndex: 2)),
                  Expanded(
                    flex: 5,
                    child: Consumer2<SubjectViewModel, CourseViewModel>(
                      builder: (context, subjectViewModel, courseViewModel,
                              child) =>
                          _page(subjectViewModel, courseViewModel, width),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      drawer:
          isCompact ? const Drawer(child: ExtraSideBar(sidebarIndex: 2)) : null,
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
                    _section(title: "WHERE IT BELONGS", children: [
                      _twoUp(
                        width,
                        _courseField(courseViewModel),
                        _typeField(),
                      ),
                    ]),
                    const SizedBox(height: AppTokens.gapMd),
                    _section(title: "SUBJECT DETAILS", children: [
                      _twoUp(
                        width,
                        _textField(
                          label: "Subject code",
                          hint: "e.g. PHY-MECH",
                          controller: codeController,
                          error: _errors[_Field.code],
                          onChanged: _revalidate,
                          uppercase: true,
                        ),
                        _textField(
                          label: "Display priority",
                          hint: "Lower numbers come first",
                          controller: priorityController,
                          error: _errors[_Field.priority],
                          onChanged: _revalidate,
                          numeric: true,
                        ),
                      ),
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
                    _section(title: "PRICING", children: [
                      _twoUp(
                        width,
                        _textField(
                          label: "Price",
                          hint: "0.00",
                          controller: priceController,
                          error: _errors[_Field.price],
                          onChanged: _revalidate,
                          money: true,
                        ),
                        _textField(
                          label: "Selling price",
                          hint: "What a student actually pays",
                          controller: sellingPriceController,
                          error: _errors[_Field.sellingPrice],
                          onChanged: _revalidate,
                          money: true,
                        ),
                      ),
                      _discountNote(),
                    ]),
                    const SizedBox(height: AppTokens.gapMd),
                    _section(title: "COUPON (OPTIONAL)", children: [
                      _twoUp(
                        width,
                        _textField(
                          label: "Coupon code",
                          hint: "e.g. NEWYEAR50",
                          controller: couponCodeController,
                          error: _errors[_Field.couponCode],
                          onChanged: _revalidate,
                          uppercase: true,
                        ),
                        _textField(
                          label: "Coupon discount",
                          hint: "Flat amount off selling price",
                          controller: couponDiscountController,
                          error: _errors[_Field.couponDiscount],
                          onChanged: _revalidate,
                          money: true,
                        ),
                      ),
                      _couponNote(),
                    ]),
                    const SizedBox(height: AppTokens.gapMd),
                    _section(
                        title: "SUBJECT IMAGE", children: [_imageField()]),
                    const SizedBox(height: AppTokens.gapMd),
                    _section(title: "AVAILABILITY", children: [
                      _toggleRow(
                        title: "Show in the app",
                        subtitle:
                            "Hidden subjects stay in the catalogue but students never see them.",
                        value: willDisplay,
                        onChanged: (v) => setState(() => willDisplay = v),
                      ),
                      const Divider(
                          height: AppTokens.gapLg,
                          thickness: 1,
                          color: AppTokens.hairline),
                      _toggleRow(
                        title: "Locked",
                        subtitle:
                            "Students can see a locked subject but cannot open its content.",
                        value: isLocked,
                        onChanged: (v) => setState(() => isLocked = v),
                      ),
                      const Divider(
                          height: AppTokens.gapLg,
                          thickness: 1,
                          color: AppTokens.hairline),
                      _toggleRow(
                        title: "Popular",
                        subtitle:
                            "Popular subjects are highlighted on the app's home screen.",
                        value: isPopular,
                        onChanged: (v) => setState(() => isPopular = v),
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
    final double? selling =
        double.tryParse(sellingPriceController.text.trim());
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
  /// matching how the student app applies it), and clearing both fields is
  /// how an existing coupon is removed. Expiry stays outside this panel.
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
                "Leave both fields blank to remove an existing coupon. "
                "Expiry is set outside this panel.",
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

  Widget _twoUp(double width, Widget left, Widget right) {
    if (width < 700) {
      return Column(children: [
        left,
        const SizedBox(height: AppTokens.gapMd),
        right,
      ]);
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: left),
        const SizedBox(width: AppTokens.gapMd),
        Expanded(child: right),
      ],
    );
  }

  Widget _pageHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _backButton(),
        const SizedBox(width: AppTokens.gapMd),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.isEdit ? "Edit subject" : "Add a subject",
                  style: AppTokens.pageTitle),
              const SizedBox(height: 3),
              Text(
                widget.isEdit
                    ? "Update this subject's details, pricing and availability."
                    : "Subjects sit under a course, and units hang off them.",
                style: AppTokens.pageSubtitle,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _backButton() {
    return Material(
      color: AppTokens.surface,
      borderRadius: BorderRadius.circular(AppTokens.radiusMd),
      child: InkWell(
        onTap: _isSaving ? null : () => Navigator.pop(context),
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        child: Container(
          height: 38,
          width: 38,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTokens.radiusMd),
            border: Border.all(color: AppTokens.hairline),
          ),
          child: const Icon(Icons.arrow_back, size: 18, color: AppTokens.ink),
        ),
      ),
    );
  }

  Widget _section({required String title, required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
      decoration: BoxDecoration(
        color: AppTokens.surface,
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        border: Border.all(color: AppTokens.hairline),
        boxShadow: AppTokens.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTokens.sectionTitle),
          const SizedBox(height: AppTokens.gapMd),
          ...children,
        ],
      ),
    );
  }

  // ---- Fields ---------------------------------------------------------

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: _labelStyle),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: AppTokens.surface,
            borderRadius: BorderRadius.circular(AppTokens.radiusMd),
            border: Border.all(
                color: error != null ? AppTokens.danger : AppTokens.hairline),
          ),
          child: TextField(
            controller: controller,
            maxLines: maxLines,
            keyboardType: money
                ? const TextInputType.numberWithOptions(decimal: true)
                : numeric
                    ? TextInputType.number
                    : TextInputType.text,
            inputFormatters: [
              if (numeric) FilteringTextInputFormatter.digitsOnly,
              if (money)
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              if (uppercase) UpperCaseTextFormatter(),
            ],
            onChanged: onChanged == null ? null : (_) => onChanged(),
            style: const TextStyle(fontSize: 13.5, color: AppTokens.ink),
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              hintText: hint,
              hintStyle:
                  const TextStyle(fontSize: 13, color: AppTokens.inkFaint),
              prefixText: money ? "₹ " : null,
              prefixStyle: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: AppTokens.inkMuted),
              contentPadding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
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

  static const TextStyle _labelStyle = TextStyle(
      fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF344054));

  Widget _courseField(CourseViewModel courseViewModel) {
    final List<String> names = courseViewModel.courseList
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: _labelStyle),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: AppTokens.surface,
            borderRadius: BorderRadius.circular(AppTokens.radiusMd),
            border: Border.all(
                color: error != null ? AppTokens.danger : AppTokens.hairline),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              key: key,
              value: value,
              isExpanded: true,
              padding: const EdgeInsets.symmetric(vertical: 4),
              borderRadius: BorderRadius.circular(AppTokens.radiusMd),
              icon: const Icon(Icons.keyboard_arrow_down,
                  size: 20, color: AppTokens.inkFaint),
              hint: Text(hint,
                  style: const TextStyle(
                      fontSize: 13, color: AppTokens.inkFaint)),
              // Built from the theme with the decoration pinned off:
              // DropdownButton uses `style` verbatim instead of merging it,
              // and this State's context sits above the Scaffold's
              // Material — inheriting DefaultTextStyle there picks up
              // WidgetsApp's yellow double-underline error style.
              style: (Theme.of(context).textTheme.bodyMedium ??
                      const TextStyle())
                  .copyWith(
                fontSize: 13.5,
                color: AppTokens.ink,
                decoration: TextDecoration.none,
              ),
              onChanged: _isSaving ? null : onChanged,
              items: items
                  .map((String item) => DropdownMenuItem<String>(
                        value: item,
                        child: Row(
                          children: [
                            Icon(icon, size: 15, color: AppTokens.inkFaint),
                            const SizedBox(width: 8),
                            Expanded(
                              child:
                                  Text(item, overflow: TextOverflow.ellipsis),
                            ),
                          ],
                        ),
                      ))
                  .toList(),
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

  Widget _imageField() {
    final String? error = _errors[_Field.image];
    final bool hasNew = selectedImageBytes != null;
    final String existingUrl = widget.existing?.image ?? "";
    final bool hasExisting = existingUrl.trim().isNotEmpty;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 108,
          width: 108,
          child: Material(
            color: AppTokens.surfaceMuted,
            borderRadius: BorderRadius.circular(AppTokens.radiusMd),
            child: InkWell(
              onTap: _isSaving ? null : _pickImage,
              borderRadius: BorderRadius.circular(AppTokens.radiusMd),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                  border: Border.all(
                    color: error != null
                        ? AppTokens.danger
                        : AppTokens.inkFaint.withValues(alpha: .4),
                  ),
                ),
                child: ClipRRect(
                  borderRadius:
                      BorderRadius.circular(AppTokens.radiusMd - 1),
                  child: hasNew
                      ? Image.memory(selectedImageBytes!, fit: BoxFit.cover)
                      : hasExisting
                          ? Image.network(existingUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (c, e, s) => _imagePlaceholder())
                          : _imagePlaceholder(),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: AppTokens.gapMd),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                hasNew
                    ? (imageName.isEmpty ? "Selected image" : imageName)
                    : hasExisting
                        ? "Using the current image"
                        : "No image chosen",
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppTokens.ink),
              ),
              const SizedBox(height: 3),
              Text(
                hasNew
                    ? _readableSize(selectedImageBytes!.lengthInBytes)
                    : "Square images work best — it is shown as a thumbnail.",
                style: const TextStyle(
                    fontSize: 11.5, height: 1.35, color: AppTokens.inkFaint),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  OutlinedButton(
                    onPressed: _isSaving ? null : _pickImage,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTokens.ink,
                      side: const BorderSide(color: AppTokens.hairline),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppTokens.radiusSm)),
                    ),
                    child: Text(
                        hasNew || hasExisting ? "Replace" : "Choose image",
                        style: const TextStyle(fontSize: 12.5)),
                  ),
                  if (hasNew) ...[
                    const SizedBox(width: AppTokens.gapSm),
                    TextButton(
                      onPressed: _isSaving
                          ? null
                          : () => setState(() {
                                selectedImageBytes = null;
                                imageName = "";
                              }),
                      style: TextButton.styleFrom(
                          foregroundColor: AppTokens.danger,
                          padding:
                              const EdgeInsets.symmetric(horizontal: 10)),
                      child: const Text("Remove",
                          style: TextStyle(fontSize: 12.5)),
                    ),
                  ],
                ],
              ),
              if (error != null) ...[
                const SizedBox(height: 6),
                Text(error, style: AppTokens.errorText),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _imagePlaceholder() => Container(
        color: AppTokens.surfaceMuted,
        alignment: Alignment.center,
        child: const Icon(Icons.add_photo_alternate_outlined,
            size: 26, color: AppTokens.inkFaint),
      );

  static String _readableSize(int bytes) {
    if (bytes < 1024) return "$bytes B";
    if (bytes < 1024 * 1024) return "${(bytes / 1024).toStringAsFixed(0)} KB";
    return "${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB";
  }

  /// A labelled switch with the consequence spelled out. These were three
  /// unlabelled `ToggleSwitch` widgets whose states were "position 0" and
  /// "position 1" — nothing on screen said which meant what.
  Widget _toggleRow({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: AppTokens.ink)),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: const TextStyle(
                      fontSize: 11.5,
                      height: 1.35,
                      color: AppTokens.inkFaint)),
            ],
          ),
        ),
        const SizedBox(width: AppTokens.gapMd),
        Switch(
          value: value,
          onChanged: _isSaving ? null : onChanged,
          activeThumbColor: Colors.white,
          activeTrackColor: AppTokens.ink,
        ),
      ],
    );
  }

  Widget _actionBar(SubjectViewModel subjectViewModel,
      CourseViewModel courseViewModel, double width) {
    final bool narrow = width < 560;

    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: width < 700 ? 16 : 32, vertical: 14),
      decoration: const BoxDecoration(
        color: AppTokens.surface,
        border: Border(top: BorderSide(color: AppTokens.hairline)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Row(
            children: [
              if (widget.isEdit)
                narrow
                    ? IconButton(
                        onPressed: _isSaving
                            ? null
                            : () => _onDelete(subjectViewModel),
                        tooltip: "Delete subject",
                        icon: const Icon(Icons.delete_outline, size: 20),
                        color: AppTokens.danger,
                      )
                    : TextButton.icon(
                        onPressed: _isSaving
                            ? null
                            : () => _onDelete(subjectViewModel),
                        icon: const Icon(Icons.delete_outline, size: 17),
                        label: const Text("Delete"),
                        style: TextButton.styleFrom(
                          foregroundColor: AppTokens.danger,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 14),
                        ),
                      ),
              if (!narrow) const Spacer(),
              TextButton(
                onPressed: _isSaving ? null : () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  foregroundColor: AppTokens.inkMuted,
                  padding: EdgeInsets.symmetric(
                      horizontal: narrow ? 12 : 18, vertical: 14),
                ),
                child: const Text("Cancel"),
              ),
              const SizedBox(width: AppTokens.gapSm),
              _saveButton(subjectViewModel, courseViewModel, expand: narrow),
            ],
          ),
        ),
      ),
    );
  }

  Widget _saveButton(SubjectViewModel subjectViewModel,
      CourseViewModel courseViewModel,
      {required bool expand}) {
    final Widget button = ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 145, minHeight: 42),
      child: ElevatedButton(
        key: const Key('subject_save_button'),
        onPressed: _isSaving
            ? null
            : () => _onSubmit(subjectViewModel, courseViewModel),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTokens.ink,
          disabledBackgroundColor: AppTokens.ink.withValues(alpha: .55),
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTokens.radiusMd)),
        ),
        child: _isSaving
            ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2.2, color: Colors.white),
              )
            : Text(widget.isEdit ? "Update subject" : "Save subject",
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 13.5, fontWeight: FontWeight.w600)),
      ),
    );

    return expand ? Expanded(child: button) : button;
  }
}
