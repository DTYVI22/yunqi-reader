import 'package:flutter/material.dart';

import 'enhancement.dart';

/// Placeholder controls for the playback-enhancement module. The public
/// snapshot omits the real sliders; the row stays visible so the settings
/// panel keeps its layout and the controller contract stays satisfied.
class ListeningEnhancementSettings extends StatelessWidget {
  const ListeningEnhancementSettings({
    super.key,
    required this.enhancement,
    required this.onChanged,
  });

  final ListeningEnhancement enhancement;
  final ValueChanged<ListeningEnhancementPreference> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '播放增强（此源码构建未包含）',
              style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant),
            ),
          ),
          Switch(
            value: enhancement.preference.enabled,
            onChanged: null,
          ),
        ],
      ),
    );
  }
}
