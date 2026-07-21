import 'package:dart_corelib/dart_corelib.dart';
import 'package:dart_firetask/dart_firetask.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class _TestModel extends ServerModel {
  final String label;
  final int value;

  _TestModel({
    required super.id,
    required this.label,
    required this.value,
    super.timestamps,
  });

  _TestModel.fromJson(Map<String, Object?> json)
      : label = json['label']?.toString() ?? '',
        value = (json['value'] as num?)?.toInt() ?? 0,
        super.fromJson(Map<String, dynamic>.from(json));

  @override
  ServerModelClient get client => throw UnsupportedError('test DTO');

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'label': label,
        'value': value,
      };
}

class _MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

class _MockWriteBatch extends Mock implements WriteBatch {}

void main() {
  group('explicit write semantics', () {
    late FakeFirebaseFirestore firestore;
    late FirestoreClient<_TestModel> client;
    late DocumentReference<Map<String, dynamic>> document;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      client = FirestoreClient<_TestModel>(
        firestore.collection('models'),
        _TestModel.fromJson,
      );
      document = firestore.collection('models').doc('model-1');
    });

    test('create writes and caches only after success', () async {
      final model = _TestModel(id: 'model-1', label: 'created', value: 1);

      await client.create(model);

      expect((await document.get()).data()!['label'], 'created');
      expect(client.cache.get(model.id), same(model));
    });

    test('patch preserves omitted server fields', () async {
      await document.set({
        'id': 'model-1',
        'label': 'old',
        'value': 0,
        'server_only': true,
      });

      await client.patch(
        _TestModel(id: 'model-1', label: 'patched', value: 2),
      );

      final data = (await document.get()).data()!;
      expect(data['label'], 'patched');
      expect(data['server_only'], isTrue);
    });

    test('replace removes omitted server fields', () async {
      await document.set({
        'id': 'model-1',
        'label': 'old',
        'value': 0,
        'server_only': true,
      });

      await client.replace(
        _TestModel(id: 'model-1', label: 'replaced', value: 3),
      );

      final data = (await document.get()).data()!;
      expect(data['label'], 'replaced');
      expect(data.containsKey('server_only'), isFalse);
    });

    test('legacy update remains a replace alias', () async {
      await document.set({
        'id': 'model-1',
        'label': 'old',
        'value': 0,
        'server_only': true,
      });

      await client.update(
        _TestModel(id: 'model-1', label: 'updated', value: 4),
      );

      final data = (await document.get()).data()!;
      expect(data['label'], 'updated');
      expect(data.containsKey('server_only'), isFalse);
    });

    test('delete removes server and cache state after success', () async {
      final model = _TestModel(id: 'model-1', label: 'created', value: 1);
      await client.create(model);

      await client.delete(model.id);

      expect((await document.get()).exists, isFalse);
      expect(client.cache.isCached(model.id), isFalse);
    });
  });

  group('cache policy', () {
    late FakeFirebaseFirestore firestore;
    late FirestoreClient<_TestModel> client;
    late DocumentReference<Map<String, dynamic>> document;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      client = FirestoreClient<_TestModel>(
        firestore.collection('models'),
        _TestModel.fromJson,
      );
      document = firestore.collection('models').doc('model-1');
    });

    test('refresh invalidates a stale cached model and reads again', () async {
      await document.set({'id': 'model-1', 'label': 'first', 'value': 1});
      expect((await client.retrieve('model-1'))!.label, 'first');

      await document.update({'label': 'second'});
      expect((await client.retrieve('model-1'))!.label, 'first');
      expect((await client.refresh('model-1'))!.label, 'second');
    });

    test('refresh clears a negative cache entry', () async {
      expect(await client.retrieve('model-1'), isNull);
      expect(client.cache.isCached('model-1'), isTrue);

      await document.set({'id': 'model-1', 'label': 'created', 'value': 1});
      expect(await client.retrieve('model-1'), isNull);
      expect((await client.refresh('model-1'))!.label, 'created');
    });

    test('clearCache removes positive and negative entries', () async {
      await document.set({'id': 'model-1', 'label': 'created', 'value': 1});
      await client.retrieve('model-1');
      await client.retrieve('missing');

      client.clearCache();

      expect(client.cache.cachedData, isEmpty);
    });
  });

  group('batch cache contract', () {
    test('does not mutate cache or timestamps before commit', () async {
      final firestore = FakeFirebaseFirestore();
      final client = FirestoreClient<_TestModel>(
        firestore.collection('models'),
        _TestModel.fromJson,
      );
      final originalCreatedAt = DateTime.utc(2020);
      final model = _TestModel(
        id: 'model-1',
        label: 'batched',
        value: 1,
        timestamps: {'created_at': originalCreatedAt},
      );

      final batch = await client.batchSet(model);

      expect(client.cache.isCached(model.id), isFalse);
      expect(model.createdAt, originalCreatedAt);

      await batch.commit();

      expect(client.cache.get(model.id), same(model));
      expect(model.createdAt, isNot(originalCreatedAt));
    });

    test('failed commit leaves cache and model timestamps unchanged', () async {
      final firestore = FakeFirebaseFirestore();
      final client = FirestoreClient<_TestModel>(
        firestore.collection('models'),
        _TestModel.fromJson,
      );
      final failedFirestore = _MockFirebaseFirestore();
      final failedWriteBatch = _MockWriteBatch();
      when(() => failedFirestore.batch()).thenReturn(failedWriteBatch);
      when(() => failedWriteBatch.commit())
          .thenThrow(StateError('commit failed'));
      final originalCreatedAt = DateTime.utc(2020);
      final model = _TestModel(
        id: 'model-1',
        label: 'batched',
        value: 1,
        timestamps: {'created_at': originalCreatedAt},
      );
      final batch = FireBatch(firestore: failedFirestore);

      await client.batchSet(model, batch: batch);
      await expectLater(batch.commit(), throwsStateError);

      expect(client.cache.isCached(model.id), isFalse);
      expect(model.createdAt, originalCreatedAt);
    });
  });

  group('legacy map document safety', () {
    late FakeFirebaseFirestore firestore;
    late FirestoreMapClient<_TestModel> client;
    late DocumentReference<Map<String, dynamic>> document;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      client = FirestoreMapClient<_TestModel>(
        firestore.collection('legacy'),
        _TestModel.fromJson,
        documentName: 'items',
      );
      document = firestore.collection('legacy').doc('items');
    });

    test('missing and empty documents return an empty list', () async {
      expect(await client.list(), isEmpty);

      await document.set({});
      expect(await client.list(), isEmpty);
    });

    test('uses the map key as id when legacy JSON has no id', () async {
      await document.set({
        'entry-a': {'label': 'A', 'value': 1},
      });

      final result = await client.list();

      expect(result.single.id, 'entry-a');
      expect(result.single.label, 'A');
    });

    test('entry writes preserve unrelated entries', () async {
      await document.set({
        'entry-a': {'id': 'entry-a', 'label': 'A', 'value': 1},
        'entry-b': {'id': 'entry-b', 'label': 'B', 'value': 2},
      });

      await client.create(
        _TestModel(id: 'entry-c', label: 'C', value: 3),
      );
      var data = (await document.get()).data()!;
      expect(data.keys, containsAll(['entry-a', 'entry-b', 'entry-c']));

      await client.delete('entry-c');
      data = (await document.get()).data()!;
      expect(data.keys, containsAll(['entry-a', 'entry-b']));
      expect(data.containsKey('entry-c'), isFalse);
    });
  });

  test('transaction runner uses the injected Firestore instance', () async {
    final firestore = FakeFirebaseFirestore();
    final document = firestore.collection('counters').doc('main');
    await document.set({'value': 1});
    final runner = FireTransactionRunner(firestore: firestore);

    await runner.run((transaction) async {
      final snapshot = await transaction.get(document);
      transaction.update(document, {'value': snapshot.get('value') + 1});
    });

    expect((await document.get()).get('value'), 2);
  });
}
