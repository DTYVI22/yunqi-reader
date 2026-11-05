import 'package:flutter/material.dart';

import 'reading_widget_design.dart';
import 'reading_widget_skin.dart';
import 'reading_widget_snapshot.dart';

/// Desktop widget sizes offered by the host. Order is stable because it is used
/// as a map key when publishing images.
enum ReadingDesktopSize { small, medium, large }

/// The public snapshot omits the desktop card renderer, so no image is produced
/// and the host keeps whatever it rendered before.
Future<void> warmReadingDesktopImages(Object value) async {}

Future<List<int>> renderReadingDesktopCard(
  Object value,
  ReadingDesktopSize size, {
  required Brightness brightness,
  bool paintQuote = true,
}) async => const <int>[];

/// Flat fallback of the desktop card. Paints the same figure the renderer would
/// draw so the settings preview still shows a plausible layout.
class ReadingDesktopCard extends StatelessWidget {
  const ReadingDesktopCard({
    super.key,
    required this.data,
    required this.size,
    required this.brightness,
    this.quoteText,
    this.quoteSource = '',
    this.quoteCount = 0,
  });

  final ReadingWidgetSnapshot data;
  final ReadingDesktopSize size;
  final Brightness brightness;
  final String? quoteText;
  final String quoteSource;
  final int quoteCount;

  @override
  Widget build(BuildContext context) {
    final dark = brightness == Brightness.dark;
    final background = dark ? const Color(0xFF16181C) : const Color(0xFFF4F1EA);
    final foreground = dark ? const Color(0xFFEDEDED) : const Color(0xFF1E1E1E);
    final label = switch (size) {
      ReadingDesktopSize.small => '小 2×2',
      ReadingDesktopSize.medium => '中 4×2',
      ReadingDesktopSize.large => '大 4×4',
    };
    return AspectRatio(
      aspectRatio: switch (size) {
        ReadingDesktopSize.small => 1,
        ReadingDesktopSize.medium => 2,
        ReadingDesktopSize.large => 1,
      },
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                data.design.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: foreground.withValues(alpha: .7),
                ),
              ),
              if (quoteText case final quote? when quote.isNotEmpty)
                Text(
                  quote,
                  maxLines: size == ReadingDesktopSize.large ? 6 : 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: foreground,
                  ),
                ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: foreground.withValues(alpha: .45),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Human-readable progress towards the daily goal.
String readingGoalCaption(int goalMinutes, int? verifiedTodaySeconds) {
  if (goalMinutes <= 0) return '按自己的节奏阅读';
  final minutes = (verifiedTodaySeconds ?? 0) ~/ 60;
  return '今日已读 $minutes / $goalMinutes 分钟';
}
