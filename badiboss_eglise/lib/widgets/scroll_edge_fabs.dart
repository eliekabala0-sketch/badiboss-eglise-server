import 'package:flutter/material.dart';

/// Boutons monter / descendre pour longues listes (scroll vertical).
Widget scrollEdgeFabs(ScrollController controller) {
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      FloatingActionButton.small(
        heroTag: 'scroll_up',
        tooltip: 'Haut de page',
        onPressed: () {
          if (!controller.hasClients) return;
          controller.animateTo(
            0,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
          );
        },
        child: const Icon(Icons.keyboard_arrow_up_rounded),
      ),
      const SizedBox(height: 8),
      FloatingActionButton.small(
        heroTag: 'scroll_down',
        tooltip: 'Bas de page',
        onPressed: () {
          if (!controller.hasClients) return;
          controller.animateTo(
            controller.position.maxScrollExtent,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
          );
        },
        child: const Icon(Icons.keyboard_arrow_down_rounded),
      ),
    ],
  );
}
