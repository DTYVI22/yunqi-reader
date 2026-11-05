import 'package:flutter/material.dart';

import 'lan_reading_sync.dart';

/// Entry point for the nearby-reading device list. The public snapshot omits
/// the transport, so the page explains the state instead of listing devices.
class LanReadingPage extends StatelessWidget {
  const LanReadingPage({
    super.key,
    required this.sync,
    required this.reduceMotion,
  });

  final LanReadingSync sync;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('局域网续读')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_tethering_off, size: 44, color: colors.onSurfaceVariant),
              const SizedBox(height: 16),
              Text(
                '此源码构建未包含局域网续读',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: colors.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                '设备的发现、配对与续读传输不在公开源码范围内。',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.6,
                  color: colors.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
