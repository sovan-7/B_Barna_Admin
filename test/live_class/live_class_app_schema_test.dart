import 'package:bbarna/live_class/model/live_class_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

/// The contract between this panel and the student app.
///
/// The app reads `live_classes` directly with its own `LiveClassModel`
/// (`b_barna_app/lib/liveClass/models/live_class_model.dart`) — there is no
/// shared package between the two projects, so nothing but a test stops the
/// two schemas drifting apart. They already had: the panel wrote
/// `startDateTime` as a Timestamp while the app read `startTime` as epoch
/// millis, so every class the panel created reached students with
/// `startTime: 0` and was filed under Past the moment it was saved.
///
/// If a rename here breaks one of these expectations, it breaks the app.
void main() {
  LiveClassModel model({
    DateTime? start,
    DateTime? end,
    List<String> subjectNames = const ["Mechanics"],
    List<String> subjectCodes = const ["MECH"],
    String teacherId = "ravi",
    String teacherPhone = "9876543210",
  }) =>
      LiveClassModel(
        docId: 'doc1',
        title: "  Kinematics  ",
        description: "  Motion in a straight line  ",
        youtubeLink: "  https://youtu.be/abc  ",
        teacherName: "  Ravi Kumar  ",
        teacherId: teacherId,
        teacherPhone: teacherPhone,
        subjectNames: subjectNames,
        subjectCodes: subjectCodes,
        startDateTime: start ?? DateTime(2026, 4, 2, 18, 0),
        endDateTime: end ?? DateTime(2026, 4, 2, 19, 30),
      );

  group('toMap writes the keys the app reads', () {
    test('exactly those keys, and no others', () {
      expect(
        model().toMap().keys.toSet(),
        {
          'title',
          'subtitle',
          'subject',
          'subjectId',
          'subjects',
          'subjectIds',
          'teacherName',
          'teacherId',
          'teacherPhone',
          'youtubeVideoLink',
          'classType',
          'startTime',
          'endTime',
        },
      );
    });

    test('times are epoch milliseconds, not Timestamps', () {
      final DateTime start = DateTime(2026, 4, 2, 18, 0);
      final DateTime end = DateTime(2026, 4, 2, 19, 30);
      final Map<String, dynamic> map = model(start: start, end: end).toMap();

      // `map['startTime'] ?? 0` in the app: a Timestamp here would not
      // throw, it would simply be a Timestamp where an int was expected.
      expect(map['startTime'], isA<int>());
      expect(map['endTime'], isA<int>());
      expect(map['startTime'], start.millisecondsSinceEpoch);
      expect(map['endTime'], end.millisecondsSinceEpoch);
      expect(map['startTime'], isNot(0),
          reason: 'a zero start files the class under Past in the app');
    });

    test('the text fields are trimmed and mapped to their app names', () {
      final Map<String, dynamic> map = model().toMap();

      expect(map['title'], 'Kinematics');
      // The app calls it subtitle; this panel calls it description.
      expect(map['subtitle'], 'Motion in a straight line');
      // The app calls it youtubeVideoLink; this panel calls it youtubeLink.
      expect(map['youtubeVideoLink'], 'https://youtu.be/abc');
      expect(map['teacherName'], 'Ravi Kumar');
    });

    test('the subject code lands under subjectId', () {
      final Map<String, dynamic> map = model(
          subjectNames: const ["Organic Chemistry"],
          subjectCodes: const ["ORG"]).toMap();

      expect(map['subject'], 'Organic Chemistry');
      // Named `subjectId` because that is what the app reads, but it holds
      // the code — the join key the rest of the project uses.
      expect(map['subjectId'], 'ORG');
      expect(map['subjects'], ['Organic Chemistry']);
      expect(map['subjectIds'], ['ORG']);
    });

    test('every subject goes in the lists; the first also stands alone', () {
      final Map<String, dynamic> map = model(
        subjectNames: const ["Mathematics", " Physics ", "WBCS Foundation"],
        subjectCodes: const ["MATH", "PHY ", "WBCS"],
      ).toMap();

      // The new app lists the class under each of these codes.
      expect(map['subjectIds'], ['MATH', 'PHY', 'WBCS']);
      expect(map['subjects'], ['Mathematics', 'Physics', 'WBCS Foundation']);
      // An app from before multi-subject classes reads only these, and so
      // still lists the class under the first subject.
      expect(map['subjectId'], 'MATH');
      expect(map['subject'], 'Mathematics');
    });
  });

  group('reading the subjects back', () {
    test('the lists, in order', () {
      expect(
        LiveClassModel.subjectsOf({
          'subjectIds': ['MATH', 'PHY'],
          'subjects': ['Mathematics', 'Physics'],
          'subjectId': 'MATH',
          'subject': 'Mathematics',
        }),
        [('MATH', 'Mathematics'), ('PHY', 'Physics')],
      );
    });

    test('a class saved before the lists reads as one subject', () {
      expect(
        LiveClassModel.subjectsOf(
            {'subjectId': 'MECH', 'subject': 'Mechanics'}),
        [('MECH', 'Mechanics')],
      );
      expect(LiveClassModel.subjectsOf({'subject': 'Mechanics'}),
          [('', 'Mechanics')]);
      expect(LiveClassModel.subjectsOf({}), isEmpty);
      expect(LiveClassModel.subjectsOf(null), isEmpty);
    });

    test('a short names list pads with "", blank entries are dropped', () {
      expect(
        LiveClassModel.subjectsOf({
          'subjectIds': ['MATH', '', 'PHY'],
          'subjects': ['Mathematics'],
        }),
        [('MATH', 'Mathematics'), ('PHY', '')],
      );
    });

    test('an unresolved teacher writes an empty id, never a stale one', () {
      final Map<String, dynamic> map = model(teacherId: "").toMap();

      // A typed name, or one kept from a deleted teacher. Empty means the
      // app marks nobody as the teacher — better than badging whoever the
      // previous pick was.
      expect(map['teacherId'], '');
      expect(map['teacherName'], 'Ravi Kumar');
    });

    test('the teacher phone number is trimmed and written under teacherPhone',
        () {
      final Map<String, dynamic> map =
          model(teacherPhone: "  9876543210  ").toMap();

      expect(map['teacherPhone'], '9876543210');
    });

    test('an unresolved teacher writes an empty phone, never a stale one',
        () {
      final Map<String, dynamic> map = model(teacherPhone: "").toMap();

      expect(map['teacherPhone'], '');
    });

    test('no Timestamp survives anywhere in the map', () {
      for (final MapEntry<String, dynamic> entry in model().toMap().entries) {
        expect(entry.value, isNot(isA<Timestamp>()),
            reason: '${entry.key} would reach the app as a Timestamp');
      }
    });
  });
}
