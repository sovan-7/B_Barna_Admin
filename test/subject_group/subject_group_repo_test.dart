// ignore_for_file: subtype_of_sealed_class

import 'package:bbarna/resources/constant.dart';
import 'package:bbarna/subject_group/repo/subject_group_repo.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_test/flutter_test.dart';

/// Deleting a whole group chat. It can't be undone, so it must remove every
/// message (Firestore deletes a collection only document by document) and
/// their pictures, and never stop because one picture is already gone.

typedef _Data = Map<String, dynamic>;

/// Just the calls [SubjectGroupRepo.deleteAll] makes. Anything else throws
/// (from Fake), so a test can't pass over a call this doesn't model.
class _FakeFirestore extends Fake implements FirebaseFirestore {
  /// Collection path -> document id -> fields.
  final Map<String, Map<String, _Data>> docs = {};
  int commits = 0;

  @override
  CollectionReference<_Data> collection(String collectionPath) =>
      _FakeCollection(this, collectionPath);

  @override
  WriteBatch batch() => _FakeBatch(this);
}

class _FakeCollection extends Fake implements CollectionReference<_Data> {
  final _FakeFirestore db;
  @override
  final String path;

  _FakeCollection(this.db, this.path);

  @override
  DocumentReference<_Data> doc([String? path]) =>
      _FakeDoc(db, this.path, path!);

  @override
  Query<_Data> limit(int limit) => _FakeQuery(db, path, limit);
}

class _FakeDoc extends Fake implements DocumentReference<_Data> {
  final _FakeFirestore db;
  final String collectionPath;
  @override
  final String id;

  _FakeDoc(this.db, this.collectionPath, this.id);

  @override
  CollectionReference<_Data> collection(String collectionPath) =>
      _FakeCollection(db, '${this.collectionPath}/$id/$collectionPath');
}

class _FakeQuery extends Fake implements Query<_Data> {
  final _FakeFirestore db;
  final String path;
  final int pageSize;

  _FakeQuery(this.db, this.path, this.pageSize);

  @override
  Future<QuerySnapshot<_Data>> get([GetOptions? options]) async {
    final List<MapEntry<String, _Data>> page =
        (db.docs[path] ?? {}).entries.take(pageSize).toList();
    return _FakeSnapshot([
      for (final MapEntry<String, _Data> entry in page)
        _FakeQueryDoc(_FakeDoc(db, path, entry.key), entry.value),
    ]);
  }
}

class _FakeSnapshot extends Fake implements QuerySnapshot<_Data> {
  @override
  final List<QueryDocumentSnapshot<_Data>> docs;

  _FakeSnapshot(this.docs);
}

class _FakeQueryDoc extends Fake implements QueryDocumentSnapshot<_Data> {
  @override
  final DocumentReference<_Data> reference;
  final _Data _data;

  _FakeQueryDoc(this.reference, this._data);

  @override
  _Data data() => _data;
}

class _FakeBatch extends Fake implements WriteBatch {
  final _FakeFirestore db;
  final List<_FakeDoc> _deletes = [];

  _FakeBatch(this.db);

  @override
  void delete(DocumentReference<Object?> document) =>
      _deletes.add(document as _FakeDoc);

  @override
  Future<void> commit() async {
    expect(_deletes.length, lessThanOrEqualTo(500),
        reason: 'Firestore takes at most 500 writes per batch');
    db.commits++;
    for (final _FakeDoc doc in _deletes) {
      db.docs[doc.collectionPath]?.remove(doc.id);
    }
  }
}

class _FakeStorage extends Fake implements FirebaseStorage {
  final List<String> deleted = [];

  /// Pictures that are already gone (deleting them throws).
  final Set<String> missing;

  _FakeStorage({this.missing = const {}});

  @override
  Reference refFromURL(String url) => _FakeRef(this, url);
}

class _FakeRef extends Fake implements Reference {
  @override
  final _FakeStorage storage;
  final String url;

  _FakeRef(this.storage, this.url);

  @override
  Future<void> delete() async {
    if (storage.missing.contains(url)) {
      throw StateError('storage/object-not-found');
    }
    storage.deleted.add(url);
  }
}

void main() {
  const String group = 'SSCGD27';
  const String messagesPath = '$subjectGroups/$group/$groupMessages';

  late _FakeFirestore firestore;

  setUp(() => firestore = _FakeFirestore());

  void addMessages(String path, int count, {int everyNthHasPicture = 0}) {
    final Map<String, _Data> docs = firestore.docs.putIfAbsent(path, () => {});
    for (int i = 0; i < count; i++) {
      final bool picture =
          everyNthHasPicture > 0 && i % everyNthHasPicture == 0;
      docs['m$i'] = {
        'text': 'Message $i',
        'image_url': picture ? 'https://img/$i.jpg' : '',
      };
    }
  }

  test('deletes every message, in rounds, with their pictures', () async {
    addMessages(messagesPath, 650, everyNthHasPicture: 100); // 7 pictures
    final _FakeStorage storage = _FakeStorage();
    final SubjectGroupRepo repo =
        SubjectGroupRepo(firestore: firestore, storage: storage);

    expect(await repo.deleteAll(group), 650);

    expect(firestore.docs[messagesPath], isEmpty);
    expect(firestore.commits, 3); // 300 + 300 + 50
    expect(storage.deleted, hasLength(7));
    expect(storage.deleted, contains('https://img/600.jpg'));
  });

  test('a picture that is already gone does not stop the rest', () async {
    addMessages(messagesPath, 10, everyNthHasPicture: 2); // 0, 2, 4, 6, 8
    final _FakeStorage storage =
        _FakeStorage(missing: {'https://img/2.jpg'});
    final SubjectGroupRepo repo =
        SubjectGroupRepo(firestore: firestore, storage: storage);

    expect(await repo.deleteAll(group), 10);
    expect(firestore.docs[messagesPath], isEmpty);
    expect(storage.deleted, hasLength(4));
  });

  test('only this subject\'s chat is touched', () async {
    const String otherPath = '$subjectGroups/OTHER/$groupMessages';
    addMessages(messagesPath, 3);
    addMessages(otherPath, 4);
    final SubjectGroupRepo repo =
        SubjectGroupRepo(firestore: firestore, storage: _FakeStorage());

    await repo.deleteAll(group);

    expect(firestore.docs[messagesPath], isEmpty);
    expect(firestore.docs[otherPath], hasLength(4));
  });

  test('an empty chat deletes nothing', () async {
    final SubjectGroupRepo repo =
        SubjectGroupRepo(firestore: firestore, storage: _FakeStorage());
    expect(await repo.deleteAll(group), 0);
    expect(firestore.commits, 0);
  });
}
