import 'dart:convert';

import 'package:bbarna/resources/constant.dart';
import 'package:bbarna/transactions/model/transaction_model.dart';
import 'package:bbarna/transactions/repo/transaction_repo.dart';
import 'package:bbarna/transactions/screen/transaction_list.dart';
import 'package:bbarna/transactions/transaction_csv.dart';
import 'package:bbarna/transactions/transaction_pdf.dart';
import 'package:bbarna/transactions/viewModel/transaction_view_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

class MockRepo extends Mock implements TransactionRepo {}

TransactionModel _t(
  String id, {
  String name = 'Riya Sen',
  String phone = '9000000000',
  String course = 'WBCS Complete Preparation',
  double paid = 2499,
  double offer = 2000,
  String? coupon,
  double couponOff = 0,
  String? paymentId = 'pay_ABC123',
}) {
  return TransactionModel(
    docId: id,
    studentId: 's1',
    studentName: name,
    phone: phone,
    subjectCode: 'S1',
    subjectName: course,
    courseType: 'Full Course',
    coursePrice: 4999,
    offerDiscount: offer,
    couponCode: coupon,
    couponDiscount: couponOff,
    amountPaid: paid,
    paymentId: paymentId,
    method: paid > 0 ? 'Razorpay' : 'Free',
    receiptNo: 'BB-20261030-$id',
    createdAt: DateTime(2026, 10, 30, 16, 5),
  );
}

