import 'package:bbarna/core/widgets/form/admin_form_scaffold.dart';
import 'package:bbarna/core/widgets/form/form_action_bar.dart';
import 'package:bbarna/core/widgets/form/form_fields.dart';
import 'package:bbarna/core/widgets/form/form_page_body.dart';
import 'package:bbarna/core/widgets/remove_alert.dart';
import 'package:bbarna/core/widgets/valid_till_picker.dart';
import 'package:bbarna/course/model/course_model.dart';
import 'package:bbarna/course/viewModel/course_view_model.dart';
import 'package:bbarna/question/widgets/question_rich_field.dart';
import 'package:bbarna/resources/app_tokens.dart';
import 'package:bbarna/resources/constant.dart';
import 'package:bbarna/subject/model/subject_model.dart';
import 'package:bbarna/subject/subject_field_rules.dart';
import 'package:bbarna/subject/viewModel/subject_view_model.dart';
import 'package:bbarna/subject/widgets/subject_pricing_fields.dart';
import 'package:bbarna/utils/formatters.dart';
import 'package:bbarna/utils/helper.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:html_editor_enhanced/html_editor.dart';
import 'package:provider/provider.dart';

/// The Add/Edit Subject page. One responsive form serves both Add and Edit; the thin screens in
/// `screen/` just choose the mode ([existing] null means Add).
///
/// Sections: where it belongs (course, course type), details, pricing,
/// optional coupon, image and availability.
class SubjectForm extends StatefulWidget {
  /// The item being edited; null means "Add".
  final SubjectModel? existing;
  const SubjectForm({this.existing, super.key});

  /// True when editing an existing item.
  bool get isEdit => existing != null;

  /// Swaps the rich description editor for a plain box. The editor is a web
  /// view, which widget tests cannot run.
  @visibleForTesting
  static bool plainDescriptionForTests = false;

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
  couponValidTill,
  video,
  validity
}

class _SubjectFormState extends State<SubjectForm> {
  /// Text of the code field.
  final TextEditingController codeController = TextEditingController();

  /// Text of the name field.
  final TextEditingController nameController = TextEditingController();

  /// The description's rich editor.
  final HtmlEditorController descriptionEditor = HtmlEditorController();

  /// Stands in for [descriptionEditor] under
  /// [SubjectForm.plainDescriptionForTests].
  final TextEditingController plainDescriptionController =
      TextEditingController();

  /// The HTML the description editor opens with.
  String _initialDescription = "";

  /// Text of the intro video link field.
  final TextEditingController videoController = TextEditingController();

  /// Text of the validity (months) field.
  final TextEditingController validityController = TextEditingController();

  /// Text of the display priority field.
  final TextEditingController priorityController = TextEditingController();

  /// Text of the price field.
  final TextEditingController priceController = TextEditingController();

  /// Text of the selling price field.
  final TextEditingController sellingPriceController = TextEditingController();

  /// Text of the coupon code field.
  final TextEditingController couponCodeController = TextEditingController();

  /// Text of the coupon discount field.
  final TextEditingController couponDiscountController =
      TextEditingController();

  /// Access types offered.
  static const List<String> courseTypeList = [
    "Full Course",
    "Part Course",
    "Mock Test",
  ];

  /// Course chosen in the dropdown (by name).
  String? _selectedCourseName;

  /// "Full Course", "Part Course" or "Mock Test".
  String? _selectedCourseType;

  /// Newly picked file, not uploaded yet (null until one is chosen).
  Uint8List? selectedImageBytes;

  /// File name of the newly picked file.
  String imageName = "";

  /// "Show in the app" switch.
  bool willDisplay = false;

  /// "Locked" switch.
  bool isLocked = false;

  /// "Popular" switch.
  bool isPopular = false;

  /// True while saving or deleting; disables every control.
  bool _isSaving = false;

  /// The last day the coupon can be used (date only); saved as the end of
  /// that day so "valid till 30 Sep" still works on 30 Sep.
  DateTime? _couponValidDate;

