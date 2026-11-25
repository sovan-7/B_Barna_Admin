// Kept free of Firebase mocks so it also runs in a browser:
//   flutter test --platform chrome test/topic1/topic1_id_test.dart
// The admin panel ships as a web app, and web integers behave differently
// from the VM's (shifts are 32-bit there), so the id generator is checked
// where it actually runs.

import 'package:bbarna/topic1/model/topic1_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('new item ids are non-empty and distinct', () {
    final List<String> ids = [for (int i = 0; i < 200; i++) newTopic1ItemId()];

    expect(ids.every((id) => id.isNotEmpty), isTrue);
    expect(ids.toSet(), hasLength(ids.length));
  });
}
