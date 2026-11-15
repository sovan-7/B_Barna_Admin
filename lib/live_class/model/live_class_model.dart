import 'package:bbarna/resources/constant.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Which bucket a class falls into on the [LiveClassList] tabs. Derived from
/// the class's start/end window against the current time — never stored in
/// Firestore, so it can't go stale.
enum LiveClassStatus { upcoming, live, past }

/// Tab / badge text for each [LiveClassStatus].
extension LiveClassStatusLabel on LiveClassStatus {
  /// "Upcoming", "Live" or "Past".
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

/// Where a class's chat (Realtime Database `live_rooms/{docId}/messages`)
/// stands. The admin requests the delete; a Cloud Function carries it out.
enum LiveClassChatState { none, deleting, deleted }

/// A scheduled live class (`liveClasses` collection), in the field names
/// the student app reads.
class LiveClassModel {
  /// [classType] of a class any student can open, bought or not.
  static const String liveClassFree = "Free";

  /// [classType] of a class only students who bought the subject can open.
  /// The student app treats a class saved without a type as this.
  static const String liveClassPaid = "Paid";

  /// "Free" or "Paid" (`classType`), in the exact casing the student app
  /// stores and compares.
  String classType = liveClassPaid;

  /// When the admin asked for the chat to be deleted
  /// (`chatDeleteRequestedAt`); cleared by the Cloud Function once done.
  /// Never written through [toMap], so editing a class can't wipe it.
  DateTime? chatDeleteRequestedAt;

  /// When the Cloud Function deleted the chat (`chatDeletedAt`). Never
  /// written through [toMap].
  DateTime? chatDeletedAt;

  /// Firestore document id.
  String docId = stringDefault;

  /// Class title (`title`).
  String title = stringDefault;

  /// Short description (`subtitle`).
  String description = stringDefault;

  /// YouTube live link (`youtubeVideoLink`).
  String youtubeLink = stringDefault;

  /// Teacher's display name (`teacherName`).
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

  /// Display names of the subjects this class is for, in the order they
  /// were ticked (`subjects`). Index-aligned with [subjectCodes]; the
  /// student app prints the name of the subject being browsed on the card.
  List<String> subjectNames;

  /// The subjects' `subject_code`s, in the same order (`subjectIds`). The
  /// student app lists a subject's classes by looking its code up here.
  /// Codes, not document ids: the join key every other collection in this
  /// project uses (`subject_code`, `subjectCodeList`).
  List<String> subjectCodes;

  /// The first subject's name, also stored alone under `subject`: app
  /// versions from before multi-subject classes read only that.
  String get subject => subjectNames.isEmpty ? "" : subjectNames.first;

  /// The first subject's code, also stored alone under `subjectId` — the
  /// only subject older app versions list the class under.
  String get subjectCode => subjectCodes.isEmpty ? "" : subjectCodes.first;

  /// When the class starts (`startTime`).
  DateTime startDateTime;

  /// When the class ends (`endTime`); always the same day as the start.
  DateTime endDateTime;

  /// Written server-side by [LiveClassRepo] with `FieldValue.serverTimestamp()`
  /// — null only for a locally-built model that hasn't round-tripped through
  /// Firestore yet.
  DateTime? createdAt;

  /// Server time of the last edit (`updatedAt`).
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

  /// Creates a class from the Add/Edit form values.
  LiveClassModel({
    required this.docId,
    required this.title,
    required this.description,
    required this.youtubeLink,
    required this.teacherName,
    required this.startDateTime,
    required this.endDateTime,
    this.teacherId = "",
    this.teacherPhone = "",
    this.subjectNames = const [],
    this.subjectCodes = const [],
    this.classType = liveClassPaid,
    this.createdAt,
    this.updatedAt,
    this.chatDeleteRequestedAt,
    this.chatDeletedAt,
  }) : assert(subjectNames.length == subjectCodes.length,
            "subjectNames and subjectCodes are index-aligned");

