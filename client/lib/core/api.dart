import 'package:flutter/foundation.dart' show kIsWeb;

abstract final class Api {
  static String get defaultBase {
    const override = String.fromEnvironment('API_BASE');
    if (override.isNotEmpty) return override;
    return kIsWeb ? Uri.base.origin : 'http://10.0.2.2:4180';
  }
}
