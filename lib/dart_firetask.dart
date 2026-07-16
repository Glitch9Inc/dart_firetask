library dart_firetask;

// models
export 'models/firetask.dart';
export 'models/fire_batch.dart';
export 'models/fire_transaction_runner.dart';
export 'models/firestore_model.dart';
export 'models/firestore_data_type.dart';

// crud
export 'crud_client/client/firestore_client.dart';
export 'crud_client/client/firestore_map_client.dart';

export 'crud_client/exception/crud_operation_exception_base.dart';
export 'crud_client/exception/crud_operation_exception_type.dart';
export 'crud_client/exception/document_snapshot_exception.dart';

// external firestore libraries
export 'package:cloud_firestore/cloud_firestore.dart';

// Firestore에서는 '.'(점)을 필드 이름으로 사용할 수 없다.
// 따라서 Email같은 것을 필드로 사용할 경우 '.'을 대체할 Seperator를 정의한다.
const kReplaceDotSeperator = '___';
