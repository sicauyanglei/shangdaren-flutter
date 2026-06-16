import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/game_recording.dart';

/// 录制管理器 - 负责录制的存储、加载、删除
class RecordingManager {
  static final RecordingManager _instance = RecordingManager._();
  factory RecordingManager() => _instance;
  RecordingManager._();

  static const _dirName = 'game_recordings';

  /// 获取录制存储目录
  Future<Directory> _getRecordingsDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/$_dirName');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// 保存录制
  Future<void> saveRecording(GameRecording recording) async {
    final dir = await _getRecordingsDir();
    final file = File('${dir.path}/${recording.id}.json');
    await file.writeAsString(recording.toJsonString());
  }

  /// 加载单个录制
  Future<GameRecording?> loadRecording(String id) async {
    try {
      final dir = await _getRecordingsDir();
      final file = File('${dir.path}/$id.json');
      if (!await file.exists()) return null;
      final str = await file.readAsString();
      return GameRecording.fromJsonString(str);
    } catch (_) {
      return null;
    }
  }

  /// 获取所有录制列表（按时间倒序）
  Future<List<GameRecording>> loadAllRecordings() async {
    try {
      final dir = await _getRecordingsDir();
      if (!await dir.exists()) return [];
      final files = dir.listSync().whereType<File>().toList();
      final recordings = <GameRecording>[];
      for (final file in files) {
        if (!file.path.endsWith('.json')) continue;
        try {
          final str = await file.readAsString();
          recordings.add(GameRecording.fromJsonString(str));
        } catch (_) {}
      }
      recordings.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return recordings;
    } catch (_) {
      return [];
    }
  }

  /// 删除录制
  Future<void> deleteRecording(String id) async {
    final dir = await _getRecordingsDir();
    final file = File('${dir.path}/$id.json');
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// 删除所有录制
  Future<void> deleteAllRecordings() async {
    final dir = await _getRecordingsDir();
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  /// 获取录制数量
  Future<int> getRecordingCount() async {
    final recordings = await loadAllRecordings();
    return recordings.length;
  }
}
