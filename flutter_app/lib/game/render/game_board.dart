import 'dart:developer' as developer;
import 'dart:math' as math;
import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flutter/painting.dart';
import '../core/atlas_loader.dart';
import '../models/card.dart';
import '../models/meld.dart';
import '../logic/hu_calculator.dart';
import 'card_render.dart';

class GameBoard extends Component {
  static const double designWidth = 1280.0;
  static const double designHeight = 720.0;

  // 手牌尺寸 - 与H5版本CSS对应(2.5rem x 10.5rem)
  static const double handCardW = 60.0;
  static const double handCardH = 224.0;
  static const double smallCardW = 28.0;
  static const double smallCardH = 48.0;
  static const double meldCardW = 34.0;
  static const double meldCardH = 56.0;
  static const double hCardW = 160.0;
  static const double hCardH = 40.0;
  static const double deckCardW = 160.0;
  static const double deckCardH = 40.0;

  static const double handStackVisible = 64.0;
  static const double handSentenceGap = 2.0;
  static const double selectedOffsetY = 28.0;

  static const double huAiHandCardW = 32.4;
  static const double huAiHandCardH = 134.4;
  static const double huAiHandStackVisible = 20.0;
  static const double huAiHandSentenceGap = 0.0;

  static const double leftMaxW = 340.0;
  static const double rightMaxW = 280.0;
  static const double smallCardGap = 2.0;
  static const double discardCardGap = 1.0;
  static const int maxDiscardPerRow = 8;
  static const double meldRowGap = 0.0;
  static const double discardRowGap = 0.0;
  static const double meldToDiscardGap = 1.0;
  static const double avatarToMeldGap = 6.0;

  static const double aiCardScale = 0.5;
  static const double meldStackVisible = 17.0;
  static const double aiHandStackVisible = 15.0;
  static const double aiHandToMeldGap = 2.0;
  static const double aiHandToMeldGapHu = 20.0;
  static const double huAiHandToMeldGap = 20.0;
  static const double huDisplayCardW = 42.0;
  static const double huDisplayCardH = 68.0;
  static const double huDisplayStackVisible = 20.0;
  static const double huDisplayGroupGap = 2.0;

  final List<CardRender> _player0Hand = [];
  final List<CardRender> _player1Hand = [];
  final List<CardRender> _player2Hand = [];
  final List<CardRender> _player0Discards = [];
  final List<CardRender> _player1Discards = [];
  final List<CardRender> _player2Discards = [];
  final List<CardRender> _player0Melds = [];
  final List<CardRender> _player1Melds = [];
  final List<CardRender> _player2Melds = [];

  Card? lastPlayedCard;
  int? newDrawnCardId;
  int? badgeAnimCardId;
  int badgeOldCount = 0;
  double badgeAnimTimer = 0.0;
  static const double badgeAnimDuration = 0.5;
  double _player2MeldRightEdge = 0;
  double _player0HandHeight = 0;
  double _player2HandHeight = 0;

  Image? _atlasImage;
  AtlasLoader? _atlasLoader;
  Map<String, Image> _smallCardImages = {};
  Map<String, Image> _horizontalCardImages = {};
  Map<String, Image> _handCardImages = {};

  int deckCount = 0;
  bool dealingComplete = false;
  bool showHuDisplay = false;

  bool showHuResult = false;
  String huWinnerName = '';
  int huWinnerIndex = -1;
  String huMethod = '';
  String huType = '';
  int huCount = 0;
  int huMultiplier = 0;
  int huScore = 0;
  int huDianpaoIndex = -1;
  String huDianpaoName = '';
  Card? huDianpaoCard;
  Card? huZimoCard;
  Map<int, int> huScoreChanges = {};
  List<String> _playerNames = [];

  Rect _huPanelCloseBtnRect = Rect.zero;
  Rect _huPanelRect = Rect.zero;

  void setHuResult({
    required bool show,
    String winnerName = '',
    int winnerIndex = -1,
    String method = '',
    String huTypeName = '',
    int huCountVal = 0,
    int multiplier = 0,
    int score = 0,
    int dianpaoIndex = -1,
    String dianpaoName = '',
    Card? dianpaoCard,
    Card? zimoCard,
    Map<int, int> scoreChanges = const {},
    List<String> playerNames = const [],
  }) {
    showHuResult = show;
    huWinnerName = winnerName;
    huWinnerIndex = winnerIndex;
    huMethod = method;
    huType = huTypeName;
    huCount = huCountVal;
    huMultiplier = multiplier;
    huScore = score;
    huDianpaoIndex = dianpaoIndex;
    huDianpaoName = dianpaoName;
    huDianpaoCard = dianpaoCard;
    huZimoCard = zimoCard;
    huScoreChanges = scoreChanges;
    _playerNames = playerNames;
  }

  void setAtlas(Image image, AtlasLoader loader) {
    _atlasImage = image;
    _atlasLoader = loader;
  }

  void setSmallCardImages(Map<String, Image> images) {
    _smallCardImages = images;
  }

  void setHorizontalCardImages(Map<String, Image> images) {
    _horizontalCardImages = images;
  }

  void setHandCardImages(Map<String, Image> images) {
    _handCardImages = images;
  }

  List<CardRender> get _allCardRenders => [
    ..._player0Hand,
    ..._player1Hand,
    ..._player2Hand,
    ..._player0Discards,
    ..._player1Discards,
    ..._player2Discards,
    ..._player0Melds,
    ..._player1Melds,
    ..._player2Melds,
  ];

  CardRender acquireCardRender(Card card, {bool faceUp = true}) {
    final cr = CardRender.pool.acquire();
    cr.setup(card, faceUp: faceUp);
    return cr;
  }

  void clearAll() {
    for (final list in [
      _player0Hand,
      _player1Hand,
      _player2Hand,
      _player0Discards,
      _player1Discards,
      _player2Discards,
      _player0Melds,
      _player1Melds,
      _player2Melds,
    ]) {
      for (final cr in list) {
        CardRender.pool.release(cr);
      }
      list.clear();
    }
    deckCount = 0;
    _player0HandHeight = 0;
    _player2HandHeight = 0;
  }

  void setPlayerHand(int playerIndex, List<Card> cards) {
    final handList = _handList(playerIndex);
    if (playerIndex == 1) {
      if (newDrawnCardId != null) {
        Card? newCard;
        for (final c in cards) {
          if (c.id == newDrawnCardId) {
            newCard = c;
            break;
          }
        }
        if (newCard != null) {
          int oldCount = 0;
          for (final cr in handList) {
            if (cr.card != null && cr.card!.character == newCard.character) {
              oldCount++;
            }
          }
          if (oldCount > 0) {
            badgeAnimCardId = newCard.id;
            badgeOldCount = oldCount;
            badgeAnimTimer = 0.0;
          }
        }
      }
    }
    for (final cr in handList) {
      CardRender.pool.release(cr);
    }
    handList.clear();
    final isFaceUp = playerIndex == 1;
    for (final card in cards) {
      final cr = acquireCardRender(card, faceUp: isFaceUp);
      if (playerIndex == 1 &&
          newDrawnCardId != null &&
          card.id == newDrawnCardId) {
        cr.isNewDrawn = true;
      }
      handList.add(cr);
    }
    updateLayout();
  }

  void addCardToHand(int playerIndex, Card card) {
    final handList = _handList(playerIndex);
    handList.add(acquireCardRender(card, faceUp: playerIndex == 1));
    updateLayout();
  }

  void removeCardFromHand(int playerIndex, Card card) {
    final handList = _handList(playerIndex);
    final idx = handList.indexWhere((cr) => cr.card == card);
    if (idx >= 0) {
      CardRender.pool.release(handList.removeAt(idx));
    }
    updateLayout();
  }

  void addDiscard(int playerIndex, Card card) {
    final discardList = _discardList(playerIndex);
    for (final existing in discardList) {
      existing.isLastDiscard = false;
    }
    final cr = acquireCardRender(card, faceUp: true);
    cr.isLastDiscard = true;
    discardList.add(cr);
    lastPlayedCard = card;
    updateLayout();
  }

  void clearLastDiscard() {
    for (final list in [_player0Discards, _player1Discards, _player2Discards]) {
      for (final cr in list) {
        cr.isLastDiscard = false;
      }
    }
    lastPlayedCard = null;
  }

  Offset getAIHandDrawTarget(int playerId) {
    final hand = playerId == 0 ? _player0Hand : _player2Hand;
    final n = hand.length;
    final startY = 120.0 + avatarToMeldGap;

    if (playerId == 0) {
      final totalWidth = n * aiHandStackVisible + meldCardW;
      if (totalWidth <= leftMaxW || n == 0) {
        return Offset(9.6 + n * aiHandStackVisible, startY);
      } else {
        final step = (leftMaxW - meldCardW) / n;
        return Offset(9.6 + n * step, startY);
      }
    } else {
      final totalWidth = n * aiHandStackVisible + meldCardW;
      if (totalWidth <= rightMaxW || n == 0) {
        return Offset(
          designWidth - 9.6 - meldCardW - n * aiHandStackVisible,
          startY,
        );
      } else {
        final step = (rightMaxW - meldCardW) / n;
        return Offset(designWidth - 9.6 - meldCardW - n * step, startY);
      }
    }
  }

  void addMeld(int playerIndex, Meld meld) {
    final meldList = _meldList(playerIndex);
    for (final card in meld.cards) {
      final cr = acquireCardRender(card, faceUp: true);
      cr.isMeldCard = true;
      meldList.add(cr);
    }
    lastPlayedCard = null;
    updateLayout();
  }

  List<CardRender> getPlayerMelds(int playerIndex) {
    return _meldList(playerIndex);
  }

  void setDeckCount(int count) {
    deckCount = count;
  }

  CardRender? findCardRender(int playerIndex, Card card) {
    final handList = _handList(playerIndex);
    for (final cr in handList) {
      if (cr.card == card) return cr;
    }
    return null;
  }

  /// 手牌碰撞检测，正确处理叠放效果
  /// 只返回每组叠放中最上面（最后一张）的牌
  Card? hitTestHand(double x, double y) {
    final sentenceGroups = _groupHandBySentence(_player1Hand);

    for (final sg in sentenceGroups.reversed) {
      final stacks = _groupStackByChar(sg);

      for (final stack in stacks.reversed) {
        if (stack.isEmpty || stack[0].position.x < -1000) continue;

        final cr = stack[0];
        final cardX = cr.position.x;
        final cardY = cr.position.y;

        if (x >= cardX && x <= cardX + handCardW) {
          final totalH = (stack.length - 1) * handStackVisible + handCardH;
          if (y >= cardY && y <= cardY + totalH) {
            return stack.last.card;
          }
        }
      }
    }
    return null;
  }

  bool hitTestHuPanelCloseBtn(double x, double y) {
    if (!showHuDisplay) return false;
    return _huPanelCloseBtnRect.contains(Offset(x, y));
  }

  bool hitTestHuPanel(double x, double y) {
    if (!showHuDisplay) return false;
    return _huPanelRect.contains(Offset(x, y));
  }

