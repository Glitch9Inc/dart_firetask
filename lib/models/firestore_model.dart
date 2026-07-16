import 'package:dart_firetask/dart_firetask.dart';
import 'package:flutter_corelib/flutter_corelib.dart';

/// General model DTO for crud operations
abstract class FirestoreModel extends ServerModel {
  @override
  FirestoreClient get client;

  FirestoreModel({super.id, super.timestamps});

  @override
  FirestoreModel.fromJson(super.json) : super.fromJson();
}
