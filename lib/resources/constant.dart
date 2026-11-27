import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App-wide messenger key, so toasts can be shown without a BuildContext.
final GlobalKey<ScaffoldMessengerState> snackBarKey =
    GlobalKey<ScaffoldMessengerState>();

/// App-wide navigator key, so dialogs can be closed from view models and
/// helpers that have no BuildContext.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Key given to the root MaterialApp.
final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey();

/// Local key/value storage (session, module access, rail state). Set in
/// `main` before the app starts; throws if read before that (e.g. tests).
late SharedPreferences sharedPreferences;

// ---- "No value" placeholders ------------------------------------------
//
// Models fill missing Firestore fields with these instead of null. Checks
// such as `value == stringDefault` mean "this field was never set".

/// Placeholder for a missing int field.
int intDefault = -1;

/// Placeholder for a missing double field.
double doubleDefault = -1;

/// Placeholder for a missing bool field.
bool boolDefault = false;

/// Placeholder for a missing string field.
String stringDefault = "NA";

// ---- Firestore collection names ------------------------------------------

/// `admin` collection.
const String admin = "admin";

/// `question` collection.
const String question = "question";

/// `course` collection.
const String course = "course";

/// `subject` collection.
const String subject = "subject";

/// `unit` collection.
const String unit = "unit";

/// `topic` collection.
const String topic = "topic";

/// `topics` collection, written by the New Topics module (`Topic1…` in
/// code): topics whose PDFs are uploaded and whose videos are YouTube links,
/// both stored on the topic itself rather than attached by code (see
/// `Topic1Model`). The module's one-time copy fills it from [topic]
/// (`Topic1Repo.copyFromTopics`).
const String topics = "topics";

/// `video` collection.
const String video = "video";

/// `pdf` collection.
const String pdf = "pdf";

/// `audio` collection.
const String audio = "audio";

/// `quiz` collection.
const String quiz = "quiz";

/// `banners` collection.
const String banners = "banners";

/// `student` collection (written by the mobile app).
const String student = "student";

/// `enrolledCourses` collection: one enrolment document per student.
const String enrolledCourse = "enrolledCourses";

/// `teacher` collection: admin-panel users.
const String teacher = "teacher";

/// `live_classes` collection.
const String liveClasses = "live_classes";

/// `books` collection: printed books sold in the student app.
const String books = "books";

/// `book_orders` collection: paid book orders, written by the student app.
const String bookOrders = "book_orders";

/// `transactions` collection: every purchase, written by the student app.
/// Read-only here.
const String transactions = "transactions";

/// `notifications` collection: push notifications sent from the panel. A
/// new document is sent to every app user by the `sendAdminNotification`
/// Cloud Function.
const String notifications = "notifications";

/// `subject_groups/{groupId}/messages`: what admins post to a subject's
/// group, read by the student app's Group tab. See `GroupMessage`.
const String subjectGroups = "subject_groups";

/// Sub-collection of a [subjectGroups] document holding its messages.
const String groupMessages = "messages";

/// `app_settings` collection: one document per feature with values the
/// admin can change. `app_settings/books` holds `delivery_charge`.
const String appSettings = "app_settings";

/// Document id of the book shop's settings inside [appSettings].
const String bookSettingsDoc = "books";

/// Sidebar module names/icons, index-aligned. [Sidebar] and [ExtraSideBar]
/// render navigation from this list; [AddTeacher] generates its
/// module-access checkboxes from the same list so the two never drift apart.
const List<String> moduleList = [
  "BANNERS",
  "COURSES",
  "SUBJECT",
  "UNIT",
  "TOPIC",
  "VIDEOS",
  "PDF",
  "AUDIO",
  "QUIZ",
  "QUESTIONS",
  "STUDENTS",
  "TEACHERS",
  "LIVE CLASSES",
  "BOOKS",
  "BOOK ORDERS",
  "NOTIFICATIONS",
  "TRANSACTIONS",
  "TOPIC1",
  "QUESTION1",
];

