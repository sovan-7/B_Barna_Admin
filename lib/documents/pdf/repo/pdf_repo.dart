import 'dart:typed_data';

import 'package:bbarna/core/repo/firestore_pager.dart';
import 'package:bbarna/core/repo/storage_upload.dart';
import 'package:bbarna/documents/pdf/model/pdf_model.dart';
import 'package:bbarna/resources/constant.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// Firestore / Storage access for the `pdf` collection.
///
/// Every method throws on failure; [PdfViewModel] catches and reports.
class PdfRepo {
  /// Firestore client.
  final FirebaseFirestore _fireStore = FirebaseFirestore.instance;

  /// Root of Firebase Storage; uploads go under it.
  final Reference storageReference = FirebaseStorage.instance.ref();

  /// The `pdf` collection.
  CollectionReference<Map<String, dynamic>> get _collection =>
      _fireStore.collection(pdf);

  /// Newest-first paging with the cursor kept here, not in the view model.
  late final FirestorePager _pager = FirestorePager(_collection);

  /// Converts raw documents into models.
  List<PdfModel> _toModels(List<FirestoreDoc> docs) =>
      docs.map((doc) => PdfModel.fromDocumentSnapshot(doc)).toList();

  /// Adds a PDF and returns the new document's id.
  Future<String> addPdf(PdfModel pdfModel) async {
    final DocumentReference<Map<String, dynamic>> doc =
        await _collection.add(pdfModel.toMap());
    return doc.id;
  }

  /// First page, newest first. Resets the paging cursor.
  Future<List<PdfModel>> getFirstPdfList(int limit) async =>
      _toModels(await _pager.firstPage(limit));

  /// The page after the last one returned (empty when there is none).
  Future<List<PdfModel>> getNextPdfList(int limit) async =>
      _toModels(await _pager.nextPage(limit));

  /// Overwrites the PDF's fields.
  Future<void> updatePdf(PdfModel pdfModel, String docId) async {
    await _collection.doc(docId).update(pdfModel.toMap());
  }

  /// Deletes the PDF document.
  Future<void> deletePdf(String docId) async {
    await _collection.doc(docId).delete();
  }

  /// Uploads [pdfData] to `pdf/pdf_<pdfId>` and stores its download URL as
  /// `pdf_link`. Keyed by document id because PDF codes are not unique.
  Future<void> uploadPdf(Uint8List pdfData, String pdfId) async {
    final String url = await uploadToStorage(
      storageReference.child("pdf").child("pdf_$pdfId"),
      pdfData,
      contentType: 'application/pdf',
    );
    await _collection.doc(pdfId).update({"pdf_link": url});
  }

  /// Sets one boolean [field] (`is_locked`, `is_downloadable`) on a PDF.
  Future<void> setPdfFlag(String pdfId, String field, bool value) async {
    await _collection.doc(pdfId).update({field: value});
  }

  /// Total PDFs in the collection.
  Future<int> getPdfListLength() => countDocuments(_collection);

  /// PDFs whose `pdf_code` starts with [searchText].
  Future<List<PdfModel>> searchPdf(String searchText) async =>
      _toModels(await prefixSearch(_collection, "pdf_code", searchText));
}
