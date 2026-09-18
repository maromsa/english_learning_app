import 'package:english_learning_app/services/notification_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

class _ScheduledCall {
  _ScheduledCall({
    required this.id,
    required this.title,
    required this.body,
    required this.scheduledDate,
    required this.matchDateTimeComponents,
  });

  final int id;
  final String? title;
  final String? body;
  final tz.TZDateTime scheduledDate;
  final DateTimeComponents? matchDateTimeComponents;
}

class _FakeNotificationsPlugin extends Fake
    implements FlutterLocalNotificationsPlugin {
  int initializeCount = 0;
  int cancelAllCount = 0;
  final List<int> cancelledIds = [];
  final List<_ScheduledCall> scheduled = [];

  @override
  Future<bool?> initialize(
    InitializationSettings initializationSettings, {
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
    DidReceiveBackgroundNotificationResponseCallback?
        onDidReceiveBackgroundNotificationResponse,
  }) async {
    initializeCount++;
    return true;
  }

  @override
  Future<void> cancel(int id, {String? tag}) async {
    cancelledIds.add(id);
  }

  @override
  Future<void> cancelAll() async {
    cancelAllCount++;
  }

  @override
  Future<void> zonedSchedule(
    int id,
    String? title,
    String? body,
    tz.TZDateTime scheduledDate,
    NotificationDetails notificationDetails, {
    required UILocalNotificationDateInterpretation
        uiLocalNotificationDateInterpretation,
    required AndroidScheduleMode androidScheduleMode,
    String? payload,
    DateTimeComponents? matchDateTimeComponents,
  }) async {
    scheduled.add(
      _ScheduledCall(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduledDate,
        matchDateTimeComponents: matchDateTimeComponents,
      ),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeNotificationsPlugin plugin;
  late NotificationService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.UTC);
    plugin = _FakeNotificationsPlugin();
    service = NotificationService(plugin: plugin);
    await service.initialize();
  });

  test('initialize configures the plugin once and is idempotent', () async {
    await service.initialize();
    expect(plugin.initializeCount, 1);
    expect(service.isInitialized, isTrue);
  });

  test('scheduleDailyReminder uses the practice-reminder copy at 16:00',
      () async {
    await service.scheduleDailyReminder(
      hour: NotificationService.defaultReminderHour,
      minute: NotificationService.defaultReminderMinute,
    );

    expect(plugin.scheduled, hasLength(1));
    final call = plugin.scheduled.single;
    expect(call.id, NotificationService.dailyReminderId);
    expect(call.title, NotificationService.dailyReminderTitle);
    expect(call.body, NotificationService.dailyReminderBody);
    expect(call.scheduledDate.hour, NotificationService.defaultReminderHour);
    expect(
        call.scheduledDate.minute, NotificationService.defaultReminderMinute);
    expect(call.matchDateTimeComponents, DateTimeComponents.time);
    expect(plugin.cancelledIds, contains(NotificationService.dailyReminderId));
  });

  test('scheduleDailyReminder skipToday fires tomorrow, not later today',
      () async {
    await service.scheduleDailyReminder(
      hour: NotificationService.defaultReminderHour,
      minute: NotificationService.defaultReminderMinute,
      skipToday: true,
    );

    final call = plugin.scheduled.single;
    final now = tz.TZDateTime.now(tz.local);
    final scheduledDay = DateTime(
      call.scheduledDate.year,
      call.scheduledDate.month,
      call.scheduledDate.day,
    );
    final today = DateTime(now.year, now.month, now.day);
    expect(scheduledDay.isAfter(today), isTrue);
    expect(call.scheduledDate.hour, NotificationService.defaultReminderHour);
    expect(call.matchDateTimeComponents, isNull);
  });

  test('cancelAllReminders cancels every pending notification', () async {
    await service.cancelAllReminders();
    expect(plugin.cancelAllCount, 1);
  });
}
