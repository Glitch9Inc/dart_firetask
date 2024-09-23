import 'package:dart_firetask/dart_firetask.dart';

class DocumentSnapshotException extends CrudOperationExceptionBase {
  DocumentSnapshotException(DocumentReference doc)
      : super(
          type: CrudOperationExceptionType.network,
          message: 'Failed to get document: ${doc.path}',
        );
}
