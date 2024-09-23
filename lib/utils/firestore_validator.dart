import 'package:flutter_corelib/flutter_corelib.dart';

abstract class FirestoreValidator {
  static Result invalidDocumentId(String id, Logger logger) {
    if (id.isEmpty) {
      logger.severe('Document ID is null or empty');
      return Result.error('Document ID is null or empty');
    }
    return Result.successVoid();
  }
}
