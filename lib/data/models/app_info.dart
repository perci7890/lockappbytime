class AppInfo {
  final String packageName;
  final String appName;
  final String iconBase64;
  final bool isSystemApp;

  AppInfo({
    required this.packageName,
    required this.appName,
    required this.iconBase64,
    required this.isSystemApp,
  });

  factory AppInfo.fromMap(Map<dynamic, dynamic> map) {
    return AppInfo(
      packageName: map['packageName'] as String? ?? '',
      appName: map['appName'] as String? ?? '',
      iconBase64: map['iconBase64'] as String? ?? '',
      isSystemApp: map['isSystemApp'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'packageName': packageName,
      'appName': appName,
      'iconBase64': iconBase64,
      'isSystemApp': isSystemApp,
    };
  }
}
