import 'package:flutter/material.dart';

import '../services/global_broadcasts_service.dart';

/// Affiche les diffusions globales à l’ouverture pour les écrans qui ne passent pas par [AppShell] / TabHome.
final class GlobalBroadcastsBootstrap extends StatefulWidget {
  final Widget child;

  const GlobalBroadcastsBootstrap({super.key, required this.child});

  @override
  State<GlobalBroadcastsBootstrap> createState() => _GlobalBroadcastsBootstrapState();
}

final class _GlobalBroadcastsBootstrapState extends State<GlobalBroadcastsBootstrap> {
  @override
  void initState() {
    super.initState();
    GlobalBroadcastsService.scheduleAfterFirstFrame(context);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
