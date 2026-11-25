import 'package:bbarna/books/model/book_model.dart';
import 'package:bbarna/books/widgets/book_form.dart';
import 'package:flutter/material.dart';

/// Edit Book screen — the shared [BookForm] pre-populated with
/// [bookData]; also offers Delete.
class EditBook extends StatelessWidget {
  /// The item being edited.
  final BookModel bookData;
  const EditBook({required this.bookData, super.key});

  @override
  Widget build(BuildContext context) => BookForm(existing: bookData);
}
