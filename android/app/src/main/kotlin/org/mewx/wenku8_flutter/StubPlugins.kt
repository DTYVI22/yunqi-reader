package org.mewx.wenku8_flutter

import io.flutter.embedding.engine.plugins.FlutterPlugin

/**
 * The public snapshot omits these four platform plugins. They are registered by
 * [attachWenkuEnginePlugins], so the classes must exist; each one registers no
 * channel, which surfaces as MissingPluginException only if Dart calls it — and
 * the Dart side of those features is stubbed out as well.
 */
internal class ListeningEnhancementPlugin : FlutterPlugin {
    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {}
    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {}
}

internal class LanReadingConfigPlugin : FlutterPlugin {
    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {}
    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {}
}

internal class LanDiscoveryPlugin : FlutterPlugin {
    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {}
    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {}
}

internal class CustomSpeechConfigPlugin : FlutterPlugin {
    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {}
    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {}
}
