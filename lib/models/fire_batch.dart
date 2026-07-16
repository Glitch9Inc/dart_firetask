import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dart_firetask/models/firetask.dart';
import 'package:dart_firetask/models/firestore_data_type.dart';
import 'package:flutter_corelib/flutter_corelib.dart';

class FireBatch {
  final FirebaseFirestore firestore;
  final WriteBatch _batch;
  final List<Firetask> _tasks = [];
  final List<Object> callbackErrors = [];

  bool _committed = false;

  FireBatch({FirebaseFirestore? firestore})
      : firestore = firestore ?? FirebaseFirestore.instance,
        _batch = (firestore ?? FirebaseFirestore.instance).batch();

  bool get isCommitted => _committed;
  bool get isEmpty => _tasks.isEmpty;
  int get length => _tasks.length;

  Future<void> set(Firetask task) async {
    if (_committed) {
      throw StateError('Cannot add a task to an already committed FireBatch.');
    }

    _registerTask(task);
    _tasks.add(task);
  }

  Future<void> commit() async {
    if (_committed) {
      throw StateError('FireBatch can only be committed once.');
    }
    _committed = true;

    try {
      await _batch.commit();
      _notifyCallbacks(Result<void>.success());
    } catch (error) {
      _notifyCallbacks(Result.error(error.toString()));
      rethrow;
    }
  }

  void _registerTask(Firetask task) {
    if (task.dataType == FirestoreDataType.mapInDocument) {
      _registerMapTask(task);
      return;
    }
    _registerDocumentTask(task);
  }

  void _registerDocumentTask(Firetask task) {
    switch (task.type) {
      case FiretaskType.merge:
        _batch.set(task.docRef, task.data!, SetOptions(merge: true));
      case FiretaskType.replace:
        _batch.set(task.docRef, task.data!);
      case FiretaskType.update:
        _batch.update(task.docRef, task.data!);
      case FiretaskType.delete:
        _batch.delete(task.docRef);
    }
  }

  void _registerMapTask(Firetask task) {
    if (task.type == FiretaskType.delete) {
      throw ArgumentError(
        'A map entry delete must use an update payload with FieldValue.delete().',
      );
    }

    // Each payload is keyed by the map entry ID. Merge writes avoid the old
    // client-side read-modify-write of the entire document.
    _batch.set(task.docRef, task.data!, SetOptions(merge: true));
  }

  void _notifyCallbacks(Result<void> result) {
    for (final task in _tasks) {
      try {
        task.onComplete?.call(result);
      } catch (error) {
        // The Firestore commit has already reached a terminal state. Do not
        // throw from a local cache callback and make callers retry the write.
        callbackErrors.add(error);
      }
    }
  }
}
