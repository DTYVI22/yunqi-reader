/// Local replacement for the playback-enhancement module the public snapshot
/// omits. Keeps the configuration contract; no audio effect is applied.
class ListeningEnhancementPreference {
  const ListeningEnhancementPreference({this.enabled = false, this.strength = 0});

  final bool enabled;
  final int strength;

  ListeningEnhancementPreference copyWith({bool? enabled, int? strength}) =>
      ListeningEnhancementPreference(
        enabled: enabled ?? this.enabled,
        strength: strength ?? this.strength,
      );

  Map<String, Object?> toJson() => {'enabled': enabled, 'strength': strength};

  factory ListeningEnhancementPreference.fromJson(Map<dynamic, dynamic> json) =>
      ListeningEnhancementPreference(
        enabled: json['enabled'] == true,
        strength: json['strength'] is int ? json['strength'] as int : 0,
      );
}

class ListeningEnhancement {
  ListeningEnhancement();

  ListeningEnhancementPreference _preference =
      const ListeningEnhancementPreference();

  ListeningEnhancementPreference get preference => _preference;

  Future<void> setPreference(ListeningEnhancementPreference value) async {
    _preference = value;
  }

  Future<void> configure(
    ListeningEnhancementPreference value, {
    int? audioSessionId,
  }) async {
    _preference = value;
  }

  Future<void> dispose() async {}
}
