import 'package:bbarna/login/model/login_result.dart';
import 'package:bbarna/resources/constant.dart';
import 'package:bbarna/utils/helper.dart';
import 'package:bbarna/utils/session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Which modules the sidebar offers is decided by
// `Helper.allowedModuleIndices`, from what `Session.signIn` stored.
//
// The bug this guards against: Books and Book orders were added to
// `moduleList`, but every existing account's module_access list had been
// saved before they existed — so the modules were in the code and invisible
// to everyone, admins included, because the role was never consulted.

/// The module list an account saved before Books existed.
const List<String> _modulesBeforeBooks = [
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
];

/// [_modulesBeforeBooks] as a non-admin sees it: Teachers is admin-only.
final List<String> _modulesWithoutTeachers = [
  for (final String module in _modulesBeforeBooks)
    if (module != "TEACHERS") module,
];

Future<void> _freshStore([Map<String, Object> values = const {}]) async {
  SharedPreferences.setMockInitialValues(Map<String, Object>.from(values));
  sharedPreferences = await SharedPreferences.getInstance();
}

List<String> _visibleModules() =>
    [for (final int i in Helper.allowedModuleIndices()) moduleList[i]];

/// Every module an admin is offered: all of them, minus the hidden ones,
/// in sidebar order.
final List<String> _shownModules = [
  for (final int i in moduleNavOrder)
    if (!hiddenModuleIndices.contains(i)) moduleList[i],
];

