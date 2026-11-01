import 'dart:typed_data';

import 'package:bbarna/books/model/book_model.dart';
import 'package:bbarna/books/repo/book_repo.dart';
import 'package:bbarna/books/screen/add_book.dart';
import 'package:bbarna/books/screen/book_list.dart';
import 'package:bbarna/books/screen/edit_book.dart';
import 'package:bbarna/books/viewModel/book_view_model.dart';
import 'package:bbarna/books/widgets/book_card.dart';
import 'package:bbarna/resources/constant.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

class MockBookRepo extends Mock implements BookRepo {}

class BookModelFake extends Fake implements BookModel {}

BookModel _book(
  String id,
  String name, {
  String author = "B Barna Team",
  double mrp = 499,
  double sellingPrice = 349,
  int timeStamp = 0,
  bool inStock = true,
  bool willDisplay = true,
}) {
  return BookModel(
    docId: id,
    name: name,
    author: author,
    description: "A description that runs on a bit.",
    image: "",
    mrp: mrp,
    sellingPrice: sellingPrice,
    inStock: inStock,
    willDisplay: willDisplay,
    displayPriority: 1,
    timeStamp: timeStamp,
  );
}

List<BookModel> _fixture() => [
      _book('a', 'WBCS Prelims Guide', timeStamp: 300),
      _book('b', 'Bengali Grammar',
          author: 'A. Sarkar', mrp: 250, sellingPrice: 199, timeStamp: 200),
      _book(
          'c',
          'An extremely long book name that will certainly not fit on one '
              'line of any card at any breakpoint whatsoever',
          mrp: 180,
          sellingPrice: 0,
          timeStamp: 100,
          inStock: false,
          willDisplay: false),
    ];

const List<Size> _sizes = [
  Size(1440, 900),
  Size(1024, 768),
  Size(700, 900),
  Size(380, 820),
];

