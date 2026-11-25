import 'dart:typed_data';

import 'package:bbarna/documents/audio/model/audio_model.dart';
import 'package:bbarna/documents/audio/repo/audio_repo.dart';
import 'package:bbarna/resources/constant.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

// Audio uploads used to be stored as PDFs and their URL saved as `pdf_link`,
// which AudioModel never read. These pin down the fix and the fallback for
// clips saved while the bug was live.

// ignore: subtype_of_sealed_class
class _MockDoc extends Mock implements DocumentSnapshot<Map<String, dynamic>> {}

AudioModel _read(Map<String, dynamic> data) {
  final _MockDoc doc = _MockDoc();
  when(() => doc.id).thenReturn('a1');
  when(() => doc.data()).thenReturn(data);
  return AudioModel.fromDocumentSnapshot(doc);
}

Uint8List _bytes(List<int> head) =>
    Uint8List.fromList([...head, ...List<int>.filled(16, 0)]);

void main() {
  group('sniffAudioContentType', () {
    test('MP3 with an ID3 tag', () {
      expect(sniffAudioContentType(_bytes('ID3'.codeUnits)), 'audio/mpeg');
    });

    test('bare MP3 frame', () {
      expect(sniffAudioContentType(_bytes([0xFF, 0xFB])), 'audio/mpeg');
    });

    test('WAV', () {
      expect(
          sniffAudioContentType(
              _bytes([...'RIFF'.codeUnits, 0, 0, 0, 0, ...'WAVE'.codeUnits])),
          'audio/wav');
    });

    test('M4A', () {
      expect(
          sniffAudioContentType(_bytes([0, 0, 0, 0x20, ...'ftyp'.codeUnits])),
          'audio/mp4');
    });

    test('ADTS AAC', () {
      expect(sniffAudioContentType(_bytes([0xFF, 0xF1])), 'audio/aac');
    });

    test('never a PDF', () {
      expect(sniffAudioContentType(_bytes('%PDF'.codeUnits)), 'audio/mpeg');
    });
  });

  group('AudioModel link', () {
    test('reads audio_link', () {
      expect(_read({'audio_link': 'https://a'}).link, 'https://a');
    });

    test('falls back to pdf_link when audio_link is the placeholder', () {
      expect(
          _read({'audio_link': stringDefault, 'pdf_link': 'https://old'}).link,
          'https://old');
    });

    test('falls back to pdf_link when audio_link is missing', () {
      expect(_read({'pdf_link': 'https://old'}).link, 'https://old');
    });

    test('prefers audio_link over a stale pdf_link', () {
      expect(
          _read({'audio_link': 'https://new', 'pdf_link': 'https://old'}).link,
          'https://new');
    });

    test('is the placeholder when neither is set', () {
      expect(_read({}).link, stringDefault);
    });
  });
}