  /// The caller-editable fields only (`createdAt` / `updatedAt` are set by
  /// [LiveClassRepo] from the server clock), in the field names the student
  /// app reads:
  ///
  ///   `subtitle` (not description), `youtubeVideoLink` (not youtubeLink),
  ///   `subjectId`, `teacherId`, and `startTime`/`endTime` as epoch
  ///   milliseconds (not `startDateTime`/`endDateTime` Timestamps).
  ///
  /// The panel adapts to the app (not the other way round) because the
  /// panel updates everywhere at once, while an app change only reaches
  /// users who update. That is also why every subject goes under
  /// `subjects`/`subjectIds` while the first one is repeated under
  /// `subject`/`subjectId`: an app that predates multi-subject classes still
  /// lists the class under that first subject.
  Map<String, dynamic> toMap() {
    return {
      "title": title.trim(),
      "subtitle": description.trim(),
      "subject": subject.trim(),
      "subjectId": subjectCode.trim(),
      "subjects": [for (final String name in subjectNames) name.trim()],
      "subjectIds": [for (final String code in subjectCodes) code.trim()],
      "teacherName": teacherName.trim(),
      "teacherId": teacherId.trim(),
      "teacherPhone": teacherPhone.trim(),
      "youtubeVideoLink": youtubeLink.trim(),
      "classType": classType,
      "startTime": startDateTime.millisecondsSinceEpoch,
      "endTime": endDateTime.millisecondsSinceEpoch,
    };
  }

  /// Reads the app's key names, falling back to the older ones this panel
  /// wrote. Classes saved in the old shape still open and list correctly;
  /// re-saving one rewrites it in the current shape.
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
        subjectNames = [
          for (final (String, String) s in subjectsOf(doc.data())) s.$2
        ],
        subjectCodes = [
          for (final (String, String) s in subjectsOf(doc.data())) s.$1
        ],
        classType = normalizeClassType(doc.data()?["classType"]),
        chatDeleteRequestedAt =
            _toDateTime(doc.data()?["chatDeleteRequestedAt"]),
        chatDeletedAt = _toDateTime(doc.data()?["chatDeletedAt"]),
        startDateTime = _toDateTime(doc.data()?["startTime"]) ??
            _toDateTime(doc.data()?["startDateTime"]) ??
            DateTime.fromMillisecondsSinceEpoch(0),
        endDateTime = _toDateTime(doc.data()?["endTime"]) ??
            _toDateTime(doc.data()?["endDateTime"]) ??
            DateTime.fromMillisecondsSinceEpoch(0),
        createdAt = _toDateTime(doc.data()?["createdAt"]),
        updatedAt = _toDateTime(doc.data()?["updatedAt"]),
        needsAppSync = doc.data()?["startTime"] == null;

  /// "Free" for anything the app would read as free (it compares
  /// case-insensitively); "Paid" for everything else, missing included —
  /// the app's own default.
  static String normalizeClassType(dynamic value) =>
      value?.toString().trim().toLowerCase() == "free"
          ? liveClassFree
          : liveClassPaid;

  /// True for a Free class.
  bool get isFree => classType == liveClassFree;

  /// The stored subjects as (code, name) pairs, in order.
  ///
  /// Reads the `subjectIds`/`subjects` lists; a class saved before those
  /// existed has only `subjectId`/`subject`, read as a one-subject list.
  /// Entries blank in both code and name are dropped, and a missing name
  /// reads as "", so the two lists always come back the same length.
  static List<(String, String)> subjectsOf(Map<String, dynamic>? data) {
    String text(Object? value) => value?.toString().trim() ?? "";
    final Object? codes = data?["subjectIds"];
    final Object? names = data?["subjects"];
    if (codes is List && codes.isNotEmpty) {
      final List<Object?> nameList = names is List ? names : const [];
      return [
        for (int i = 0; i < codes.length; i++)
          (text(codes[i]), i < nameList.length ? text(nameList[i]) : ""),
      ].where((s) => s.$1.isNotEmpty || s.$2.isNotEmpty).toList();
    }
    final String code = text(data?["subjectId"]);
    final String name = text(data?["subject"]);
    if (code.isEmpty && name.isEmpty) return [];
    return [(code, name)];
  }

  /// Deleted once the function stamped [chatDeletedAt] — unless a newer
  /// request is still pending, which wins.
  LiveClassChatState get chatState {
    final DateTime? requested = chatDeleteRequestedAt;
    final DateTime? deleted = chatDeletedAt;
    if (requested != null &&
        (deleted == null || requested.isAfter(deleted))) {
      return LiveClassChatState.deleting;
    }
    if (deleted != null) return LiveClassChatState.deleted;
    return LiveClassChatState.none;
  }

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

  /// [statusAt] for the current time.
  LiveClassStatus get status => statusAt(DateTime.now());
}
