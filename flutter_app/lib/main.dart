import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'dart:io';

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

class _GamePageState extends State<GamePage> {
  late WebViewController _controller;
  bool _isLoading = true;
  bool _pageLoaded = false;
  static const _testChannel = MethodChannel('com.shangdaren.game/test');
  bool _testTriggered = false;

  @override
  void initState() {
    super.initState();
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
            Future.delayed(const Duration(seconds: 3), () {
              _checkPendingTest();
            });
          },
        ),
      )
      ..addJavaScriptChannel(
        'FlutterBridge',
        onMessageReceived: (message) {
          final msg = message.message;
          if (msg == 'exit') {
            exit(0);
          } else if (msg == 'runAutoTest') {
            _controller.runJavaScript('runAutoTest(3);');
          } else if (msg.startsWith('runAutoTest:')) {
            final rounds = int.tryParse(msg.split(':')[1]) ?? 3;
            _controller.runJavaScript('runAutoTest($rounds);');
          } else if (msg.startsWith('SDR_LOG:')) {
            debugPrint('SDR ${msg.substring(8)}');
          } else if (msg.startsWith('TEST_DONE:')) {
            if (false) {
              const platform = MethodChannel('com.shangdaren.game/log');
              platform.invokeMethod('log', {
                'tag': 'AUTOTEST_RESULT',
                'msg': msg.substring(10),
              });
            }
          } else if (msg.startsWith('AUTOTEST_LOG:')) {
            if (false) {
              const platform = MethodChannel('com.shangdaren.game/log');
              platform.invokeMethod('log', {
                'tag': 'AUTOTEST',
                'msg': msg.substring(13),
              });
            }
          }
        },
      )
      ..loadFlutterAsset('assets/html/index.html');

    if (_controller.platform is AndroidWebViewController) {
      final androidController =
          _controller.platform as AndroidWebViewController;
      androidController.setMediaPlaybackRequiresUserGesture(false);
      AndroidWebViewController.enableDebugging(true);
    }

    _pollPendingTest();
  }

  void _pollPendingTest() {
    Future.delayed(const Duration(seconds: 5), () {
      if (!mounted || !_pageLoaded) return;
      _checkPendingTest();
      _pollPendingTest();
    });
  }

  void _checkPendingTest() {
    return;
    if (_testTriggered || !_pageLoaded) return;
    _testChannel
        .invokeMethod<int>('getPendingRounds')
        .then((rounds) {
          if (rounds != null && rounds > 0 && !_testTriggered) {
            _testTriggered = true;
            const logChannel = MethodChannel('com.shangdaren.game/log');
            logChannel.invokeMethod('log', {
              'tag': 'AUTOTEST',
              'msg': 'Triggering runAutoTest($rounds)',
            });
            _controller.runJavaScript(
              'try { runAutoTest($rounds); } catch(e) { FlutterBridge.postMessage("AUTOTEST_LOG:ERROR:" + e.message); }',
            );
          }
        })
        .catchError((e) {
          const logChannel = MethodChannel('com.shangdaren.game/log');
          logChannel.invokeMethod('log', {
            'tag': 'AUTOTEST',
            'msg': 'getPendingRounds error: $e',
          });
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
          exit(0);
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
