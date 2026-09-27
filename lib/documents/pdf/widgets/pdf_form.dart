import 'package:bbarna/core/widgets/form/admin_form_scaffold.dart';
import 'package:bbarna/core/widgets/form/form_action_bar.dart';
import 'package:bbarna/core/widgets/form/form_fields.dart';
import 'package:bbarna/core/widgets/form/form_page_body.dart';
import 'package:bbarna/core/widgets/remove_alert.dart';
import 'package:bbarna/documents/pdf/model/pdf_model.dart';
import 'package:bbarna/documents/pdf/viewModel/pdf_view_model.dart';
import 'package:bbarna/resources/app_tokens.dart';
import 'package:bbarna/resources/constant.dart';
import 'package:bbarna/utils/formatters.dart';
import 'package:bbarna/utils/helper.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

/// The whole Add/Edit PDF page. [existing] null means Add.
///
/// Add and Edit were two 406 and 424 line screens holding the same form
/// twice over. There is one responsive form here, and the two screens in
/// `screen/` just choose the mode.
class PdfForm extends StatefulWidget {
  final PdfModel? existing;
  const PdfForm({this.existing, super.key});

  bool get isEdit => existing != null;

  @override
  State<PdfForm> createState() => _PdfFormState();
}

enum _Field { code, title, file, type }

class _PdfFormState extends State<PdfForm> {
  final TextEditingController codeController = TextEditingController();
  final TextEditingController titleController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  Uint8List? selectedPdfBytes;
  String pdfName = "";
  bool isDownloadable = false;
  bool isLocked = false;

  static const List<String> pdfTypeList = ["FREE", "PAID"];
  String? _selectedType;
  bool _isSaving = false;

  final Map<_Field, String> _errors = <_Field, String>{};

  @override
  void initState() {
    super.initState();
    final PdfModel? existing = widget.existing;
    if (existing != null) {
      codeController.text = existing.code;
      titleController.text = existing.title;
      descriptionController.text =
          existing.description == stringDefault ? "" : existing.description;
      _selectedType =
          pdfTypeList.contains(existing.pdfType) ? existing.pdfType : null;
      isDownloadable = existing.isDownloadable;
      isLocked = existing.isLocked;
    }
  }

