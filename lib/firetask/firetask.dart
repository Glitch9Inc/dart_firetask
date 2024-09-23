import 'package:flutter_corelib/flutter_corelib.dart';
import 'package:dart_firetask/dart_firetask.dart';

// Firestore 작업의 종류를 나타내는 열거형
enum FiretaskOperationType {
  set,
  update,
  delete,
}

class Firetask {
  final FiretaskOperationType type;
  final FirestoreDataType dataType;
  final DocumentReference docRef;
  final Map<String, dynamic>? data;
  final void Function(Result<void>)? onComplete;

  Firetask.set(this.docRef, this.data, this.dataType, {this.onComplete}) : type = FiretaskOperationType.set;

  Firetask.update(this.docRef, this.data, this.dataType, {this.onComplete}) : type = FiretaskOperationType.update;

  Firetask.delete(this.docRef, this.dataType, {this.onComplete})
      : type = FiretaskOperationType.delete,
        data = null;
}