  /// Inline error per field: filled on a failed submit, then refreshed on
  /// every change so each message clears as its field is fixed.
  final Map<_Field, String> _errors = <_Field, String>{};

  @override
  void initState() {
    super.initState();
    final SubjectModel? existing = widget.existing;
    if (existing != null) {
      codeController.text = existing.code;
      nameController.text = existing.name;
      _initialDescription =
          subjectDescriptionToEditorHtml(existing.description);
      plainDescriptionController.text = _initialDescription;
      videoController.text =
          existing.videoLink == stringDefault ? "" : existing.videoLink;
      validityController.text =
          existing.validityMonths > 0 ? existing.validityMonths.toString() : "";
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

  /// [value] without a trailing ".0" (for pre-filling price fields).
  static String _plain(double value) =>
      value == value.roundToDouble() ? value.toInt().toString() : "$value";

  /// [d] at midnight.
  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// The last millisecond of [d]'s day (coupon expiry is inclusive).
  static int _endOfDayMillis(DateTime d) =>
      DateTime(d.year, d.month, d.day, 23, 59, 59, 999).millisecondsSinceEpoch;

  @override
  void dispose() {
    codeController.dispose();
    nameController.dispose();
    plainDescriptionController.dispose();
    videoController.dispose();
    validityController.dispose();
    priorityController.dispose();
    priceController.dispose();
    sellingPriceController.dispose();
    couponCodeController.dispose();
    couponDiscountController.dispose();
    super.dispose();
  }

  // ---- Validation -----------------------------------------------------

  /// Checks every field and returns the problems (empty when valid).
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

    final String video = videoController.text.trim();
    if (video.isEmpty) {
      errors[_Field.video] = "Add the intro video's YouTube link";
    } else if (SubjectVideoLink.idOf(video) == null) {
      errors[_Field.video] = "Paste a YouTube video link";
    }

    final String validity = validityController.text.trim();
    final int? months = int.tryParse(validity);
    if (validity.isEmpty) {
      errors[_Field.validity] = "Enter the validity in months";
    } else if (months == null || months < 1 || months > 120) {
      errors[_Field.validity] = "Enter 1 to 120 months";
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

  /// Re-runs validation after an edit, but only once a submit has failed
  /// (so errors never appear while the form is still being filled in).
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

  /// Asks whether an empty description box really means "remove it".
  Future<bool> _confirmRemoveDescription() async {
    final bool? remove = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text("Remove the description?"),
        content: const Text(
            "The description box is empty. If it was still loading, keep the "
            "description and save again."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text("Keep description"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text("Remove it"),
          ),
        ],
      ),
    );
    return remove ?? false;
  }

  /// The description to save, or null if the editor did not answer. It
  /// never answers when asked before it has loaded, and waiting without a
  /// limit would leave the form stuck on "saving".
  Future<String?> _readDescription() async {
    if (SubjectForm.plainDescriptionForTests) {
      return subjectDescriptionToSave(plainDescriptionController.text);
    }
    try {
      final String html =
          await descriptionEditor.getText().timeout(const Duration(seconds: 5));
      return subjectDescriptionToSave(html);
    } catch (_) {
      return null;
    }
  }

  /// Validates, then creates or updates the item. Closes the page on
  /// success; on failure the view model has already shown why.
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

    // The course code comes from the chosen course. If that course has
    // been renamed or removed since, keep the code the subject already had.
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

    final String? description = await _readDescription();
    if (!mounted) return;
    if (description == null) {
      setState(() => _isSaving = false);
      Helper.showSnackBarMessage(
          msg: "The description editor isn't ready yet. Try again.",
          isSuccess: false);
      return;
    }

    // The editor is briefly blank while it loads, so an empty reading of a
    // subject that had a description may not be what the admin wants saved.
    if (description.isEmpty &&
        subjectDescriptionToSave(_initialDescription).isNotEmpty) {
      final bool remove = await _confirmRemoveDescription();
      if (!mounted) return;
      if (!remove) {
        setState(() => _isSaving = false);
        return;
      }
    }

    final SubjectModel model = SubjectModel(
      courseCode,
      _selectedCourseType ?? stringDefault,
      _selectedCourseName ?? stringDefault,
      double.parse(priceController.text.trim()),
      double.parse(sellingPriceController.text.trim()),
      codeController.text.trim().toUpperCase(),
      description,
      nameController.text.trim(),
      widget.existing?.image ?? "",
      int.parse(priorityController.text.trim()),
      widget.existing?.timeStamp ?? DateTime.now().millisecondsSinceEpoch,
      willDisplay,
      isLocked,
      isPopular,
      videoLink: SubjectVideoLink.normalize(videoController.text),
      validityMonths: int.tryParse(validityController.text.trim()),
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
      Navigator.pop(context, true);
    }
  }

