import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:bbarna/teacher/model/teacher_model.dart';

class MockDocumentSnapshot extends Mock
    implements DocumentSnapshot<Map<String, dynamic>> {}

void main() {
  group('TeacherModel', () {
    test('toMap() produces the expected Firestore field map', () {
      final model = TeacherModel(
        docId: 'jane_doe',
        name: 'Jane Doe',
        imageUrl: 'https://example.com/jane.jpg',
        username: 'jane_doe',
        password: 'hashed-password-value',
        phoneNumber: '9876543210',
        timeStamp: 1700000000000,
        moduleAccess: const ['COURSES', 'SUBJECT'],
        role: 'admin',
      );

      expect(model.toMap(), {
        'name': 'Jane Doe',
        'image_url': 'https://example.com/jane.jpg',
        'username': 'jane_doe',
        'password': 'hashed-password-value',
        'phone_number': '9876543210',
        'timeStamp': 1700000000000,
        'module_access': ['COURSES', 'SUBJECT'],
        'role': 'admin',
      });
    });

    test('fromDocumentSnapshot() parses a Firestore document correctly', () {
      final snapshot = MockDocumentSnapshot();
      when(() => snapshot.id).thenReturn('jane_doe');
      when(() => snapshot.data()).thenReturn({
        'name': 'Jane Doe',
        'image_url': 'https://example.com/jane.jpg',
        'username': 'jane_doe',
        'password': 'hashed-password-value',
        'phone_number': '9876543210',
        'timeStamp': 1700000000000,
        'module_access': ['COURSES', 'SUBJECT'],
        'role': 'admin',
      });

      final model = TeacherModel.fromDocumentSnapshot(snapshot);

      expect(model.docId, 'jane_doe');
      expect(model.name, 'Jane Doe');
      expect(model.imageUrl, 'https://example.com/jane.jpg');
      expect(model.username, 'jane_doe');
      expect(model.password, 'hashed-password-value');
      expect(model.phoneNumber, '9876543210');
      expect(model.timeStamp, 1700000000000);
      expect(model.moduleAccess, ['COURSES', 'SUBJECT']);
      expect(model.role, 'admin');
    });

    test(
        'fromDocumentSnapshot() falls back to codebase defaults for missing fields',
        () {
      final snapshot = MockDocumentSnapshot();
      when(() => snapshot.id).thenReturn('incomplete');
      when(() => snapshot.data()).thenReturn({
        'name': 'Incomplete Teacher',
      });

      final model = TeacherModel.fromDocumentSnapshot(snapshot);

      expect(model.name, 'Incomplete Teacher');
      expect(model.imageUrl, 'NA'); // stringDefault, from lib/resources/constant.dart
      expect(model.username, 'NA'); // stringDefault
      expect(model.password, 'NA'); // stringDefault
      expect(model.phoneNumber, 'NA'); // stringDefault
      expect(model.timeStamp, -1); // intDefault
      expect(model.moduleAccess, isEmpty);
      expect(model.role, 'subadmin'); // falls back to roleSubadmin, not stringDefault
    });
  });
}
