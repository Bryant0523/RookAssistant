import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../modules/reminders/reminders_module.dart';
import '../theme/jarvis_theme.dart';

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});
  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  List<Reminder> _reminders = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await RemindersModule.instance.getAllReminders();
    if (mounted) setState(() { _reminders = list; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: JarvisTheme.background,
      appBar: AppBar(
        title: const Text('RECORDATORIOS'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 16, color: JarvisTheme.textSecondary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator(color: JarvisTheme.primary))
        : _reminders.isEmpty
          ? _buildEmpty()
          : _buildList(),
    );
  }

  Widget _buildEmpty() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.notifications_none, color: JarvisTheme.textHint, size: 48),
          SizedBox(height: 12),
          Text('Sin recordatorios',
            style: TextStyle(color: JarvisTheme.textSecondary, fontSize: 14, letterSpacing: 1)),
          SizedBox(height: 6),
          Text('Di "Recuérdame..." para crear uno',
            style: TextStyle(color: JarvisTheme.textHint, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildList() {
    final fmt = DateFormat("d MMM · HH:mm", 'es');
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _reminders.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final r = _reminders[i];
        final isPast = r.scheduledAt.isBefore(DateTime.now());
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: JarvisTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: r.completed || isPast ? JarvisTheme.border : JarvisTheme.primary.withOpacity(0.3),
              width: 0.5,
            ),
          ),
          child: Row(
            children: [
              Icon(
                r.completed ? Icons.check_circle : Icons.notifications_outlined,
                color: r.completed ? JarvisTheme.success
                     : isPast ? JarvisTheme.textHint
                     : JarvisTheme.primary,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.label,
                      style: TextStyle(
                        color: r.completed ? JarvisTheme.textSecondary : JarvisTheme.textPrimary,
                        fontSize: 14,
                        decoration: r.completed ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(fmt.format(r.scheduledAt),
                      style: TextStyle(
                        color: isPast ? JarvisTheme.error.withOpacity(0.7) : JarvisTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
