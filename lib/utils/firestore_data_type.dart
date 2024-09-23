enum FirestoreDataType {
  document,
  field,
}

extension FirestoreDataTypeExtension on FirestoreDataType {
  String getName({bool firstLetter = false}) {
    String name = '';
    switch (this) {
      case FirestoreDataType.document:
        name = 'document';
        break;
      case FirestoreDataType.field:
        name = 'field';
        break;
    }

    if (firstLetter) {
      return name[0].toUpperCase() + name.substring(1);
    } else {
      return name;
    }
  }
}