  /// Asks for confirmation, deletes the item and closes the page.
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
          Navigator.pop(context, true);
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

  /// The scrolling form (header and sections) with the action bar below.
  Widget _page(SubjectViewModel subjectViewModel,
      CourseViewModel courseViewModel, double width) {
    return FormPageBody(
      width: width,
      actionBar: _actionBar(subjectViewModel, courseViewModel, width),
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
          if (SubjectForm.plainDescriptionForTests)
            _textField(
              label: "Description",
              hint: "",
              controller: plainDescriptionController,
            )
          else
            QuestionRichField(
              label: "Description",
              hint: "What does this subject cover? Shown on the app's Overview "
                  "tab. Optional.",
              controller: descriptionEditor,
              initialText: _initialDescription,
              height: 280,
            ),
          const SizedBox(height: AppTokens.gapMd),
          FormTwoUp(
              width: width,
              left: _textField(
                label: "Intro video",
                hint: "YouTube link",
                controller: videoController,
                error: _errors[_Field.video],
                onChanged: _revalidate,
              ),
              right: _textField(
                label: "Validity (months)",
                hint: "e.g. 15",
                controller: validityController,
                error: _errors[_Field.validity],
                onChanged: _revalidate,
                numeric: true,
              )),
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
          SubjectPriceSummary(
            priceText: priceController.text,
            sellingPriceText: sellingPriceController.text,
          ),
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
          CouponValidTillField(
            date: _couponValidDate,
            error: _errors[_Field.couponValidTill],
            enabled: !_isSaving,
            onTap: _pickCouponValidDate,
            onClear: () {
              setState(() => _couponValidDate = null);
              _revalidate();
            },
          ),
          const CouponNote(),
        ]),
        const SizedBox(height: AppTokens.gapMd),
        FormSection(title: "SUBJECT IMAGE", children: [_imageField()]),
        const SizedBox(height: AppTokens.gapMd),
        FormSection(title: "AVAILABILITY", children: [
          FormToggleRow(
            title: "Show in the app",
            subtitle:
                "Hidden subjects stay in the catalogue but students never see them.",
            value: willDisplay,
            onChanged:
                _isSaving ? null : (v) => setState(() => willDisplay = v),
          ),
          const FormToggleDivider(),
          FormToggleRow(
            title: "Locked",
            subtitle:
                "Students can see a locked subject but cannot open its content.",
            value: isLocked,
            onChanged: _isSaving ? null : (v) => setState(() => isLocked = v),
          ),
          const FormToggleDivider(),
          FormToggleRow(
            title: "Popular",
            subtitle:
                "Popular subjects are highlighted on the app's home screen.",
            value: isPopular,
            onChanged: _isSaving ? null : (v) => setState(() => isPopular = v),
          ),
        ]),
        const SizedBox(height: AppTokens.gapXl),
      ],
    );
  }

  /// Opens the shared valid-till calendar for the coupon.
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

  /// Course dropdown.
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
          : courseViewModel.loadError != null && names.isEmpty
              ? "Couldn't load courses"
              : "Select a course",
      // The course list failed to load: say so, with Retry.
      loadError: names.isEmpty ? courseViewModel.loadError : null,
      onRetry: courseViewModel.getCourseList,
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

  /// Course-type dropdown.
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
    String? loadError,
    VoidCallback? onRetry,
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
      loadError: loadError,
      onRetry: onRetry,
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
