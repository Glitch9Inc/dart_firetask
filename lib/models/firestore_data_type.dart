enum FirestoreDataType {
  /// Each data is stored in a single document
  singleDocument,

  /// Each data is stored in a map in a document
  mapInDocument,
}

extension FirestoreDataTypeExtension on FirestoreDataType {
  String getName({bool firstLetter = false}) {
    String name = '';
    switch (this) {
      case FirestoreDataType.singleDocument:
        name = 'single document';
        break;
      case FirestoreDataType.mapInDocument:
        name = 'map in document';
        break;
    }

    if (firstLetter) {
      return name[0].toUpperCase() + name.substring(1);
    } else {
      return name;
    }
  }
}