Future<void> _pump(
    WidgetTester tester, Size size, Widget home, BookViewModel vm) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(ChangeNotifierProvider<BookViewModel>.value(
    value: vm,
    child: MaterialApp(navigatorKey: navigatorKey, home: home),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

/// The form's text boxes, top to bottom.
const int _name = 0, _mrp = 3, _sellingPrice = 4, _priority = 5;

Future<void> _type(WidgetTester tester, int field, String text) async {
  await tester.enterText(find.byType(TextField).at(field), text);
  await tester.pump();
}

Future<void> _save(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(const Key('book_save_button')));
  await tester.tap(find.byKey(const Key('book_save_button')));
  await tester.pump();
  await tester.pump();
}

void main() {
  setUpAll(() {
    registerFallbackValue(BookModelFake());
    registerFallbackValue(Uint8List(0));
  });

  late MockBookRepo repo;

  setUp(() {
    repo = MockBookRepo();
    when(() => repo.getBookList()).thenAnswer((_) async => _fixture());
    when(() => repo.getDeliveryCharge()).thenAnswer((_) async => 40);
  });

  group('layout', () {
    for (final Size size in _sizes) {
      testWidgets('the list lays out at ${size.width.toInt()}', (tester) async {
        final vm = BookViewModel(bookRepo: repo);
        await _pump(tester, size, const Scaffold(body: BookList()), vm);

        expect(tester.takeException(), isNull);
        expect(find.text('Books'), findsOneWidget);
        expect(find.byType(BookCard), findsNWidgets(3));
      });

      testWidgets('the add form lays out at ${size.width.toInt()}',
          (tester) async {
        final vm = BookViewModel(bookRepo: repo);
        await _pump(tester, size, const AddBook(), vm);

        expect(tester.takeException(), isNull);
        expect(find.text('Add a book'), findsOneWidget);
      });

      testWidgets('the edit form lays out at ${size.width.toInt()}',
          (tester) async {
        final vm = BookViewModel(bookRepo: repo);
        await _pump(tester, size, EditBook(bookData: _fixture().first), vm);

        expect(tester.takeException(), isNull);
        expect(find.text('Edit book'), findsOneWidget);
      });
    }
  });

  group('the list', () {
    testWidgets('is newest first', (tester) async {
      final vm = BookViewModel(bookRepo: repo);
      await _pump(
          tester, const Size(1440, 900), const Scaffold(body: BookList()), vm);

      expect(vm.bookList.map((b) => b.docId).toList(), ['a', 'b', 'c']);
    });

    testWidgets('search filters on name or author, and clears back',
        (tester) async {
      final vm = BookViewModel(bookRepo: repo);
      await _pump(
          tester, const Size(1440, 900), const Scaffold(body: BookList()), vm);

      vm.searchBook(searchText: 'grammar');
      await tester.pump();
      expect(find.byType(BookCard), findsOneWidget);

      vm.searchBook(searchText: 'sarkar');
      await tester.pump();
      expect(vm.bookList.single.docId, 'b');

      vm.searchBook(searchText: '');
      await tester.pump();
      expect(find.byType(BookCard), findsNWidgets(3));
    });

    testWidgets('shows what a student pays, and the MRP when it differs',
        (tester) async {
      final vm = BookViewModel(bookRepo: repo);
      await _pump(
          tester, const Size(1440, 900), const Scaffold(body: BookList()), vm);

      expect(find.text('B Barna Team · ₹349 (MRP ₹499)'), findsOneWidget);
      // No selling price: the book sells at its MRP.
      expect(find.text('B Barna Team · ₹180'), findsOneWidget);
    });

    testWidgets('shows the delivery charge, or Free when there is none',
        (tester) async {
      final vm = BookViewModel(bookRepo: repo);
      await _pump(
          tester, const Size(1440, 900), const Scaffold(body: BookList()), vm);
      expect(find.text('Delivery charge: ₹40'), findsOneWidget);

      when(() => repo.getDeliveryCharge()).thenAnswer((_) async => 0);
      await vm.getBookList();
      await tester.pump();
      expect(find.text('Delivery charge: Free'), findsOneWidget);
    });

    testWidgets('the delivery charge popup saves through the repo',
        (tester) async {
      when(() => repo.setDeliveryCharge(any())).thenAnswer((_) async {});
      final vm = BookViewModel(bookRepo: repo);
      await _pump(
          tester, const Size(1440, 900), const Scaffold(body: BookList()), vm);

      await tester.tap(find.byKey(const Key('delivery_charge_button')));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const Key('delivery_charge_field')), '55');
      await tester.tap(find.byKey(const Key('delivery_charge_save')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      verify(() => repo.setDeliveryCharge(55)).called(1);
      expect(vm.deliveryCharge, 55);
      expect(find.text('Delivery charge: ₹55'), findsOneWidget);
    });
  });

  group('the in-stock toggle', () {
    testWidgets('goes through the repo and updates the row in place',
        (tester) async {
      when(() => repo.setInStock(any(), any())).thenAnswer((_) async {});
      final vm = BookViewModel(bookRepo: repo);
      await _pump(
          tester, const Size(1440, 900), const Scaffold(body: BookList()), vm);
      clearInteractions(repo);

      await tester.tap(find.byKey(const Key('book_stock_a')));
      await tester.pump();
      await tester.pump();

      verify(() => repo.setInStock('a', false)).called(1);
      expect(vm.bookList.firstWhere((b) => b.docId == 'a').inStock, isFalse);
      verifyNever(() => repo.getBookList());
    });
  });

  group('createBook keeps the collection clean', () {
    Future<void> withNavigator(WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        navigatorKey: navigatorKey,
        home: const Scaffold(body: SizedBox()),
      ));
    }

    test('uploads the cover against the new document id', () async {
      when(() => repo.addBook(any())).thenAnswer((_) async => 'new-id');
      when(() => repo.uploadBookImage(any(), any())).thenAnswer((_) async {});

      final vm = BookViewModel(bookRepo: repo);
      final Uint8List bytes = Uint8List.fromList([1, 2, 3]);
      expect(await vm.createBook(_book('', 'New book'), bytes), isTrue);

      verify(() => repo.uploadBookImage(bytes, 'new-id')).called(1);
    });

    testWidgets('a failed upload takes the half-made book with it',
        (tester) async {
      when(() => repo.addBook(any())).thenAnswer((_) async => 'new-id');
      when(() => repo.uploadBookImage(any(), any()))
          .thenThrow(Exception('storage down'));
      when(() => repo.deleteBook(any())).thenAnswer((_) async {});
      await withNavigator(tester);

      final vm = BookViewModel(bookRepo: repo);
      expect(
          await vm.createBook(_book('', 'New book'), Uint8List.fromList([1])),
          isFalse);

      verify(() => repo.deleteBook('new-id')).called(1);
    });
  });

  group('updateBook', () {
    test('leaves the existing cover alone when none was picked', () async {
      when(() => repo.updateBook(any(), any())).thenAnswer((_) async {});

      final vm = BookViewModel(bookRepo: repo);
      expect(await vm.updateBook(_book('a', 'X'), 'a'), isTrue);

      verifyNever(() => repo.uploadBookImage(any(), any()));
    });
  });

  group('the form', () {
    testWidgets('an invalid submit marks every offending field',
        (tester) async {
      final vm = BookViewModel(bookRepo: repo);
      await _pump(tester, const Size(1024, 900), const AddBook(), vm);

      await _save(tester);

      expect(find.text('Give the book a name'), findsOneWidget);
      expect(find.text('Set the printed price (MRP)'), findsOneWidget);
      expect(find.text('Set a display priority'), findsOneWidget);
      expect(find.text('Choose a cover image'), findsOneWidget);
      verifyNever(() => repo.addBook(any()));

      // Each message goes as its field is fixed.
      await _type(tester, _name, 'WBCS Guide');
      expect(find.text('Give the book a name'), findsNothing);
      expect(find.text('Set the printed price (MRP)'), findsOneWidget);
    });

    testWidgets('a selling price above the MRP is refused', (tester) async {
      final vm = BookViewModel(bookRepo: repo);
      await _pump(tester, const Size(1024, 900),
          EditBook(bookData: _fixture().first), vm);

      await _type(tester, _mrp, '300');
      await _type(tester, _sellingPrice, '350');
      await _save(tester);

      expect(
          find.text("Selling price can't be above the MRP"), findsOneWidget);
      verifyNever(() => repo.updateBook(any(), any()));
    });

    testWidgets('the selling price may be left empty', (tester) async {
      when(() => repo.updateBook(any(), any())).thenAnswer((_) async {});
      final vm = BookViewModel(bookRepo: repo);
      await _pump(tester, const Size(1024, 900),
          EditBook(bookData: _fixture().first), vm);

      await _type(tester, _sellingPrice, '');
      await _save(tester);

      final BookModel saved =
          verify(() => repo.updateBook(captureAny(), 'a')).captured.single
              as BookModel;
      // 0 is how "sell at MRP" is stored.
      expect(saved.sellingPrice, 0);
      expect(saved.price, 499);
    });

    testWidgets('saves the name, price and selling price that were typed',
        (tester) async {
      when(() => repo.updateBook(any(), any())).thenAnswer((_) async {});
      final vm = BookViewModel(bookRepo: repo);
      await _pump(tester, const Size(1024, 900),
          EditBook(bookData: _fixture().first), vm);

      await _type(tester, _name, '  General Knowledge Yearbook  ');
      await _type(tester, _mrp, '299.50');
      await _type(tester, _sellingPrice, '249');
      await _type(tester, _priority, '4');
      await _save(tester);

      final BookModel saved =
          verify(() => repo.updateBook(captureAny(), 'a')).captured.single
              as BookModel;
      expect(saved.name, 'General Knowledge Yearbook');
      expect(saved.mrp, 299.5);
      expect(saved.sellingPrice, 249);
      expect(saved.displayPriority, 4);
      // Untouched fields keep what the book already had.
      expect(saved.author, 'B Barna Team');
      expect(saved.timeStamp, 300);
      expect(saved.inStock, isTrue);
    });

    testWidgets('price boxes take digits and two decimals only',
        (tester) async {
      final vm = BookViewModel(bookRepo: repo);
      await _pump(tester, const Size(1024, 900), const AddBook(), vm);

      await _type(tester, _mrp, '12a.5');
      expect(find.text('12a.5'), findsNothing);
    });

    testWidgets('editing does not demand a new cover', (tester) async {
      when(() => repo.updateBook(any(), any())).thenAnswer((_) async {});
      final vm = BookViewModel(bookRepo: repo);
      await _pump(tester, const Size(1024, 900),
          EditBook(bookData: _fixture().first), vm);

      await _save(tester);

      expect(find.text('Choose a cover image'), findsNothing);
      verify(() => repo.updateBook(any(), 'a')).called(1);
      verifyNever(() => repo.uploadBookImage(any(), any()));
    });
  });
}
