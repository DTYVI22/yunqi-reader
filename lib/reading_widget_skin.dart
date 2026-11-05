import 'package:flutter/material.dart';

/// Visual skin of the desktop reading widget. The public snapshot omits the
/// renderer, so the picker lists the alternatives but every skin paints the
/// same flat card.
enum ReadingWidgetSkin {
  original('原版'),
  seasons('四季'),
  ink('水墨');

  const ReadingWidgetSkin(this.label);

  final String label;

  static ReadingWidgetSkin fromId(String? id) {
    for (final value in values) {
      if (value.name == id) return value;
    }
    return original;
  }

  String get description => switch (this) {
    ReadingWidgetSkin.original => '跟随应用配色',
    ReadingWidgetSkin.seasons => '按季节变化的插画背景',
    ReadingWidgetSkin.ink => '低饱和的水墨质感',
  };
}

/// Clamps a stored daily goal to the values the picker offers.
int readingDailyGoal(int? minutes) {
  if (minutes == null || minutes <= 0) return 0;
  if (minutes < 15) return 15;
  if (minutes < 30) return 15;
  if (minutes < 60) return 30;
  return 60;
}