void main() {
  test('the fixture really is every module before the book ones', () {
    expect([
      ..._modulesBeforeBooks,
      "BOOKS",
      "BOOK ORDERS",
      "NOTIFICATIONS",
      "TRANSACTIONS",
      "TOPIC1",
      "QUESTION1",
    ], moduleList);
  });

  test('Topic1 is listed right after Topics, without moving any position', () {
    expect(moduleList[topicModuleIndex], "TOPIC");
    expect(moduleList[topic1ModuleIndex], "TOPIC1");
    // Appended after it, so Topic1 keeps its stored position.
    expect(moduleList[question1ModuleIndex], "QUESTION1");
    expect(question1ModuleIndex, moduleList.length - 1);
    expect(topic1ModuleIndex, question1ModuleIndex - 1);
    expect(moduleNavOrder.toSet(),
        {for (int i = 0; i < moduleList.length; i++) i});
    expect(moduleNavOrder, hasLength(moduleList.length));
    final int at = moduleNavOrder.indexOf(topicModuleIndex);
    expect(moduleNavOrder.sublist(at, at + 3),
        [topicModuleIndex, topic1ModuleIndex, topicModuleIndex + 1]);
  });

  group('an admin', () {
    test('sees modules added after their module list was saved', () async {
      await _freshStore();
      await Session.signIn(const LoginResult(
        adminId: 't1',
        moduleAccess: _modulesBeforeBooks,
        role: roleAdmin,
      ));

      expect(Session.isAdmin, isTrue);
      expect(_visibleModules(), _shownModules);
      expect(Helper.allowedModuleIndices(), contains(notificationModuleIndex));
      expect(Helper.allowedModuleIndices(), contains(transactionModuleIndex));
    });

    test('does not see hidden modules', () async {
      await _freshStore();
      await Session.signIn(const LoginResult(
          adminId: 't1', moduleAccess: ["BOOKS"], role: roleAdmin));

      expect(Helper.allowedModuleIndices(), isNot(contains(bookModuleIndex)));
      expect(
          Helper.allowedModuleIndices(), isNot(contains(bookOrderModuleIndex)));
      expect(
          Helper.allowedModuleIndices(), isNot(contains(question1ModuleIndex)));
    });

    test('sees Topic1 right after Topics', () async {
      await _freshStore();
      await Session.signIn(const LoginResult(
          adminId: 't1', moduleAccess: _modulesBeforeBooks, role: roleAdmin));

      final List<String> visible = _visibleModules();
      expect(visible.indexOf("TOPIC1"), visible.indexOf("TOPIC") + 1);
    });

    test('sees everything even with a short module list', () async {
      await _freshStore();
      await Session.signIn(const LoginResult(
          adminId: 't1', moduleAccess: ["COURSES"], role: roleAdmin));

      expect(_visibleModules(), _shownModules);
    });
  });

  group('a subadmin', () {
    test('sees only the modules they were given', () async {
      await _freshStore();
      await Session.signIn(const LoginResult(
        adminId: 't2',
        moduleAccess: ["COURSES", "TOPIC"],
        role: roleSubadmin,
      ));

      expect(Session.isAdmin, isFalse);
      expect(_visibleModules(), ["COURSES", "TOPIC"]);
    });

    test('sees Topic1 only once it is ticked, next to Topics', () async {
      await _freshStore();
      await Session.signIn(const LoginResult(
        adminId: 't2',
        moduleAccess: ["TOPIC"],
        role: roleSubadmin,
      ));
      expect(_visibleModules(), ["TOPIC"]);

      await Session.signOut();
      await Session.signIn(const LoginResult(
        adminId: 't2',
        moduleAccess: ["VIDEOS", "TOPIC1", "COURSES", "TOPIC"],
        role: roleSubadmin,
      ));
      expect(_visibleModules(), ["COURSES", "TOPIC", "TOPIC1", "VIDEOS"]);
    });

    test('does not get Books just because it exists', () async {
      await _freshStore();
      await Session.signIn(const LoginResult(
        adminId: 't2',
        moduleAccess: _modulesBeforeBooks,
        role: roleSubadmin,
      ));

      expect(_visibleModules(), _modulesWithoutTeachers);
    });

    test('never gets Transactions, even when it is ticked', () async {
      await _freshStore();
      await Session.signIn(const LoginResult(
        adminId: 't2',
        moduleAccess: ["COURSES", "TRANSACTIONS"],
        role: roleSubadmin,
      ));

      expect(_visibleModules(), ["COURSES"]);
      expect(Helper.allowedModuleIndices(),
          isNot(contains(transactionModuleIndex)));
    });

    test('never gets Teachers, even when it is ticked', () async {
      await _freshStore();
      await Session.signIn(const LoginResult(
        adminId: 't2',
        moduleAccess: ["COURSES", "TEACHERS"],
        role: roleSubadmin,
      ));

      expect(_visibleModules(), ["COURSES"]);
      expect(
          Helper.allowedModuleIndices(), isNot(contains(teacherModuleIndex)));
    });

    test('does not see hidden modules, even when they are ticked', () async {
      await _freshStore();
      await Session.signIn(const LoginResult(
        adminId: 't2',
        moduleAccess: ["COURSES", "BOOKS", "BOOK ORDERS"],
        role: roleSubadmin,
      ));

      // Book orders must not resolve to any other module's screen, least of
      // all the admin-only Transactions one.
      expect(_visibleModules(), ["COURSES"]);
      expect(Helper.allowedModuleIndices(),
          isNot(contains(transactionModuleIndex)));
    });

    test('with an empty module list sees nothing', () async {
      await _freshStore();
      await Session.signIn(const LoginResult(adminId: 't2', moduleAccess: []));

      expect(_visibleModules(), isEmpty);
    });

    test('with no module list stored sees nothing', () async {
      await _freshStore({adminIdPrefsKey: 't2', rolePrefsKey: roleSubadmin});

      expect(_visibleModules(), isEmpty);
    });
  });

  test(
      'a session saved before roles were stored keeps its module list, '
      'minus Teachers', () async {
    // What an already signed-in browser holds: no role key at all.
    await _freshStore({
      adminIdPrefsKey: 't1',
      moduleAccessPrefsKey: _modulesBeforeBooks,
    });

    expect(Session.isAdmin, isFalse);
    expect(_visibleModules(), _modulesWithoutTeachers);
  });

  test('signing out forgets the role', () async {
    await _freshStore();
    await Session.signIn(const LoginResult(
        adminId: 't1', moduleAccess: ["COURSES"], role: roleAdmin));
    expect(sharedPreferences.getString(rolePrefsKey), roleAdmin);

    await Session.signOut();

    expect(sharedPreferences.getString(rolePrefsKey), isNull);
    expect(Session.isAdmin, isFalse);
  });

  test('the next person to sign in does not inherit an admin role', () async {
    await _freshStore();
    await Session.signIn(const LoginResult(
        adminId: 't1', moduleAccess: _modulesBeforeBooks, role: roleAdmin));
    await Session.signOut();
    await Session.signIn(const LoginResult(
        adminId: 't2', moduleAccess: ["COURSES"], role: roleSubadmin));

    expect(_visibleModules(), ["COURSES"]);
  });
}
