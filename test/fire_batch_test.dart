import 'package:dart_firetask/dart_firetask.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class _MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

class _MockWriteBatch extends Mock implements WriteBatch {}

void main() {
  late _MockFirebaseFirestore firestore;
  late _MockWriteBatch writeBatch;
  late DocumentReference<Object?> document;

  setUp(() {
    firestore = _MockFirebaseFirestore();
    writeBatch = _MockWriteBatch();
    document = FakeFirebaseFirestore().collection('tests').doc('document');
    when(() => firestore.batch()).thenReturn(writeBatch);
  });

  test('uses the injected Firestore instance', () {
    final batch = FireBatch(firestore: firestore);

    expect(batch.firestore, same(firestore));
    verify(() => firestore.batch()).called(1);
  });

  test('runs callbacks only after a successful commit', () async {
    when(() => writeBatch.commit()).thenAnswer((_) async {});
    final results = <bool>[];
    final batch = FireBatch(firestore: firestore);

    await batch.set(Firetask.delete(
      document,
      FirestoreDataType.singleDocument,
      onComplete: (result) => results.add(result.isSuccess),
    ));

    expect(results, isEmpty);
    await batch.commit();

    expect(results, [true]);
    expect(batch.isCommitted, isTrue);
    verify(() => writeBatch.delete(document)).called(1);
    verify(() => writeBatch.commit()).called(1);
  });

  test('reports commit failure and rethrows it', () async {
    final failure = StateError('network failure');
    when(() => writeBatch.commit()).thenThrow(failure);
    final results = <bool>[];
    final batch = FireBatch(firestore: firestore);

    await batch.set(Firetask.delete(
      document,
      FirestoreDataType.singleDocument,
      onComplete: (result) => results.add(result.isSuccess),
    ));

    await expectLater(batch.commit(), throwsA(same(failure)));
    expect(results, [false]);
    expect(batch.isCommitted, isTrue);
  });

  test('callback errors do not turn a successful commit into a write retry',
      () async {
    when(() => writeBatch.commit()).thenAnswer((_) async {});
    final batch = FireBatch(firestore: firestore);

    await batch.set(Firetask.delete(
      document,
      FirestoreDataType.singleDocument,
      onComplete: (_) => throw StateError('local cache callback failed'),
    ));

    await batch.commit();

    expect(batch.callbackErrors, hasLength(1));
  });

  test('rejects reuse after commit', () async {
    when(() => writeBatch.commit()).thenAnswer((_) async {});
    final batch = FireBatch(firestore: firestore);
    await batch.commit();

    await expectLater(batch.commit(), throwsStateError);
    await expectLater(
      batch.set(Firetask.delete(
        document,
        FirestoreDataType.singleDocument,
      )),
      throwsStateError,
    );
  });
}
