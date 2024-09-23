import 'package:flutter_corelib/flutter_corelib.dart';
import 'package:dart_firetask/dart_firetask.dart';

class FiretaskBatch {
  // Firestore 인스턴스
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 배치 작업 캐시
  static final List<Firetask> _tasks = [];
  static final Map<DocumentReference, Map<String, dynamic>> _fieldBatchTempData = {};
  static int get taskCount => _tasks.length;

  // 배치 작업 시작
  static void reset() {
    _fieldBatchTempData.clear();
    _tasks.clear();
  }

  // Firetask 추가
  static void add(Firetask task) {
    _tasks.add(task);
  }

// Firetask를 배치에 적용하는 메서드
  static Future<WriteBatch> _applyTask(Firetask task, WriteBatch batch) async {
    if (task.dataType == FirestoreDataType.document) {
      return _registerDocumentTask(task, batch);
    } else {
      return await _registerFieldTask(task, batch);
    }
  }

  // This is for Collection Type Firestore
  static WriteBatch _registerDocumentTask(Firetask task, WriteBatch batch) {
    switch (task.type) {
      case FiretaskOperationType.set:
        batch.set(task.docRef, task.data!, SetOptions(merge: true));
        break;
      case FiretaskOperationType.update:
        batch.update(task.docRef, task.data!);
        break;
      case FiretaskOperationType.delete:
        batch.delete(task.docRef);
        break;
    }
    return batch;
  }

  // This is for Document Type Firestore
  static Future<WriteBatch> _registerFieldTask(Firetask task, WriteBatch batch) async {
    if (!_fieldBatchTempData.containsKey(task.docRef)) {
      //_fieldBatchTempData[task.docRef] = {};
      // 빈 맵을 만들어서 넣어주는 것이 아니라, 기존의 데이터를 가져와서 넣어주어야 함
      _fieldBatchTempData[task.docRef] = {};

      var docRef = task.docRef;
      var snapshot = await docRef.get();

      if (snapshot.exists) {
        _fieldBatchTempData[task.docRef]!.addAll(snapshot.data() as Map<String, dynamic>);
      }
    }

    _fieldBatchTempData[task.docRef]!.addAll(task.data!);
    return batch;
  }

  // 배치 작업 커밋
  static Future<Result<void>> commit() async {
    WriteBatch writeBatch = _firestore.batch();
    List<String> errorMessages = [];

    for (var task in _tasks) {
      try {
        writeBatch = await _applyTask(task, writeBatch);
        task.onComplete?.call(Result(isSuccess: true));
      } catch (e) {
        errorMessages.add(e.toString());
        task.onComplete?.call(Result(isSuccess: false, message: e.toString()));
      }
    }

    if (_fieldBatchTempData.isNotEmpty) {
      for (var entry in _fieldBatchTempData.entries) {
        try {
          writeBatch.set(entry.key, entry.value);
        } catch (e) {
          errorMessages.add(e.toString());
        }
      }
    }

    try {
      await writeBatch.commit();
    } catch (e) {
      errorMessages.add(e.toString());
    }

    reset();

    if (errorMessages.isNotEmpty) {
      return Result(isSuccess: false, message: errorMessages.join('\n'));
    } else {
      return Result(isSuccess: true);
    }
  }
}
