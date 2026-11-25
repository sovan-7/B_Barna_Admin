import 'package:bbarna/resources/constant.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// One PDF in the `pdf` collection; topics attach it by its code.
class PdfModel {
  /// Firestore document id (not stored inside the document).
  String docId = stringDefault;

  /// PDF code, stored upper-case (`pdf_code`).
  String code = stringDefault;

  /// Creation time in epoch milliseconds (`timeStamp`); lists sort newest
  /// first on it.
  int timeStamp = intDefault;

  /// Display title (`pdf_title`).
  String title = stringDefault;

  /// Free-text description (`pdf_description`).
  String description = stringDefault;

  /// Download URL of the uploaded file (`pdf_link`).
  String pdfLink = stringDefault;

  /// "FREE" or "PAID" (`pdf_type`).
  String pdfType = stringDefault;

  /// Whether students may download it, or only view it (`is_downloadable`).
  bool isDownloadable = boolDefault;

  /// Visible but not openable in the app (`is_locked`).
  bool isLocked = boolDefault;

  /// Creates a PDF from the Add/Edit form values.
  PdfModel(
    this.code,
    this.description,
    this.title,
    this.pdfLink,
    this.isDownloadable,
    this.pdfType,
    this.timeStamp,
    this.isLocked,
  );

  /// Converts this model to the Firestore document map (field names as
  /// stored in the collection).
  Map<String, dynamic> toMap() {
    return {
      "pdf_code": code.trim(),
      "pdf_description": description,
      "pdf_title": title,
      "timeStamp": timeStamp,
      "pdf_link": pdfLink,
      "pdf_type": pdfType,
      "is_downloadable": isDownloadable,
      "is_locked": isLocked
    };
  }

  /// Reads a Firestore document; missing fields fall back to the
  /// `*Default` placeholders from `constant.dart`.
  PdfModel.fromDocumentSnapshot(DocumentSnapshot<Map<String, dynamic>> doc)
      : docId = doc.id,
        code = doc.data()!["pdf_code"] ?? stringDefault,
        description = doc.data()!["pdf_description"] ?? stringDefault,
        title = doc.data()!["pdf_title"] ?? stringDefault,
        pdfLink = doc.data()!["pdf_link"] ?? stringDefault,
        pdfType = doc.data()!["pdf_type"] ?? stringDefault,
        isDownloadable = doc.data()!["is_downloadable"] ?? boolDefault,
        timeStamp = doc.data()!["timeStamp"] ?? intDefault,
        isLocked = doc.data()!["is_locked"] ?? boolDefault;
}
