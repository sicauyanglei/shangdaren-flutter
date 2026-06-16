import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/player.dart';

class AudioManager {
  static final AudioManager _instance = AudioManager._internal();
  factory AudioManager() => _instance;
  AudioManager._internal();

  final AudioPlayer _player = AudioPlayer();
  final AudioPlayer _player2 = AudioPlayer();
  String _voiceType = 'male';
  double _volume = 1.0;
  double get volume => _volume;
  bool _tickEnabled = true;
  bool get tickEnabled => _tickEnabled;
  String _difficulty = 'hard';
  String get difficulty => _difficulty;
  bool _recordingEnabled = true;
  bool get recordingEnabled => _recordingEnabled;

  bool _autoHostingEnabled = false;
  bool get autoHostingEnabled => _autoHostingEnabled;

  // 托管策略: 'ai' = AI托管策略, 'simple' = 非AI托管(简单出牌)
  String _autoHostingStrategy = 'ai';
  String get autoHostingStrategy => _autoHostingStrategy;
  bool _initialized = false;

  static const _audioFileMap = <String, String>{
    '吃': 'chi',
    '碰': 'peng',
    '招': 'zhao',
    '胡': 'hu',
    '自摸': 'zimo',
    '出牌': 'chupai',
    '过': 'guo',
    '快点吧': 'kuaidianba',
    '流局': 'liuju',
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
    '枯胡': 'kuhu',
    '清枯胡': 'qingkuhu',
    '枯台胡': 'kutaihu',
    '枯重台卡': 'kuchongtaika',
    '枯重台胡': 'kuchongtaihu',
    '清枯台卡': 'qingkutaika',
    '清枯台胡': 'qingkutaihu',
    '清枯重台卡': 'qingkuchongtaika',
    '清枯重台胡': 'qingkuchongtaihu',
    '十对': 'shidui',
    '黑元': 'heiyuan',
    '红元': 'hongyuan',
    '红元3精': 'hongyuan3jing',
    '红元4精': 'hongyuan4jing',
    '红元5精': 'hongyuan5jing',
    '红元6精': 'hongyuan6jing',
    '清胡': 'qinghu',
    '清卡胡': 'qingkahu',
    '卡胡': 'kahu',
    '普通胡': 'putonghu',
    '台卡': 'taika',
    '台胡': 'taihu',
    '重台卡': 'chongtaika',
    '重台胡': 'chongtaihu',
  };

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    final context = AudioContext(
      android: AudioContextAndroid(
        audioMode: AndroidAudioMode.normal,
        contentType: AndroidContentType.sonification,
        usageType: AndroidUsageType.game,
        audioFocus: AndroidAudioFocus.none,
      ),
      iOS: AudioContextIOS(
        category: AVAudioSessionCategory.playback,
        options: {AVAudioSessionOptions.mixWithOthers},
      ),
    );

