/// Reference-face rendering for the desktop widget. The public snapshot omits
/// the image pipeline, so publishing yields no new images and the host keeps
/// its previous render.
Future<Map<String, List<int>>> renderReadingDesktopCards(Object value) async =>
    const <String, List<int>>{};
