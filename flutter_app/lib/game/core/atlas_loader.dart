import 'dart:convert';
import 'package:flame/flame.dart';
import 'package:flutter/services.dart';

class SpriteInfo {
  final int srcX;
  final int srcY;
  final int srcW;
  final int srcH;
  final bool rotated;
  final int sourceW;
  final int sourceH;

  const SpriteInfo({
    required this.srcX,
    required this.srcY,
    required this.srcW,
    required this.srcH,
    required this.rotated,
    required this.sourceW,
    required this.sourceH,
  });
}

class AtlasLoader {
  static const String _atlasImagePath = 'atlas.webp';
  static const String _atlasJsonPath = 'images/atlas.json';

  static const Map<String, String> charToPinyin = {
    '上': 'shang',
    '大': 'da',
    '人': 'ren',
    '丘': 'qiu',
    '乙': 'yi',
    '己': 'ji',
    '化': 'hua',
    '三': 'san',
    '千': 'qian',
    '七': 'qi',
    '十': 'shi',
    '土': 'tu',
    '尔': 'er',
    '小': 'xiao',
    '生': 'sheng',
    '八': 'ba',
    '九': 'jiu',
    '子': 'zi',
    '佳': 'jia',
    '作': 'zuo',
    '亡': 'wang',
    '福': 'fu',
    '禄': 'lu',
    '寿': 'shou',
  };

  final Map<String, SpriteInfo> _sprites = {};
  bool _loaded = false;

  bool get isLoaded => _loaded;

  Future<void> load() async {
    final jsonStr = await rootBundle.loadString('assets/$_atlasJsonPath');
    final jsonData = jsonDecode(jsonStr) as Map<String, dynamic>;
    final frames = jsonData['frames'] as Map<String, dynamic>;

    for (final entry in frames.entries) {
      final key = entry.key;
      final value = entry.value as Map<String, dynamic>;
      final frame = value['frame'] as Map<String, dynamic>;
      final sourceSize = value['sourceSize'] as Map<String, dynamic>;
      final rotated = value['rotated'] as bool? ?? false;

      _sprites[key] = SpriteInfo(
        srcX: frame['x'] as int,
        srcY: frame['y'] as int,
        srcW: frame['w'] as int,
        srcH: frame['h'] as int,
        rotated: rotated,
        sourceW: sourceSize['w'] as int,
        sourceH: sourceSize['h'] as int,
      );
    }

    await Flame.images.load(_atlasImagePath);
    _loaded = true;
  }

  SpriteInfo? getSprite(String key) {
    return _sprites[key];
  }

  SpriteInfo? getSpriteByChar(String char) {
    final pinyin = charToPinyin[char];
    if (pinyin == null) return null;
    return _sprites[pinyin];
  }
}
