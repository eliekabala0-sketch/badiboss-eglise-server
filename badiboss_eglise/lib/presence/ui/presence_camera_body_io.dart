import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Scanner QR (mobile/desktop natif) — non utilisé sur web.
final class PresenceCameraBody extends StatefulWidget {
  final ValueChanged<String> onDetected;

  const PresenceCameraBody({super.key, required this.onDetected});

  @override
  State<PresenceCameraBody> createState() => _PresenceCameraBodyState();
}

final class _PresenceCameraBodyState extends State<PresenceCameraBody> {
  bool _done = false;

  @override
  Widget build(BuildContext context) {
    return MobileScanner(
      onDetect: (capture) {
        if (_done) return;
        final code = capture.barcodes.isNotEmpty ? capture.barcodes.first.rawValue : null;
        if (code == null || code.trim().isEmpty) return;
        setState(() => _done = true);
        widget.onDetected(code.trim());
      },
    );
  }
}
