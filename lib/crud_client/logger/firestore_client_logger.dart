import 'package:logging/logging.dart';

class FirestoreClientLogger {
  late final Logger _logger;
  late final String _firestoreDataTypeCap;
  late final String _firestoreDataType;

  FirestoreClientLogger(
      {required String className, required String firestoreDataType}) {
    _logger = Logger(className);
    _firestoreDataTypeCap = firestoreDataType.isEmpty
        ? firestoreDataType
        : '${firestoreDataType[0].toUpperCase()}${firestoreDataType.substring(1)}';
    _firestoreDataType = firestoreDataType;
  }

  void info(String message) {
    _logger.info(message);
  }

  void warning(String message) {
    _logger.warning(message);
  }

  void severe(String message) {
    _logger.severe(message);
  }

  void onCreate(String id) {
    _logger.info('Creating $_firestoreDataType: $id');
  }

  void onCreated(String id) {
    _logger.info('$_firestoreDataTypeCap created: $id');
  }

  void onCached(String id) {
    _logger.info('$_firestoreDataTypeCap cached: $id');
  }

  void onCacheFound(String id) {
    _logger.info('$_firestoreDataTypeCap cache found: $id');
  }

  void onCacheFoundButNull(String id) {
    _logger.warning('$_firestoreDataTypeCap cache found but null: $id');
  }

  void onDocumentFound(String id) {
    _logger.info('$_firestoreDataTypeCap document found: $id');
  }

  void onDocumentNotFound(String id) {
    _logger.warning('$_firestoreDataTypeCap document not found: $id');
  }

  void onDocumentNotFoundCreateNew(String id) {
    _logger.warning(
        '$_firestoreDataTypeCap document not found and create new: $id');
  }

  void onRetrieve(String id) {
    _logger.info('Retrieving $_firestoreDataType: $id');
  }

  void onRetrieved(String id) {
    _logger.info('$_firestoreDataTypeCap retrieved: $id');
  }

  void onUpdate(String id) {
    _logger.info('Updating $_firestoreDataType: $id');
  }

  void onUpdated(String id) {
    _logger.info('$_firestoreDataTypeCap updated: $id');
  }

  void onCacheUpdated(String id) {
    _logger.info('$_firestoreDataTypeCap cache updated: $id');
  }

  void onDelete(String id) {
    _logger.info('Deleting $_firestoreDataType: $id');
  }

  void onDeleted(String id) {
    _logger.info('$_firestoreDataTypeCap deleted: $id');
  }

  void onCacheDeleted(String id) {
    _logger.info('$_firestoreDataTypeCap cache deleted: $id');
  }

  void onList({int? count, String? orderBy, String? id}) {
    _logger.info(
        'Listing $_firestoreDataType: count: $count, orderBy: $orderBy, id: $id');
  }

  void onListed({int? count, String? orderBy, String? id}) {
    _logger.info(
        '$_firestoreDataTypeCap listed: count: $count, orderBy: $orderBy, id: $id');
  }

  void onBatchSet(String id) {
    _logger.info('Batch setting $_firestoreDataType: $id');
  }

  void onBatchPatch(String id) {
    _logger.info('Batch patching $_firestoreDataType: $id');
  }

  void onBatchDelete(String id) {
    _logger.info('Batch deleting $_firestoreDataType: $id');
  }
}
