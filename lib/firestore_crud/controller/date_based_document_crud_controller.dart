import 'package:flutter_corelib/flutter_corelib.dart';
import 'package:dart_firetask/dart_firetask.dart';

/// Mainly used for data that is stored in Firestore in a date-based manner
/// such as daily history data or monthly statistics data.
abstract class DateBasedDocumentCrudController<TModel extends DailyDto<TModel>,
        TSelf extends DateBasedDocumentCrudController<TModel, TSelf>>
    extends BaseFirestoreCrudController<TModel, Date, TSelf> {
  final DateBasedCacheMap<String, TModel> cache;
  final String dataName;

  DateBasedDocumentCrudController(CollectionReference collectionReference, {required this.dataName})
      : cache = DateBasedCacheMap<String, TModel>(dataName: dataName),
        super(collectionReference, FirestoreDataType.field);

  @override
  String resolveDocumentId(Date? arg) {
    arg ??= Date.today();
    return '${arg.year}-${arg.month}';
  }

  @override
  String resolveFieldName(String id) => '$dataName-$id';

  @override
  DocumentReference getDocument(String id, {Date? arg}) =>
      collectionReference.doc(resolveDocumentId(cache.resolveDate(arg)));

  @override
  TModel? fromSnapshotMap(Map<String, dynamic> data, String id, {Date? arg}) {
    if (arg == null) {
      final cachedData = getCache(id, arg);
      if (cachedData != null) {
        return cachedData;
      }
    }

    int totalDaysInMonth = arg!.toDateTime().daysInMonth();
    for (int i = 1; i <= totalDaysInMonth; i++) {
      final key = '$dataName-$i';
      if (data[key] == null) {
        // null을 캐싱한다 (데이터가 없다는 것을 의미)
        logger.info('Cache null data: $id, $key');
        setCache(key, null, arg);
      }
      final model = fromJson(this as TSelf, data[key] as Map<String, dynamic>);
      logger.info('Cache data: $id, $key');
      setCache(key, model, arg);
    }

    // 그중에 필요한 데이터만 반환한다.
    return getCache(id, arg);
  }

  @override
  bool isCached(String id, Date? arg) => cache.isCached(id, date: arg);

  @override
  void setCache(String id, TModel? data, Date? arg) => cache.set(id, data, date: arg);

  @override
  TModel? getCache(String id, Date? arg) => cache.get(id, date: arg);

  @override
  void removeCache(String id, Date? arg) => cache.remove(id, date: arg);
}
