import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shangdaren_game/game/core/build_config.dart';

class GameLogger {
  static File? _logFile;
  static bool _initialized = false;
  static bool _enabled = BuildConfig.enableGameLog;
  static String? _logFilePath;

  static void setEnabled(bool enabled) {
    _enabled = enabled;
  }

  static bool get isEnabled => _enabled;

  static String? get logFilePath => _logFilePath;

  static Future<void> init() async {
    if (!_enabled) {
      debugPrint('GameLogger: disabled by BuildConfig');
      return;
    }

    try {
      Directory? dir;

      bool hasExternalStorage = false;
      try {
        final status = await Permission.manageExternalStorage.status;
        if (status.isGranted) {
          hasExternalStorage = true;
        } else {
          final result = await Permission.manageExternalStorage.request();
          hasExternalStorage = result.isGranted;
        }
      } catch (e) {
        debugPrint('GameLogger: permission request failed: $e');
      }

      if (hasExternalStorage) {
        dir = Directory('/storage/emulated/0/DCIM/ShangDaRen');
        try {
          if (!await dir.exists()) {
            await dir.create(recursive: true);
          }
          debugPrint('GameLogger: using external storage: ${dir.path}');
        } catch (e) {
          debugPrint('GameLogger: failed to create external dir: $e');
          dir = null;
        }
      }

      if (dir == null) {
        try {
          dir = await getApplicationDocumentsDirectory();
          final logDir = Directory('${dir.path}/ShangDaRen');
          if (!await logDir.exists()) {
            await logDir.create(recursive: true);
          }
          dir = logDir;
          debugPrint('GameLogger: using app documents dir: ${dir.path}');
        } catch (e) {
          debugPrint('GameLogger: getApplicationDocumentsDirectory failed: $e');
        }
      }

      if (dir == null) {
        debugPrint('GameLogger: failed to find/create log directory');
        return;
      }

      final timestamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .split('.')
          .first;
      _logFile = File('${dir.path}/game_log_$timestamp.txt');
      await _logFile!.writeAsString('=== Game Log Started at $timestamp ===\n');
      await _logFile!.writeAsString('Log directory: ${dir.path}\n');
      await _logFile!.writeAsString(
        'External storage permission: $hasExternalStorage\n',
      );
      _initialized = true;
      _logFilePath = _logFile!.path;

      debugPrint('GameLogger initialized: ${_logFile!.path}');
    } catch (e, st) {
      debugPrint('GameLogger init failed: $e');
      debugPrint('StackTrace: $st');
    }
  }

  static Future<void> _writeLog(String tag, String message) async {
    if (!_initialized || _logFile == null) return;

    try {
      final timestamp = DateTime.now().toIso8601String();
      final logLine = '[$timestamp] [$tag] $message\n';
      await _logFile!.writeAsString(logLine, mode: FileMode.append);
    } catch (e) {
      debugPrint('GameLogger write failed: $e');
    }
  }

  static void d(String tag, String message) {
    if (!_enabled) return;
    debugPrint('[$tag] $message');
    _writeLog(tag, message);
  }

  static void e(
    String tag,
    String message, [
    Object? error,
    StackTrace? stackTrace,
  ]) {
    if (!_enabled) return;
    debugPrint('[$tag] ERROR: $message');
    _writeLog(tag, 'ERROR: $message');
    if (error != null) {
      _writeLog(tag, 'Error: $error');
    }
    if (stackTrace != null) {
      _writeLog(tag, 'StackTrace: $stackTrace');
    }
  }

  static void i(String tag, String message) {
    if (!_enabled) return;
    debugPrint('[$tag] INFO: $message');
    _writeLog(tag, 'INFO: $message');
  }

  static void w(String tag, String message) {
    if (!_enabled) return;
    debugPrint('[$tag] WARN: $message');
    _writeLog(tag, 'WARN: $message');
  }

  static Future<String?> getLogPath() async {
    if (!_initialized || _logFile == null) return null;
    return _logFile!.path;
  }
}
