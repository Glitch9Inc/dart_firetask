import 'package:cloud_firestore/cloud_firestore.dart';

class FireTransactionRunner {
  final FirebaseFirestore firestore;

  const FireTransactionRunner({required this.firestore});

  Future<T> run<T>(
    Future<T> Function(Transaction transaction) action, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) {
    return firestore.runTransaction(
      action,
      timeout: timeout,
      maxAttempts: maxAttempts,
    );
  }
}
