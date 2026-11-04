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
];

/// Modules switched off for everyone, admins included. They stay in
/// [moduleList] and its index-aligned lists so no other module's position
/// moves; remove an index from here to bring its module back.
const Set<int> hiddenModuleIndices = {bookModuleIndex, bookOrderModuleIndex};

/// What a teacher's access can be chosen from: everything except modules
/// only an admin may ever open and modules switched off for everyone.
final List<String> assignableModuleList = [
  for (int i = 0; i < moduleList.length; i++)
    if (i != transactionModuleIndex && !hiddenModuleIndices.contains(i))
      moduleList[i],
];

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
];
