class GameLogger {
  static Future<void> init() async {}
  static void d(String tag, String message) {}
  static void e(
    String tag,
    String message, [
    Object? error,
    StackTrace? stackTrace,
  ]) {}
  static void i(String tag, String message) {}
  static void w(String tag, String message) {}
  static Future<String?> getLogPath() async => null;
}
