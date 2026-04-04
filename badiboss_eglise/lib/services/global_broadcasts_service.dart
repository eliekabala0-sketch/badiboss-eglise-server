import 'package:flutter/material.dart';

import 'church_api.dart';

final class GlobalBroadcast {
  final String id;
  final String title;
  final String body;
  final String imageUrl;
  final String kind;
  final String audience;
  final bool showOnOpen;
  final bool dismissible;

  GlobalBroadcast({
    required this.id,
    required this.title,
    required this.body,
    required this.imageUrl,
    required this.kind,
    required this.audience,
    required this.showOnOpen,
    required this.dismissible,
  });

  static GlobalBroadcast? fromJson(Map<String, dynamic> m) {
    final id = (m['id'] ?? '').toString().trim();
    if (id.isEmpty) return null;
    return GlobalBroadcast(
      id: id,
      title: (m['title'] ?? '').toString(),
      body: (m['body'] ?? '').toString(),
      imageUrl: (m['image_url'] ?? '').toString().trim(),
      kind: (m['kind'] ?? 'notification').toString().toLowerCase(),
      audience: (m['audience'] ?? 'all').toString(),
      showOnOpen: (m['show_on_open'] ?? 1) == 1 || m['show_on_open'] == true,
      dismissible: (m['dismissible'] ?? 1) == 1 || m['dismissible'] == true,
    );
  }
}

final class GlobalBroadcastsService {
  const GlobalBroadcastsService._();

  /// Évite les doubles affichages (ex. TabHome + dashboard) pour la même diffusion dans la session.
  static final Set<String> _shownOnOpenIds = <String>{};

  static Future<List<GlobalBroadcast>> fetch() async {
    try {
      final dec = await ChurchApi.getJson('/me/broadcasts');
      final raw = dec['items'];
      if (raw is! List) return <GlobalBroadcast>[];
      final out = <GlobalBroadcast>[];
      for (final e in raw) {
        if (e is! Map) continue;
        final b = GlobalBroadcast.fromJson(Map<String, dynamic>.from(e));
        if (b != null) out.add(b);
      }
      return out;
    } catch (_) {
      return <GlobalBroadcast>[];
    }
  }

  static Future<void> dismiss(String broadcastId) async {
    try {
      await ChurchApi.postJson('/me/broadcasts/dismiss', {'broadcast_id': broadcastId});
      _shownOnOpenIds.remove(broadcastId);
    } catch (_) {}
  }

  static void scheduleAfterFirstFrame(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!context.mounted) return;
      final br = await fetch();
      final open = br.where((x) => x.showOnOpen).toList();
      if (!context.mounted || open.isEmpty) return;
      await presentOnOpen(context, open);
    });
  }

  /// Affiche les diffusions `show_on_open` — notifications/messages en dialogue, communiqués en bannière.
  static Future<void> presentOnOpen(BuildContext context, List<GlobalBroadcast> items) async {
    if (!context.mounted || items.isEmpty) return;
    for (final b in items) {
      if (!b.showOnOpen || !context.mounted) continue;
      if (_shownOnOpenIds.contains(b.id)) continue;
      if (b.kind == 'communique') {
        await showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (ctx) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(b.title, style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  if (b.imageUrl.isNotEmpty) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        b.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Text(b.body, style: Theme.of(ctx).textTheme.bodyMedium),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      if (b.dismissible)
                        TextButton(
                          onPressed: () async {
                            await dismiss(b.id);
                            if (ctx.mounted) Navigator.pop(ctx);
                          },
                          child: const Text('Fermer'),
                        ),
                      const Spacer(),
                      FilledButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
        _shownOnOpenIds.add(b.id);
        continue;
      }
      await showDialog<void>(
        context: context,
        barrierDismissible: b.dismissible,
        builder: (ctx) => AlertDialog(
          title: Text(b.title.isEmpty ? 'Information' : b.title),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (b.imageUrl.isNotEmpty) ...[
                  Image.network(
                    b.imageUrl,
                    errorBuilder:  (_, __, ___) => const Icon(Icons.broken_image_outlined),
                  ),
                  const SizedBox(height: 12),
                ],
                Text(b.body),
              ],
            ),
          ),
          actions: [
            if (b.dismissible)
              TextButton(
                onPressed: () async {
                  await dismiss(b.id);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('Ne plus afficher'),
              ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Fermer'),
            ),
          ],
        ),
      );
      _shownOnOpenIds.add(b.id);
    }
  }
}
