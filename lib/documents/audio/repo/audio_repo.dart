import 'dart:typed_data';

import 'package:bbarna/core/repo/firestore_pager.dart';
import 'package:bbarna/core/repo/storage_upload.dart';
import 'package:bbarna/documents/audio/model/audio_model.dart';
import 'package:bbarna/resources/constant.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// Firestore / Storage access for the `audio` collection.
///
/// Every method throws on failure; [AudioViewModel] catches and reports.
class AudioRepo {
  /// Firestore client.
  final FirebaseFirestore _fireStore = FirebaseFirestore.instance;

  /// Root of Firebase Storage; uploads go under it.
  final Reference storageReference = FirebaseStorage.instance.ref();

  /// The `audio` collection.
  CollectionReference<Map<String, dynamic>> get _collection =>
      _fireStore.collection(audio);

  /// Newest-first paging with the cursor kept here, not in the view model.
  late final FirestorePager _pager = FirestorePager(_collection);

  /// Converts raw documents into models.
  List<AudioModel> _toModels(List<FirestoreDoc> docs) =>
      docs.map((doc) => AudioModel.fromDocumentSnapshot(doc)).toList();

  /// Adds a clip and returns the new document's id.
  Future<String> addAudio(AudioModel audioModel) async {
    final DocumentReference<Map<String, dynamic>> doc =
        await _collection.add(audioModel.toMap());
    return doc.id;
  }

  /// First page, newest first. Resets the paging cursor.
  Future<List<AudioModel>> getFirstAudioList(int limit) async =>
      _toModels(await _pager.firstPage(limit));

  /// The page after the last one returned (empty when there is none).
  Future<List<AudioModel>> getNextAudioList(int limit) async =>
      _toModels(await _pager.nextPage(limit));

  /// Overwrites the clip's fields.
  Future<void> updateAudio(AudioModel audioModel, String docId) async {
    await _collection.doc(docId).update(audioModel.toMap());
  }

  /// Deletes the clip document.
  Future<void> deleteAudio(String docId) async {
    await _collection.doc(docId).delete();
  }

  /// Uploads [audioData] and stores its download URL on document
  /// [audioId]. The storage file is keyed by document id (ids are unique,
  /// codes are not).
  Future<void> uploadAudio(Uint8List audioData, String audioId) async {
    final String url = await uploadToStorage(
      storageReference.child("audio").child("audio_$audioId"),
      audioData,
      contentType: sniffAudioContentType(audioData),
    );
    await _collection.doc(audioId).update({"audio_link": url});
  }

  /// Total clips in the collection.
  Future<int> getAudioListLength() => countDocuments(_collection);

  /// Clips whose `audio_code` starts with [searchText].
  Future<List<AudioModel>> searchAudio(String searchText) async =>
      _toModels(await prefixSearch(_collection, "audio_code", searchText));
}

/// Content type from the file's first bytes, for the formats the Audio form
/// accepts (mp3, m4a, wav, aac). Defaults to MP3.
String sniffAudioContentType(Uint8List bytes) {
  bool startsWith(String ascii, [int offset = 0]) =>
      bytes.length >= offset + ascii.length &&
      String.fromCharCodes(bytes.sublist(offset, offset + ascii.length)) ==
          ascii;
  if (startsWith("RIFF") && startsWith("WAVE", 8)) return "audio/wav";
  if (startsWith("ftyp", 4)) return "audio/mp4";
  // ADTS AAC: 12-bit sync word, then layer bits 00 (MP3 frames have 01).
  if (bytes.length >= 2 && bytes[0] == 0xFF && (bytes[1] & 0xF6) == 0xF0) {
    return "audio/aac";
  }
  return "audio/mpeg";
}
