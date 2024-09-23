import 'package:dart_firetask/dart_firetask.dart';
import 'package:flutter_corelib/flutter_corelib.dart';

abstract class BaseFirestoreCrudController<TModel extends CrudModelMixin, TArg,
    TSelf extends BaseFirestoreCrudController<TModel, TArg, TSelf>> extends BaseCrudController<TModel, TArg, TSelf> {
  final CollectionReference collectionReference;
  final Logger logger;
  final FirestoreDataType dataType;

  BaseFirestoreCrudController(this.collectionReference, this.dataType) : logger = Logger(TSelf.toString());

  // override these methods in the concrete class
  DocumentReference getDocument(String id, {TArg? arg});
  TModel? fromSnapshotMap(Map<String, dynamic> data, String id, {TArg? arg});

  // cache for storing data
  bool isCached(String id, TArg? arg);
  void setCache(String id, TModel? data, TArg? arg);
  TModel? getCache(String id, TArg? arg);
  void removeCache(String id, TArg? arg);

  // optional methods to override
  String resolveDocumentId(TArg? arg) => arg.toString();
  String resolveFieldName(String id) => id;
  TArg? resolveArg(TArg? arg) => arg;

  @override
  Future<Result<void>> create(TModel data, {TArg? arg}) async {
    try {
      logger.info('Creating \'${data.id}\' ${dataType.getName()}...');

      arg = resolveArg(arg);
      data.createdAt = DateTime.now();

      if (dataType == FirestoreDataType.document) {
        await getDocument(data.id, arg: arg).set(data.toJson());
      } else {
        await getDocument(data.id, arg: arg).set({resolveFieldName(data.id): data.toJson()}, SetOptions(merge: true));
      }

      logger.info('${dataType.getName(firstLetter: true)} created with ID: ${data.id}');
      setCache(data.id, data, arg);
      logger.info('${dataType.getName(firstLetter: true)} cached with ID: ${data.id}');
      return Result(isSuccess: true);
    } catch (e) {
      logger.severe('Failed to create ${dataType.getName()}: $e');
      return Result(isSuccess: false, message: e.toString());
    }
  }

  @override
  Future<Result<TModel?>> retrieve(String id, {TArg? arg}) async {
    var idValidation = FirestoreValidator.invalidDocumentId(id, logger);
    if (idValidation.isError) {
      return Result(isSuccess: false, message: idValidation.message);
    }

    try {
      arg = resolveArg(arg);

      if (isCached(id, arg)) {
        logger.info('Cached data with key \'$id\' found');
        final cached = getCache(id, arg);
        if (cached == null) {
          logger.warning('Cached data with key \'$id\' found as null');
          return Result(isSuccess: false, message: '${dataType.getName(firstLetter: true)} not found');
        }
        return Result(isSuccess: true, data: cached);
      }
      //logger.info('Cache miss for ID: $id');
      logger.info('Getting \'$id\' ${dataType.getName()}...');
      final docSnapshot = await getDocument(id, arg: arg).get();

      if (docSnapshot.exists) {
        logger.info('\'$id\' ${dataType.getName()} found');

        if (dataType == FirestoreDataType.document) {
          final snapshotMap = docSnapshot.data();

          if (snapshotMap == null) {
            logger.warning('\'$id\' ${dataType.getName()} found but data is null');
            setCache(id, null, arg); // 캐시에 null 값 저장
            return Result(isSuccess: false, message: '${dataType.getName(firstLetter: true)} not found');
          }

          final model = fromSnapshotMap(snapshotMap as Map<String, Object?>, id, arg: arg);

          if (model == null) {
            logger.warning('\'$id\' ${dataType.getName()} found but data is null');
            setCache(id, null, arg); // 캐시에 null 값 저장
            return Result(isSuccess: false, message: '${dataType.getName(firstLetter: true)} not found');
          } else {
            setCache(id, model, arg); // 캐시 업데이트
            return Result(isSuccess: true, data: model);
          }
        } else {
          final data = docSnapshot.data() as Map<String, Object?>;

          if (data.isEmpty) {
            logger.warning('There is no data in the document snapshot');
            return Result(isSuccess: false, message: 'There is no data in the document snapshot');
          }

          logger.info('${data.length} ${dataType.getName()}s found in the document snapshot');

          List<TModel> models = [];
          TModel? modelToReturn;

          for (var entry in data.entries) {
            final id = entry.key;
            Map<String, dynamic> convertedEntry = entry.value as Map<String, dynamic>;
            final model = fromSnapshotMap(convertedEntry, id, arg: arg);
            if (model == null) {
              logger.warning('No ${dataType.getName()} found for ID: $id');
            } else {
              if (model.id.isEmpty) {
                logger.severe('There was an issue while converting data to model: empty id');
              }
              models.add(model);
              setCache(id, model, arg);
              if (model.id == id) {
                modelToReturn = model;
              }
            }
          }

          if (modelToReturn != null) {
            logger.info('${dataType.getName(firstLetter: true)}s found and cache updated');
            return Result(isSuccess: true, data: modelToReturn);
          } else {
            logger.warning('No ${dataType.getName()}s found');
            return Result(isSuccess: false, message: 'No ${dataType.getName()}s found');
          }
        }
      } else {
        logger.warning('\'$id\' ${dataType.getName()} not found');
        setCache(id, null, arg); // 캐시에 null 값 저장
        return Result(isSuccess: false, message: '${dataType.getName(firstLetter: true)} not found');
      }
    } catch (e) {
      logger.severe('Failed to get \'$id\' ${dataType.getName()}: ${e.toString()}');
      return Result(isSuccess: false, message: e.toString());
    }
  }

  @override
  Future<Result<void>> update(TModel data, {bool createNew = false, TArg? arg}) async {
    try {
      logger.info('Updating \'${data.id}\' ${dataType.getName()}...');
      data.updatedAt = DateTime.now();

      if (createNew) {
        arg = resolveArg(arg);

        var doc = getDocument(data.id, arg: arg);
        var docSnapshot = await doc.get();
        if (!docSnapshot.exists) {
          // create instead
          logger.info('Document not found, creating new document with ID: ${data.id}');
          return create(data, arg: arg);
        }
      }

      if (dataType == FirestoreDataType.document) {
        await getDocument(data.id, arg: arg).set(data.toJson());
      } else {
        await getDocument(data.id, arg: arg).set({resolveFieldName(data.id): data.toJson()}, SetOptions(merge: true));
      }

      logger.info('${dataType.getName(firstLetter: true)} updated with ID: ${data.id}');
      setCache(data.id, data, arg); // 캐시 업데이트
      logger.info('${dataType.getName(firstLetter: true)} cached with ID: ${data.id}');
      return Result(isSuccess: true);
    } catch (e) {
      logger.severe('Failed to update ${dataType.getName()}: $e');
      return Result(isSuccess: false, message: e.toString());
    }
  }

  @override
  Future<Result<void>> delete(String id, {TArg? arg}) async {
    var idValidation = FirestoreValidator.invalidDocumentId(id, logger);
    if (idValidation.isError) return idValidation;

    try {
      arg = resolveArg(arg);
      logger.info('Deleting \'$id\' ${dataType.getName()}...');

      if (dataType == FirestoreDataType.document) {
        await getDocument(id, arg: arg).delete();
      } else {
        await getDocument(id, arg: arg).update({resolveFieldName(id): FieldValue.delete()});
      }

      removeCache(id, arg); // 캐시에서 데이터 삭제
      logger.info('${dataType.getName(firstLetter: true)} deleted and cache cleared for ID: $id');
      return Result(isSuccess: true);
    } catch (e) {
      logger.severe('Failed to delete ${dataType.getName()}: $e');
      return Result(isSuccess: false, message: e.toString());
    }
  }

  @override
  Future<Result<List<TModel>>> list({String? orderBy, String? id, TArg? arg}) async {
    try {
      logger.info('Listing ${dataType.getName()}s');
      arg = resolveArg(arg);

      if (dataType == FirestoreDataType.document) {
        Query<TModel> query;

        if (orderBy != null) {
          query = collectionReference.orderBy(orderBy).withConverter(
              fromFirestore: (snapshot, _) => fromJson(this as TSelf, snapshot.data()!),
              toFirestore: (user, _) => user.toJson());
          logger.info('Ordering by: $orderBy');
        } else {
          query = collectionReference.withConverter(
              fromFirestore: (snapshot, _) => fromJson(this as TSelf, snapshot.data()!),
              toFirestore: (user, _) => user.toJson());
        }

        final querySnapshot = await query.get();
        final result = querySnapshot.docs.map((e) => e.data()).toList();
        if (result.isNotEmpty) {
          for (var element in result) {
            setCache(element.id, element, arg); // 캐시 업데이트
          }
          logger.info('${dataType.getName(firstLetter: true)}s listed and cache updated');
          return Result(isSuccess: true, data: result);
        }
      } else {
        final docSnapshot = await getDocument(id ?? '', arg: arg).get();
        if (docSnapshot.exists) {
          final data = docSnapshot.data() as Map<String, Object?>;

          if (data.isEmpty) {
            logger.warning('There is no data in the document snapshot');
            return Result(isSuccess: false, message: 'There is no data in the document snapshot');
          }

          logger.info('${data.length} ${dataType.getName()}s found in the document snapshot');

          List<TModel> models = [];
          for (var entry in data.entries) {
            final id = entry.key;
            Map<String, dynamic> convertedEntry = entry.value as Map<String, dynamic>;
            final model = fromSnapshotMap(convertedEntry, id, arg: arg);
            if (model == null) {
              logger.warning('No ${dataType.getName()} found for ID: $id');
            } else {
              if (model.id.isEmpty) {
                logger.severe('There was an issue while converting data to model: empty id');
              }
              models.add(model);
              setCache(id, model, arg);
            }
          }

          if (models.isNotEmpty) {
            logger.info('${dataType.getName(firstLetter: true)}s listed and cache updated');
            return Result(isSuccess: true, data: models);
          } else {
            logger.warning('No ${dataType.getName()}s found');
            return Result(isSuccess: false, message: 'No ${dataType.getName()}s found');
          }
        }
      }

      logger.warning('No ${dataType.getName()}s found');
      return Result(isSuccess: false, message: 'No ${dataType.getName()}s found');
    } catch (e) {
      logger.severe('Failed to list ${dataType.getName()}s: $e');
      return Result(isSuccess: false, message: e.toString());
    }
  }

  @override
  Future<Result<TModel?>> query(String fieldName, dynamic value, {TArg? arg}) async {
    if (dataType == FirestoreDataType.field) {
      String message = 'Query operation not supported for field data type';
      logger.warning(message);
      return Result(isSuccess: false, message: message);
    }

    try {
      arg = resolveArg(arg);

      value = FirestoreConverter.processDynamic(value);
      logger.info('Querying documents with field $fieldName and value $value...');
      final querySnapshot = await collectionReference.where(fieldName, isEqualTo: value).get();
      final docs = querySnapshot.docs;
      if (docs.isNotEmpty) {
        final data = docs.first.data() as Map<String, Object?>;
        final model = fromJson(this as TSelf, data);
        setCache(model.id, model, arg); // 캐시 업데이트
        logger.info('Documents queried and cache updated');
        return Result(isSuccess: true, data: model);
      }
      logger.warning('No documents found');
      return Result(isSuccess: false, message: 'No documents found');
    } catch (e) {
      logger.severe('Failed to query documents: $e');
      return Result(isSuccess: false, message: e.toString());
    }
  }

  @override
  Future<Result<void>> setField(String id, String fieldName, dynamic value, {TArg? arg}) async {
    var idValidation = FirestoreValidator.invalidDocumentId(id, logger);
    if (idValidation.isError) return idValidation;

    try {
      arg = resolveArg(arg);

      value = FirestoreConverter.processDynamic(value);
      logger.info('Setting field $fieldName with value $value for document with ID: $id');
      await getDocument(id, arg: arg).update({FieldPath.fromString(fieldName): value});
      logger.info('Field $fieldName updated and cache updated for ID: $id');
      return Result(isSuccess: true);
    } catch (e) {
      logger.severe('Failed to set field $fieldName: $e');
      return Result(isSuccess: false, message: e.toString());
    }
  }

  @override
  Future<Result<void>> setMapValue(String id, String mapFieldName, String mapKey, dynamic value, {TArg? arg}) async {
    var idValidation = FirestoreValidator.invalidDocumentId(id, logger);
    if (idValidation.isError) return idValidation;

    try {
      arg = resolveArg(arg);

      value = FirestoreConverter.processDynamic(value);
      logger.info('Setting map field $mapFieldName with key $mapKey and value $value for document with ID: $id');
      await getDocument(id, arg: arg).update({'$mapFieldName.$mapKey': value});
      logger.info('Map field $mapFieldName updated and cache updated for ID: $id');
      return Result(isSuccess: true);
    } catch (e) {
      logger.severe('Failed to set map field $mapFieldName: $e');
      return Result(isSuccess: false, message: e.toString());
    }
  }

  @override
  void batchSet(TModel data, {TArg? arg}) {
    logger.info('Batch setting ${dataType.getName()} with ID: ${data.id}');
    arg = resolveArg(arg);

    final docRef = getDocument(data.id, arg: arg);

    if (!isBatchingTasks) {
      FiretaskBatch.reset();
      isBatchingTasks = true;
    }

    data.createdAt = DateTime.now();

    if (dataType == FirestoreDataType.document) {
      FiretaskBatch.add(Firetask.set(docRef, data.toJson(), FirestoreDataType.document, onComplete: (result) {
        _onUpdateBatchCommited(data, arg, FirestoreDataType.document, result);
      }));
    } else {
      FiretaskBatch.add(Firetask.set(docRef, {resolveFieldName(data.id): data.toJson()}, FirestoreDataType.field,
          onComplete: (result) {
        _onUpdateBatchCommited(data, arg, FirestoreDataType.field, result);
      }));
    }
  }

  @override
  void batchPatch(TModel data, {TArg? arg}) {
    logger.info('Batch updating ${dataType.getName()} with ID: ${data.id}');
    arg = resolveArg(arg);

    final docRef = getDocument(data.id, arg: arg);

    if (!isBatchingTasks) {
      FiretaskBatch.reset();
      isBatchingTasks = true;
    }

    data.updatedAt = DateTime.now();

    if (dataType == FirestoreDataType.document) {
      FiretaskBatch.add(Firetask.update(docRef, data.toJson(), FirestoreDataType.document, onComplete: (result) {
        _onUpdateBatchCommited(data, arg, FirestoreDataType.document, result);
      }));
    } else {
      FiretaskBatch.add(Firetask.update(docRef, {resolveFieldName(data.id): data.toJson()}, FirestoreDataType.field,
          onComplete: (result) {
        _onUpdateBatchCommited(data, arg, FirestoreDataType.field, result);
      }));
    }
  }

  @override
  void batchDelete(String id, {TArg? arg}) {
    logger.info('Batch deleting ${dataType.getName()} with ID: $id');
    arg = resolveArg(arg);

    final docRef = getDocument(id, arg: arg);

    if (!isBatchingTasks) {
      FiretaskBatch.reset();
      isBatchingTasks = true;
    }

    if (dataType == FirestoreDataType.document) {
      FiretaskBatch.add(Firetask.delete(docRef, FirestoreDataType.document, onComplete: (result) {
        _onRemoveBatchCommited(id, arg, FirestoreDataType.document, result);
      }));
    } else {
      FiretaskBatch.add(Firetask.update(
        docRef,
        {resolveFieldName(id): FieldValue.delete()},
        FirestoreDataType.field,
        onComplete: (result) {
          _onRemoveBatchCommited(id, arg, FirestoreDataType.field, result);
        },
      ));
    }
  }

  @override
  Future<Result<void>> batchCommit() async {
    logger.info('Committing ${FiretaskBatch.taskCount} batch tasks...');

    try {
      await FiretaskBatch.commit();
      logger.info('Batch tasks committed successfully!');
      return Result(isSuccess: true);
    } catch (e) {
      logger.severe('Failed to commit batch: $e');
      return Result(isSuccess: false, message: e.toString());
    } finally {
      isBatchingTasks = false;
      FiretaskBatch.reset();
    }
  }

  void _onUpdateBatchCommited(TModel data, TArg? arg, FirestoreDataType dataType, Result<void> result) {
    if (result.isSuccess) {
      setCache(data.id, data, arg); // 캐시 업데이트
      logger.info('${dataType.getName(firstLetter: true)} batch set and cached with ID: ${data.id}');
    } else {
      logger.severe('Failed to batch set ${dataType.getName()}: ${result.message}');
    }
  }

  void _onRemoveBatchCommited(String id, TArg? arg, FirestoreDataType dataType, Result<void> result) {
    if (result.isSuccess) {
      removeCache(id, arg); // 캐시에서 데이터 삭제
      logger.info('${dataType.getName(firstLetter: true)} batch deleted and cache cleared for ID: $id');
    } else {
      logger.severe('Failed to batch delete ${dataType.getName()}: ${result.message}');
    }
  }
}
