import 'package:flutter_corelib/flutter_corelib.dart';
import 'package:dart_firetask/dart_firetask.dart';

abstract class CollectionCrudController<TModel extends CrudModelMixin,
    TSelf extends CollectionCrudController<TModel, TSelf>> extends BaseFirestoreCrudController<TModel, dynamic, TSelf> {
  final CacheMap<String, TModel> cache = CacheMap<String, TModel>();

  CollectionCrudController(CollectionReference collectionReference)
      : super(collectionReference, FirestoreDataType.document);

  @override
  DocumentReference getDocument(String id, {dynamic arg}) => collectionReference.doc(id);

  @override
  TModel? fromSnapshotMap(Map<String, dynamic> data, String id, {dynamic arg}) => fromJson(this as TSelf, data);

  @override
  bool isCached(String id, dynamic arg) => cache.isCached(id);

  @override
  void setCache(String id, TModel? data, dynamic arg) => cache.set(id, data);

  @override
  TModel? getCache(String id, dynamic arg) => cache.get(id);

  @override
  void removeCache(String id, dynamic arg) => cache.remove(id);
}