    await AudioPlayer.global.setAudioContext(context);
  }

  void setVoiceType(String type) {
    _voiceType = type;
  }

  static String voiceTypeFromGender(Gender gender) {
    return gender == Gender.female ? 'female' : 'male';
  }

  void setVolume(double volume) {
    _volume = volume.clamp(0.0, 1.0);
    _saveSettings();
  }

  void setTickEnabled(bool enabled) {
    _tickEnabled = enabled;
    _saveSettings();
  }

  void setDifficulty(String difficulty) {
    _difficulty = difficulty;
    _saveSettings();
  }

  void setRecordingEnabled(bool enabled) {
    _recordingEnabled = enabled;
    _saveSettings();
  }

  void setAutoHostingEnabled(bool enabled) {
    _autoHostingEnabled = enabled;
    _saveSettings();
  }

  void setAutoHostingStrategy(String strategy) {
    _autoHostingStrategy = strategy;
    _saveSettings();
  }

  Future<void> loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _volume = prefs.getDouble('audio_volume') ?? 1.0;
      _tickEnabled = prefs.getBool('tick_enabled') ?? true;
      _difficulty = prefs.getString('difficulty') ?? 'hard';
      _recordingEnabled = prefs.getBool('recording_enabled') ?? true;
      _autoHostingEnabled = prefs.getBool('auto_hosting_enabled') ?? false;
      _autoHostingStrategy = prefs.getString('auto_hosting_strategy') ?? 'ai';
    } catch (_) {}
  }

  void _saveSettings() {
    SharedPreferences.getInstance().then((prefs) {
      prefs.setDouble('audio_volume', _volume);
      prefs.setBool('tick_enabled', _tickEnabled);
      prefs.setString('difficulty', _difficulty);
      prefs.setBool('recording_enabled', _recordingEnabled);
      prefs.setBool('auto_hosting_enabled', _autoHostingEnabled);
      prefs.setString('auto_hosting_strategy', _autoHostingStrategy);
    });
  }

  Future<void> play(
    String text, {
    String? voiceType,
    double volumeMultiplier = 1.0,
  }) async {
    final fileName = _audioFileMap[text];
    if (fileName == null) return;

    final vt = voiceType ?? _voiceType;
    final path = 'audio/$vt/$fileName.mp3';
    final vol = (_volume * volumeMultiplier).clamp(0.0, 1.0);

    try {
      await _player.stop();
      await _player.setVolume(vol);
      await _player.play(AssetSource(path));
    } catch (_) {}
  }

  Future<void> playDelayed(
    String text, {
    String? voiceType,
    double volumeMultiplier = 1.0,
    int delayMs = 1000,
  }) async {
    final fileName = _audioFileMap[text];
    if (fileName == null) return;

    await Future.delayed(Duration(milliseconds: delayMs));

    final vt = voiceType ?? _voiceType;
    final path = 'audio/$vt/$fileName.mp3';
    final vol = (_volume * volumeMultiplier).clamp(0.0, 1.0);

    try {
      await _player2.stop();
      await _player2.setVolume(vol);
      await _player2.play(AssetSource(path));
    } catch (_) {}
  }

  Future<void> playDiscard(String character, {String? voiceType}) async {
    await play(character, voiceType: voiceType);
  }

  Future<void> playChi({String? voiceType}) async {
    await play('吃', voiceType: voiceType);
  }

  Future<void> playPeng({String? voiceType}) async {
    await play('碰', voiceType: voiceType);
  }

  Future<void> playZhao({String? voiceType}) async {
    await play('招', voiceType: voiceType);
  }

  Future<void> playHu({String? voiceType}) async {
    await play('胡', voiceType: voiceType, volumeMultiplier: 1.5);
  }

  Future<void> playZimo({String? voiceType}) async {
    await play('自摸', voiceType: voiceType, volumeMultiplier: 1.5);
  }

  Future<void> playGuo({String? voiceType}) async {
    await play('过', voiceType: voiceType);
  }

  Future<void> playLiuju({String? voiceType}) async {
    await play('流局', voiceType: voiceType);
  }

  Future<void> playHurry({String? voiceType}) async {
    await play('快点吧', voiceType: voiceType);
  }

  Future<void> playTickSlow() async {
    if (!_tickEnabled) return;
    final vol = _volume.clamp(0.0, 1.0);
    try {
      await _player2.stop();
      await _player2.setVolume(vol * 0.5);
      await _player2.play(AssetSource('audio/tick_slow.wav'));
    } catch (_) {}
  }

  Future<void> playTickMedium() async {
    if (!_tickEnabled) return;
    final vol = _volume.clamp(0.0, 1.0);
    try {
      await _player2.stop();
      await _player2.setVolume(vol * 0.7);
      await _player2.play(AssetSource('audio/tick_medium.wav'));
    } catch (_) {}
  }

  Future<void> playTickFast() async {
    if (!_tickEnabled) return;
    final vol = _volume.clamp(0.0, 1.0);
    try {
      await _player2.stop();
      await _player2.setVolume(vol);
      await _player2.play(AssetSource('audio/tick_fast.wav'));
    } catch (_) {}
  }

  Future<void> playHuType(
    String huTypeName, {
    String? voiceType,
    int delayMs = 1000,
  }) async {
    await playDelayed(
      huTypeName,
      voiceType: voiceType,
      volumeMultiplier: 1.5,
      delayMs: delayMs,
    );
  }

  Future<void> stop() async {
    try {
      await _player.stop();
      await _player2.stop();
    } catch (_) {}
  }

  Future<void> dispose() async {
    try {
      await _player.dispose();
      await _player2.dispose();
    } catch (_) {}
  }
}
