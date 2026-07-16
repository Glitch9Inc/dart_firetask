import 'package:dart_firetask/dart_firetask.dart';
import 'package:flutter_corelib/flutter_corelib.dart';

/// Legacy storage strategy that keeps multiple records in one document.
///
/// Prefer one Firestore document per record for new domains. This client remains
/// available for existing schemas and migrations.
class FirestoreMapClient<TDto extends ServerModel>
    extends FirestoreClient<TDto> {
  FirestoreMapClient(
    super.collectionReference,
    super.fromJson, {
    required super.documentName,
  }) : super(firestoreDataType: 'map in document');

  static Future<FirestoreMapClient<TModel>> init<TModel extends ServerModel>(
    CollectionReference collection,
    TModel Function(Map<String, Object?> json) fromJson, {
    required String documentName,
    bool loadOnInit = false,
  }) async {
    final client = FirestoreMapClient<TModel>(
      collection,
      fromJson,
      documentName: documentName,
    );
    if (loadOnInit) {
      await client.list();
    }
    return client;
  }

  @override
  DocumentReference getDocument(String id) => collection.doc(documentName);

  TDto? fromSnapshotMap(Map<String, dynamic> data, String id) {
    if (data.isEmpty) {
      logger.warning('Map entry $id is empty');
      return null;
    }

    data.putIfAbsent('id', () => id);
    return fromJson(data);
  }

  @override
  Future<void> createInternal(String id, Map<String, dynamic> json) {
    return _writeEntry(id, json);
  }

  @override
  Future<void> replaceInternal(String id, Map<String, dynamic> json) {
    return _writeEntry(id, json);
  }

  @override
  Future<void> patchInternal(String id, Map<String, dynamic> json) {
    // A map entry is still replaced as a unit. Field-level patching is not
    // reliable for arbitrary IDs and is one reason this strategy is legacy.
    return _writeEntry(id, json);
  }

  Future<void> _writeEntry(String id, Map<String, dynamic> json) {
    return getDocument(id).set({id: json}, SetOptions(merge: true));
  }

  @override
  Future<void> deleteInternal(String id) {
    return getDocument(id).set(
      {id: FieldValue.delete()},
      SetOptions(merge: true),
    );
  }

  @override
  Future<TDto?> retrieveInternal(
    String id,
    DocumentSnapshot<Object?> docSnapshot,
  ) async {
    final snapshotData = docSnapshot.data();
    if (snapshotData is! Map<String, Object?> || snapshotData.isEmpty) {
      cache.setEmpty(id);
      return null;
    }

    TDto? requested;
    for (final entry in snapshotData.entries) {
      final model = _convertEntry(entry.key, entry.value);
      if (model == null) continue;

      cache.set(entry.key, model);
      if (entry.key == id || model.id == id) {
        requested = model;
      }
    }

    if (requested == null) {
      cache.setEmpty(id);
    }
    return requested;
  }

  @override
  Future<List<TDto>> list({int? count, String? orderBy, String? id}) async {
    final snapshot = await getDocument(documentName).get();
    final snapshotData = snapshot.data();
    if (!snapshot.exists ||
        snapshotData is! Map<String, Object?> ||
        snapshotData.isEmpty) {
      clearCache();
      return <TDto>[];
    }

    clearCache();
    final models = <TDto>[];
    for (final entry in snapshotData.entries) {
      final model = _convertEntry(entry.key, entry.value);
      if (model == null) continue;

      models.add(model);
      cache.set(entry.key, model);
    }

    if (orderBy != null || count != null) {
      logger.warning(
        'FirestoreMapClient cannot apply server-side orderBy/count. '
        'Migrate to one document per record.',
      );
    }
    return count != null && count > 0
        ? models.take(count).toList(growable: false)
        : models;
  }

  @override
  Future<TDto?> query(String fieldName, dynamic value) {
    throw UnsupportedError(
      'FirestoreMapClient cannot query individual map entries. '
      'Migrate to one document per record.',
    );
  }

  @override
  Future<void> batchSetInternal(
    DocumentReference<Object?> docRef,
    TDto data,
    Map<String, dynamic> json,
    FireBatch batch, {
    required DateTime createdAt,
  }) {
    return batch.set(
      Firetask.set(
        docRef,
        {data.id: json},
        FirestoreDataType.mapInDocument,
        onComplete: (result) => handleBatchUpdateCommitted(
          data,
          result,
          createdAt: createdAt,
        ),
      ),
    );
  }

  @override
  Future<void> batchReplaceInternal(
    DocumentReference<Object?> docRef,
    TDto data,
    Map<String, dynamic> json,
    FireBatch batch, {
    required DateTime updatedAt,
  }) {
    return batch.set(
      Firetask.replace(
        docRef,
        {data.id: json},
        FirestoreDataType.mapInDocument,
        onComplete: (result) => handleBatchUpdateCommitted(
          data,
          result,
          updatedAt: updatedAt,
        ),
      ),
    );
  }

  @override
  Future<void> batchPatchInternal(
    DocumentReference<Object?> docRef,
    TDto data,
    Map<String, dynamic> json,
    FireBatch batch, {
    required DateTime updatedAt,
  }) {
    return batch.set(
      Firetask.update(
        docRef,
        {data.id: json},
        FirestoreDataType.mapInDocument,
        onComplete: (result) => handleBatchUpdateCommitted(
          data,
          result,
          updatedAt: updatedAt,
        ),
      ),
    );
  }

  @override
  Future<void> batchDeleteInternal(
    DocumentReference<Object?> docRef,
    String id,
    FireBatch batch,
  ) {
    return batch.set(
      Firetask.update(
        docRef,
        {id: FieldValue.delete()},
        FirestoreDataType.mapInDocument,
        onComplete: (result) => handleBatchDeleteCommitted(id, result),
      ),
    );
  }

  TDto? _convertEntry(String id, Object? value) {
    if (value is! Map) {
      logger.warning('Map entry $id is not an object');
      return null;
    }

    return fromSnapshotMap(Map<String, dynamic>.from(value), id);
  }
}
