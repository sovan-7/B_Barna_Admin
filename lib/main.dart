import 'package:bbarna/banners/viewModel/banners_view_model.dart';
import 'package:bbarna/book_orders/viewModel/book_order_view_model.dart';
import 'package:bbarna/books/viewModel/book_view_model.dart';
import 'package:bbarna/core/widgets/sidebar.dart';
import 'package:bbarna/course/viewModel/course_view_model.dart';
import 'package:bbarna/documents/audio/viewModel/audio_view_model.dart';
import 'package:bbarna/documents/pdf/viewModel/pdf_view_model.dart';
import 'package:bbarna/documents/video/viewModel/video_view_model.dart';
import 'package:bbarna/live_class/viewModel/live_class_view_model.dart';
import 'package:bbarna/login/screen/login_screen.dart';
import 'package:bbarna/login/viewModel/login_view_model.dart';
import 'package:bbarna/notifications/viewModel/notifications_view_model.dart';
import 'package:bbarna/question/viewModel/question_view_model.dart';
import 'package:bbarna/quiz/viewModel/quiz_view_model.dart';
import 'package:bbarna/resources/constant.dart';
import 'package:bbarna/student/viewModel/student_view_model.dart';
import 'package:bbarna/subject/viewModel/subject_view_model.dart';
import 'package:bbarna/teacher/viewModel/teacher_view_model.dart';
import 'package:bbarna/topic/viewModel/topic_view_model.dart';
import 'package:bbarna/units/viewModel/unit_view_model.dart';
import 'package:bbarna/utils/session.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Entry point: starts Firebase and local storage, then runs the app with
/// every module's view model provided at the top of the tree (so lists
/// keep their state while the admin moves between modules).
///
/// If start-up fails, a plain error screen is shown instead.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
        options: const FirebaseOptions(
            apiKey: "AIzaSyDMo9aZg1-zlGXCfp2Bft6o3MZaFwiv67Q",
            appId: "1:23963148123:web:f16c6712a418dedecc847e",
            messagingSenderId: "23963148123",
            projectId: "bbarna-6a725",
            authDomain: "bbarna-6a725.firebaseapp.com",
            storageBucket: "bbarna-6a725.appspot.com",
            measurementId: "G-T6QDXLT4V0"));

    sharedPreferences = await SharedPreferences.getInstance();
  } catch (error, stackTrace) {
    debugPrint("App initialization failed: $error\n$stackTrace");
    runApp(InitializationErrorApp(error: error));
    return;
  }

  // One view model per module, shared by its list and Add/Edit screens.
  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => QuestionViewModel()),
      ChangeNotifierProvider(create: (_) => CourseViewModel()),
      ChangeNotifierProvider(create: (_) => SubjectViewModel()),
      ChangeNotifierProvider(create: (_) => UnitViewModel()),
      ChangeNotifierProvider(create: (_) => TopicViewModel()),
      ChangeNotifierProvider(create: (_) => VideoViewModel()),
      ChangeNotifierProvider(create: (_) => PdfViewModel()),
      ChangeNotifierProvider(create: (_) => AudioViewModel()),
      ChangeNotifierProvider(create: (_) => QuizViewModel()),
      ChangeNotifierProvider(create: (_) => BannersViewModel()),
      ChangeNotifierProvider(create: (_) => StudentViewModel()),
      ChangeNotifierProvider(create: (_) => TeacherViewModel()),
      ChangeNotifierProvider(create: (_) => LiveClassViewModel()),
      ChangeNotifierProvider(create: (_) => BookViewModel()),
      ChangeNotifierProvider(create: (_) => BookOrderViewModel()),
      ChangeNotifierProvider(create: (_) => NotificationsViewModel()),
      ChangeNotifierProvider(create: (_) => LoginViewModel()),
    ],
    child: const MyApp(),
  ));
}

/// Minimal app shown when Firebase or local storage failed to start.
class InitializationErrorApp extends StatelessWidget {
  /// What went wrong, shown on screen.
  final Object error;

  const InitializationErrorApp({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                const Text(
                  "Failed to start the app",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text("$error", textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The admin panel: opens the module shell ([Sidebar]) when a session
/// exists, otherwise the [LoginScreen].
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        debugShowCheckedModeBanner: false,
        scaffoldMessengerKey: snackBarKey,
        navigatorKey: navigatorKey,
        key: scaffoldKey,
        title: "BBARNA",
        home: Session.isSignedIn
            ? const Sidebar(sidebarIndex: 0)
            : const LoginScreen());
  }
}
