import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Servicio para programar recordatorios reales de hidratación con notificaciones locales.
class HydrationReminderService {
  HydrationReminderService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const int _hydrationNotificationId = 7001;
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;

    tz.initializeTimeZones();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: DarwinInitializationSettings(),
    );

    await _plugin.initialize(initSettings);
    _initialized = true;
  }

  static Future<void> requestPermissions() async {
    await initialize();

    final androidImplementation =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidImplementation?.requestNotificationsPermission();

    final iosImplementation =
        _plugin.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
    await iosImplementation?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  static Future<void> cancelHydrationReminder() async {
    await initialize();
    await _plugin.cancel(_hydrationNotificationId);
  }

  static Future<void> scheduleHydrationReminder({
    required int intervalMinutes,
  }) async {
    await initialize();

    if (intervalMinutes <= 0) {
      await cancelHydrationReminder();
      return;
    }

    await cancelHydrationReminder();

    final androidDetails = AndroidNotificationDetails(
      'hydration_reminders_channel',
      'Recordatorios de hidratación',
      channelDescription: 'Notificaciones para recordar tomar agua',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
    );

    const iosDetails = DarwinNotificationDetails();

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final now = tz.TZDateTime.now(tz.local);
    final next = now.add(Duration(minutes: intervalMinutes));

    await _plugin.zonedSchedule(
      _hydrationNotificationId,
      'Hora de hidratarte 💧',
      'Toma un vaso de agua para seguir tu meta diaria.',
      next,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: 'hydration_reminder',
    );
  }

  static Future<void> showTestNotification() async {
    await initialize();

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'hydration_reminders_channel',
        'Recordatorios de hidratación',
        channelDescription: 'Notificaciones para recordar tomar agua',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
      ),
      iOS: DarwinNotificationDetails(),
    );

    await _plugin.show(
      _hydrationNotificationId + 1,
      'Prueba de notificación 💧',
      'Las notificaciones de hidratación están activas.',
      details,
      payload: 'hydration_test',
    );
  }
}
