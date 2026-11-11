import 'package:bbarna/book_orders/model/book_order_model.dart';
import 'package:bbarna/books/model/book_model.dart';
import 'package:bbarna/resources/constant.dart';
import 'package:bbarna/utils/money.dart';
import 'package:flutter_test/flutter_test.dart';

// The admin panel writes `books` and the student app reads them; the
// student app writes `book_orders` and the admin panel reads them. Neither
// side can see the other's code, so these tests pin the field names both
// have to agree on (see b_barna_app/lib/books/model/).
void main() {
  group('BookModel (admin writes, app reads)', () {
    test('toMap uses the field names the student app reads', () {
      final Map<String, dynamic> map = BookModel(
        name: 'WBCS Guide',
        author: 'B Barna Team',
        description: 'All topics',
        image: 'https://x/y.jpg',
        mrp: 499,
        sellingPrice: 349,
        inStock: true,
        willDisplay: true,
        displayPriority: 2,
        timeStamp: 1,
      ).toMap();

      expect(
          map.keys,
          containsAll(<String>[
            'name',
            'author',
            'description',
            'image',
            'mrp',
            'selling_price',
            'in_stock',
            'willDisplay',
            'display_priority',
          ]));
      expect(map['selling_price'], 349);
      expect(map['in_stock'], isTrue);
    });

    test('round-trips through its own map', () {
      final BookModel original = BookModel(
        name: 'A',
        author: 'B',
        description: 'C',
        image: 'D',
        mrp: 250,
        sellingPrice: 199.5,
        inStock: false,
        willDisplay: true,
        displayPriority: 7,
        timeStamp: 42,
      );
      final BookModel copy = BookModel.fromMap('id1', original.toMap());

      expect(copy.docId, 'id1');
      expect(copy.sellingPrice, 199.5);
      expect(copy.inStock, isFalse);
      expect(copy.displayPriority, 7);
      expect(copy.timeStamp, 42);
    });

    test('no selling price means the book sells at MRP', () {
      final BookModel book = BookModel.fromMap('id', {'mrp': 300});
      expect(book.price, 300);
      expect(book.inStock, isTrue);
    });
  });

  group('BookOrderModel (app writes, admin reads)', () {
    final Map<String, dynamic> saved = {
      'student_id': 's1',
      'student_name': 'Riya Sen',
      'phone': '9876543210',
      'address': {
        'line1': '12 College Road',
        'locality': 'Gopsai',
        'city': 'Midnapore',
        'state': 'West Bengal',
        'pin_code': '721101',
      },
      'items': [
        {'book_id': 'a', 'name': 'WBCS Guide', 'image': '', 'mrp': 499, 'price': 349, 'qty': 2},
        {'book_id': 'b', 'name': 'Grammar', 'image': '', 'mrp': 250, 'price': 199, 'qty': 1},
      ],
      'total_mrp': 1248,
      'items_total': 897,
      'delivery_charge': 40,
      'total_amount': 937,
      'payment_id': 'pay_ABC123',
      'receipt_no': 'BB-20261013-ABC123',
      'status': 'placed',
    };

    test('reads what the student app saves', () {
      final BookOrderModel order =
          BookOrderModel.fromMap('o1', saved, DateTime(2026, 10, 13));

      expect(order.studentName, 'Riya Sen');
      expect(order.phone, '9876543210');
      expect(order.address,
          '12 College Road, Gopsai, Midnapore, West Bengal - 721101');
      expect(order.items, hasLength(2));
      expect(order.items.first.lineTotal, 698);
      expect(order.copies, 3);
      expect(order.deliveryCharge, 40);
      expect(order.amountPaid, 937);
      expect(order.receiptNo, 'BB-20261013-ABC123');
      expect(order.status, BookOrderStatus.placed);
    });

    test('an empty document still reads as a new order', () {
      final BookOrderModel order = BookOrderModel.fromMap('o2', {}, null);
      expect(order.status, BookOrderStatus.placed);
      expect(order.items, isEmpty);
      expect(order.address, '');
    });

    test('every status has a label', () {
      expect(BookOrderStatus.all.map(BookOrderStatus.label).toList(),
          ['New order', 'Shipped', 'Delivered', 'Cancelled']);
    });
  });

  group('sidebar wiring', () {
    test('the book modules sit where their index constants say', () {
      expect(moduleList[bookModuleIndex], 'BOOKS');
      expect(moduleList[bookOrderModuleIndex], 'BOOK ORDERS');
      expect(moduleDisplayList[bookModuleIndex], 'Books');
      expect(moduleDisplayList[bookOrderModuleIndex], 'Book orders');
    });

    test('older modules did not move', () {
      expect(moduleList.indexOf('BANNERS'), 0);
      expect(moduleList[liveClassModuleIndex], 'LIVE CLASSES');
    });
  });

  test('formatRupees groups the Indian way', () {
    expect(formatRupees(349), '₹349');
    expect(formatRupees(1248), '₹1,248');
    expect(formatRupees(123456), '₹1,23,456');
    expect(formatRupees(349.5), '₹349.50');
  });
}
