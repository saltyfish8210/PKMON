import '../api/api_failure.dart';

/// DTO 解析的严格小工具：缺字段或类型不符一律抛 [FailureKind.protocol]。
/// 设计约定：多余字段忽略（向前兼容），必填字段缺失不静默补默认值。

Map<String, dynamic> asJsonMap(Object? value, String field) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  throw ApiFailure.protocol('响应字段 $field 不是对象');
}

List<Object?> asJsonList(Object? value, String field) {
  if (value is List) return value;
  throw ApiFailure.protocol('响应字段 $field 不是数组');
}

String requireString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String && value.isNotEmpty) return value;
  throw ApiFailure.protocol('响应缺少字段 $key');
}

String? optionalString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is String) return value;
  throw ApiFailure.protocol('响应字段 $key 不是字符串');
}

int requireInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is int) return value;
  if (value is num) return value.toInt();
  throw ApiFailure.protocol('响应缺少整数字段 $key');
}

int? optionalInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  throw ApiFailure.protocol('响应字段 $key 不是整数');
}

bool requireBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is bool) return value;
  throw ApiFailure.protocol('响应缺少布尔字段 $key');
}

bool? optionalBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is bool) return value;
  throw ApiFailure.protocol('响应字段 $key 不是布尔值');
}

DateTime requireUtcTime(Map<String, dynamic> json, String key) {
  final raw = requireString(json, key);
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) throw ApiFailure.protocol('响应字段 $key 不是合法时间');
  return parsed.toUtc();
}

DateTime? optionalUtcTime(Map<String, dynamic> json, String key) {
  final raw = optionalString(json, key);
  if (raw == null || raw.isEmpty) return null;
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) throw ApiFailure.protocol('响应字段 $key 不是合法时间');
  return parsed.toUtc();
}
