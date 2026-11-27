import 'package:bbarna/core/widgets/list_page/table_cells.dart';
import 'package:bbarna/quiz/model/quiz_model.dart';
import 'package:bbarna/quiz/screen/quiz_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

QuizModel _quiz(String status, {String type = "FREE", DateTime? opensAt}) =>
    QuizModel("Q", "Quiz", status, type, 30, 0, 2, 1, 0, 2, const ["A", "B"],
        availableAt: opensAt);

void main() {
  final DateTime now = DateTime(2026, 11, 28, 10);

  group('quizChipMatches', () {
    test('matches the status students see', () {
      final QuizModel live = _quiz("LIVE");
      final QuizModel opened = _quiz("UPCOMING",
          opensAt: DateTime.now().subtract(const Duration(hours: 1)));
      final QuizModel later = _quiz("UPCOMING",
          opensAt: DateTime.now().add(const Duration(days: 2)));
      final QuizModel pending = _quiz("PENDING");

      expect(quizChipMatches(live, "live"), isTrue);
      expect(quizChipMatches(opened, "live"), isTrue,
          reason: 'an upcoming quiz past its opening time is live');
      expect(quizChipMatches(opened, "upcoming"), isFalse);
      expect(quizChipMatches(later, "upcoming"), isTrue);
      expect(quizChipMatches(pending, "pending"), isTrue);
      expect(quizChipMatches(pending, "live"), isFalse);
    });

    test('matches free and paid', () {
      expect(quizChipMatches(_quiz("LIVE"), "free"), isTrue);
      expect(quizChipMatches(_quiz("LIVE", type: "PAID"), "paid"), isTrue);
      expect(quizChipMatches(_quiz("LIVE", type: "PAID"), "free"), isFalse);
    });
  });

  group('quizStatusPill', () {
    String label(QuizModel quiz) =>
        (quizStatusPill(quiz, now: now) as StatusPill).label;

    test('says Live, Opens <time> or Pending', () {
      expect(label(_quiz("LIVE")), "Live");
      expect(label(_quiz("UPCOMING", opensAt: DateTime(2026, 11, 30, 10))),
          "Opens 30 Nov, 10:00");
      expect(
          label(_quiz("UPCOMING", opensAt: DateTime(2026, 11, 28, 9))), "Live",
          reason: 'already open');
      expect(label(_quiz("UPCOMING")), "Upcoming");
      expect(label(_quiz("PENDING")), "Pending");
    });

    test('live shows a dot', () {
      final StatusPill pill =
          quizStatusPill(_quiz("LIVE"), now: now) as StatusPill;
      expect(pill.dot, isTrue);
      expect(pill.tone, StatusTone.danger);
    });
  });

  testWidgets('the pill renders', (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: quizStatusPill(_quiz("PENDING"), now: now))));
    expect(find.text('Pending'), findsOneWidget);
  });
}
