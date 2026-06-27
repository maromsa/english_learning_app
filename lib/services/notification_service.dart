// lib/services/notification_service.dart
//
// Local push notifications for the English learning app.
//
// Two channels:
//   1. "daily_reminder" — daily practice reminder at a user-chosen time.
//   2. "srs_due"        — reminder when SRS cards are due for review.
//
// Both are scheduled with flutter_local_notifications + timezone.
// No server push required — all scheduling is device-local.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Wraps [FlutterLocalNotificationsPlugin] with app-level scheduling helpers.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const String _prefDailyHour = 'notif_daily_hour';
  static const String _prefDailyMinute = 'notif_daily_minute';
  static const String _prefDailyEnabled = 'notif_daily_enabled';
  static const String _prefSrsEnabled = 'notif_srs_enabled';

  static const int _dailyReminderId = 1001;
  static const int _srsReminderId = 1002;

  bool _initialized = false;

  // --------------------------------------------------------------------------
  // Init
  // --------------------------------------------------------------------------

  Future<void> initialize() async {
    if (_initialized) return;
    if (kIsWeb) {
      _initialized = true;
      return; // no local notifications on web
    }

    tz.initializeTimeZones();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(initSettings);
    _initialized = true;
  }

  // --------------------------------------------------------------------------
  // Permissions
  // --------------------------------------------------------------------------

  /// Request notification permission (iOS / Android 13+).
  /// Returns true if granted.
  Future<bool> requestPermission() async {
    if (kIsWeb) return false;
    if (Platform.isIOS) {
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      final granted = await ios?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }
    if (Platform.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final granted = await android?.requestNotificationsPermission();
      return granted ?? false;
    }
    return false;
  }

  // --------------------------------------------------------------------------
  // Daily reminder
  // --------------------------------------------------------------------------

  /// Schedule (or reschedule) the daily practice reminder.
  ///
  /// [hour] and [minute] are local-time values (0–23, 0–59).
  Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
  }) async {
    if (kIsWeb || !_initialized) return;

    await _plugin.cancel(_dailyReminderId);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefDailyHour, hour);
    await prefs.setInt(_prefDailyMinute, minute);
    await prefs.setBool(_prefDailyEnabled, true);

    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      _dailyReminderId,
      'זמן ללמוד אנגלית! 🌟',
      'ספארק מחכה לך — בוא נלמד מילה חדשה היום!',
      scheduled,
      _androidDetails('daily_reminder', 'תזכורת יומית'),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> cancelDailyReminder() async {
    if (kIsWeb) return;
    await _plugin.cancel(_dailyReminderId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefDailyEnabled, false);
  }

  // --------------------------------------------------------------------------
  // SRS due reminder
  // --------------------------------------------------------------------------

  /// Schedule a one-time reminder for SRS review, [when] in the future.
  ///
  /// If [when] is in the past or within the next minute, schedules 1 minute
  /// from now instead.
  Future<void> scheduleSrsReminder({DateTime? when}) async {
    if (kIsWeb || !_initialized) return;

    await _plugin.cancel(_srsReminderId);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefSrsEnabled, true);

    final now = tz.TZDateTime.now(tz.local);
    final rawWhen = when ?? now.toLocal().add(const Duration(hours: 4));
    var scheduled = tz.TZDateTime.from(rawWhen, tz.local);
    if (scheduled.isBefore(now.add(const Duration(minutes: 1)))) {
      scheduled = now.add(const Duration(minutes: 1));
    }

    await _plugin.zonedSchedule(
      _srsReminderId,
      'יש לך מילים לחזרה! 🧠',
      'כמה מילות SRS ממתינות לך — חזרה קצרה ממצקת את הזיכרון!',
      scheduled,
      _androidDetails('srs_due', 'חזרה מדורגת'),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  Future<void> cancelSrsReminder() async {
    if (kIsWeb) return;
    await _plugin.cancel(_srsReminderId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefSrsEnabled, false);
  }

  // --------------------------------------------------------------------------
  // Restore on app-launch (re-schedule if settings say enabled)
  // --------------------------------------------------------------------------

  Future<void> restoreScheduledNotifications() async {
    if (kIsWeb || !_initialized) return;

    final prefs = await SharedPreferences.getInstance();

    final dailyEnabled = prefs.getBool(_prefDailyEnabled) ?? false;
    if (dailyEnabled) {
      final hour = prefs.getInt(_prefDailyHour) ?? 18;
      final minute = prefs.getInt(_prefDailyMinute) ?? 0;
      await scheduleDailyReminder(hour: hour, minute: minute);
    }
  }

  // --------------------------------------------------------------------------
  // Settings getters (for Settings UI)
  // --------------------------------------------------------------------------

  Future<({bool dailyEnabled, int hour, int minute, bool srsEnabled})>
      getSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return (
      dailyEnabled: prefs.getBool(_prefDailyEnabled) ?? false,
      hour: prefs.getInt(_prefDailyHour) ?? 18,
      minute: prefs.getInt(_prefDailyMinute) ?? 0,
      srsEnabled: prefs.getBool(_prefSrsEnabled) ?? false,
    );
  }

  // --------------------------------------------------------------------------
  // Helpers
  // --------------------------------------------------------------------------

  NotificationDetails _androidDetails(String channelId, String channelName) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: 'התראות מהאפליקציה ללמידת אנגלית',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
  }
}
