import 'package:dart_corelib/dart_corelib.dart';
import 'package:dart_firetask/dart_firetask.dart';

/// General model DTO for crud operations
abstract class FirestoreModel extends ServerModel {
  @override
  FirestoreClient get client;

  FirestoreModel({super.id, super.timestamps});

  @override
  FirestoreModel.fromJson(super.json) : super.fromJson();
}
