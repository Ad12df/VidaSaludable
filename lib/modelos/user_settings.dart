class UserSettings {
  final String userId;
  final String? brightness;
  final int? seedColor;
  final String? fontFamily;
  final String? language;
  final bool? followLocation;
  final double? metaHydratationMl;
  // Agregado para permisos y preferencias adicionales
  final Map<String, bool>? permissions;
  final bool? shareAnonymous;
  final bool? pushEnabled;
  final bool? remindersEnabled;
  final bool? healthAlerts;
  final bool? locationPersonalized;
  final bool? highContrast;
  final int? notificationFrequency;
  final double? textScale;
  final bool? sleepAutoDetectionEnabled;
  final String? appTheme;

  const UserSettings({
    required this.userId,
    this.brightness,
    this.seedColor,
    this.fontFamily,
    this.language,
    this.followLocation,
    this.metaHydratationMl,
    this.permissions,
    this.shareAnonymous,
    this.pushEnabled,
    this.remindersEnabled,
    this.healthAlerts,
    this.locationPersonalized,
    this.highContrast,
    this.notificationFrequency,
    this.textScale,
    this.sleepAutoDetectionEnabled,
    this.appTheme,
  });

  Map<String, dynamic> toMap() => {
    'userId': userId,
    'brightness': brightness,
    'seedColor': seedColor,
    'fontFamily': fontFamily,
    'language': language,
    'followLocation': followLocation,
    'metaHydratationMl': metaHydratationMl,
    'permissions': permissions,
    'shareAnonymous': shareAnonymous,
    'pushEnabled': pushEnabled,
    'remindersEnabled': remindersEnabled,
    'healthAlerts': healthAlerts,
    'locationPersonalized': locationPersonalized,
    'highContrast': highContrast,
    'notificationFrequency': notificationFrequency,
    'textScale': textScale,
    'sleepAutoDetectionEnabled': sleepAutoDetectionEnabled,
    'appTheme': appTheme,
  };

  factory UserSettings.fromMap(Map map) => UserSettings(
    userId: '${map['userId'] ?? ''}',
    brightness: map['brightness'] == null ? null : '${map['brightness']}',
    seedColor: (map['seedColor'] is int)
        ? map['seedColor']
        : int.tryParse('${map['seedColor'] ?? ''}'),
    fontFamily: map['fontFamily'] == null ? null : '${map['fontFamily']}',
    language: map['language'] == null ? null : '${map['language']}',
    followLocation: map['followLocation'] == null
        ? null
        : (map['followLocation'] is bool
              ? map['followLocation']
              : '${map['followLocation']}' == 'true'),
    metaHydratationMl: (map['metaHydratationMl'] is double)
        ? map['metaHydratationMl']
        : double.tryParse('${map['metaHydratationMl'] ?? ''}'),
    permissions: (map['permissions'] is Map)
        ? Map<String, bool>.from(
            (map['permissions'] as Map).map(
              (k, v) => MapEntry('$k', v is bool ? v : '$v' == 'true'),
            ),
          )
        : null,
    shareAnonymous: map['shareAnonymous'] == null
        ? null
        : (map['shareAnonymous'] is bool
              ? map['shareAnonymous']
              : '${map['shareAnonymous']}' == 'true'),
    pushEnabled: map['pushEnabled'] == null
        ? null
        : (map['pushEnabled'] is bool
              ? map['pushEnabled']
              : '${map['pushEnabled']}' == 'true'),
    remindersEnabled: map['remindersEnabled'] == null
        ? null
        : (map['remindersEnabled'] is bool
              ? map['remindersEnabled']
              : '${map['remindersEnabled']}' == 'true'),
    healthAlerts: map['healthAlerts'] == null
        ? null
        : (map['healthAlerts'] is bool
              ? map['healthAlerts']
              : '${map['healthAlerts']}' == 'true'),
    locationPersonalized: map['locationPersonalized'] == null
        ? null
        : (map['locationPersonalized'] is bool
              ? map['locationPersonalized']
              : '${map['locationPersonalized']}' == 'true'),
    highContrast: map['highContrast'] == null
        ? null
        : (map['highContrast'] is bool
              ? map['highContrast']
              : '${map['highContrast']}' == 'true'),
    notificationFrequency: (map['notificationFrequency'] is int)
        ? map['notificationFrequency']
        : int.tryParse('${map['notificationFrequency'] ?? ''}'),
    textScale: (map['textScale'] is double)
        ? map['textScale']
        : double.tryParse('${map['textScale'] ?? ''}'),
    sleepAutoDetectionEnabled: map['sleepAutoDetectionEnabled'] == null
        ? null
        : (map['sleepAutoDetectionEnabled'] is bool
              ? map['sleepAutoDetectionEnabled']
              : '${map['sleepAutoDetectionEnabled']}' == 'true'),
    appTheme: map['appTheme'] == null ? null : '${map['appTheme']}',
  );
}
