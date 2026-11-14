// Deleting is the admin's alone: a subadmin can add and edit in the modules
// they were given, but every delete control is hidden from them and
// `confirmDelete` refuses to run for them.

import 'package:bbarna/banners/model/banners_model.dart';
import 'package:bbarna/banners/widgets/banner_card.dart';
import 'package:bbarna/core/widgets/card/card_actions.dart';
import 'package:bbarna/core/widgets/card/card_helpers.dart';
import 'package:bbarna/core/widgets/form/form_action_bar.dart';
import 'package:bbarna/resources/constant.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Starts a session with [role], the way a sign-in stores it.
Future<void> _signInAs(String role) async {
  SharedPreferences.setMockInitialValues(
      <String, Object>{adminIdPrefsKey: 't1', rolePrefsKey: role});
  sharedPreferences = await SharedPreferences.getInstance();
}

Widget _host(Widget child) =>
    MaterialApp(home: Scaffold(body: Center(child: child)));

Widget _cardButtons() => CardActions(
      visible: true,
      buttons: [
        CardEditButton(
            buttonKey: const Key('edit'), tooltip: "Edit", onTap: () {}),
        CardDeleteButton(
            buttonKey: const Key('delete'), tooltip: "Delete", onTap: () {}),
      ],
    );

Widget _formBar() => FormActionBar(
      width: 900,
      isSaving: false,
      saveKey: const Key('save'),
      saveLabel: "Update",
      onSave: () {},
      onDelete: () {},
    );

void main() {
  group('an admin', () {
    setUp(() => _signInAs(roleAdmin));

    testWidgets('sees the card delete button', (tester) async {
      await tester.pumpWidget(_host(_cardButtons()));
      expect(find.byKey(const Key('edit')), findsOneWidget);
      expect(find.byKey(const Key('delete')), findsOneWidget);
    });

    testWidgets('sees Delete in the form bar', (tester) async {
      await tester.pumpWidget(_host(_formBar()));
      expect(find.text("Delete"), findsOneWidget);
    });
  });

  group('a subadmin', () {
    setUp(() => _signInAs(roleSubadmin));

    testWidgets('keeps the edit button but not the delete button',
        (tester) async {
      await tester.pumpWidget(_host(_cardButtons()));
      expect(find.byKey(const Key('edit')), findsOneWidget);
      expect(find.byKey(const Key('delete')), findsNothing);
    });

    testWidgets('gets no Delete in the form bar, but can still save',
        (tester) async {
      await tester.pumpWidget(_host(_formBar()));
      expect(find.text("Delete"), findsNothing);
      expect(find.byTooltip("Delete"), findsNothing);
      expect(find.byKey(const Key('save')), findsOneWidget);
      expect(find.text("Cancel"), findsOneWidget);
    });

    testWidgets('a banner without onDelete has no delete button',
        (tester) async {
      await tester.pumpWidget(_host(SizedBox(
        width: 320,
        child: BannerCard(
          banner: BannersModel(bannerImage: ''),
          position: 1,
        ),
      )));
      expect(find.byTooltip("Delete banner"), findsNothing);
    });

    test('confirmDelete does not delete', () async {
      bool deleted = false;
      confirmDelete(
        title: "Something",
        delete: () async => deleted = true,
        successMessage: "Deleted",
      );
      expect(deleted, isFalse);
    });
  });
}