  List<Offset> getHuPanelScorePositions(
    int winnerIndex,
    Map<int, int> scoreChangesMap,
  ) {
    final handArea = getPlayer1HandArea();
    final panelBottomY = handArea.top - 10;
    final panelH = 260.0;
    final panelY = panelBottomY - panelH;
    final cx = designWidth / 2;

    final winnerScoreY = panelY + 130;
    final losersY = panelY + 190;

    final positions = <Offset>[];

    final losers = <int>[];
    for (int i = 0; i < 3; i++) {
      if (i == winnerIndex) continue;
      final s = scoreChangesMap[i] ?? 0;
      if (s != 0) {
        losers.add(i);
      }
    }

    final loserGap = 16.0;
    final loserPadH = 16.0;
    final loserFontSize = 14.0;
    final loserScoreFontSize = 20.0;
    final loserPadV = 8.0;

    final loserWidths = <double>[];
    double totalLoserW = 0;
    for (final li in losers) {
      final nameTp = TextPainter(
        text: TextSpan(
          text: _playerNames[li],
          style: TextStyle(
            fontSize: loserFontSize,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final scoreTp = TextPainter(
        text: TextSpan(
          text: '${scoreChangesMap[li]}',
          style: TextStyle(
            fontSize: loserScoreFontSize,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final w =
          (nameTp.width > scoreTp.width ? nameTp.width : scoreTp.width) +
          loserPadH * 2;
      loserWidths.add(w);
      totalLoserW += w;
    }
    totalLoserW += (losers.length > 0 ? losers.length - 1 : 0) * loserGap;

    var loserX = cx - totalLoserW / 2;

    for (int i = 0; i < 3; i++) {
      final s = scoreChangesMap[i] ?? 0;
      if (s == 0) continue;

      if (i == winnerIndex) {
        positions.add(Offset(cx, winnerScoreY));
      } else {
        final loserIdx = losers.indexOf(i);
        if (loserIdx >= 0) {
          final lw = loserWidths[loserIdx];
          positions.add(Offset(loserX + lw / 2, losersY));
          loserX += lw + loserGap;
        }
      }
    }

    return positions;
  }

  Offset? getCardPosition(Card card) {
    for (final cr in _player1Hand) {
      if (cr.card == card) {
        return Offset(cr.position.x, cr.position.y);
      }
    }
    return null;
  }

  Rect getPlayer1HandArea() {
    if (_player1Hand.isEmpty) {
      return Rect.fromLTWH(0, designHeight - 200, designWidth, 200);
    }
    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = double.negativeInfinity;
    double maxY = double.negativeInfinity;
    for (final cr in _player1Hand) {
      if (cr.position.x < -1000) continue;
      final x = cr.position.x;
      final y = cr.position.y;
      if (x < minX) minX = x;
      if (y < minY) minY = y;
      if (x + handCardW > maxX) maxX = x + handCardW;
      if (y + handCardH > maxY) maxY = y + handCardH;
    }
    if (minX == double.infinity) {
      return Rect.fromLTWH(0, designHeight - 200, designWidth, 200);
    }
    return Rect.fromLTWH(
      minX - 5,
      minY - 5,
      maxX - minX + 10,
      maxY - minY + 10,
    );
  }

  void setPlayerDiscards(int playerIndex, List<Card> cards) {
    final discardList = _discardList(playerIndex);
    for (final cr in discardList) {
      CardRender.pool.release(cr);
    }
    discardList.clear();
    for (final card in cards) {
      final cr = acquireCardRender(card, faceUp: true);
      if (lastPlayedCard != null && card.id == lastPlayedCard!.id) {
        cr.isLastDiscard = true;
      }
      discardList.add(cr);
    }
    updateLayout();
  }

  void setPlayerMelds(int playerIndex, List<Meld> melds) {
    final meldList = _meldList(playerIndex);
    for (final cr in meldList) {
      CardRender.pool.release(cr);
    }
    meldList.clear();
    int groupId = 0;
    for (final meld in melds) {
      final sortedCards = List<Card>.from(meld.cards);
      if (meld.type == MeldType.ju) {
        sortedCards.sort((a, b) => a.position.compareTo(b.position));
      }
      for (final card in sortedCards) {
        final cr = acquireCardRender(card, faceUp: true);
        cr.isMeldCard = true;
        cr.meldGroupId = groupId;
        meldList.add(cr);
      }
      groupId++;
    }
    updateLayout();
  }

  void setTingBadge(int playerIndex, bool show) {
    for (final cr in _handList(playerIndex)) {
      cr.showTingBadge = show;
    }
  }

  void setActionButtons({
    bool canChi = false,
    bool canPeng = false,
    bool canZhao = false,
    bool canHu = false,
  }) {}

  void setTingBadges(int playerIndex, List<Card> tingCards, bool show) {
    for (final cr in _handList(playerIndex)) {
      cr.showTingBadge = show && tingCards.any((tc) => tc.id == cr.card?.id);
    }
  }

  void setSelected(int playerIndex, Card? card) {
    for (final cr in _handList(playerIndex)) {
      cr.isSelected = card != null && cr.card == card;
    }
  }

  List<CardRender> _handList(int i) =>
      [_player0Hand, _player1Hand, _player2Hand][i];
  List<CardRender> _discardList(int i) =>
      [_player0Discards, _player1Discards, _player2Discards][i];
  List<CardRender> _meldList(int i) =>
      [_player0Melds, _player1Melds, _player2Melds][i];

  void updateLayout() {
    _layoutPlayer1Hand();
    _layoutPlayer0Hand();
    _layoutPlayer2Hand();
    _layoutPlayer0Melds();
    _layoutPlayer1Melds();
    _layoutPlayer2Melds();
    _layoutPlayer0Discards();
    _layoutPlayer1Discards();
    _layoutPlayer2Discards();
  }

  List<List<CardRender>> _groupHandBySentence(List<CardRender> hand) {
    final groups = <int, List<CardRender>>{};
    for (final cr in hand) {
      if (cr.card == null) continue;
      groups.putIfAbsent(cr.card!.sentence, () => []).add(cr);
    }
    return (groups.keys.toList()..sort()).map((k) => groups[k]!).toList();
  }

  List<List<CardRender>> _groupStackByChar(List<CardRender> sentenceCards) {
    final groups = <String, List<CardRender>>{};
    for (final cr in sentenceCards) {
      if (cr.card == null) continue;
      groups.putIfAbsent(cr.card!.character, () => []).add(cr);
    }
    final sortedKeys = groups.keys.toList()
      ..sort((a, b) {
        final ca = sentenceCards.firstWhere((cr) => cr.card?.character == a);
        final cb = sentenceCards.firstWhere((cr) => cr.card?.character == b);
        return ca.card!.position.compareTo(cb.card!.position);
      });
    for (final key in groups.keys) {
      groups[key]!.sort((a, b) => a.card!.position.compareTo(b.card!.position));
    }
    return sortedKeys.map((k) => groups[k]!).toList();
  }

  void _layoutPlayer1Hand() {
    final sentenceGroups = _groupHandBySentence(_player1Hand);

    int maxPositions = 0;
    for (final sg in sentenceGroups) {
      final posCount = _groupStackByChar(sg).length;
      if (posCount > maxPositions) maxPositions = posCount;
    }

    final totalW = sentenceGroups.isEmpty
        ? 0.0
        : sentenceGroups.length * handCardW +
              (sentenceGroups.length - 1) * handSentenceGap;
    final totalH = maxPositions > 0
        ? (maxPositions - 1) * handStackVisible + handCardH
        : 0.0;

    final startX = (designWidth - totalW) / 2;
    final startY = designHeight - totalH + 60;

    double curX = startX;
    for (final sg in sentenceGroups) {
      final stacks = _groupStackByChar(sg);
      double curY = startY;
      for (int i = 0; i < stacks.length; i++) {
        for (final cr in stacks[i]) {
          cr.position.setValues(curX, curY);
          cr.angle = 0;
          cr.scale.setValues(1, 1);
        }
        if (i < stacks.length - 1) {
          curY += handStackVisible;
        }
      }
      curX += handCardW + handSentenceGap;
    }
  }

  void _layoutPlayer0Hand() {
    if (_player0Hand.isEmpty) {
      _player0HandHeight = 0;
    } else if (showHuDisplay) {
      final sentenceChars = <int, Set<String>>{};
      for (final cr in _player0Hand) {
        if (cr.card == null) continue;
        sentenceChars
            .putIfAbsent(cr.card!.sentence, () => {})
            .add(cr.card!.character);
      }
      int maxChars = 0;
      for (final chars in sentenceChars.values) {
        if (chars.length > maxChars) maxChars = chars.length;
      }
      _player0HandHeight = maxChars > 0
          ? huAiHandCardH + (maxChars - 1) * huAiHandStackVisible
          : 0;
    } else {
      _player0HandHeight = meldCardH;
    }
    for (final cr in _player0Hand) {
      cr.position.setValues(-9999, -9999);
    }
  }

  void _layoutPlayer2Hand() {
    if (_player2Hand.isEmpty) {
      _player2HandHeight = 0;
    } else if (showHuDisplay) {
      final sentenceChars = <int, Set<String>>{};
      for (final cr in _player2Hand) {
        if (cr.card == null) continue;
        sentenceChars
            .putIfAbsent(cr.card!.sentence, () => {})
            .add(cr.card!.character);
      }
      int maxChars = 0;
      for (final chars in sentenceChars.values) {
        if (chars.length > maxChars) maxChars = chars.length;
      }
      _player2HandHeight = maxChars > 0
          ? huAiHandCardH + (maxChars - 1) * huAiHandStackVisible
          : 0;
    } else {
      _player2HandHeight = meldCardH;
    }
    for (final cr in _player2Hand) {
      cr.position.setValues(-9999, -9999);
    }
  }

  void _layoutPlayer0Melds() {
    if (_player0Melds.isEmpty) return;
    final startX = 9.6;
    final gap = showHuDisplay ? aiHandToMeldGapHu : aiHandToMeldGap;
    final handOffset = _player0HandHeight > 0 ? _player0HandHeight + gap : 0;
    final startY = 120.0 + avatarToMeldGap + handOffset;
    final groups = _groupMeldsByGroup(_player0Melds);
    final cw = showHuDisplay ? huDisplayCardW : meldCardW;
    final ch = showHuDisplay ? huDisplayCardH : meldCardH;
    final sv = showHuDisplay ? huDisplayStackVisible : meldStackVisible;
    double curX = startX;
    double curY = startY;
    int groupCountInRow = 0;
    for (final group in groups) {
      final groupW = (group.length - 1) * sv + cw;
      if (curX + groupW > startX + leftMaxW || groupCountInRow >= 3) {
        curX = startX;
        curY += ch + meldRowGap;
        groupCountInRow = 0;
      }
      for (int i = 0; i < group.length; i++) {
        final cr = group[i];
        cr.position.setValues(curX + i * sv, curY);
        cr.angle = 0;
        cr.scale.setValues(1, 1);
      }
      curX += groupW + 2;
      groupCountInRow++;
    }
  }

  void _layoutPlayer1Melds() {
    if (_player1Melds.isEmpty) return;

    final groups = _groupMeldsByGroup(_player1Melds);
    final cw = showHuDisplay ? huDisplayCardW : meldCardW;
    final ch = showHuDisplay ? huDisplayCardH : meldCardH;
    final sv = showHuDisplay ? huDisplayStackVisible : meldStackVisible;
    int meldRowCount = 1;
    double curX = 0.0;
    int groupCountInRow = 0;
    for (final group in groups) {
      final groupW = (group.length - 1) * sv + cw;
      if (curX + groupW > leftMaxW || groupCountInRow >= 3) {
        curX = 0;
        meldRowCount++;
        groupCountInRow = 0;
      }
      curX += groupW + 2;
      groupCountInRow++;
    }

    final avatarTop = designHeight - 114.0;
    final baseY =
        avatarTop - avatarToMeldGap - meldRowCount * (ch + meldRowGap);

    double curXPos = 10.0;
    double rowY = baseY;
    int currentGroupInRow = 0;
    for (final group in groups) {
      final groupW = (group.length - 1) * sv + cw;
      if (curXPos + groupW > 10.0 + leftMaxW || currentGroupInRow >= 3) {
        curXPos = 10.0;
        rowY += ch + meldRowGap;
        currentGroupInRow = 0;
      }
      for (int i = 0; i < group.length; i++) {
        final cr = group[i];
        cr.position.setValues(curXPos + i * sv, rowY);
        cr.angle = 0;
        cr.scale.setValues(1, 1);
      }
      curXPos += groupW + 2;
      currentGroupInRow++;
    }
  }

  List<List<CardRender>> _groupMeldsByGroup(List<CardRender> melds) {
    final groups = <List<CardRender>>[];
    final used = <int>{};

    for (int i = 0; i < melds.length; i++) {
      if (used.contains(i)) continue;
      final cr = melds[i];
      final groupId = cr.meldGroupId;
      final group = <CardRender>[cr];
      used.add(i);

      for (int j = i + 1; j < melds.length; j++) {
        if (used.contains(j)) continue;
        if (melds[j].meldGroupId == groupId) {
          group.add(melds[j]);
          used.add(j);
        }
      }
      groups.add(group);
    }

    return groups;
  }

  void _layoutPlayer2Melds() {
    if (_player2Melds.isEmpty) {
      _player2MeldRightEdge = designWidth - 9.6;
      return;
    }
    final groups = _groupMeldsByGroup(_player2Melds);
    final startX = designWidth - 9.6;
    final gap2 = showHuDisplay ? aiHandToMeldGapHu : aiHandToMeldGap;
    final handOffset = _player2HandHeight > 0 ? _player2HandHeight + gap2 : 0;
    final startY = 120.0 + avatarToMeldGap + handOffset;
    final leftBound = designWidth - 9.6 - rightMaxW;
    final cw = showHuDisplay ? huDisplayCardW : meldCardW;
    final ch = showHuDisplay ? huDisplayCardH : meldCardH;
    final sv = showHuDisplay ? huDisplayStackVisible : meldStackVisible;
    double curX = startX;
    double curY = startY;
    int groupCountInRow = 0;
    for (int g = 0; g < groups.length; g++) {
      final group = groups[g];
      final groupW = (group.length - 1) * sv + cw;
      final cardRightEdge = curX - cw + (group.length - 1) * sv;
      if (cardRightEdge < leftBound || groupCountInRow >= 3) {
        curX = startX;
        curY += ch + meldRowGap;
        groupCountInRow = 0;
      }
      for (int i = 0; i < group.length; i++) {
        final cr = group[i];
        cr.position.setValues(curX - groupW + i * sv, curY);
        cr.angle = 0;
        cr.scale.setValues(1, 1);
      }
      curX -= groupW + 2;
      groupCountInRow++;
    }
    _player2MeldRightEdge = startX;
  }

  void _layoutPlayer0Discards() {
    final startX = 9.6;
    final cols = maxDiscardPerRow;
    int meldRows = 0;
    if (_player0Melds.isNotEmpty) {
      final groups = _groupMeldsByGroup(_player0Melds);
      double cx = 9.6;
      int groupCountInRow = 0;
      for (final group in groups) {
        final gw = (group.length - 1) * meldStackVisible + meldCardW;
        if (cx + gw > 9.6 + leftMaxW || groupCountInRow >= 3) {
          cx = 9.6;
          meldRows++;
          groupCountInRow = 0;
        }
        cx += gw + 2;
        groupCountInRow++;
      }
      meldRows++;
    }
    final dGap0 = showHuDisplay ? aiHandToMeldGapHu : aiHandToMeldGap;
    final handOffset = _player0HandHeight > 0 ? _player0HandHeight + dGap0 : 0;
    final startY =
        120.0 +
        avatarToMeldGap +
        handOffset +
        meldRows * (meldCardH + meldRowGap) +
        meldToDiscardGap;
    for (int i = 0; i < _player0Discards.length; i++) {
      final cr = _player0Discards[i];
      final col = i % cols;
      final row = i ~/ cols;
      cr.position.setValues(
        startX + col * (smallCardW + discardCardGap),
        startY + row * (smallCardH + discardRowGap),
      );
      cr.angle = 0;
      cr.scale.setValues(1, 1);
    }
  }

  void _layoutPlayer1Discards() {
    if (_player1Discards.isEmpty) return;
    final startX = 10.0;
    final cols = maxDiscardPerRow;
    final discardRows = ((_player1Discards.length + cols - 1) ~/ cols);

    final groups = _groupMeldsByGroup(_player1Melds);
    int meldRowCount = 0;
    if (_player1Melds.isNotEmpty) {
      double cx = 0.0;
      int groupCountInRow = 0;
      for (final group in groups) {
        final gw = (group.length - 1) * meldStackVisible + meldCardW;
        if (cx + gw > leftMaxW || groupCountInRow >= 3) {
          cx = 0;
          meldRowCount++;
          groupCountInRow = 0;
        }
        cx += gw + 2;
        groupCountInRow++;
      }
      meldRowCount++;
    }

    final avatarTop = designHeight - 114.0;
    final startY =
        avatarTop -
        avatarToMeldGap -
        meldRowCount * (meldCardH + meldRowGap) -
        meldToDiscardGap -
        discardRows * (smallCardH + discardRowGap);
    for (int i = 0; i < _player1Discards.length; i++) {
      final cr = _player1Discards[i];
      final col = i % cols;
      final row = i ~/ cols;
      cr.position.setValues(
        startX + col * (smallCardW + discardCardGap),
        startY + row * (smallCardH + discardRowGap),
      );
      cr.angle = 0;
      cr.scale.setValues(1, 1);
    }
  }

  void _layoutPlayer2Discards() {
    if (_player2Discards.isEmpty) return;

    final groups = _groupMeldsByGroup(_player2Melds);
    int meldRowCount = 0;
    if (_player2Melds.isNotEmpty) {
      final startX = designWidth - 9.6;
      final leftBound = designWidth - 9.6 - rightMaxW;
      double curX = startX;
      double curY = 120.0 + avatarToMeldGap;
      int groupCountInRow = 0;
      int rowsUsed = 1;
      for (int g = 0; g < groups.length; g++) {
        final group = groups[g];
        final gw = (group.length - 1) * meldStackVisible + meldCardW;
        final cardRightEdge =
            curX - meldCardW + (group.length - 1) * meldStackVisible;
        if (cardRightEdge < leftBound || groupCountInRow >= 3) {
          curX = startX;
          curY += meldCardH + meldRowGap;
          groupCountInRow = 0;
          rowsUsed++;
        }
        curX -= gw + 2;
        groupCountInRow++;
      }
      meldRowCount = rowsUsed;
    }

    final cols = maxDiscardPerRow;
    final startX =
        _player2MeldRightEdge -
        (cols - 1) * (smallCardW + discardCardGap) -
        smallCardW;
    final dGap2 = showHuDisplay ? aiHandToMeldGapHu : aiHandToMeldGap;
    final handOffset = _player2HandHeight > 0 ? _player2HandHeight + dGap2 : 0;
    final startY =
        120.0 +
        avatarToMeldGap +
        handOffset +
        meldRowCount * (meldCardH + meldRowGap) +
        meldToDiscardGap;
    for (int i = 0; i < _player2Discards.length; i++) {
      final cr = _player2Discards[i];
      final colFromRight = i % cols;
      final row = i ~/ cols;
      cr.position.setValues(
        startX + (cols - 1 - colFromRight) * (smallCardW + discardCardGap),
        startY + row * (smallCardH + discardRowGap),
      );
      cr.angle = 0;
      cr.scale.setValues(1, 1);
    }
  }

  int _getDeckLayerCount(int count) {
    if (count >= 60) return 10;
    if (count >= 50) return 8;
    if (count >= 40) return 7;
    if (count >= 30) return 6;
    if (count >= 20) return 5;
    if (count >= 10) return 4;
    if (count >= 5) return 3;
    if (count > 0) return 2;
    return 0;
  }

  @override
  void update(double dt) {
    for (final cr in _allCardRenders) {
      cr.update(dt);
      if (cr.isNewDrawn && !cr.showNewBadge) {
        cr.showNewBadge = true;
        cr.newBadgeTimer = 0.0;
      }
    }
    if (badgeAnimTimer < badgeAnimDuration) {
      badgeAnimTimer += dt;
      if (badgeAnimTimer > badgeAnimDuration) {
        badgeAnimTimer = badgeAnimDuration;
        badgeAnimCardId = null;
      }
    }
  }

  @override
  void render(Canvas canvas) {
    _renderBackground(canvas);
    _renderDeck(canvas);
    _renderDeckIndicator(canvas);
    _renderPlayedCards(canvas);
    _renderSmallCards(canvas);
    _renderAIHandCards(canvas);
    _renderHandCards(canvas);
    _renderOverlays(canvas);
    _renderDragCard(canvas);
    if (showHuResult || showHuDisplay) {
      _renderHuResult(canvas);
    }
  }

  bool _isDragging = false;
  Card? _dragCard;
  int? _dragCardIndex;
  double _dragX = 0;
  double _dragY = 0;

  void setDragState(
    bool isDragging,
    Card? card,
    int? index,
    double x,
    double y,
  ) {
    _isDragging = isDragging;
    _dragCard = card;
    _dragCardIndex = index;
    _dragX = x;
    _dragY = y;
  }

  void _renderDragCard(Canvas canvas) {
    if (!_isDragging || _dragCard == null) return;

    canvas.save();
    canvas.translate(_dragX, _dragY);

    final shadowPaint = Paint()
      ..color = const Color(0x80000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(5, 5, handCardW, handCardH),
        const Radius.circular(8),
      ),
      shadowPaint,
    );

    final dragRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, handCardW, handCardH),
      const Radius.circular(6),
    );
    canvas.clipPath(Path()..addRRect(dragRRect));

    final paint = Paint()..filterQuality = FilterQuality.high;

    final handImg = _handCardImages[_dragCard!.character];
    if (handImg != null) {
      final imgW = handImg.width.toDouble();
      final imgH = handImg.height.toDouble();
      canvas.drawImageRect(
        handImg,
        Rect.fromLTWH(0, 0, imgW, imgH),
        Rect.fromLTWH(0, 0, handCardW, handCardH),
        paint,
      );
    } else if (_atlasImage != null && _atlasLoader != null) {
      final info = _atlasLoader!.getSpriteByChar(_dragCard!.character);
      if (info != null) {
        if (info.rotated) {
          canvas.rotate(-math.pi / 2);
          canvas.translate(-handCardH, 0);
          canvas.drawImageRect(
            _atlasImage!,
            Rect.fromLTWH(
              info.srcX.toDouble(),
              info.srcY.toDouble(),
              info.srcW.toDouble(),
              info.srcH.toDouble(),
            ),
            Rect.fromLTWH(0, 0, handCardH, handCardW),
            paint,
          );
        } else {
          canvas.drawImageRect(
            _atlasImage!,
            Rect.fromLTWH(
              info.srcX.toDouble(),
              info.srcY.toDouble(),
              info.srcW.toDouble(),
              info.srcH.toDouble(),
            ),
            Rect.fromLTWH(0, 0, handCardW, handCardH),
            paint,
          );
        }
      }
    }

    final labelTp = TextPainter(
      text: const TextSpan(
        text: '出',
        style: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: Color(0xFFFFFFFF),
          shadows: [
            Shadow(color: Color(0xFFFF0000), blurRadius: 10),
            Shadow(color: Color(0xFFFF0000), blurRadius: 20),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    labelTp.layout();
    final cx = handCardW / 2;
    final cy = handCardH / 2;
    labelTp.paint(
      canvas,
      Offset(cx - labelTp.width / 2, cy - labelTp.height / 2),
    );

    canvas.restore();
  }

  void _renderBackground(Canvas canvas) {
    final rect = Rect.fromLTWH(-10, -10, designWidth + 20, designHeight + 20);
    final paint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 0.7,
        colors: const [Color(0xFF1a5c2e), Color(0xFF0d3d1a), Color(0xFF062810)],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, paint);
  }

  void _renderDeck(Canvas canvas) {
    if (deckCount <= 0 || _atlasImage == null || _atlasLoader == null) return;

    final info = _atlasLoader!.getSprite('back');
    if (info == null) return;

    double deckX, deckY, deckScale;
    if (dealingComplete) {
      deckX = designWidth / 2 - deckCardW * 0.5 / 2;
      deckY = 9.6;
      deckScale = 0.5;
    } else {
      deckX = designWidth / 2 - deckCardW / 2;
      deckY = designHeight / 2 - deckCardH / 2;
      deckScale = 1.0;
    }

    final displayCount = _getDeckLayerCount(deckCount);
    for (int i = 0; i < displayCount; i++) {
      final opacity = 0.4 + (i / displayCount) * 0.6;
      final paint = Paint()
        ..color = Color.fromRGBO(255, 255, 255, opacity)
        ..filterQuality = FilterQuality.high;

      canvas.save();
      canvas.translate(deckX + i * 4 * deckScale, deckY + i * 1 * deckScale);
      canvas.drawImageRect(
        _atlasImage!,
        Rect.fromLTWH(
          info.srcX.toDouble(),
          info.srcY.toDouble(),
          info.srcW.toDouble(),
          info.srcH.toDouble(),
        ),
        Rect.fromLTWH(0, 0, deckCardW * deckScale, deckCardH * deckScale),
        paint,
      );
      canvas.restore();
    }
  }

  void _renderDeckIndicator(Canvas canvas) {
    if (deckCount <= 0) return;

    if (dealingComplete) {
      final fontSize = 48.0;
      final tp = TextPainter(
        text: TextSpan(
          text: '$deckCount',
          style: TextStyle(
            color: const Color(0xFFFFFFFF),
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            shadows: [
              Shadow(color: const Color(0xFFffd700), blurRadius: 24),
              Shadow(color: const Color(0xFFffd700), blurRadius: 12),
              Shadow(color: Color.fromRGBO(0, 0, 0, 0.95), blurRadius: 6),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      final deckStackCenterX = designWidth / 2;
      final deckStackCenterY = 9.6 + deckCardH * 0.5 / 2;
      tp.paint(
        canvas,
        Offset(
          deckStackCenterX - tp.width / 2,
          deckStackCenterY - tp.height / 2,
        ),
      );
    } else {
      final fontSize = 48.0;
      final tp = TextPainter(
        text: TextSpan(
          text: '$deckCount',
          style: TextStyle(
            color: const Color(0xFFFFFFFF),
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            shadows: [
              Shadow(color: const Color(0xFFffd700), blurRadius: 24),
              Shadow(color: const Color(0xFFffd700), blurRadius: 12),
              Shadow(color: Color.fromRGBO(0, 0, 0, 0.95), blurRadius: 6),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      final deckCenterX = designWidth / 2;
      final deckCenterY = designHeight / 2;
      tp.paint(
        canvas,
        Offset(deckCenterX - tp.width / 2, deckCenterY - tp.height / 2),
      );
    }
  }

  void _renderPlayedCards(Canvas canvas) {
    if (lastPlayedCard == null) return;
    if (!dealingComplete) return;
    if (showHuDisplay && huMethod == '点炮') return;

    double px, py;
    if (dealingComplete) {
      px = designWidth / 2 - hCardW / 2;
      py = 55.0;
    } else {
      px = designWidth / 2 - hCardW / 2;
      py = designHeight / 2 - hCardH / 2 - 50;
    }

    canvas.save();
    canvas.translate(px, py);

    final hImg = _horizontalCardImages[lastPlayedCard!.character];
    if (hImg != null) {
      final paint = Paint()..filterQuality = FilterQuality.high;
      final imgW = hImg.width.toDouble();
      final imgH = hImg.height.toDouble();
      final scaleX = hCardW / imgW;
      final scaleY = hCardH / imgH;
      final scale = scaleX < scaleY ? scaleX : scaleY;
      final drawW = imgW * scale;
      final drawH = imgH * scale;
      final offsetX = (hCardW - drawW) / 2;
      final offsetY = (hCardH - drawH) / 2;
      canvas.drawImageRect(
        hImg,
        Rect.fromLTWH(0, 0, imgW, imgH),
        Rect.fromLTWH(offsetX, offsetY, drawW, drawH),
        paint,
      );
    } else if (_atlasImage != null && _atlasLoader != null) {
      final pinyin = AtlasLoader.charToPinyin[lastPlayedCard!.character];
      if (pinyin != null) {
        final info = _atlasLoader!.getSprite('v/$pinyin');
        if (info != null) {
          final paint = Paint()..filterQuality = FilterQuality.high;
          canvas.drawImageRect(
            _atlasImage!,
            Rect.fromLTWH(
              info.srcX.toDouble(),
              info.srcY.toDouble(),
              info.srcW.toDouble(),
              info.srcH.toDouble(),
            ),
            Rect.fromLTWH(0, 0, hCardW, hCardH),
            paint,
          );
        }
      }
    }

    if (showHuDisplay && huWinnerIndex == 1 && huMethod == '自摸') {
      final label = '自摸';
      final labelColor = const Color(0xFFffd700);
      final bgPaint = Paint()..color = const Color(0xCC000000);
      final bgW = hCardW * 0.6;
      final bgH = hCardH * 0.7;
      final bgX = (hCardW - bgW) / 2;
      final bgY = (hCardH - bgH) / 2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(bgX, bgY, bgW, bgH),
          const Radius.circular(6),
        ),
        bgPaint,
      );
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            fontSize: 18.0,
            fontWeight: FontWeight.bold,
            color: labelColor,
            shadows: [Shadow(color: const Color(0xFF000000), blurRadius: 4)],
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(
        canvas,
        Offset(hCardW / 2 - tp.width / 2, hCardH / 2 - tp.height / 2),
      );
    }

    canvas.restore();
  }

  void _renderSmallCards(Canvas canvas) {
    if (_atlasImage == null || _atlasLoader == null) return;

    final smallLists = showHuDisplay
        ? [_player0Melds, _player1Melds, _player2Melds]
        : [
            _player0Melds,
            _player1Melds,
            _player2Melds,
            _player0Discards,
            _player1Discards,
            _player2Discards,
          ];

    for (final list in smallLists) {
      final meldGroups = <List<CardRender>>[];
      final nonMeldCards = <CardRender>[];
      List<CardRender>? currentMeldGroup;
      int? currentGroupId;

      for (final cr in list) {
        if (cr.card == null || cr.position.x < -1000) continue;
        if (cr.isMeldCard) {
          if (cr.meldGroupId != currentGroupId || currentMeldGroup == null) {
            currentMeldGroup = <CardRender>[];
            meldGroups.add(currentMeldGroup);
            currentGroupId = cr.meldGroupId;
          }
          currentMeldGroup.add(cr);
        } else {
          nonMeldCards.add(cr);
        }
      }

      for (final group in meldGroups) {
        for (int i = group.length - 1; i >= 0; i--) {
          _renderSmallCard(canvas, group[i]);
        }
      }
      for (final cr in nonMeldCards) {
        _renderSmallCard(canvas, cr);
      }
    }
  }

  void _renderSmallCard(Canvas canvas, CardRender cr) {
    final isMeld = cr.isMeldCard;
    final cardW = isMeld
        ? (showHuDisplay ? huDisplayCardW : meldCardW)
        : smallCardW;
    final cardH = isMeld
        ? (showHuDisplay ? huDisplayCardH : meldCardH)
        : smallCardH;

    final paint = Paint()
      ..color = Color.fromRGBO(255, 255, 255, cr.cardOpacity)
      ..filterQuality = FilterQuality.high;

    canvas.save();
    canvas.translate(cr.position.x, cr.position.y);

    final smallImg = _smallCardImages[cr.card!.character];
    if (smallImg != null) {
      final imgW = smallImg.width.toDouble();
      final imgH = smallImg.height.toDouble();
      final scaleX = cardW / imgW;
      final scaleY = cardH / imgH;
      final scale = scaleX < scaleY ? scaleX : scaleY;
      final drawW = imgW * scale;
      final drawH = imgH * scale;
      final offsetX = (cardW - drawW) / 2;
      final offsetY = (cardH - drawH) / 2;
      canvas.drawImageRect(
        smallImg,
        Rect.fromLTWH(0, 0, imgW, imgH),
        Rect.fromLTWH(offsetX, offsetY, drawW, drawH),
        paint,
      );
    } else {
      final pinyin = AtlasLoader.charToPinyin[cr.card!.character];
      final info = pinyin != null ? _atlasLoader!.getSprite('s/$pinyin') : null;
      if (info == null) {
        canvas.restore();
        return;
      }
      canvas.drawImageRect(
        _atlasImage!,
        Rect.fromLTWH(
          info.srcX.toDouble(),
          info.srcY.toDouble(),
          info.srcW.toDouble(),
          info.srcH.toDouble(),
        ),
        Rect.fromLTWH(0, 0, cardW, cardH),
        paint,
      );
    }

    if (cr.isLastDiscard) {
      final t = (cr.pulseTimer % 0.5) / 0.5;
      double shakeX;
      if (t < 0.15) {
        shakeX = -2.0 * (t / 0.15);
      } else if (t < 0.30) {
        shakeX = -2.0 + 4.0 * ((t - 0.15) / 0.15);
      } else if (t < 0.45) {
        shakeX = 2.0 - 3.0 * ((t - 0.30) / 0.15);
      } else if (t < 0.60) {
        shakeX = -1.0 + 2.0 * ((t - 0.45) / 0.15);
      } else {
        shakeX = 1.0 - 1.0 * ((t - 0.60) / 0.40);
      }
      canvas.translate(shakeX, 0);

      final borderPaint = Paint()
        ..color = const Color(0xFFFF9800)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, cardW, cardH),
          const Radius.circular(3),
        ),
        borderPaint,
      );
    }

    canvas.restore();
  }

  void _renderHandCards(Canvas canvas) {
    if (_atlasImage == null || _atlasLoader == null) return;

    List<CardRender> renderOrder = _player1Hand;

    if (showHuDisplay && huWinnerIndex == 1) {
      Card? huCard;
      if (huMethod == '点炮' && huDianpaoCard != null) {
        huCard = huDianpaoCard;
      } else if (huMethod == '自摸' && huZimoCard != null) {
        huCard = huZimoCard;
      }
      if (huCard != null) {
        final sorted = List<CardRender>.from(_player1Hand);
        sorted.sort((a, b) {
          if (a.card == null) return 1;
          if (b.card == null) return -1;
          if (a.card!.id == huCard!.id) return 1;
          if (b.card!.id == huCard.id) return -1;
          if (a.card!.sentence != b.card!.sentence) {
            return a.card!.sentence.compareTo(b.card!.sentence);
          }
          return a.card!.position.compareTo(b.card!.position);
        });
        renderOrder = sorted;
      }
    }

    for (final cr in renderOrder) {
      if (cr.card == null || cr.position.x < -1000) continue;
      if (_isDragging && _dragCard != null && cr.card!.id == _dragCard!.id) {
        continue;
      }

      final offsetX = cr.position.x;
      final offsetY = cr.position.y + (cr.isSelected ? -selectedOffsetY : 0);

      canvas.save();
      canvas.translate(offsetX, offsetY);

      if (cr.isNewDrawn) {
        cr.cardOpacity = 1.0;
      }

      final shadowPaint = Paint()
        ..color = const Color(0x66000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(3, 3, handCardW, handCardH),
          const Radius.circular(8),
        ),
        shadowPaint,
      );

      final cardRRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, handCardW, handCardH),
        const Radius.circular(6),
      );
      canvas.clipPath(Path()..addRRect(cardRRect));

      final paint = Paint()
        ..color = Color.fromRGBO(255, 255, 255, cr.cardOpacity)
        ..filterQuality = FilterQuality.high;

      final handImg = _handCardImages[cr.card!.character];
      if (handImg != null) {
        final imgW = handImg.width.toDouble();
        final imgH = handImg.height.toDouble();
        canvas.drawImageRect(
          handImg,
          Rect.fromLTWH(0, 0, imgW, imgH),
          Rect.fromLTWH(0, 0, handCardW, handCardH),
          paint,
        );
      } else {
        final info = _atlasLoader!.getSpriteByChar(cr.card!.character);
        if (info != null) {
          if (info.rotated) {
            canvas.rotate(-math.pi / 2);
            canvas.translate(-handCardH, 0);
            canvas.drawImageRect(
              _atlasImage!,
              Rect.fromLTWH(
                info.srcX.toDouble(),
                info.srcY.toDouble(),
                info.srcW.toDouble(),
                info.srcH.toDouble(),
              ),
              Rect.fromLTWH(0, 0, handCardH, handCardW),
              paint,
            );
          } else {
            canvas.drawImageRect(
              _atlasImage!,
              Rect.fromLTWH(
                info.srcX.toDouble(),
                info.srcY.toDouble(),
                info.srcW.toDouble(),
                info.srcH.toDouble(),
              ),
              Rect.fromLTWH(0, 0, handCardW, handCardH),
              paint,
            );
          }
        }
      }

      canvas.restore();

      if (showHuDisplay && huWinnerIndex == 1) {
        String? cardLabel;
        Card? matchCard;
        if (huMethod == '点炮' && huDianpaoCard != null) {
          cardLabel = '炮';
          matchCard = huDianpaoCard;
        } else if (huMethod == '自摸' && huZimoCard != null) {
          cardLabel = '自摸';
          matchCard = huZimoCard;
        }
        if (cardLabel != null &&
            matchCard != null &&
            cr.card!.id == matchCard.id) {
          _drawHuCardLabel(
            canvas,
            offsetX,
            offsetY,
            handCardW,
            handCardH,
            cardLabel,
          );
        }
      }
    }
  }

  void _renderAIHandCards(Canvas canvas) {
    if (_atlasImage == null || _atlasLoader == null) return;
    if (showHuDisplay) {
      _renderAIHand(
        canvas,
        _player0Hand,
        0,
        9.6,
        120.0 + avatarToMeldGap,
        leftMaxW,
        true,
      );
      _renderAIHand(
        canvas,
        _player2Hand,
        2,
        designWidth - 9.6,
        120.0 + avatarToMeldGap,
        rightMaxW,
        false,
      );
    } else {
      _renderPlayerAIHand(
        canvas,
        _player0Hand,
        9.6,
        120.0 + avatarToMeldGap,
        leftMaxW,
        true,
      );
      _renderPlayerAIHand(
        canvas,
        _player2Hand,
        designWidth - 9.6,
        120.0 + avatarToMeldGap,
        rightMaxW,
        false,
      );
    }
  }

  void _renderAIHand(
    Canvas canvas,
    List<CardRender> hand,
    int playerIndex,
    double edgeX,
    double startY,
    double maxWidth,
    bool leftToRight,
  ) {
    if (hand.isEmpty) return;

    final cards = hand.map((cr) => cr.card!).where((c) => c != null).toList();

    Card? highlightCard;
    String? highlightLabel;
    if (showHuDisplay && huWinnerIndex == playerIndex) {
      if (huMethod == '点炮' && huDianpaoCard != null) {
        cards.add(huDianpaoCard!);
        cards.sort((a, b) {
          if (a.sentence != b.sentence) return a.sentence.compareTo(b.sentence);
          return a.position.compareTo(b.position);
        });
        highlightCard = huDianpaoCard;
        highlightLabel = '炮';
      } else if (huMethod == '自摸' && huZimoCard != null) {
        highlightCard = huZimoCard;
        highlightLabel = '自摸';
      }
    }

    final cw = huAiHandCardW;
    final ch = huAiHandCardH;
    final sv = huAiHandStackVisible;
    final gap = huAiHandSentenceGap;

    final sentenceGroups = _groupHandBySentenceForAI(cards);

    if (leftToRight) {
      double curX = edgeX;
      for (final sg in sentenceGroups) {
        double curY = startY;
        for (int i = 0; i < sg.length; i++) {
          final stack = sg[i];
          final cardX = curX;
          Card drawCard = stack[0];
          if (highlightCard != null) {
            for (final c in stack) {
              if (c.id == highlightCard.id) {
                drawCard = c;
                break;
              }
            }
          }
          _drawHuAIHandCard(canvas, cardX, curY, drawCard, cw, ch);
          if (highlightCard != null && drawCard.id == highlightCard.id) {
            _drawHuCardLabel(canvas, cardX, curY, cw, ch, highlightLabel!);
          }
          if (stack.length > 1) {
            _drawHuAIHandOverlay(canvas, cardX, curY, stack.length, cw, ch);
          }
          if (i < sg.length - 1) {
            curY += sv;
          }
        }
        curX += cw + gap;
      }
    } else {
      double curX = edgeX;
      for (final sg in sentenceGroups) {
        double curY = startY;
        for (int i = 0; i < sg.length; i++) {
          final stack = sg[i];
          final cardX = curX - cw;
          Card drawCard = stack[0];
          if (highlightCard != null) {
            for (final c in stack) {
              if (c.id == highlightCard.id) {
                drawCard = c;
                break;
              }
            }
          }
          _drawHuAIHandCard(canvas, cardX, curY, drawCard, cw, ch);
          if (highlightCard != null && drawCard.id == highlightCard.id) {
            _drawHuCardLabel(canvas, cardX, curY, cw, ch, highlightLabel!);
          }
          if (stack.length > 1) {
            _drawHuAIHandOverlay(canvas, cardX, curY, stack.length, cw, ch);
          }
          if (i < sg.length - 1) {
            curY += sv;
          }
        }
        curX -= cw + gap;
      }
    }
  }

  void _drawHuAIHandOverlay(
    Canvas canvas,
    double x,
    double y,
    int count,
    double cw,
    double ch,
  ) {
    canvas.save();
    canvas.translate(x, y);

    final badgeR = cw * 0.35;
    final badgeCx = cw - badgeR;
    final badgeCy = badgeR;

    canvas.drawCircle(
      Offset(badgeCx, badgeCy),
      badgeR,
      Paint()..color = const Color(0xFFFF4444),
    );

    final text = '$count';
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: const Color(0xFFFFFFFF),
          fontSize: badgeR * 0.9,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(canvas, Offset(badgeCx - tp.width / 2, badgeCy - tp.height / 2));

    canvas.restore();
  }

  List<List<List<Card>>> _groupHandBySentenceForAI(List<Card> cards) {
    final sentenceGroups = <List<Card>>[];
    for (int s = 1; s <= 8; s++) {
      final sg = cards.where((c) => c.sentence == s).toList();
      if (sg.isEmpty) continue;
      sg.sort((a, b) {
        if (a.position != b.position) return a.position.compareTo(b.position);
        return a.id.compareTo(b.id);
      });
      sentenceGroups.add(sg);
    }
    final result = <List<List<Card>>>[];
    for (final sg in sentenceGroups) {
      final charGroups = <List<Card>>[];
      String? currentChar;
      List<Card>? currentGroup;
      for (final c in sg) {
        if (c.character != currentChar) {
          if (currentGroup != null && currentGroup.isNotEmpty) {
            charGroups.add(currentGroup);
          }
          currentChar = c.character;
          currentGroup = [c];
        } else {
          currentGroup!.add(c);
        }
      }
      if (currentGroup != null && currentGroup.isNotEmpty) {
        charGroups.add(currentGroup);
      }
      if (charGroups.isNotEmpty) {
        result.add(charGroups);
      }
    }
    return result;
  }

  void _drawHuAIHandCard(
    Canvas canvas,
    double x,
    double y,
    Card card,
    double cw,
    double ch,
  ) {
    canvas.save();
    canvas.translate(x, y);

    final paint = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..filterQuality = FilterQuality.high;

    final handImg = _handCardImages[card.character];
    if (handImg != null) {
      final imgW = handImg.width.toDouble();
      final imgH = handImg.height.toDouble();
      canvas.drawImageRect(
        handImg,
        Rect.fromLTWH(0, 0, imgW, imgH),
        Rect.fromLTWH(0, 0, cw, ch),
        paint,
      );
    } else {
      final info = _atlasLoader!.getSpriteByChar(card.character);
      if (info != null) {
        if (info.rotated) {
          canvas.rotate(-math.pi / 2);
          canvas.translate(-ch, 0);
          canvas.drawImageRect(
            _atlasImage!,
            Rect.fromLTWH(
              info.srcX.toDouble(),
              info.srcY.toDouble(),
              info.srcW.toDouble(),
              info.srcH.toDouble(),
            ),
            Rect.fromLTWH(0, 0, ch, cw),
            paint,
          );
        } else {
          canvas.drawImageRect(
            _atlasImage!,
            Rect.fromLTWH(
              info.srcX.toDouble(),
              info.srcY.toDouble(),
              info.srcW.toDouble(),
              info.srcH.toDouble(),
            ),
            Rect.fromLTWH(0, 0, cw, ch),
            paint,
          );
        }
      }
    }

    final borderRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, cw, ch),
      const Radius.circular(3),
    );
    canvas.drawRRect(
      borderRRect,
      Paint()
        ..color = const Color(0x40000000)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    canvas.restore();
  }

  void _drawHuDisplayCard(Canvas canvas, double x, double y, Card card) {
    canvas.save();
    canvas.translate(x, y);

    final cw = huDisplayCardW;
    final ch = huDisplayCardH;

    final paint = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..filterQuality = FilterQuality.high;

    final smallImg = _smallCardImages[card.character];
    if (smallImg != null) {
      final imgW = smallImg.width.toDouble();
      final imgH = smallImg.height.toDouble();
      final scaleX = cw / imgW;
      final scaleY = ch / imgH;
      final scale = scaleX < scaleY ? scaleX : scaleY;
      final drawW = imgW * scale;
      final drawH = imgH * scale;
      final offsetX = (cw - drawW) / 2;
      final offsetY = (ch - drawH) / 2;
      canvas.drawImageRect(
        smallImg,
        Rect.fromLTWH(0, 0, imgW, imgH),
        Rect.fromLTWH(offsetX, offsetY, drawW, drawH),
        paint,
      );
    } else {
      final pinyin = AtlasLoader.charToPinyin[card.character];
      final info = pinyin != null ? _atlasLoader!.getSprite('s/$pinyin') : null;
      if (info != null && _atlasImage != null) {
        canvas.drawImageRect(
          _atlasImage!,
          Rect.fromLTWH(
            info.srcX.toDouble(),
            info.srcY.toDouble(),
            info.srcW.toDouble(),
            info.srcH.toDouble(),
          ),
          Rect.fromLTWH(0, 0, cw, ch),
          paint,
        );
      }
    }

    final borderRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, cw, ch),
      const Radius.circular(3),
    );
    canvas.drawRRect(
      borderRRect,
      Paint()
        ..color = const Color(0x40000000)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    canvas.restore();
  }

  void _drawHuCardLabel(
    Canvas canvas,
    double x,
    double y,
    double cw,
    double ch,
    String label,
  ) {
    canvas.save();

    final fontSize = 16.0;
    final labelColor = const Color(0xFFFFFFFF);

    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: labelColor,
          shadows: const [
            Shadow(color: Color(0xFFFF0000), blurRadius: 10),
            Shadow(color: Color(0xFFFF0000), blurRadius: 20),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(
      canvas,
      Offset(x + cw / 2 - tp.width / 2, y + ch / 2 - tp.height / 2),
    );
    canvas.restore();
  }

  void _renderPlayerAIHand(
    Canvas canvas,
    List<CardRender> hand,
    double edgeX,
    double startY,
    double maxWidth,
    bool leftToRight,
  ) {
    if (hand.isEmpty) return;

    final totalWidth = (hand.length - 1) * aiHandStackVisible + meldCardW;

    if (leftToRight) {
      if (totalWidth <= maxWidth) {
        for (int i = 0; i < hand.length; i++) {
          _drawAICardBack(canvas, edgeX + i * aiHandStackVisible, startY);
        }
      } else {
        final step = (maxWidth - meldCardW) / (hand.length - 1);
        for (int i = 0; i < hand.length; i++) {
          _drawAICardBack(canvas, edgeX + i * step, startY);
        }
      }
    } else {
      if (totalWidth <= maxWidth) {
        for (int i = 0; i < hand.length; i++) {
          _drawAICardBack(
            canvas,
            edgeX - meldCardW - i * aiHandStackVisible,
            startY,
          );
        }
      } else {
        final step = (maxWidth - meldCardW) / (hand.length - 1);
        for (int i = 0; i < hand.length; i++) {
          _drawAICardBack(canvas, edgeX - meldCardW - i * step, startY);
        }
      }
    }
  }

  void _drawAICardBack(Canvas canvas, double x, double y) {
    canvas.save();
    canvas.translate(x, y);

    final shadowRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(1, 2, meldCardW, meldCardH),
      const Radius.circular(3),
    );
    canvas.drawRRect(shadowRRect, Paint()..color = const Color(0x40000000));

    final backInfo = _atlasLoader?.getSprite('back');
    if (backInfo != null && _atlasImage != null) {
      final paint = Paint()..filterQuality = FilterQuality.high;
      canvas.drawImageRect(
        _atlasImage!,
        Rect.fromLTWH(
          backInfo.srcX.toDouble(),
          backInfo.srcY.toDouble(),
          backInfo.srcW.toDouble(),
          backInfo.srcH.toDouble(),
        ),
        Rect.fromLTWH(0, 0, meldCardW, meldCardH),
        paint,
      );
    } else {
      final rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, meldCardW, meldCardH),
        const Radius.circular(3),
      );
      canvas.drawRRect(rrect, Paint()..color = const Color(0xFF1B5E20));
      final innerRRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(2, 2, meldCardW - 4, meldCardH - 4),
        const Radius.circular(2),
      );
      canvas.drawRRect(innerRRect, Paint()..color = const Color(0xFF2E7D32));
    }

    final borderRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, meldCardW, meldCardH),
      const Radius.circular(3),
    );
    canvas.drawRRect(
      borderRRect,
      Paint()
        ..color = const Color(0x99000000)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    canvas.restore();
  }

  void _renderOverlays(Canvas canvas) {
    _renderHandOverlays(canvas);
    _renderSmallOverlays(canvas);
  }

  void _renderHandOverlays(Canvas canvas) {
    final sentenceGroups = _groupHandBySentence(_player1Hand);

    for (final sg in sentenceGroups) {
      final stacks = _groupStackByChar(sg);
      for (final stack in stacks) {
        if (stack.isEmpty || stack[0].position.x < -1000) continue;

        final cr = stack[0];
        final offsetX = cr.position.x;
        final offsetY = cr.position.y + (cr.isSelected ? -selectedOffsetY : 0);

        canvas.save();
        canvas.translate(offsetX, offsetY);

        if (cr.showTingBadge && stack.length <= 1) {
          canvas.drawCircle(
            Offset(handCardW - 8, 8),
            6,
            Paint()..color = const Color(0xFFFF4444),
          );
        }

        if (stack.length > 1) {
          final badgeR = 18.0;
          final badgeCx = handCardW - badgeR;
          final badgeCy = badgeR + 2;

          canvas.drawCircle(
            Offset(badgeCx, badgeCy),
            badgeR,
            Paint()..color = const Color(0xFFFF4444),
          );

          bool isAnimating = false;
          double animProgress = 1.0;
          int oldCount = 0;
          if (badgeAnimCardId != null) {
            for (final s in stack) {
              if (s.card?.id == badgeAnimCardId) {
                isAnimating = badgeAnimTimer < badgeAnimDuration;
                animProgress = (badgeAnimTimer / badgeAnimDuration).clamp(
                  0.0,
                  1.0,
                );
                oldCount = badgeOldCount;
                break;
              }
            }
          }

          if (isAnimating) {
            canvas.save();
            canvas.clipRect(
              Rect.fromCircle(
                center: Offset(badgeCx, badgeCy),
                radius: badgeR - 1,
              ),
            );

            final oldText = '$oldCount';
            final oldTp = TextPainter(
              text: TextSpan(
                text: oldText,
                style: TextStyle(
                  color: const Color(0xFFFFFFFF),
                  fontSize: oldText.length > 1 ? 20.0 : 28.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
              textDirection: TextDirection.ltr,
            );
            oldTp.layout();
            final oldOpacity = 1.0 - animProgress;
            final oldSlideY = -badgeR * 2 * animProgress;
            oldTp.paint(
              canvas,
              Offset(
                badgeCx - oldTp.width / 2,
                badgeCy - oldTp.height / 2 + oldSlideY,
              ),
            );

            final newText = '${stack.length}';
            final newTp = TextPainter(
              text: TextSpan(
                text: newText,
                style: TextStyle(
                  color: const Color(0xFFFFFFFF),
                  fontSize: newText.length > 1 ? 20.0 : 28.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
              textDirection: TextDirection.ltr,
            );
            newTp.layout();
            final newSlideY = badgeR * 2 * (1.0 - animProgress);
            newTp.paint(
              canvas,
              Offset(
                badgeCx - newTp.width / 2,
                badgeCy - newTp.height / 2 + newSlideY,
              ),
            );

            canvas.restore();
          } else {
            final text = '${stack.length}';
            final tp = TextPainter(
              text: TextSpan(
                text: text,
                style: TextStyle(
                  color: const Color(0xFFFFFFFF),
                  fontSize: text.length > 1 ? 20.0 : 28.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
              textDirection: TextDirection.ltr,
            );
            tp.layout();
            tp.paint(
              canvas,
              Offset(badgeCx - tp.width / 2, badgeCy - tp.height / 2),
            );
          }
        }

        CardRender? newBadgeCr;
        for (final s in stack) {
          if (s.showNewBadge) {
            newBadgeCr = s;
            break;
          }
        }
        if (newBadgeCr != null) {
          final badgeR = 10.0;
          final badgeCx = badgeR + 2;
          final badgeCy = badgeR + 2;
          final pulseT = (newBadgeCr.newBadgeTimer % 1.5) / 1.5;
          final pulseScale = 1.0 + 0.1 * math.sin(pulseT * math.pi);
          final pulseBlur = 3.0 + 5.0 * math.sin(pulseT * math.pi);

          canvas.save();
          canvas.translate(badgeCx, badgeCy);
          canvas.scale(pulseScale, pulseScale);

          canvas.drawCircle(
            Offset.zero,
            badgeR,
            Paint()
              ..color = const Color(0xFFFF4444)
              ..maskFilter = MaskFilter.blur(BlurStyle.normal, pulseBlur),
          );
          canvas.drawCircle(
            Offset.zero,
            badgeR,
            Paint()..color = const Color(0xFFFF4444),
          );

          final tp = TextPainter(
            text: const TextSpan(
              text: '新',
              style: TextStyle(
                color: Color(0xFF333333),
                fontSize: 11.0,
                fontWeight: FontWeight.bold,
              ),
            ),
            textDirection: TextDirection.ltr,
          );
          tp.layout();
          tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));

          canvas.restore();
        }

        canvas.restore();
      }
    }
  }

  void _renderSmallOverlays(Canvas canvas) {}

  static List<TextSpan> _buildTagSpans(
    String text,
    Color color,
    double fontSize,
    double numFontSize,
  ) {
    final numRegExp = RegExp(r'(\d+)');
    final spans = <TextSpan>[];
    int lastEnd = 0;
    for (final match in numRegExp.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(
          TextSpan(
            text: text.substring(lastEnd, match.start),
            style: TextStyle(
              fontSize: fontSize,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      }
      spans.add(
        TextSpan(
          text: match.group(0),
          style: TextStyle(
            fontSize: numFontSize,
            color: color,
            fontWeight: FontWeight.w900,
          ),
        ),
      );
      lastEnd = match.end;
    }
    if (lastEnd < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(lastEnd),
          style: TextStyle(
            fontSize: fontSize,
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }
    if (spans.isEmpty) {
      spans.add(
        TextSpan(
          text: text,
          style: TextStyle(
            fontSize: fontSize,
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }
    return spans;
  }

  static Color _getHuTypeColor(String huTypeName) {
    switch (huTypeName) {
      case '清枯重台卡':
      case '清枯重台胡':
        return const Color(0xFFff2d2d);
      case '枯重台卡':
      case '枯重台胡':
      case '清枯台胡':
      case '清枯台卡':
        return const Color(0xFFe040fb);
      case '十对':
        return const Color(0xFFff9800);
      case '枯台胡':
      case '清枯胡':
      case '枯胡':
      case '重台卡':
      case '重台胡':
        return const Color(0xFFff6b6b);
      case '红元精':
      case '红元2精':
      case '红元3精':
      case '红元4精':
      case '黑元':
        return const Color(0xFFab47bc);
      case '清卡胡':
      case '清胡':
      case '卡胡':
        return const Color(0xFF4ecdc4);
      case '台卡':
      case '台胡':
        return const Color(0xFF42a5f5);
      default:
        return const Color(0xFF4ecdc4);
    }
  }

  static List<List<Card>> _groupHandForHuDisplay(List<Card> hand) {
    if (hand.isEmpty) return [];

    final remaining = List<Card>.from(hand);
    final aSet = <Meld>[];
    final bSet = <Meld>[];
    final cSet = <Meld>[];
    final dSet = <Meld>[];

    HuCalculator.extractJu(remaining, aSet);
    HuCalculator.extractZhao(remaining, bSet);
    HuCalculator.extractKan(remaining, cSet);
    HuCalculator.extractDuiAndKao(remaining, dSet);

    final groups = <List<Card>>[];

    for (final m in aSet) {
      groups.add(List<Card>.from(m.cards));
    }
    for (final m in bSet) {
      groups.add(List<Card>.from(m.cards));
    }
    for (final m in cSet) {
      groups.add(List<Card>.from(m.cards));
    }
    for (final m in dSet) {
      groups.add(List<Card>.from(m.cards));
    }
    for (final c in remaining) {
      groups.add([c]);
    }

    return groups;
  }

  void _renderHuResult(Canvas canvas) {
    final cx = designWidth / 2;

    final handArea = getPlayer1HandArea();
    final panelBottomY = handArea.top - 10;
    final panelW = 540.0;
    final panelH = 260.0;
    final panelX = (designWidth - panelW) / 2;
    final panelY = panelBottomY - panelH;

    canvas.save();
    canvas.drawRect(
      Rect.fromLTWH(0, 0, designWidth, designHeight),
      Paint()..color = const Color(0x88000000),
    );

    if (!showHuResult && showHuDisplay) {
      final liujuW = 260.0;
      final liujuH = 100.0;
      final liujuY = panelBottomY - liujuH;
      final liujuR = RRect.fromRectAndRadius(
        Rect.fromLTWH(panelX + (panelW - liujuW) / 2, liujuY, liujuW, liujuH),
        const Radius.circular(16),
      );
      canvas.drawRRect(liujuR, Paint()..color = const Color(0xE61a472a));
      canvas.drawRRect(
        liujuR,
        Paint()
          ..color = const Color(0xFFffd700)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            panelX + (panelW - liujuW) / 2 - 3,
            liujuY - 3,
            liujuW + 6,
            liujuH + 6,
          ),
          const Radius.circular(19),
        ),
        Paint()
          ..color = const Color(0x33ffd700)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
      );
      final tp = TextPainter(
        text: TextSpan(
          text: '流局',
          style: TextStyle(
            fontSize: 36,
            color: const Color(0xFFff9800),
            fontWeight: FontWeight.bold,
            shadows: [Shadow(color: const Color(0x80ff9800), blurRadius: 10)],
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(
        canvas,
        Offset(cx - tp.width / 2, liujuY + liujuH / 2 - tp.height / 2),
      );
      canvas.restore();
      return;
    }

    final panelRect = Rect.fromLTWH(panelX, panelY, panelW, panelH);
    final panelR = RRect.fromRectAndRadius(
      panelRect,
      const Radius.circular(16),
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(panelRect.inflate(8), const Radius.circular(22)),
      Paint()
        ..color = const Color(0x33ffd700)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20),
    );

    canvas.drawRRect(
      panelR,
      Paint()
        ..shader = LinearGradient(
          colors: [const Color(0xF01a472a), const Color(0xF80d2818)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(panelRect),
    );

    canvas.drawRRect(
      panelR,
      Paint()
        ..color = const Color(0xFFffd700)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    final closeBtnSize = 44.0;
    final closeBtnX = panelX + panelW - closeBtnSize - 8;
    final closeBtnY = panelY + 8;
    _huPanelRect = Rect.fromLTWH(panelX, panelY, panelW, panelH);
    _huPanelCloseBtnRect = Rect.fromLTWH(
      closeBtnX,
      closeBtnY,
      closeBtnSize,
      closeBtnSize,
    );
    final closeBtnR = RRect.fromRectAndRadius(
      Rect.fromLTWH(closeBtnX, closeBtnY, closeBtnSize, closeBtnSize),
      Radius.circular(closeBtnSize / 2),
    );
    canvas.drawRRect(
      closeBtnR.inflate(3),
      Paint()
        ..color = const Color(0x40000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawRRect(closeBtnR, Paint()..color = const Color(0xCCcc0000));
    final closeTp = TextPainter(
      text: const TextSpan(
        text: '✕',
        style: TextStyle(
          fontSize: 22,
          color: Color(0xFFFFFFFF),
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    closeTp.layout();
    closeTp.paint(
      canvas,
      Offset(
        closeBtnX + (closeBtnSize - closeTp.width) / 2,
        closeBtnY + (closeBtnSize - closeTp.height) / 2,
      ),
    );

    final titleY = panelY + 32;
    final titleText = '$huWinnerName 胡牌!';
    final titleTp = TextPainter(
      text: TextSpan(
        text: titleText,
        style: TextStyle(
          fontSize: 24,
          color: const Color(0xFFffd700),
          fontWeight: FontWeight.bold,
          shadows: [Shadow(color: const Color(0x80ffd700), blurRadius: 15)],
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    titleTp.layout();
    titleTp.paint(
      canvas,
      Offset(cx - titleTp.width / 2, titleY - titleTp.height / 2),
    );

    final tagsY = panelY + 72;
    final tagFontSize = 14.0;
    final tagNumFontSize = 17.0;
    const tagPadH = 10.0;
    const tagPadV = 4.0;
    const tagRadius = 10.0;

    final tags = <MapEntry<String, Color>>[];
    if (huMethod == '点炮' && huDianpaoName.isNotEmpty) {
      tags.add(MapEntry('点炮', const Color(0xFFFFFFFF)));
    } else if (huMethod == '自摸') {
      tags.add(MapEntry('自摸', const Color(0xFFFFFFFF)));
    }
    tags.add(MapEntry(huType, _getHuTypeColor(huType)));
    tags.add(MapEntry('胡数:$huCount', const Color(0xFFffd700)));
    tags.add(MapEntry('$huMultiplier倍', const Color(0xFFff6b6b)));

    final tagBgColors = <Color>[
      const Color(0x26FFFFFF),
      _getHuTypeColor(huType).withValues(alpha: 0.2),
      const Color(0x33ffd700),
      const Color(0x33ff6b6b),
    ];

    final tagWidths = <double>[];
    double totalTagW = 0;
    for (int i = 0; i < tags.length; i++) {
      final spans = _buildTagSpans(
        tags[i].key,
        tags[i].value,
        tagFontSize,
        tagNumFontSize,
      );
      final tp = TextPainter(
        text: TextSpan(children: spans),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      final w = tp.width + tagPadH * 2;
      tagWidths.add(w);
      totalTagW += w;
    }
    totalTagW += (tags.length - 1) * 8;

    var tagX = cx - totalTagW / 2;
    for (int i = 0; i < tags.length; i++) {
      final tw = tagWidths[i];
      final tagH = tagNumFontSize + tagPadV * 2;
      final tagR = RRect.fromRectAndRadius(
        Rect.fromLTWH(tagX, tagsY - tagH / 2, tw, tagH),
        const Radius.circular(tagRadius),
      );
      canvas.drawRRect(tagR, Paint()..color = tagBgColors[i]);
      canvas.drawRRect(
        tagR,
        Paint()
          ..color = tags[i].value.withValues(alpha: 0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
      final spans = _buildTagSpans(
        tags[i].key,
        tags[i].value,
        tagFontSize,
        tagNumFontSize,
      );
      final tp = TextPainter(
        text: TextSpan(children: spans),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(
        canvas,
        Offset(tagX + (tw - tp.width) / 2, tagsY - tp.height / 2),
      );
      tagX += tw + 8;
    }

    final scoreY = panelY + 128;
    final scoreText = '+$huScore';
    final scorePaint = Paint()
      ..shader = LinearGradient(
        colors: [const Color(0xFFffd700), const Color(0xFFff8c00)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, 200, 60));
    final scoreTp = TextPainter(
      text: TextSpan(
        text: scoreText,
        style: TextStyle(
          fontSize: 60,
          fontWeight: FontWeight.w900,
          foreground: scorePaint,
          shadows: [Shadow(color: const Color(0x80ffd700), blurRadius: 24)],
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    scoreTp.layout();
    final unitTp = TextPainter(
      text: const TextSpan(
        text: '分',
        style: TextStyle(
          fontSize: 20,
          color: Color(0xB3ffd700),
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    unitTp.layout();
    final totalScoreW = scoreTp.width + 4 + unitTp.width;
    final scoreOffsetX = cx - totalScoreW / 2;
    final scoreOffsetY = scoreY - scoreTp.height / 2;
    scoreTp.paint(canvas, Offset(scoreOffsetX, scoreOffsetY));
    unitTp.paint(
      canvas,
      Offset(scoreOffsetX + scoreTp.width + 4, scoreY - unitTp.height / 2 + 14),
    );

    final losersY = panelY + 196;
    final loserFontSize = 13.0;
    final loserScoreFontSize = 24.0;
    final loserPadH = 16.0;
    final loserPadV = 8.0;
    final loserGap = 16.0;

    final losers = <MapEntry<String, int>>[];
    if (huMethod == '点炮' && huDianpaoName.isNotEmpty) {
      losers.add(MapEntry(huDianpaoName, -huScore));
    } else if (huMethod == '自摸') {
      for (int i = 0; i < _playerNames.length; i++) {
        if (i == huWinnerIndex) continue;
        final s = huScoreChanges[i];
        if (s != null && s < 0) {
          losers.add(MapEntry(_playerNames[i], s));
        }
      }
    }

    if (losers.isNotEmpty) {
      final loserWidths = <double>[];
      double totalLoserW = 0;
      for (final loser in losers) {
        final nameTp = TextPainter(
          text: TextSpan(
            text: loser.key,
            style: TextStyle(
              fontSize: loserFontSize,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        nameTp.layout();
        final scoreTp2 = TextPainter(
          text: TextSpan(
            text: '${loser.value}',
            style: TextStyle(
              fontSize: loserScoreFontSize,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        scoreTp2.layout();
        final w =
            (nameTp.width > scoreTp2.width ? nameTp.width : scoreTp2.width) +
            loserPadH * 2;
        loserWidths.add(w);
        totalLoserW += w;
      }
      totalLoserW += (losers.length - 1) * loserGap;

      var loserX = cx - totalLoserW / 2;
      for (int i = 0; i < losers.length; i++) {
        final lw = loserWidths[i];
        final loserH = loserFontSize + loserScoreFontSize + loserPadV * 3;
        final loserR = RRect.fromRectAndRadius(
          Rect.fromLTWH(loserX, losersY - loserH / 2, lw, loserH),
          const Radius.circular(8),
        );
        canvas.drawRRect(loserR, Paint()..color = const Color(0x1Aff6b6b));
        canvas.drawRRect(
          loserR,
          Paint()
            ..color = const Color(0x33ff6b6b)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );

        final nameTp = TextPainter(
          text: TextSpan(
            text: losers[i].key,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFFaaaaaa),
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        nameTp.layout();
        nameTp.paint(
          canvas,
          Offset(
            loserX + (lw - nameTp.width) / 2,
            losersY - loserH / 2 + loserPadV,
          ),
        );

        final scoreTp2 = TextPainter(
          text: TextSpan(
            text: '${losers[i].value}',
            style: const TextStyle(
              fontSize: 24,
              color: Color(0xFFff6b6b),
              fontWeight: FontWeight.w900,
              shadows: [Shadow(color: Color(0x66ff6b6b), blurRadius: 6)],
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        scoreTp2.layout();
        scoreTp2.paint(
          canvas,
          Offset(
            loserX + (lw - scoreTp2.width) / 2,
            losersY - loserH / 2 + loserPadV + nameTp.height + 2,
          ),
        );

        loserX += lw + loserGap;
      }
    }

    canvas.restore();

    _renderHuBadges(canvas);
  }

  double _drawHuText(
    Canvas canvas,
    String text,
    double x,
    double y,
    double fontSize,
    Color color,
  ) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    canvas.save();
    tp.paint(canvas, Offset(x, y - tp.height / 2));
    canvas.restore();
    return x + tp.width + 8;
  }

  double _drawHuBadge(
    Canvas canvas,
    String text,
    double x,
    double y,
    Color color, {
    double fontSize = 16,
    double padH = 10,
    double padV = 5,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          color: const Color(0xFFFFFFFF),
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    tp.layout();

    final badgeW = tp.width + padH * 2;
    final badgeH = tp.height + padV * 2;
    final badgeR = RRect.fromRectAndRadius(
      Rect.fromLTWH(x, y - badgeH / 2, badgeW, badgeH),
      Radius.circular(padH),
    );
    canvas.drawRRect(badgeR, Paint()..color = color.withValues(alpha: 0.3));
    canvas.drawRRect(
      badgeR,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    canvas.save();
    tp.paint(canvas, Offset(x + padH, y - tp.height / 2));
    canvas.restore();
    return x + badgeW + 6;
  }

  void _renderHuWinningCard(Canvas canvas) {
    if (lastPlayedCard == null || huWinnerIndex < 0) return;

    final card = lastPlayedCard!;
    final cw = huDisplayCardW;
    final ch = huDisplayCardH;
    double px, py;

    if (huWinnerIndex == 1) {
      final handArea = getPlayer1HandArea();
      px = handArea.left + (handArea.width - cw) / 2;
      py = handArea.top - ch - 4;
    } else if (huWinnerIndex == 0) {
      final handY = 120.0 + avatarToMeldGap;
      px = 9.6;
      py = handY - ch - 4;
    } else {
      final handY = 120.0 + avatarToMeldGap;
      px = designWidth - 9.6 - cw;
      py = handY - ch - 4;
    }

    canvas.save();
    canvas.translate(px, py);

    final paint = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..filterQuality = FilterQuality.high;

    final smallImg = _smallCardImages[card.character];
    if (smallImg != null) {
      final imgW = smallImg.width.toDouble();
      final imgH = smallImg.height.toDouble();
      final scaleX = cw / imgW;
      final scaleY = ch / imgH;
      final scale = scaleX < scaleY ? scaleX : scaleY;
      final drawW = imgW * scale;
      final drawH = imgH * scale;
      final offsetX = (cw - drawW) / 2;
      final offsetY = (ch - drawH) / 2;
      canvas.drawImageRect(
        smallImg,
        Rect.fromLTWH(0, 0, imgW, imgH),
        Rect.fromLTWH(offsetX, offsetY, drawW, drawH),
        paint,
      );
    } else {
      final pinyin = AtlasLoader.charToPinyin[card.character];
      final info = pinyin != null ? _atlasLoader!.getSprite('s/$pinyin') : null;
      if (info != null && _atlasImage != null) {
        canvas.drawImageRect(
          _atlasImage!,
          Rect.fromLTWH(
            info.srcX.toDouble(),
            info.srcY.toDouble(),
            info.srcW.toDouble(),
            info.srcH.toDouble(),
          ),
          Rect.fromLTWH(0, 0, cw, ch),
          paint,
        );
      }
    }

    final borderRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, cw, ch),
      const Radius.circular(3),
    );
    canvas.drawRRect(
      borderRRect,
      Paint()
        ..color = const Color(0x40000000)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    final label = '炮';
    final labelColor = const Color(0xFFff6b6b);
    final bgPaint = Paint()..color = const Color(0xCC000000);
    final bgW = cw * 0.7;
    final bgH = ch * 0.5;
    final bgX = (cw - bgW) / 2;
    final bgY = (ch - bgH) / 2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(bgX, bgY, bgW, bgH),
        const Radius.circular(4),
      ),
      bgPaint,
    );
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          fontSize: 20.0,
          fontWeight: FontWeight.bold,
          color: labelColor,
          shadows: [Shadow(color: const Color(0xFF000000), blurRadius: 4)],
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(canvas, Offset(cw / 2 - tp.width / 2, ch / 2 - tp.height / 2));

    canvas.restore();
  }

  void _renderHuBadges(Canvas canvas) {
    if (huWinnerIndex < 0) return;

    final winnerBadges = <MapEntry<String, bool>>[];
    final primaryBadge = huMethod == '自摸' ? '自摸' : null;
    if (primaryBadge != null) {
      winnerBadges.add(MapEntry(primaryBadge, true));
    }
    winnerBadges.add(MapEntry(huType, false));
    _renderPlayerHuBadges(canvas, huWinnerIndex, winnerBadges);

    if (huMethod == '点炮' && huDianpaoIndex >= 0) {
      _renderPlayerHuBadges(canvas, huDianpaoIndex, [MapEntry('点炮', true)]);
    }
  }

  void _renderPlayerHuBadges(
    Canvas canvas,
    int playerIndex,
    List<MapEntry<String, bool>> badges,
  ) {
    if (badges.isEmpty) return;

    final badgeGap = 4.0;
    final padH = 10.0;
    final padV = 6.0;
    final fontSize = 18.0;
    final badgeH = fontSize + padV * 2;

    final badgeSizes = <double>[];
    double totalW = 0;
    for (final entry in badges) {
      final tp = TextPainter(
        text: TextSpan(
          text: entry.key,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            color: const Color(0xFFFFFFFF),
            letterSpacing: 1,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      final w = tp.width + padH * 2;
      badgeSizes.add(w);
      totalW += w;
    }
    totalW += (badges.length - 1) * badgeGap;

    double startX;
    double startY;
    const double aiAvatarLeft = 9.6;
    const double aiAvatarTop = 4.8;
    const double aiAvatarH = 108.0;
    const double myAvatarLeft = 10.0;
    const double myAvatarBottom = 5.0;
    const double avatarW = 250.0;
    const double badgeGapFromAvatar = 10.0;
    if (playerIndex == 0) {
      startX = aiAvatarLeft + avatarW + badgeGapFromAvatar;
      startY = aiAvatarTop + aiAvatarH - badgeH;
    } else if (playerIndex == 1) {
      startX = myAvatarLeft + avatarW + badgeGapFromAvatar;
      startY = designHeight - myAvatarBottom - aiAvatarH;
    } else {
      startX =
          designWidth - aiAvatarLeft - avatarW - totalW - badgeGapFromAvatar;
      startY = aiAvatarTop + aiAvatarH - badgeH;
    }

    double curX = startX;
    for (int i = 0; i < badges.length; i++) {
      final entry = badges[i];
      final text = entry.key;
      final isPrimary = entry.value;
      final bw = badgeSizes[i];

      List<Color> bgColors;
      Color borderColor;
      Color innerBorderColor;
      Color textColor;
      Color shadowColor;
      Color? glowColor;

      if (isPrimary && text == '自摸') {
        bgColors = const [Color(0xFF6a1b9a), Color(0xFF9c27b0)];
        borderColor = const Color(0xFFffd700);
        innerBorderColor = const Color(0xFFce93d8);
        textColor = const Color(0xFFFFFFFF);
        shadowColor = const Color(0xFF6a1b9a);
        glowColor = const Color(0xFFce93d8);
      } else if (isPrimary && text == '点炮') {
        bgColors = const [Color(0xFFe65100), Color(0xFFff8f00)];
        borderColor = const Color(0xFFffd700);
        innerBorderColor = const Color(0xFFffcc80);
        textColor = const Color(0xFFFFFFFF);
        shadowColor = const Color(0xFFe65100);
        glowColor = const Color(0xFFffb74d);
      } else {
        bgColors = const [Color(0xFFc62828), Color(0xFFef5350)];
        borderColor = const Color(0xFFffd700);
        innerBorderColor = const Color(0xFFFF8A80);
        textColor = const Color(0xFFFFFFFF);
        shadowColor = const Color(0xFFc62828);
        glowColor = const Color(0xFFff6b6b);
      }

      final badgeRect = Rect.fromLTWH(curX, startY, bw, badgeH);
      final badgeR = RRect.fromRectAndRadius(
        badgeRect,
        const Radius.circular(10),
      );

      canvas.drawRRect(
        badgeR,
        Paint()
          ..color = shadowColor.withValues(alpha: 0.5)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );

      canvas.drawRRect(
        badgeR,
        Paint()
          ..shader = LinearGradient(
            colors: bgColors,
            begin: Alignment(-0.6, -0.6),
            end: Alignment(0.6, 0.6),
          ).createShader(badgeRect),
      );

      canvas.drawRRect(
        badgeR,
        Paint()
          ..color = borderColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );

      final innerR = RRect.fromRectAndRadius(
        badgeRect.inflate(-3),
        const Radius.circular(7),
      );
      canvas.drawRRect(
        innerR,
        Paint()
          ..color = innerBorderColor.withValues(alpha: 0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          badgeRect.inflate(3),
          const Radius.circular(13),
        ),
        Paint()
          ..color = glowColor.withOpacity(0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );

      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            foreground: Paint()
              ..shader = LinearGradient(
                colors: [textColor, textColor.withValues(alpha: 0.85)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ).createShader(badgeRect),
            shadows: [
              Shadow(color: borderColor.withValues(alpha: 0.6), blurRadius: 4),
            ],
            letterSpacing: 1,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      canvas.save();
      tp.paint(
        canvas,
        Offset(curX + (bw - tp.width) / 2, startY + (badgeH - tp.height) / 2),
      );
      canvas.restore();

      curX += bw + badgeGap;
    }
  }
}
