import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../../core/models/intent.dart';

// ─── Modelo de Recordatorio ───────────────────────────────────────────────────

class Reminder {
  final String id;
  final String label;
  final DateTime scheduledAt;
  final bool completed;
  final DateTime createdAt;

  const Reminder({
    required this.id,
    required this.label,
    required this.scheduledAt,
    this.completed = false,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'id'         : id,
    'label'      : label,
    'scheduledAt': scheduledAt.toIso8601String(),
    'completed'  : completed ? 1 : 0,
    'createdAt'  : createdAt.toIso8601String(),
  };

  factory Reminder.fromMap(Map<String, dynamic> m) => Reminder(
    id          : m['id'] as String,
    label       : m['label'] as String,
    scheduledAt : DateTime.parse(m['scheduledAt'] as String),
    completed   : (m['completed'] as int) == 1,
    createdAt   : DateTime.parse(m['createdAt'] as String),
  );

  Reminder copyWith({bool? completed}) => Reminder(
    id: id, label: label, scheduledAt: scheduledAt,
    completed: completed ?? this.completed, createdAt: createdAt,
  );
}

// ─── Módulo de Recordatorios ──────────────────────────────────────────────────

class RemindersModule {
  static final RemindersModule instance = RemindersModule._();
  RemindersModule._();

  Database? _db;
  final List<Reminder> _webReminders = [];
  final _notifications = FlutterLocalNotificationsPlugin();
  final _uuid = const Uuid();
  bool _initialized = false;

  List<String> get supportedIntents =>
    ['set_reminder', 'list_reminders', 'delete_reminder'];

  bool canHandle(String intent) => supportedIntents.contains(intent);

  Future<void> init() async {
    if (_initialized) return;
    tz.initializeTimeZones();
    if (!kIsWeb) {
      await _initDb();
    }
    await _initNotifications();
    _initialized = true;
    debugPrint('[Reminders] Módulo inicializado');
  }

  Future<void> _initDb() async {
    if (kIsWeb) return;

    final dbPath = await getDatabasesPath();
    _db = await openDatabase(
      p.join(dbPath, 'jarvis_reminders.db'),
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE reminders (
            id TEXT PRIMARY KEY,
            label TEXT NOT NULL,
            scheduledAt TEXT NOT NULL,
            completed INTEGER NOT NULL DEFAULT 0,
            createdAt TEXT NOT NULL
          )
        ''');
      },
    );
  }

  Future<void> _initNotifications() async {
    if (kIsWeb) {
      debugPrint('[Reminders] Notificaciones deshabilitadas en web');
      return;
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _notifications.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );
  }

  // ─── Ejecutar intent ───────────────────────────────────────────────────────

  Future<String> execute(JarvisIntent intent) async {
    await init();
    switch (intent.name) {
      case 'set_reminder':   return _setReminder(intent);
      case 'list_reminders': return _listReminders();
      case 'delete_reminder':return _deleteReminder(intent);
      default:               return 'No entendí el comando de recordatorio.';
    }
  }

  Future<String> _setReminder(JarvisIntent intent) async {
    final label    = intent.params['label'] as String? ?? intent.rawText;
    final datetime = intent.params['datetime'] as DateTime?;

    if (datetime == null) {
      return 'No entendí la hora del recordatorio. Puedes decir, por ejemplo: "Recuérdame tomar agua a las 3 de la tarde".';
    }

    final reminder = Reminder(
      id: _uuid.v4(),
      label: label,
      scheduledAt: datetime,
      createdAt: DateTime.now(),
    );

    await _saveReminder(reminder);
    await _scheduleNotification(reminder);

    final fmt = DateFormat("d 'de' MMMM 'a las' HH:mm", 'es');
    return 'Recordatorio creado: "$label" para el ${fmt.format(datetime)}.';
  }

  Future<String> _listReminders() async {
    final reminders = await _getPendingReminders();

    if (reminders.isEmpty) {
      return 'No tienes recordatorios pendientes.';
    }

    final fmt = DateFormat("d 'de' MMMM 'a las' HH:mm", 'es');
    final items = reminders.take(5).map((r) =>
      '${r.label} — ${fmt.format(r.scheduledAt)}'
    ).join('. ');

    return 'Tienes ${reminders.length} recordatorio${reminders.length > 1 ? "s" : ""}: $items.';
  }

  Future<String> _deleteReminder(JarvisIntent intent) async {
    final reminders = await _getPendingReminders();
    if (reminders.isEmpty) {
      return 'No tienes recordatorios para eliminar.';
    }
    // Elimina el más reciente por defecto
    final last = reminders.first;

    if (kIsWeb) {
      _webReminders.removeWhere((r) => r.id == last.id);
      return 'Recordatorio "${last.label}" eliminado.';
    }

    await _db!.delete('reminders', where: 'id = ?', whereArgs: [last.id]);
    await _notifications.cancel(last.id.hashCode);
    return 'Recordatorio "${last.label}" eliminado.';
  }

  // ─── DB helpers ───────────────────────────────────────────────────────────

  Future<void> _saveReminder(Reminder r) async {
    if (kIsWeb) {
      _webReminders.add(r);
      return;
    }

    await _db!.insert('reminders', r.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Reminder>> _getPendingReminders() async {
    if (kIsWeb) {
      final filtered = _webReminders
          .where((r) => !r.completed && r.scheduledAt.isAfter(DateTime.now()))
          .toList();
      filtered.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
      return filtered;
    }

    final rows = await _db!.query(
      'reminders',
      where: 'completed = 0 AND scheduledAt > ?',
      whereArgs: [DateTime.now().toIso8601String()],
      orderBy: 'scheduledAt ASC',
    );
    return rows.map(Reminder.fromMap).toList();
  }

  Future<List<Reminder>> getAllReminders() async {
    await init();
    if (kIsWeb) {
      return List.unmodifiable(_webReminders);
    }

    final rows = await _db!.query('reminders', orderBy: 'scheduledAt DESC');
    return rows.map(Reminder.fromMap).toList();
  }

  // ─── Notificación programada ──────────────────────────────────────────────

  Future<void> _scheduleNotification(Reminder r) async {
    if (kIsWeb) {
      debugPrint('[Reminders] No se programan notificaciones en web');
      return;
    }

    final tzTime = tz.TZDateTime.from(r.scheduledAt, tz.local);

    const androidDetails = AndroidNotificationDetails(
      'jarvis_reminders',
      'Recordatorios JARVIS',
      channelDescription: 'Recordatorios de tu asistente personal',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    await _notifications.zonedSchedule(
      r.id.hashCode,
      'JARVIS — Recordatorio',
      r.label,
      tzTime,
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
    );
  }
}
