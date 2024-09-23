import 'package:dart_firetask/dart_firetask.dart';

abstract class CrudOperationExceptionBase implements Exception {
  final String message;
  final CrudOperationExceptionType type;

  CrudOperationExceptionBase({
    required this.type,
    required this.message,
  });
}
