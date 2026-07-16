/// 기본 컨버터. 이걸 확장해서 [FireModel]안의 static 변수에 할당하면 다른 컨버터를 사용할 수 있음.
class MapConverter {
  Map<String, dynamic> toJson(Map<String, Object?> map) {
    // 기본 타입이 아닌 경우
    // 1. Enum
    // 2. DateTime
    // 3. TimeOfDay
    // 4. Duration

    final networkMap = <String, dynamic>{};

    map.forEach((key, value) {
      if (value == null) {
        networkMap[key] = null;
      } else if (value is Enum) {
        networkMap[key] = getEnumName(value.toString());
      } else if (value is DateTime) {
        networkMap[key] = value.toIso8601String();
      } else if (value is Duration) {
        networkMap[key] = value.inMilliseconds;
      } else {
        networkMap[key] = value;
      }
    });

    return networkMap;
  }

  String getEnumName(String enumAsString) =>
      enumAsString.split('.').last.toLowerCase();

  Map<String, Object?> fromJson(Map<String, Object?> map) {
    final localMap = <String, Object?>{};

    map.forEach((key, value) {
      if (value == null) {
        localMap[key] = null;
      } else if (value is String) {
        if (value.contains('T') && value.contains('Z')) {
          localMap[key] = DateTime.parse(value);
        } else {
          localMap[key] = value;
        }
      } else if (value is int) {
        localMap[key] = Duration(milliseconds: value);
      } else {
        localMap[key] = value;
      }
    });

    return localMap;
  }
}
