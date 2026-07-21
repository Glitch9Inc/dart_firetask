import 'package:dart_corelib/dart_corelib.dart';
import 'package:dart_firetask/dart_firetask.dart';

enum FiretaskType {
  merge,
  replace,
  update,
  delete,
}

class Firetask {
  final FiretaskType type;
  final FirestoreDataType dataType;
  final DocumentReference docRef;
  final Map<String, dynamic>? data;
  final void Function(Result<void>)? onComplete;

  /// Backwards-compatible merge write.
  Firetask.set(this.docRef, this.data, this.dataType, {this.onComplete})
      : type = FiretaskType.merge;

  Firetask.replace(this.docRef, this.data, this.dataType, {this.onComplete})
      : type = FiretaskType.replace;

  Firetask.update(this.docRef, this.data, this.dataType, {this.onComplete})
      : type = FiretaskType.update;

  Firetask.delete(this.docRef, this.dataType, {this.onComplete})
      : type = FiretaskType.delete,
        data = null;
}