/// Modules switched off for everyone, admins included. They stay in
/// [moduleList] and its index-aligned lists so no other module's position
/// moves; remove an index from here to bring its module back.
const Set<int> hiddenModuleIndices = {
  bookModuleIndex,
  bookOrderModuleIndex,
  question1ModuleIndex,
};

/// The `course_type` of a subject that is a full course. Only these
/// subjects get live classes (the student app shows its Live Class tab on
/// full courses only).
const String courseTypeFullCourse = "Full Course";

/// What a teacher's access can be chosen from: everything except modules
/// only an admin may ever open and modules switched off for everyone.
final List<String> assignableModuleList = [
  for (final int i in moduleNavOrder)
    if (i != transactionModuleIndex && !hiddenModuleIndices.contains(i))
      moduleList[i],
];

/// Every position in [moduleList], in the order the sidebar (and the
/// teacher module chips) list them.
///
/// New modules are appended to [moduleList] so no stored position moves,
/// but some belong next to an older one on screen: Topic1 is listed right
/// after Topics.
final List<int> moduleNavOrder = [
  for (int i = 0; i < moduleList.length; i++)
    if (i != topic1ModuleIndex) ...[
      i,
      if (i == topicModuleIndex) topic1ModuleIndex,
    ],
];

/// One heading in the sidebar and the modules listed under it.
class ModuleGroup {
  /// Heading shown above the modules ("Content") and the first part of the
  /// header's breadcrumb.
  final String label;

  /// Positions in [moduleList], in the order they are listed.
  final List<int> modules;

  const ModuleGroup(this.label, this.modules);
}

/// How the sidebar groups the modules. Display only: a module's identity
/// stays its [moduleList] string, and access checks still go through
/// `Helper.allowedModuleIndices`. Every position in [moduleList] appears in
/// exactly one group (hidden ones too, so un-hiding one needs no change
/// here); groups the signed-in teacher can open nothing in are not shown.
const List<ModuleGroup> moduleGroups = [
  ModuleGroup("Content", [
    courseModuleIndex,
    subjectModuleIndex,
    unitModuleIndex,
    topicModuleIndex,
    topic1ModuleIndex,
  ]),
  ModuleGroup("Media", [videoModuleIndex, pdfModuleIndex, audioModuleIndex]),
  ModuleGroup("Assessment", [
    quizModuleIndex,
    questionModuleIndex,
    question1ModuleIndex,
  ]),
  ModuleGroup("People", [studentModuleIndex, teacherModuleIndex]),
  ModuleGroup("Engage", [
    liveClassModuleIndex,
    bannerModuleIndex,
    notificationModuleIndex,
  ]),
  ModuleGroup("Shop", [bookModuleIndex, bookOrderModuleIndex]),
  ModuleGroup("Finance", [transactionModuleIndex]),
];

/// The group [moduleIndex] is listed under, or null for an unknown index.
ModuleGroup? groupOfModule(int moduleIndex) {
  for (final ModuleGroup group in moduleGroups) {
    if (group.modules.contains(moduleIndex)) return group;
  }
  return null;
}

/// Position of the Banners module within [moduleList].
const int bannerModuleIndex = 0;

/// Position of the Courses module within [moduleList].
const int courseModuleIndex = 1;

/// Position of the Subjects module within [moduleList].
const int subjectModuleIndex = 2;

/// Position of the Units module within [moduleList].
const int unitModuleIndex = 3;

/// Position of the Videos module within [moduleList].
const int videoModuleIndex = 5;

/// Position of the PDFs module within [moduleList].
const int pdfModuleIndex = 6;

/// Position of the Audio module within [moduleList].
const int audioModuleIndex = 7;

/// Position of the Quizzes module within [moduleList].
const int quizModuleIndex = 8;

/// Position of the Questions module within [moduleList].
const int questionModuleIndex = 9;

/// Position of the Students module within [moduleList].
const int studentModuleIndex = 10;

/// Position of the Books module within [moduleList] — the value the Book
/// form passes as `sidebarIndex`. New modules are appended, never
/// inserted, so the positions of the older ones never move.
const int bookModuleIndex = 13;

/// Position of the Book orders module within [moduleList].
const int bookOrderModuleIndex = 14;

/// Position of the Notifications module within [moduleList].
const int notificationModuleIndex = 15;

