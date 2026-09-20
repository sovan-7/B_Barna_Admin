import 'package:bbarna/resources/constant.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Which bucket a class falls into on the [LiveClassList] tabs. Derived from
/// the class's start/end window against the current time — never stored in
/// Firestore, so it can't go stale.
enum LiveClassStatus { upcoming, live, past }

extension LiveClassStatusLabel on LiveClassStatus {
  String get label {
    switch (this) {
      case LiveClassStatus.upcoming:
        return "Upcoming";
      case LiveClassStatus.live:
        return "Live";
      case LiveClassStatus.past:
        return "Past";
    }
  }
}

class LiveClassModel {
  String docId = stringDefault;
  String title = stringDefault;
  String description = stringDefault;
  String youtubeLink = stringDefault;
  String teacherName = stringDefault;

  /// The teacher's document id in the `teacher` collection.
  ///
  /// The student app compares this against the uid a participant joined the
  /// live room under, to mark who is teaching in chat and the people list.
  /// Empty when the name was typed by hand rather than picked.
  ///
  /// Defaults to "" and not [stringDefault]: these three reach the student
  /// app verbatim, and "NA" would be drawn on the card as the literal text
  /// "NA" where an empty string draws nothing.
  String teacherId = "";

  /// The picked teacher's phone number, copied from the `teacher` collection
  /// at save time. Not read by the student app today — kept here purely so
  /// admins can see who to call about a class without opening Teachers.
  /// Empty under the same conditions as [teacherId]: a hand-typed name, or a
  /// removed teacher.
  String teacherPhone = "";

  /// The subject's display name, shown on the class card in the app.
  String subject = "";

  /// The subject's `subject_code`. Stored under `subjectId` because that is
  /// the key the app reads, but it holds the code — the join key every other
  /// collection in this project uses (`subject_code`, `subjectCodeList`).
  String subjectCode = "";

  DateTime startDateTime;
  DateTime endDateTime;

  /// Written server-side by [LiveClassRepo] with `FieldValue.serverTimestamp()`
  /// — null only for a locally-built model that hasn't round-tripped through
  /// Firestore yet.
  DateTime? createdAt;
  DateTime? updatedAt;

  /// True for a document still written in this panel's original shape —
  /// `startDateTime`/`endDateTime` Timestamps rather than the `startTime`/
  /// `endTime` millis the student app reads.
  ///
  /// The panel itself reads such a class correctly (see the fallbacks in
  /// [LiveClassModel.fromDocumentSnapshot]) but the app does not: it gets
  /// `startTime: 0`, which files the class under Past however far in the
  /// future it is scheduled. That is why a class can read Upcoming here and
  /// Past there at the same moment.
  ///
  /// Set from the raw document, so it says what is *stored*, not what was
  /// parsed. Never written to Firestore.
  bool needsAppSync = false;

  LiveClassModel({
    required this.docId ,
    required this.title,
    required this.description,
    required this.youtubeLink,
    required this.teacherName,
    required this.startDateTime,
    required this.endDateTime,
    this.teacherId = "",
    this.teacherPhone = "",
    this.subject = "",
    this.subjectCode = "",
    this.createdAt,
    this.updatedAt,
  });

  /// Only the caller-editable fields. `createdAt`/`updatedAt` are owned by
  /// [LiveClassRepo] so the server clock — not the admin's browser — decides
  /// them.
  ///
  /// **These key names are the student app's, not this panel's.** The app
  /// reads `live_classes` directly with its own `LiveClassModel.fromMap`,
  /// and it is the shipped side — a rename here reaches every student the
  /// moment this panel deploys, where a rename there only reaches whoever
  /// updates. So the panel writes what the app already reads:
  ///
  ///   `subtitle` (not description), `youtubeVideoLink` (not youtubeLink),
  ///   `subjectId`, `teacherId`, and `startTime`/`endTime` as epoch
  ///   milliseconds (not `startDateTime`/`endDateTime` Timestamps).
  ///
  /// Before this, none of those lined up: a class saved here reached the app
  /// with `startTime: 0`, which put it in the Past bucket the instant it was
  /// created, so it never appeared under Live or Upcoming at all.
  Map<String, dynamic> toMap() {
    return {
      "title": title.trim(),
      "subtitle": description.trim(),
      "subject": subject.trim(),
      "subjectId": subjectCode.trim(),
      "teacherName": teacherName.trim(),
      "teacherId": teacherId.trim(),
      "teacherPhone": teacherPhone.trim(),
      "youtubeVideoLink": youtubeLink.trim(),
      "startTime": startDateTime.millisecondsSinceEpoch,
      "endTime": endDateTime.millisecondsSinceEpoch,
    };
  }

  /// Reads the app's key names, falling back to the ones this panel used to
  /// write. Classes created before the schema was aligned keep opening and
  /// listing correctly here; re-saving one rewrites it in the new shape.
  LiveClassModel.fromDocumentSnapshot(
      DocumentSnapshot<Map<String, dynamic>> doc)
      : docId = doc.id,
        title = doc.data()?["title"] ?? stringDefault,
        description = doc.data()?["subtitle"] ??
            doc.data()?["description"] ??
            stringDefault,
        youtubeLink = doc.data()?["youtubeVideoLink"] ??
            doc.data()?["youtubeLink"] ??
            stringDefault,
        teacherName = doc.data()?["teacherName"] ?? stringDefault,
        teacherId = doc.data()?["teacherId"] ?? "",
        teacherPhone = doc.data()?["teacherPhone"] ?? "",
        subject = doc.data()?["subject"] ?? "",
        subjectCode = doc.data()?["subjectId"] ?? "",
        startDateTime = _toDateTime(doc.data()?["startTime"]) ??
            _toDateTime(doc.data()?["startDateTime"]) ??
            DateTime.fromMillisecondsSinceEpoch(0),
        endDateTime = _toDateTime(doc.data()?["endTime"]) ??
            _toDateTime(doc.data()?["endDateTime"]) ??
            DateTime.fromMillisecondsSinceEpoch(0),
        createdAt = _toDateTime(doc.data()?["createdAt"]),
        updatedAt = _toDateTime(doc.data()?["updatedAt"]),
        needsAppSync = doc.data()?["startTime"] == null;

  /// Tolerates the three shapes a date can arrive in: a Firestore
  /// [Timestamp] (what we write), an int of millis (what a hand-edited or
  /// legacy doc might hold), or missing/garbage (null).
  static DateTime? _toDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return null;
  }

  /// Live is inclusive of both edges, so a class is never briefly in no
  /// bucket at all at the exact start/end instant.
  LiveClassStatus statusAt(DateTime now) {
    if (now.isBefore(startDateTime)) return LiveClassStatus.upcoming;
    if (now.isAfter(endDateTime)) return LiveClassStatus.past;
    return LiveClassStatus.live;
  }

  LiveClassStatus get status => statusAt(DateTime.now());
}
