import 'package:flutter_corelib/flutter_corelib.dart';

abstract class FirestoreCrud {
  static BaseExceptionHandler? exceptionHandler;

  static void handleException(Object e, StackTrace s) {
    if (exceptionHandler == null) return;
    exceptionHandler!(e, s);
  }
}
