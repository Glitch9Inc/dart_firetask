import 'package:cloud_firestore/cloud_firestore.dart';

abstract class FirestoreConverter {
  static dynamic processDynamic(dynamic value) {
    if (value is DateTime) {
      return Timestamp.fromDate(value);
    } else {
      return value;
    }
  }
}