void main() {
  late MockRepo repo;

  setUp(() {
    repo = MockRepo();
    when(() => repo.getTotalCount()).thenAnswer((_) async => 3);
  });

  void answerFirstPage(List<TransactionModel> items, {bool hasMore = false}) {
    when(() => repo.getPage())
        .thenAnswer((_) async => TransactionPage(items, 'cursor-1', hasMore));
  }

  group('the model', () {
    // The student app's TransactionModel.toMap writes these exact names. If
    // either side renames one, purchases silently show blank here.
    test('reads the fields the student app writes', () {
      final TransactionModel t = TransactionModel.fromMap('d1', {
        'student_id': 's1',
        'student_name': 'Riya Sen',
        'phone': '9000000000',
        'subject_code': 'S1',
        'subject_name': 'History',
        'course_type': 'Full Course',
        'course_price': 999, // Firestore hands whole numbers back as ints
        'offer_discount': 500.0,
        'coupon_code': 'SAVE50',
        'coupon_discount': 50,
        'amount_paid': 449,
        'payment_id': 'pay_1',
        'method': 'Razorpay',
        'status': 'success',
        'receipt_no': 'BB-1',
        'created_at': Timestamp.fromDate(DateTime(2026, 9, 26)),
      });

      expect(t.docId, 'd1');
      expect(t.studentName, 'Riya Sen');
      expect(t.subjectName, 'History');
      expect(t.coursePrice, 999.0);
      expect(t.couponCode, 'SAVE50');
      expect(t.amountPaid, 449.0);
      expect(t.saved, 550.0);
      expect(t.isFree, isFalse);
      expect(t.receiptNo, 'BB-1');
      expect(t.createdAt, DateTime(2026, 9, 26));
    });

    test('a purchase the server has not stamped yet has no date', () {
      final TransactionModel t = TransactionModel.fromMap('d1', {});
      expect(t.createdAt, isNull);
      expect(t.amountPaid, 0);
      expect(t.isFree, isTrue);
      expect(t.paymentId, isNull);
    });
  });

  group('search, filter and totals', () {
    late TransactionViewModel vm;

    setUp(() async {
      answerFirstPage([
        _t('a', name: 'Riya Sen', paid: 2499, couponOff: 500, coupon: 'B20'),
        _t('b', name: 'Abhijit Roy', phone: '8000000000', paid: 999),
        _t('c', name: 'Mita Das', paid: 0, offer: 4999, paymentId: null),
      ]);
      vm = TransactionViewModel(repo: repo);
      await vm.getTransactions();
    });

    test('totals cover what is shown', () {
      expect(vm.shown, hasLength(3));
      expect(vm.totalCollected, 3498);
      expect(vm.totalDiscounts, 2500 + 2000 + 4999);
    });

    test('searching matches name, phone, course, receipt and payment ID', () {
      vm.setSearch('abhijit');
      expect(vm.shown.single.docId, 'b');
      vm.setSearch('80000');
      expect(vm.shown.single.docId, 'b');
      vm.setSearch('BB-20261030-c');
      expect(vm.shown.single.docId, 'c');
      vm.setSearch('pay_abc');
      expect(vm.shown, hasLength(2));
      vm.setSearch('wbcs');
      expect(vm.shown, hasLength(3));
      vm.setSearch('nobody');
      expect(vm.shown, isEmpty);
    });

    test('a search narrows the totals, so one student can be added up', () {
      vm.setSearch('riya');
      expect(vm.totalCollected, 2499);
    });

    test('the filter splits paid from free, and its counts follow a search',
        () {
      vm.setFilter(TransactionFilter.free);
      expect(vm.shown.single.docId, 'c');
      vm.setFilter(TransactionFilter.paid);
      expect(vm.shown, hasLength(2));
      expect(vm.countFor(TransactionFilter.free), 1);

      vm.setSearch('riya');
      expect(vm.countFor(TransactionFilter.all), 1);
      expect(vm.countFor(TransactionFilter.free), 0);
    });
  });

  group('loading', () {
    test('a failed load reports an error instead of an empty list', () async {
      when(() => repo.getPage()).thenThrow(Exception('permission-denied'));
      final vm = TransactionViewModel(repo: repo);
      await vm.getTransactions();

      expect(vm.isLoading, isFalse);
      expect(vm.loadError, "Couldn't load transactions");
    });

    test('load more appends older purchases from where the last page ended',
        () async {
      answerFirstPage([_t('a')], hasMore: true);
      when(() => repo.getPage(cursor: 'cursor-1')).thenAnswer(
          (_) async => TransactionPage([_t('b')], 'cursor-2', false));
      final vm = TransactionViewModel(repo: repo);

      await vm.getTransactions();
      expect(vm.hasMore, isTrue);
      await vm.loadMore();

      expect(vm.shown.map((t) => t.docId), ['a', 'b']);
      expect(vm.hasMore, isFalse);
    });

    test('refreshing while a page loads ignores the older answer', () async {
      answerFirstPage([_t('a')], hasMore: true);
      final vm = TransactionViewModel(repo: repo);
      await vm.getTransactions();

      when(() => repo.getPage(cursor: 'cursor-1')).thenAnswer((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return TransactionPage([_t('stale')], 'x', false);
      });
      final Future<void> more = vm.loadMore();
      answerFirstPage([_t('fresh')]);
      await vm.getTransactions();
      await more;

      expect(vm.shown.map((t) => t.docId), ['fresh']);
    });

    test('failing to get the total is not an error', () async {
      answerFirstPage([_t('a')]);
      when(() => repo.getTotalCount()).thenThrow(Exception('offline'));
      final vm = TransactionViewModel(repo: repo);
      await vm.getTransactions();
      await Future<void>.delayed(Duration.zero);

      expect(vm.loadError, isNull);
      expect(vm.totalCount, isNull);
    });
  });

  group('the module list', () {
    test('Transactions was appended, so no older module moved', () {
      expect(moduleList[transactionModuleIndex], 'TRANSACTIONS');
      expect(moduleDisplayList[transactionModuleIndex], 'Transactions');
      expect(transactionModuleIndex, moduleList.length - 1);
    });

    test('a teacher cannot be given it', () {
      expect(assignableModuleList, isNot(contains('TRANSACTIONS')));
      expect(assignableModuleList,
          hasLength(moduleList.length - 1 - hiddenModuleIndices.length));
    });
  });

  group('the CSV', () {
    List<List<dynamic>> parse(String csv) =>
        const CsvToListConverter(shouldParseNumbers: false).convert(csv);

    test('has one row per purchase with the money as numbers', () {
      final List<List<dynamic>> rows = parse(transactionsCsv([
        _t('a', coupon: 'B20', couponOff: 500),
        _t('b', paid: 0, paymentId: null),
      ]));

      expect(rows, hasLength(3));
      expect(rows[0].first, 'Date');
      expect(rows[1][1], 'Riya Sen');
      expect(rows[1][7], 'B20');
      expect(rows[1][9], '2499.0');
      expect(rows[2][11], '');
    });

    test('a name that looks like a formula cannot run in a spreadsheet', () {
      for (final String risky in ['=1+1', '+91', '-5', '@cmd', '\t=x']) {
        expect(safeCsvText(risky), "'$risky");
      }
      expect(safeCsvText('Riya'), 'Riya');
      expect(safeCsvText(''), '');
      final List<List<dynamic>> rows =
          parse(transactionsCsv([_t('a', name: '=HYPERLINK("x")')]));
      expect(rows[1][1], '\'=HYPERLINK("x")');
    });

    test('keeps commas, quotes and Bengali intact', () {
      final String csv =
          transactionsCsv([_t('a', course: 'ইতিহাস, "প্রথম" পর্ব')]);
      expect(parse(csv)[1][3], 'ইতিহাস, "প্রথম" পর্ব');
      expect(utf8.decode(utf8.encode(csv)), csv);
    });
  });

  group('the PDFs', () {
    TestWidgetsFlutterBinding.ensureInitialized();

    bool isPdf(List<int> bytes) => ascii.decode(bytes.sublist(0, 4)) == '%PDF';

    test('a paid receipt, with a coupon', () async {
      expect(
          isPdf(await TransactionPdf.receipt(
              _t('a', coupon: 'B20', couponOff: 500))),
          isTrue);
    });

    test('a free receipt, with no payment ID', () async {
      expect(
          isPdf(
              await TransactionPdf.receipt(_t('a', paid: 0, paymentId: null))),
          isTrue);
    });

    test('a statement too long for one page', () async {
      expect(
          isPdf(await TransactionPdf.statement(
            [for (int i = 0; i < 120; i++) _t('t$i')],
            totalCollected: 1000,
            totalDiscounts: 500,
            now: DateTime(2026, 11, 2),
          )),
          isTrue);
    });
  });

  group('the screen', () {
    Future<void> pump(WidgetTester tester, Size size) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(ChangeNotifierProvider<TransactionViewModel>(
        create: (_) => TransactionViewModel(repo: repo),
        child: const MaterialApp(home: Scaffold(body: TransactionList())),
      ));
      await tester.pump();
      await tester.pump();
    }

    for (final Size size in const [
      Size(1440, 900),
      Size(1024, 768),
      Size(700, 900),
      Size(380, 800),
    ]) {
      testWidgets('lays out with no overflow at ${size.width.toInt()}',
          (tester) async {
        answerFirstPage(
            [_t('a', coupon: 'BARNA20', couponOff: 500), _t('b', paid: 0)]);
        await pump(tester, size);

        expect(tester.takeException(), isNull);
        expect(find.text('Transactions'), findsOneWidget);
        // On a small window the later rows are below the fold.
        expect(find.text('WBCS Complete Preparation'), findsWidgets);
      });
    }

    testWidgets('a failed load shows the error with Retry', (tester) async {
      when(() => repo.getPage()).thenThrow(Exception('permission-denied'));
      await pump(tester, const Size(1024, 768));

      expect(find.text("Couldn't load transactions"), findsOneWidget);
    });

    testWidgets('an empty collection says so and offers no export',
        (tester) async {
      answerFirstPage([]);
      await pump(tester, const Size(1024, 768));

      expect(find.text('No transactions yet'), findsOneWidget);
      final ButtonStyleButton csv =
          tester.widget(find.byKey(const Key('transactions_export_csv')));
      expect(csv.onPressed, isNull);
    });

    testWidgets('tapping a row opens its details and receipt', (tester) async {
      answerFirstPage([_t('a', coupon: 'BARNA20', couponOff: 500)]);
      await pump(tester, const Size(1024, 900));

      await tester.tap(find.byKey(const Key('transaction_row_a')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Payment successful'), findsOneWidget);
      expect(find.text('BB-20261030-a'), findsOneWidget);
      expect(find.text('pay_ABC123'), findsOneWidget);
      expect(find.byKey(const Key('transaction_download_receipt')),
          findsOneWidget);
    });

    testWidgets('a short window scrolls instead of overflowing',
        (tester) async {
      answerFirstPage([_t('a'), _t('b')]);
      await pump(tester, const Size(1024, 420));

      expect(tester.takeException(), isNull);
    });

    testWidgets('while searching, the footer counts matches', (tester) async {
      answerFirstPage([_t('a'), _t('b', name: 'Abhijit Roy')]);
      await pump(tester, const Size(1024, 768));

      expect(find.text('Showing 2 of 3'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'abhijit');
      await tester.pump();
      expect(find.text('1 match'), findsOneWidget);
    });

    testWidgets('warns when the totals do not cover everything',
        (tester) async {
      answerFirstPage([_t('a')], hasMore: true);
      await pump(tester, const Size(1024, 768));

      final Text note =
          tester.widget(find.byKey(const Key('transactions_totals_note')));
      expect(note.data, contains("Older purchases aren't loaded yet"));
    });
  });
}
