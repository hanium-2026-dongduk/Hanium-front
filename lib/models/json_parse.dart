/// 서버 JSON을 읽을 때 쓰는 작은 변환기들.
library;

/// 식별자 파싱.
///
/// 백엔드 id 컬럼이 BIGINT라 드라이버 설정에 따라 숫자로도, 문자열로도 내려온다.
/// 어느 쪽이 와도 깨지지 않게 한곳에서 흡수한다.
int parseId(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

/// 선택 정수 필드. 값이 없거나 형식이 어긋나면 null.
int? parseOptionalInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}
