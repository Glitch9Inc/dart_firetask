import 'package:dart_firetask/crud_client/logger/firestore_client_logger.dart';
import 'package:dart_firetask/dart_firetask.dart';
import 'package:dart_firetask/utils/firestore_converter.dart';
import 'package:flutter_corelib/flutter_corelib.dart';

class FirestoreClient<TModel extends ServerModel>
    with ServerModelClient<TModel, FireBatch> {
  final CollectionReference collection;
  final FirestoreClientLogger logger;
  final TModel Function(Map<String, Object?> json) fromJson;
  final String documentName;
  final CacheMap<String, TModel> cache = CacheMap<String, TModel>();

  FirestoreClient(
    this.collection,
    this.fromJson, {
    this.documentName = '',
    String firestoreDataType = 'document',
  }) : logger = FirestoreClientLogger(
          className: TModel.toString(),
          firestoreDataType: firestoreDataType,
        );

  FirebaseFirestore get firestore => collection.firestore;
  Iterable<TModel> get values => cache.cachedData.values.whereType<TModel>();

  /// Creates a batch bound to the same Firestore instance as this client.
  ///
  /// Callers that compose writes manually should use this instead of a bare
  /// `FireBatch()` so emulator/secondary-app injection is preserved.
  FireBatch createBatch() => FireBatch(firestore: firestore);

  static Future<FirestoreClient<TModel>> init<TModel extends ServerModel>(
    CollectionReference collection,
    TModel Function(Map<String, Object?> json) fromJson, {
    String documentName = '',
    String firestoreDataType = 'document',
    bool loadOnInit = false,
    int? loadOnInitCount,
  }) async {
    final client = FirestoreClient<TModel>(
      collection,
      fromJson,
      documentName: documentName,
      firestoreDataType: firestoreDataType,
    );
    if (loadOnInit) {
      await client.list(count: loadOnInitCount);
    }
    return client;
  }

  DocumentReference getDocument(String id) {
    return collection.doc(documentName.isEmpty ? id : documentName);
  }

  void clearCache() => cache.setMap({});

  void invalidateCache(String id) => cache.remove(id);

  Future<TModel?> refresh(String id) async {
    invalidateCache(id);
    return retrieve(id);
  }

  @override
  Future<void> create(TModel data) async {
    logger.onCreate(data.id);

    final createdAt = DateTime.now();
    final json = _serializeWithCreatedAt(data, createdAt);
    await createInternal(data.id, json);

    data.createdAt = createdAt;
    logger.onCreated(data.id);
    cache.set(data.id, data);
    logger.onCached(data.id);
  }

  Future<void> createInternal(String id, Map<String, dynamic> json) {
    return getDocument(id).set(json);
  }

  Future<void> replace(TModel data, {bool createNew = false}) async {
    final id = data.id;
    logger.onUpdate(id);

    if (createNew &&
        !await getDocument(id).get().then((snapshot) => snapshot.exists)) {
      logger.onDocumentNotFoundCreateNew(id);
      await create(data);
      return;
    }

    final updatedAt = DateTime.now();
    final json = _serializeWithUpdatedAt(data, updatedAt);
    await replaceInternal(id, json);

    data.updatedAt = updatedAt;
    logger.onUpdated(id);
    cache.set(id, data);
    logger.onCacheUpdated(id);
  }

  Future<void> replaceInternal(String id, Map<String, dynamic> json) {
    return getDocument(id).set(json);
  }

  Future<void> patch(TModel data, {bool createNew = false}) async {
    final id = data.id;
    logger.onUpdate(id);

    if (createNew &&
        !await getDocument(id).get().then((snapshot) => snapshot.exists)) {
      logger.onDocumentNotFoundCreateNew(id);
      await create(data);
      return;
    }

    final updatedAt = DateTime.now();
    final json = _serializeWithUpdatedAt(data, updatedAt);
    await patchInternal(id, json);

    data.updatedAt = updatedAt;
    logger.onUpdated(id);
    cache.set(id, data);
    logger.onCacheUpdated(id);
  }

  Future<void> patchInternal(String id, Map<String, dynamic> json) {
    return getDocument(id).update(json);
  }

  /// Backwards-compatible alias. Existing `update` calls replace a document.
  @override
  Future<void> update(TModel data, {bool createNew = false}) {
    return replace(data, createNew: createNew);
  }

  @override
  Future<TModel?> retrieve(String id) async {
    _requireId(id, 'retrieve');

    if (cache.isCached(id)) {
      logger.onCacheFound(id);
      final cached = cache.get(id);
      if (cached == null) {
        logger.onCacheFoundButNull(id);
      }
      return cached;
    }

    logger.onRetrieve(id);
    DocumentSnapshot<Object?> snapshot;
    try {
      snapshot = await getDocument(id).get();
    } catch (error) {
      logger.warning('Failed to retrieve $id: $error');
      return null;
    }

    if (!snapshot.exists) {
      logger.onDocumentNotFound(id);
      cache.setEmpty(id);
      return null;
    }

    logger.onDocumentFound(id);
    return retrieveInternal(id, snapshot);
  }

  Future<TModel?> retrieveInternal(
    String id,
    DocumentSnapshot<Object?> docSnapshot,
  ) async {
    final snapshotMap = docSnapshot.data();
    if (snapshotMap == null) {
      cache.setEmpty(id);
      return null;
    }

    final model = fromJson(snapshotMap as Map<String, Object?>);
    cache.set(id, model);
    return model;
  }

  @override
  Future<void> delete(String id) async {
    _requireId(id, 'delete');

    logger.onDelete(id);
    await deleteInternal(id);

    logger.onDeleted(id);
    cache.remove(id);
    logger.onCacheDeleted(id);
  }

  Future<void> deleteInternal(String id) => getDocument(id).delete();

  @override
  Future<List<TModel>> list({int? count, String? orderBy, String? id}) async {
    logger.onList(count: count, orderBy: orderBy, id: id);

    Query<TModel> query = collection.withConverter(
      fromFirestore: (snapshot, _) => fromJson(snapshot.data()!),
      toFirestore: (model, _) => model.toJson(),
    );
    if (orderBy != null && orderBy.isNotEmpty) {
      query = query.orderBy(orderBy);
    }
    if (count != null && count > 0) {
      query = query.limit(count);
    }

    final snapshot = await query.get();
    final result = snapshot.docs.map((document) => document.data()).toList();
    for (final model in result) {
      cache.set(model.id, model);
    }

    if (result.isEmpty) {
      logger.warning('No documents found');
    } else {
      logger.onListed(count: count, orderBy: orderBy, id: id);
    }
    return result;
  }

  @override
  Future<TModel?> query(String fieldName, dynamic value) async {
    final convertedValue = FirestoreConverter.processDynamic(value);
    logger.info(
      'Querying documents with field $fieldName and value $convertedValue...',
    );

    final snapshot = await collection
        .where(fieldName, isEqualTo: convertedValue)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) {
      logger.onDocumentNotFound('Query');
      return null;
    }

    final model = fromJson(
      snapshot.docs.first.data() as Map<String, Object?>,
    );
    cache.set(model.id, model);
    return model;
  }

  @override
  Future<void> setField(String id, String fieldName, dynamic value) async {
    _requireId(id, 'set a field on');

    final document = getDocument(id);
    if (!await document.get().then((snapshot) => snapshot.exists)) {
      logger.onDocumentNotFoundCreateNew(id);
      await create(fromJson({'id': id}));
    }

    await document.update({
      FieldPath.fromString(fieldName): FirestoreConverter.processDynamic(value),
    });
    invalidateCache(id);
  }

  @override
  Future<void> setMapValue(
    String id,
    String mapFieldName,
    String mapKey,
    dynamic value,
  ) async {
    _requireId(id, 'set a map value on');

    await getDocument(id).update({
      '$mapFieldName.$mapKey': FirestoreConverter.processDynamic(value),
    });
    invalidateCache(id);
  }

  @override
  Future<FireBatch> batchSet(TModel data, {FireBatch? batch}) async {
    final createdAt = DateTime.now();
    final json = _serializeWithCreatedAt(data, createdAt);
    final targetBatch = batch ?? createBatch();

    logger.onBatchSet(data.id);
    await batchSetInternal(
      getDocument(data.id),
      data,
      json,
      targetBatch,
      createdAt: createdAt,
    );
    return targetBatch;
  }

  Future<void> batchSetInternal(
    DocumentReference<Object?> docRef,
    TModel data,
    Map<String, dynamic> json,
    FireBatch batch, {
    required DateTime createdAt,
  }) {
    return batch.set(
      Firetask.set(
        docRef,
        json,
        FirestoreDataType.singleDocument,
        onComplete: (result) => handleBatchUpdateCommitted(
          data,
          result,
          createdAt: createdAt,
        ),
      ),
    );
  }

  Future<FireBatch> batchReplace(TModel data, {FireBatch? batch}) async {
    final updatedAt = DateTime.now();
    final json = _serializeWithUpdatedAt(data, updatedAt);
    final targetBatch = batch ?? createBatch();

    logger.onBatchPatch(data.id);
    await batchReplaceInternal(
      getDocument(data.id),
      data,
      json,
      targetBatch,
      updatedAt: updatedAt,
    );
    return targetBatch;
  }

  Future<void> batchReplaceInternal(
    DocumentReference<Object?> docRef,
    TModel data,
    Map<String, dynamic> json,
    FireBatch batch, {
    required DateTime updatedAt,
  }) {
    return batch.set(
      Firetask.replace(
        docRef,
        json,
        FirestoreDataType.singleDocument,
        onComplete: (result) => handleBatchUpdateCommitted(
          data,
          result,
          updatedAt: updatedAt,
        ),
      ),
    );
  }

  @override
  Future<FireBatch> batchPatch(TModel data, {FireBatch? batch}) async {
    final updatedAt = DateTime.now();
    final json = _serializeWithUpdatedAt(data, updatedAt);
    final targetBatch = batch ?? createBatch();

    logger.onBatchPatch(data.id);
    await batchPatchInternal(
      getDocument(data.id),
      data,
      json,
      targetBatch,
      updatedAt: updatedAt,
    );
    return targetBatch;
  }

  Future<void> batchPatchInternal(
    DocumentReference<Object?> docRef,
    TModel data,
    Map<String, dynamic> json,
    FireBatch batch, {
    required DateTime updatedAt,
  }) {
    return batch.set(
      Firetask.update(
        docRef,
        json,
        FirestoreDataType.singleDocument,
        onComplete: (result) => handleBatchUpdateCommitted(
          data,
          result,
          updatedAt: updatedAt,
        ),
      ),
    );
  }

  @override
  Future<FireBatch> batchDelete(String id, {FireBatch? batch}) async {
    _requireId(id, 'batch delete');

    final targetBatch = batch ?? createBatch();
    logger.onBatchDelete(id);
    await batchDeleteInternal(getDocument(id), id, targetBatch);
    return targetBatch;
  }

  Future<void> batchDeleteInternal(
    DocumentReference<Object?> docRef,
    String id,
    FireBatch batch,
  ) {
    return batch.set(
      Firetask.delete(
        docRef,
        FirestoreDataType.singleDocument,
        onComplete: (result) => handleBatchDeleteCommitted(id, result),
      ),
    );
  }

  void handleBatchUpdateCommitted(
    TModel data,
    Result<void> result, {
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    if (!result.isSuccess) {
      logger.warning('Batch write failed for ${data.id}: ${result.message}');
      return;
    }

    if (createdAt != null) data.createdAt = createdAt;
    if (updatedAt != null) data.updatedAt = updatedAt;
    cache.set(data.id, data);
    logger.info('Batch write committed and cached with ID: ${data.id}');
  }

  void handleBatchDeleteCommitted(String id, Result<void> result) {
    if (!result.isSuccess) {
      logger.warning('Batch delete failed for $id: ${result.message}');
      return;
    }

    cache.remove(id);
    logger.info('Batch delete committed and cache cleared for ID: $id');
  }

  Map<String, dynamic> _serializeWithCreatedAt(
    TModel data,
    DateTime createdAt,
  ) {
    return _serializeWithoutMutating(data, () => data.createdAt = createdAt);
  }

  Map<String, dynamic> _serializeWithUpdatedAt(
    TModel data,
    DateTime updatedAt,
  ) {
    return _serializeWithoutMutating(data, () => data.updatedAt = updatedAt);
  }

  Map<String, dynamic> _serializeWithoutMutating(
    TModel data,
    void Function() applyTemporaryTimestamp,
  ) {
    final originalTimestamps = Map<String, DateTime>.from(data.timestamps);
    applyTemporaryTimestamp();
    final json = data.toJson().removeNullEntries();
    data.timestamps
      ..clear()
      ..addAll(originalTimestamps);
    return json;
  }

  void _requireId(String id, String operation) {
    if (id.isEmpty) {
      throw ArgumentError(
          'You cannot $operation Firestore data with an empty ID.');
    }
  }
}
