import 'package:flutter/material.dart';

import 'controller.dart';
import 'custom_tts.dart';

/// Placeholder page for the custom SSML endpoint. The public snapshot omits the
/// configuration UI; this keeps the settings entry and its navigation contract
/// compiling while reporting the feature as absent.
class CustomSpeechPage extends StatelessWidget {
  const CustomSpeechPage({
    super.key,
    required this.settings,
    required this.controller,
  });

  final CustomSpeechSettings settings;
  final ListeningController controller;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('自定义语音接口')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.record_voice_over_outlined,
                size: 44,
                color: colors.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text(
                '此源码构建未包含自定义语音接口',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: colors.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                '可继续使用 Edge 神经网络音色或已安装的系统朗读引擎。',
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