  @override
  void dispose() {
    codeController.dispose();
    titleController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  Map<_Field, String> _validate() {
    final Map<_Field, String> errors = <_Field, String>{};
    if (codeController.text.trim().isEmpty) {
      errors[_Field.code] = "Give the PDF a code";
    }
    if (titleController.text.trim().isEmpty) {
      errors[_Field.title] = "Give the PDF a title";
    }

    // A file is only mandatory when creating: an edit keeps the one the
    // document already has.
    if (!widget.isEdit && selectedPdfBytes == null) {
      errors[_Field.file] = "Choose a PDF file to upload";
    }

    if ((_selectedType ?? "").isEmpty) {
      errors[_Field.type] = "Choose whether it is free or paid";
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

  Future<void> _onSubmit(PdfViewModel pdfViewModel) async {
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

    final PdfModel model = PdfModel(
      codeController.text.trim().toUpperCase(),
      descriptionController.text.trim(),
      titleController.text.trim(),
      widget.existing?.pdfLink ?? "",
      isDownloadable,
      _selectedType ?? stringDefault,
      widget.existing?.timeStamp ?? DateTime.now().millisecondsSinceEpoch,
      isLocked,
    );

    final bool success = widget.isEdit
        ? await pdfViewModel.updatePdf(model, widget.existing!.docId,
            file: selectedPdfBytes)
        : await pdfViewModel.createPdf(model, selectedPdfBytes!);

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (success) {
      Helper.showSnackBarMessage(
          msg: widget.isEdit
              ? "PDF updated successfully"
              : "PDF added successfully",
          isSuccess: true);
      Navigator.pop(context);
    }
  }

  void _onDelete(PdfViewModel pdfViewModel) {
    final PdfModel existing = widget.existing!;
    RemoveAlert.showRemoveAlert(
      title: existing.title,
      description: "Are you sure want to delete ?",
      onPressYes: () async {
        Navigator.pop(navigatorKey.currentContext!);
        if (mounted) setState(() => _isSaving = true);
        final bool success = await pdfViewModel.deletePdf(existing.docId);
        if (!mounted) return;
        setState(() => _isSaving = false);
        if (success) {
          Helper.showInfoMessage(msg: "PDF deleted successfully");
          Navigator.pop(context);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminFormScaffold(
      headerTitle: "PDFs",
      sidebarIndex: 6,
      body: (context, width) => Consumer<PdfViewModel>(
        builder: (context, pdfViewModel, child) => _page(pdfViewModel, width),
      ),
    );
  }

  Widget _page(PdfViewModel pdfViewModel, double width) {
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
                    FormSection(title: "PDF DETAILS", children: [
                      FormTwoUp(
                          width: width,
                          left: _textField(
                            label: "PDF code",
                            hint: "e.g. NOTES-01",
                            controller: codeController,
                            error: _errors[_Field.code],
                            onChanged: _revalidate,
                            uppercase: true,
                          ),
                          right: _typeField()),
                      const SizedBox(height: AppTokens.gapMd),
                      _textField(
                        label: "Title",
                        hint: "e.g. Kinematics — formula sheet",
                        controller: titleController,
                        error: _errors[_Field.title],
                        onChanged: _revalidate,
                      ),
                      const SizedBox(height: AppTokens.gapMd),
                      _textField(
                        label: "Description",
                        hint: "What does this PDF cover? (optional)",
                        controller: descriptionController,
                        maxLines: 4,
                      ),
                    ]),
                    const SizedBox(height: AppTokens.gapMd),
                    FormSection(title: "FILE", children: [_fileField()]),
                    const SizedBox(height: AppTokens.gapMd),
                    FormSection(title: "ACCESS", children: [
                      FormToggleRow(
                        title: "Downloadable",
                        subtitle:
                            "Students can save a copy instead of only reading it in the app.",
                        value: isDownloadable,
                        onChanged: _isSaving
                            ? null
                            : (v) => setState(() => isDownloadable = v),
                      ),
                      const FormToggleDivider(),
                      FormToggleRow(
                        title: "Locked",
                        subtitle:
                            "Students can see a locked PDF but cannot open it.",
                        value: isLocked,
                        onChanged: _isSaving
                            ? null
                            : (v) => setState(() => isLocked = v),
                      ),
                    ]),
                    const SizedBox(height: AppTokens.gapXl),
                  ],
                ),
              ),
            ),
          ),
        ),
        _actionBar(pdfViewModel, width),
      ],
    );
  }

  /// Back button, title and subtitle at the top of the page.
  Widget _pageHeader() {
    return FormPageHeader(
      title: widget.isEdit ? "Edit PDF" : "Add a PDF",
      subtitle: widget.isEdit
          ? "Update this PDF's details, file and access."
          : "Upload a PDF for students to read in the app.",
      onBack: _isSaving ? null : () => Navigator.pop(context),
    );
  }

  /// A [FormTextField] configured for this form.
  Widget _textField({
    required String label,
    required String hint,
    required TextEditingController controller,
    int maxLines = 1,
    String? error,
    VoidCallback? onChanged,
    bool uppercase = false,
    IconData? prefixIcon,
  }) {
    return FormTextField(
      label: label,
      hint: hint,
      controller: controller,
      maxLines: maxLines,
      error: error,
      onChanged: onChanged,
      prefixIcon: prefixIcon,
      inputFormatters: [if (uppercase) UpperCaseTextFormatter()],
    );
  }

  /// FREE / PAID as two segments.
  Widget _typeField() {
    return FormAccessTypeField(
      types: pdfTypeList,
      selected: _selectedType,
      keyPrefix: "pdf",
      error: _errors[_Field.type],
      enabled: !_isSaving,
      onSelect: (type) {
        setState(() => _selectedType = type);
        _revalidate();
      },
    );
  }

  Future<void> _pickFile() async {
    final FilePickerResult? picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (picked == null || !mounted) return;
    setState(() {
      selectedPdfBytes = picked.files.first.bytes;
      pdfName = picked.files.first.name;
    });
    _revalidate();
  }

  /// The old picker was a grey "Choose Pdf" chip with the file name in
  /// plain text beside it, and no way to tell whether an edit already had
  /// a file attached.
  Widget _fileField() {
    final String? error = _errors[_Field.file];
    final bool hasNew = selectedPdfBytes != null;
    final bool hasExisting = (widget.existing?.pdfLink ?? "").trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          color: hasNew ? AppTokens.surface : AppTokens.surfaceMuted,
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          child: InkWell(
            key: const Key('pdf_choose_file'),
            onTap: _isSaving ? null : _pickFile,
            borderRadius: BorderRadius.circular(AppTokens.radiusMd),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 26),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                border: Border.all(
                  color: error != null
                      ? AppTokens.danger
                      : AppTokens.inkFaint.withValues(alpha: .5),
                  width: 1.4,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                      hasNew
                          ? Icons.picture_as_pdf
                          : Icons.upload_file_outlined,
                      size: 30,
                      color: hasNew
                          ? const Color(0xFFD92D20)
                          : AppTokens.inkFaint),
                  const SizedBox(height: 10),
                  Text(
                    hasNew
                        ? (pdfName.isEmpty ? "Selected file" : pdfName)
                        : hasExisting
                            ? "Replace the current file"
                            : "Choose a PDF file",
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: AppTokens.ink),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hasNew
                        ? readableFileSize(selectedPdfBytes!.lengthInBytes)
                        : hasExisting
                            ? "A file is already attached — leave this to keep it."
                            : "PDF only.",
                    style: const TextStyle(
                        fontSize: 12, color: AppTokens.inkFaint),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (hasNew) ...[
          const SizedBox(height: AppTokens.gapSm),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _isSaving
                  ? null
                  : () => setState(() {
                        selectedPdfBytes = null;
                        pdfName = "";
                      }),
              style: TextButton.styleFrom(
                  foregroundColor: AppTokens.danger,
                  padding: const EdgeInsets.symmetric(horizontal: 10)),
              child: const Text("Remove", style: TextStyle(fontSize: 12.5)),
            ),
          ),
        ],
        if (error != null) ...[
          const SizedBox(height: 6),
          Text(error, style: AppTokens.errorText),
        ],
      ],
    );
  }

  /// Delete / Cancel / Save bar pinned to the bottom of the page.
  Widget _actionBar(PdfViewModel pdfViewModel, double width) {
    return FormActionBar(
      width: width,
      isSaving: _isSaving,
      onDelete: widget.isEdit ? () => _onDelete(pdfViewModel) : null,
      deleteTooltip: "Delete PDF",
      saveKey: const Key('pdf_save_button'),
      saveLabel: widget.isEdit ? "Update PDF" : "Save PDF",
      onSave: () => _onSubmit(pdfViewModel),
      saveMinWidth: 135,
    );
  }
}
