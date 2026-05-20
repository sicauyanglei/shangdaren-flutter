import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '上大人字牌',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.brown),
      ),
      home: const GamePage(),
    );
  }
}

class GamePage extends StatefulWidget {
  const GamePage({super.key});

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> with WidgetsBindingObserver {
  late WebViewController _controller;
  bool _isLoading = true;
  bool _pageLoaded = false;
  static const MethodChannel _testChannel = MethodChannel(
    'com.shangdaren.game/test',
  );
  File? _logFile;
  IOSink? _logSink;
  Timer? _resourceMonitorTimer;
  Timer? _logFlushTimer;
  int _pendingLogCount = 0;
  int _lastRssMb = 0;
  int _consecutiveHighMemory = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            setState(() {
              _isLoading = false;
            });
            _pageLoaded = true;
            _controller.runJavaScript('try{localStorage.clear();}catch(e){}');
            _initLogFile();
            _checkPendingAutoTest();
          },
        ),
      )
      ..addJavaScriptChannel(
        'FlutterBridge',
        onMessageReceived: (message) {
          final msg = message.message;
          if (msg == 'exit') {
            SystemNavigator.pop();
          } else if (msg == 'ROUND_END') {
            _handleRoundEnd();
          } else if (msg.startsWith('SDR_LOG:')) {
            final logContent = msg.substring(8);
            final lines = logContent.split('\n');
            for (final line in lines) {
              if (line.isEmpty) continue;
              debugPrint('SDR $line');
              _writeLog(line);
            }
          } else if (msg.startsWith('AUTOTEST_LOG:')) {
            final logLine = '[AUTOTEST] ${msg.substring(13)}';
            debugPrint(logLine);
            _writeLog(logLine);
          } else if (msg.startsWith('TEST_DONE:')) {
            debugPrint('TEST_DONE ${msg.substring(10)}');
          }
        },
      )
      ..loadFlutterAsset('assets/html/index.html');

    if (_controller.platform is AndroidWebViewController) {
      final androidController =
          _controller.platform as AndroidWebViewController;
      androidController.setMediaPlaybackRequiresUserGesture(false);
      AndroidWebViewController.enableDebugging(kDebugMode);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _controller.runJavaScript(
        'if(typeof onAppBackground==="function"){onAppBackground();}',
      );
    } else if (state == AppLifecycleState.resumed) {
      _controller.runJavaScript(
        'if(typeof onAppForeground==="function"){onAppForeground();}',
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _resourceMonitorTimer?.cancel();
    _logFlushTimer?.cancel();
    _flushLog();
    _logSink?.close();
    super.dispose();
  }

  Future<void> _checkPendingAutoTest() async {
    if (kReleaseMode) return;
    try {
      final rounds = await _testChannel.invokeMethod<int>('getPendingRounds');
      if (rounds != null && rounds > 0) {
        debugPrint('AUTOTEST: Starting auto test with $rounds rounds');
        await Future.delayed(const Duration(seconds: 2));
        _controller.runJavaScript('runAutoTest($rounds)');
      }
    } catch (e) {
      debugPrint('AUTOTEST: Error checking pending rounds: $e');
    }
  }

  Future<void> _initLogFile() async {
    try {
      final now = DateTime.now();
      final dateStr =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';

      Directory? logDir;

      var status = await Permission.manageExternalStorage.status;
      if (!status.isGranted) {
        status = await Permission.manageExternalStorage.request();
      }
      if (!status.isGranted) {
        status = await Permission.storage.request();
      }

      if (status.isGranted) {
        final sdrDir = Directory('/storage/emulated/0/DCIM/ShangDaRen');
        if (!await sdrDir.exists()) {
          await sdrDir.create(recursive: true);
        }
        logDir = sdrDir;
      }

      if (logDir == null) {
        final extDir = await getExternalStorageDirectory();
        if (extDir != null) {
          final sdrDir = Directory('${extDir.path}/ShangDaRen');
          if (!await sdrDir.exists()) {
            await sdrDir.create(recursive: true);
          }
          logDir = sdrDir;
        }
      }

      if (logDir == null) {
        debugPrint('No available log directory');
        return;
      }

      _logFile = File('${logDir.path}/game_log_$dateStr.txt');
      _logSink = _logFile!.openWrite(mode: FileMode.append);
      _logSink!.writeln('=== 上大人字牌日志 $dateStr ===');
      _pendingLogCount = 1;
      _startLogFlushTimer();
      debugPrint('Log file: ${_logFile!.path}');
      _startResourceMonitor();
    } catch (e) {
      debugPrint('Init log file error: $e');
    }
  }

  void _startResourceMonitor() {
    _resourceMonitorTimer?.cancel();
    _logNativeResource();
    _resourceMonitorTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _logNativeResource();
      _checkMemoryWarning();
    });
  }

  void _logNativeResource() {
    try {
      final info = ProcessInfo.currentRss;
      final maxRss = ProcessInfo.maxRss;
      final usedMb = (info / 1048576).round();
      final maxMb = (maxRss / 1048576).round();
      final line = '[NATIVE_RESOURCE] RSS=${usedMb}MB, MaxRSS=${maxMb}MB';
      debugPrint('SDR $line');
      _writeLog(line);
    } catch (e) {
      debugPrint('Resource monitor error: $e');
    }
  }

  void _checkMemoryWarning() {
    try {
      final rss = ProcessInfo.currentRss;
      final rssMb = (rss / 1048576).round();
      _lastRssMb = rssMb;

      if (rssMb >= 300 && rssMb < 400) {
        _consecutiveHighMemory++;
        _writeLog('[MEMORY_L1] RSS=${rssMb}MB, consecutive=$_consecutiveHighMemory');
        _forceJsGc();
      } else if (rssMb >= 400 && rssMb < 500) {
        _consecutiveHighMemory++;
        _writeLog('[MEMORY_L2] RSS=${rssMb}MB, consecutive=$_consecutiveHighMemory');
        _forceJsGc();
        _trimJsMemory();
      } else if (rssMb >= 500) {
        _consecutiveHighMemory++;
        _writeLog('[MEMORY_L3] RSS=${rssMb}MB, consecutive=$_consecutiveHighMemory');
        _forceJsGc();
        _trimJsMemory();
        _trimWebViewCache();
      } else {
        _consecutiveHighMemory = 0;
      }

      if (_consecutiveHighMemory >= 4 && rssMb >= 400) {
        _writeLog('[MEMORY_CRITICAL] RSS=${rssMb}MB, aggressive cleanup');
        _aggressiveCleanup();
        _consecutiveHighMemory = 0;
      }
    } catch (e) {
      debugPrint('Memory check error: $e');
    }
  }

  void _handleRoundEnd() {
    try {
      final rss = ProcessInfo.currentRss;
      final rssMb = (rss / 1048576).round();
      _writeLog('[ROUND_END] RSS=${rssMb}MB');

      _forceJsGc();
      _trimJsMemory();
    } catch (e) {
      debugPrint('Round end handler error: $e');
    }
  }

  void _forceJsGc() {
    try {
      _controller.runJavaScript(
        'if(typeof cleanupOrphanDom==="function"){cleanupOrphanDom();}'
        'if(typeof gc==="function"){gc();}',
      );
    } catch (e) {
      debugPrint('Force JS GC error: $e');
    }
  }

  void _trimJsMemory() {
    try {
      _controller.runJavaScript(
        'if(typeof trimMemory==="function"){trimMemory();}',
      );
    } catch (e) {
      debugPrint('Trim JS memory error: $e');
    }
  }

  void _trimWebViewCache() {
    try {
      if (_controller.platform is AndroidWebViewController) {
        final androidController =
            _controller.platform as AndroidWebViewController;
        androidController.clearCache();
        _writeLog('[CACHE] WebView cache trimmed');
      }
    } catch (e) {
      debugPrint('Trim WebView cache error: $e');
    }
  }

  void _aggressiveCleanup() {
    try {
      _controller.runJavaScript(
        'if(typeof aggressiveCleanup==="function"){aggressiveCleanup();}',
      );
      if (_controller.platform is AndroidWebViewController) {
        final androidController =
            _controller.platform as AndroidWebViewController;
        androidController.clearCache();
      }
      _writeLog('[MEMORY] Aggressive cleanup completed');
    } catch (e) {
      debugPrint('Aggressive cleanup error: $e');
    }
  }

  void _writeLog(String line) {
    if (_logSink != null) {
      final timestamp = DateTime.now().toString().substring(11, 23);
      _logSink!.writeln('[$timestamp] $line');
      _pendingLogCount++;
    }
  }

  void _flushLog() {
    if (_logSink != null && _pendingLogCount > 0) {
      _logSink!.flush();
      _pendingLogCount = 0;
    }
  }

  void _startLogFlushTimer() {
    _logFlushTimer?.cancel();
    _logFlushTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _flushLog();
    });
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
        body: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (_isLoading)
              const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
          ],
        ),
      ),
    );
  }
}
