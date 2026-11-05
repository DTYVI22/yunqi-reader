import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

/// Local replacement for the custom SSML endpoint that the public snapshot
/// omits. The configuration shape is kept so the controller, cache and voice
/// picker keep compiling; synthesis reports the feature as unavailable.
class CustomSpeechConfig {
  const CustomSpeechConfig({
    required this.namespace,
    required this.voiceId,
    required this.locale,
    required this.voice,
  });

  final String namespace;
  final String voiceId;
  final String locale;
  final SpeechVoice voice;

  CustomSpeechConfig copyWith({SpeechVoice? voice}) => CustomSpeechConfig(
    namespace: namespace,
    voiceId: voice?.id ?? voiceId,
    locale: voice?.locale ?? locale,
    voice: voice ?? this.voice,
  );

  Map<String, Object?> toJson() => {
    'namespace': namespace,
    'voiceId': voiceId,
    'locale': locale,
    'voice': voice.toJson(),
  };

  factory CustomSpeechConfig.fromJson(Map<String, dynamic> json) {
    final voice = json['voice'];
    return CustomSpeechConfig(
      namespace: json['namespace'] is String ? json['namespace'] as String : '',
      voiceId: json['voiceId'] is String ? json['voiceId'] as String : '',
      locale: json['locale'] is String ? json['locale'] as String : 'zh-CN',
      voice: SpeechVoice.fromJson(
        voice is Map
            ? Map<String, dynamic>.from(voice)
            : const <String, dynamic>{'id': '', 'label': ''},
      ),
    );
  }
}

class CustomSpeechSettings extends ChangeNotifier {
  CustomSpeechSettings();

  static const _key = 'listening.customSpeech.v1';

  CustomSpeechConfig? _config;

  CustomSpeechConfig? get config => _config;

  Future<void> load() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final raw = preferences.getString(_key);
      if (raw == null) return;
      final value = jsonDecode(raw);
      if (value is Map) {
        _config = CustomSpeechConfig.fromJson(Map<String, dynamic>.from(value));
      }
    } catch (_) {
      // A damaged optional endpoint must leave ordinary playback usable.
      _config = null;
    }
    notifyListeners();
  }

  Future<void> save(CustomSpeechConfig? value) async {
    _config = value;
    notifyListeners();
    final preferences = await SharedPreferences.getInstance();
    if (value == null) {
      await preferences.remove(_key);
      return;
    }
    await preferences.setString(_key, jsonEncode(value.toJson()));
  }

  Future<void> clear() => save(null);
}

class CustomSpeechClient {
  CustomSpeechClient();

  Future<Uint8List> synthesize(
    String text,
    CustomSpeechConfig config,
    SpeechCancellation cancellation,
  ) {
    cancellation.check();
    throw const SpeechFailure('此源码构建未包含自定义语音接口实现，请改用 Edge 或系统引擎');
  }
}
