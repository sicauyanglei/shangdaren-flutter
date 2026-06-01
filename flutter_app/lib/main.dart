import 'dart:async';
import 'package:flutter/material.dart' hide Card;
import 'package:flutter/services.dart';
import 'package:flame/game.dart';
import 'game/shangdaren_game.dart';
import 'game/ui/start_screen.dart';
import 'game/ui/settlement_screen.dart';
import 'game/ui/settings_screen.dart';
import 'game/ui/game_overlay.dart';
import 'game/core/game_logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GameLogger.init();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      statusBarColor: Colors.transparent,
    ),
  );
  runApp(const ShangdarenApp());
}

class ShangdarenApp extends StatelessWidget {
  const ShangdarenApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '上大人字牌',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.brown),
        scaffoldBackgroundColor: Colors.black,
      ),
      home: const GameHomePage(),
    );
  }
}

class GameHomePage extends StatefulWidget {
  const GameHomePage({super.key});

  @override
  State<GameHomePage> createState() => _GameHomePageState();
}

class _GameHomePageState extends State<GameHomePage>
    with WidgetsBindingObserver {
  late final ShangdarenGame _game;
  Offset _lastDragPos = Offset.zero;
  Offset? _dragStartPos;
  bool _showStartScreen = true;
  bool _showSettlement = false;
  bool _showSettings = false;
  final Map<int, int> _displayScores = {};
  final Map<int, int> _targetScores = {};
  final Map<int, Timer> _scoreAnimTimers = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _game = ShangdarenGame();
    _game.onGameStateChanged = () {
      if (mounted) setState(() {});
    };
    _game.onShowSettlement = () {
      if (mounted) setState(() => _showSettlement = true);
    };
    _game.onShowHu = () {
      if (!mounted) return;
      final state = _game.gameController?.state;
      if (state != null && state.huResultOldScores != null) {
        for (final entry
            in state.huResultScoreChanges?.entries ?? <MapEntry<int, int>>[]) {
          if (entry.value != 0) {
            final oldScore =
                state.huResultOldScores![entry.key] ??
                state.players[entry.key].score;
            _displayScores[entry.key] = oldScore;
            _targetScores[entry.key] = state.players[entry.key].score;
          }
        }
      }
      setState(() {});
    };
    _game.onShowLiuju = () {
      if (mounted) {
        setState(() {});
      }
    };
    _game.onHuCloseFromPanel = () {
      if (mounted) {
        _triggerNextOrSettlement();
      }
    };
    _game.onScoreArrive = (playerId) {
      if (!mounted) return;
      _startScoreAnim(playerId);
    };
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState appState) {
    if (appState == AppLifecycleState.paused) {
      _game.pauseGame();
    } else if (appState == AppLifecycleState.resumed) {
      _game.resumeGame();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (final t in _scoreAnimTimers.values) {
      t.cancel();
    }
    _scoreAnimTimers.clear();
    _game.onRemove();
    super.dispose();
  }

  void _startScoreAnim(int playerId) {
    _scoreAnimTimers[playerId]?.cancel();
    final totalSteps = 10;
    var step = 0;
    _scoreAnimTimers[playerId] = Timer.periodic(
      const Duration(milliseconds: 50),
      (timer) {
        step++;
        final oldScore = _displayScores[playerId] ?? 0;
        final newScore = _targetScores[playerId] ?? oldScore;
        final diff = newScore - oldScore;
        final progress = step / totalSteps;
        final current = oldScore + (diff * progress).round();
        _displayScores[playerId] = current;
        if (mounted) setState(() {});
        if (step >= totalSteps) {
          timer.cancel();
          _scoreAnimTimers.remove(playerId);
          _displayScores.remove(playerId);
          _targetScores.remove(playerId);
          if (mounted) setState(() {});
        }
      },
    );
  }

  void _onStartGame(
    int baseScore,
    int multiplierBase,
    String difficulty,
    bool piaoEnabled,
  ) {
    if (!_game.gameLoaded) return;
    setState(() => _showStartScreen = false);
    _game.overlays.add('gameOverlay');
    _game.startGame(
      baseScore: baseScore,
      multiplierBase: multiplierBase,
      difficulty: difficulty,
      piaoEnabled: piaoEnabled,
    );
  }

  void _onCloseSettlement() {
    setState(() {
      _showSettlement = false;
      _showStartScreen = true;
    });
  }

  void _onCloseHuOverlay() {
    _game.gameState.showHuResult = false;
    _game.handleHuClose();
  }

  void _triggerNextOrSettlement() {
    final state = _game.gameState;
    state.showHuResult = false;
    state.showLiujuResult = false;
    if (state.roundNumber >= 8) {
      setState(() {
        _showSettlement = true;
      });
    } else {
      _game.handleHuClose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldExit = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('退出游戏'),
            content: const Text('确定要退出游戏吗？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('确定'),
              ),
            ],
          ),
        );
        if (shouldExit == true) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        extendBody: true,
        body: MediaQuery.removePadding(
          context: context,
          removeTop: true,
          removeBottom: true,
          removeLeft: true,
          removeRight: true,
          child: Stack(
            children: [
              Positioned.fill(
                child: AbsorbPointer(
                  absorbing: _showStartScreen || _showSettings,
                  child: GestureDetector(
                    onTapUp: (details) {
                      _game.handleTapAt(details.globalPosition);
                    },
                    onPanStart: (details) {
                      _lastDragPos = details.globalPosition;
                      _dragStartPos = details.globalPosition;
                      _game.handleDragStart(details.globalPosition);
                    },
                    onPanUpdate: (details) {
                      _lastDragPos = details.globalPosition;
                      _game.handleDragUpdate(details.globalPosition);
                    },
                    onPanEnd: (details) {
                      final state = _game.gameState;
                      if (state.showHuResult || state.showLiujuResult) {
                        if (_dragStartPos != null) {
                          final dx = _lastDragPos.dx - _dragStartPos!.dx;
                          final dy = _lastDragPos.dy - _dragStartPos!.dy;
                          final dist = dx * dx + dy * dy;
                          if (dist > 50 * 50) {
                            _triggerNextOrSettlement();
                            return;
                          }
                        }
                      }
                      _game.handleDragEnd(_lastDragPos);
                    },
                    onPanCancel: () {
                      _game.handleDragCancel();
                    },
                    child: GameWidget(
                      game: _game,
                      loadingBuilder: (context) => const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                      overlayBuilderMap: {
                        'gameOverlay': (context, game) {
                          final g = game as ShangdarenGame;
                          final screenSize = MediaQuery.of(context).size;
                          final designW = ShangdarenGame.designWidth;
                          final designH = ShangdarenGame.designHeight;
                          final scaleX = screenSize.width / designW;
                          final scaleY = screenSize.height / designH;

                          GameLogger.i(
                            "UI",
                            "gameOverlay: screen=${screenSize.width}x${screenSize.height}, design=${designW}x$designH, scale=($scaleX,$scaleY)",
                          );

                          return SizedBox.expand(
                            child: FittedBox(
                              fit: BoxFit.fill,
                              child: SizedBox(
                                width: ShangdarenGame.designWidth,
                                height: ShangdarenGame.designHeight,
                                child: GameOverlay(
                                  gameState: g.gameState,
                                  displayScores: _displayScores,
                                  onChi: g.respondChi,
                                  onPeng: g.respondPeng,
                                  onZhao: g.respondZhao,
                                  onSelectZhaoCharacter: g.selectZhaoCharacter,
                                  onHu: g.respondHu,
                                  onPass: g.respondPass,
                                  onSettings: () =>
                                      setState(() => _showSettings = true),
                                  onSetPiao: g.setPiao,
                                  onNextRound: _triggerNextOrSettlement,
                                  onShowSettlementFromButton:
                                      _triggerNextOrSettlement,
                                ),
                              ),
                            ),
                          );
                        },
                      },
                    ),
                  ),
                ),
              ),
              if (_showStartScreen)
                StartScreen(
                  onStartGame: _onStartGame,
                  onExit: () => SystemNavigator.pop(),
                ),
              if (_showSettlement)
                SettlementScreen(
                  players: _game.gameState.players,
                  roundResults: _game.gameState.roundHistory,
                  onClose: _onCloseSettlement,
                ),

              if (_showSettings)
                SettingsScreen(
                  onVolumeChanged: (_) {},
                  onDifficultyChanged: (_) {},
                  onExitGame: () => SystemNavigator.pop(),
                  onClose: () => setState(() => _showSettings = false),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