/// Position of the Transactions module within [moduleList]. Only an admin
/// may open it, because it shows payments and students' phone numbers (see
/// `Helper.allowedModuleIndices`).
const int transactionModuleIndex = 16;

/// Position of the Teachers module within [moduleList]. Only an admin may
/// open it (see `Helper.allowedModuleIndices`).
const int teacherModuleIndex = 11;

/// Position of the Live Classes module within [moduleList] — the value
/// every Live Class screen passes as `ExtraSideBar(sidebarIndex: ...)`.
const int liveClassModuleIndex = 12;

/// Position of the Topics module within [moduleList].
const int topicModuleIndex = 4;

/// Position of the New Topics module (`Topic1…` in code) within
/// [moduleList] — the value every Topic1 screen passes as `sidebarIndex`.
/// Shown right after Topics (see [moduleNavOrder]).
const int topic1ModuleIndex = 17;

/// Position of the Question1 module within [moduleList] — the value every
/// Question1 screen passes as `ExtraSideBar(sidebarIndex: ...)`.
const int question1ModuleIndex = 18;

/// What the sidebar *shows*, index-aligned with [moduleList].
///
/// [moduleList] is the persisted identity of a module: a teacher's
/// module-access list stores those exact strings and
/// `Helper.allowedModuleIndices` matches on them, so renaming an entry
/// there would silently revoke access for every existing teacher. This
/// list carries the human label instead, and is safe to reword.
const List<String> moduleDisplayList = [
  "Banners",
  "Courses",
  "Subjects",
  "Units",
  "Topics",
  "Videos",
  "PDFs",
  "Audio",
  "Quizzes",
  "Questions",
  "Students",
  "Teachers",
  "Live Classes",
  "Books",
  "Book orders",
  "Notifications",
  "Transactions",
  "New Topics",
  "Question1",
];

/// Role with full access, including managing teachers.
const String roleAdmin = "admin";

/// Role limited to the modules ticked on the teacher.
const String roleSubadmin = "subadmin";

/// SharedPreferences key the signed-in teacher's document id is stored
/// under at login. Its presence *is* the session: `main` sends the app
/// straight to [Sidebar] when it is set, and to [LoginScreen] when it is
/// not, so clearing it is what signing out means.
const String adminIdPrefsKey = "admin_id";

/// SharedPreferences key the logged-in teacher's module_access list is
/// stored under at login — [Sidebar] and [ExtraSideBar] read it back to
/// restrict which modules they render.
const String moduleAccessPrefsKey = "module_access";

/// SharedPreferences key the logged-in teacher's role ([roleAdmin] or
/// [roleSubadmin]) is stored under at login. An admin is shown every
/// module, including ones added after their module_access list was saved.
const String rolePrefsKey = "role";

/// SharedPreferences key remembering whether the navigation rail was left
/// collapsed, so the choice survives the pushReplacement each add/edit
/// screen makes on its way back to [Sidebar].
const String sidebarCollapsedPrefsKey = "sidebar_collapsed";

/// The stored form of a teacher's username: trimmed and lower-cased.
///
/// It is both the `username` field and the Firestore document id, so
/// account creation and the login lookup must both go through this.
String normalizeUsername(String raw) => raw.trim().toLowerCase();

/// [AddTeacher] generates its role selector from this list — keep it as the
/// single source of truth for valid teacher roles.
const List<String> roleList = [roleAdmin, roleSubadmin];

/// Sidebar icon for each module, index-aligned with [moduleList].
const List<IconData> moduleIconList = [
  Icons.image,
  Icons.subject_outlined,
  Icons.book,
  Icons.ad_units,
  Icons.topic_outlined,
  Icons.video_file,
  Icons.picture_as_pdf,
  Icons.audio_file,
  Icons.quiz_outlined,
  Icons.question_mark_sharp,
  Icons.people,
  Icons.people_alt_outlined,
  Icons.live_tv,
  Icons.auto_stories,
  Icons.local_shipping_outlined,
  Icons.campaign_outlined,
  Icons.receipt_long_outlined,
  Icons.topic,
  Icons.library_books,
];
