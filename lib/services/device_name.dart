import 'package:device_info_plus/device_info_plus.dart';

/// "Redmi Note 13 Pro" + "Android 15", shown in Logged-in devices.
Future<Map<String, String>> deviceInfo() async {
  try {
    final a = await DeviceInfoPlugin().androidInfo;
    final brand = a.manufacturer.isEmpty ? '' : '${a.manufacturer[0].toUpperCase()}${a.manufacturer.substring(1)}';
    final model = a.model.toLowerCase().startsWith(a.manufacturer.toLowerCase()) ? a.model : '$brand ${a.model}';
    return {'name': model.trim(), 'platform': 'Android ${a.version.release}'};
  } catch (_) {
    return {'name': 'Android phone', 'platform': 'Android'};
  }
}
