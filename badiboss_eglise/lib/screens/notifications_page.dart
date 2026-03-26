import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/notification_store.dart';

final class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});
  static const routeName = '/notifications';

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

final class _NotificationsPageState extends State<NotificationsPage> {
  List<AppNotification> _items = <AppNotification>[];
  String _phone = '';
  String _role = '';
  String _church = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    _phone = (p.getString('auth_phone') ?? '').trim();
    _role = (p.getString('auth_role') ?? '').trim();
    _church = (p.getString('auth_church_code') ?? '').trim();
    final all = await NotificationStore.loadAll();
    _items = all.where((n) {
      return NotificationStore.isTargetFor(
        n: n,
        churchCode: _church,
        role: _role,
        phone: _phone,
        groupIds: const <String>[],
      );
    }).toList();
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: _items.length,
          itemBuilder: (_, i) {
            final n = _items[i];
            final unread = !n.readByPhones.contains(_phone);
            return Card(
              child: ListTile(
                leading: Icon(unread ? Icons.notifications_active_rounded : Icons.notifications_none_rounded),
                title: Text(n.title),
                subtitle: Text('${n.body}\n${n.sender} • ${n.createdAtIso.substring(0, 19)}'),
                isThreeLine: true,
                onTap: () async {
                  await NotificationStore.markAsReadFor(notificationId: n.id, phone: _phone);
                  await _load();
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
