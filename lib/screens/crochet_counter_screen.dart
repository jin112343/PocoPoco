import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import '../models/crochet_stitch.dart';
import '../widgets/row_and_stitch_display.dart';
import '../widgets/stitch_pattern_grid.dart';
import '../widgets/stitch_history_section.dart';
import '../widgets/control_buttons.dart';
import 'settings_screen.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'dart:io';

class CrochetCounterScreen extends StatefulWidget {
  const CrochetCounterScreen({super.key});

  @override
  State<CrochetCounterScreen> createState() => _CrochetCounterScreenState();
}

class _CrochetCounterScreenState extends State<CrochetCounterScreen> {
  final Logger _logger = Logger();
  int _stitchCount = 0;
  int _rowNumber = 1;
  CrochetStitch _selectedStitch = CrochetStitch.singleCrochet;
  final List<Map<String, dynamic>> _stitchHistory = [];
  RewardedAd? _rewardedAd;
  bool _isRewardedAdLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadRewardedAd();
  }

  void _loadRewardedAd() {
    final adUnitId = Platform.isAndroid
        ? 'ca-app-pub-3940256099942544/5224354917'
        : 'ca-app-pub-3940256099942544/1712485313';
    RewardedAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          setState(() {
            _rewardedAd = ad;
            _isRewardedAdLoaded = true;
          });
        },
        onAdFailedToLoad: (error) {
          setState(() {
            _rewardedAd = null;
            _isRewardedAdLoaded = false;
          });
        },
      ),
    );
  }

  void _showRewardedAdAndReset() {
    if (_isRewardedAdLoaded && _rewardedAd != null) {
      _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _loadRewardedAd();
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          ad.dispose();
          _loadRewardedAd();
        },
      );
      _rewardedAd!.show(
        onUserEarnedReward: (ad, reward) {
          _resetAll();
        },
      );
      setState(() {
        _rewardedAd = null;
        _isRewardedAdLoaded = false;
      });
    } else {
      // 広告がロードされていない場合はそのままリセット
      _resetAll();
      _loadRewardedAd();
    }
  }

  @override
  void dispose() {
    _rewardedAd?.dispose();
    super.dispose();
  }

  void _addStitch(CrochetStitch stitch) {
    try {
      setState(() {
        _stitchCount++;
        _stitchHistory.add({
          'stitch': stitch,
          'row': _rowNumber,
          'position': _stitchCount,
          'timestamp': DateTime.now(),
        });
      });
      _logger.i(
          'addStitch: ${stitch.name}を追加しました。段: $_rowNumber, 位置: $_stitchCount');
    } catch (e, stackTrace) {
      _logger.e('関数名: _addStitch, '
          'パラメータ: stitch=$stitch, '
          '例外内容: $e, '
          'スタックトレース: $stackTrace');
    }
  }

  void _removeLastStitch() {
    try {
      if (_stitchCount > 0) {
        setState(() {
          _stitchCount--;
          if (_stitchHistory.isNotEmpty) {
            _stitchHistory.removeLast();
          }
        });
        _logger.i('removeLastStitch: 最後の編み目を削除しました。現在の値: $_stitchCount');
      }
    } catch (e, stackTrace) {
      _logger.e('関数名: _removeLastStitch, '
          'パラメータ: なし, '
          '例外内容: $e, '
          'スタックトレース: $stackTrace');
    }
  }

  void _completeRow() {
    try {
      if (_stitchCount > 0) {
        setState(() {
          _rowNumber++;
          _stitchCount = 0;
          // 段完成時に空の段を履歴に追加して表示
          _stitchHistory.add({
            'stitch': _selectedStitch,
            'row': _rowNumber,
            'position': 0, // 0は段開始を示す
            'timestamp': DateTime.now(),
            'isRowStart': true, // 段開始フラグ
          });
        });

        _logger.i('completeRow: 段を完成しました。新しい段: $_rowNumber');
      }
    } catch (e, stackTrace) {
      _logger.e('関数名: _completeRow, '
          'パラメータ: なし, '
          '例外内容: $e, '
          'スタックトレース: $stackTrace');
    }
  }

  void _resetAll() {
    try {
      setState(() {
        _stitchCount = 0;
        _rowNumber = 1;
        _stitchHistory.clear();
      });
      _logger.i('resetAll: すべてをリセットしました');
    } catch (e, stackTrace) {
      _logger.e('関数名: _resetAll, '
          'パラメータ: なし, '
          '例外内容: $e, '
          'スタックトレース: $stackTrace');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFCE4EC),
      appBar: AppBar(
        title: const Text(
          'かぎ針編みカウンター',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFFEC407A),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const SettingsScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      RowAndStitchDisplay(
                        rowNumber: _rowNumber,
                        stitchCount: _stitchCount,
                        onRowTap: (rowNumber) {
                          // 段目ボタンがタップされた時の処理
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('$rowNumber段目をタップしました'),
                              duration: const Duration(milliseconds: 500),
                              backgroundColor: const Color(0xFFAD1457),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                      StitchPatternGrid(
                        selectedStitch: _selectedStitch,
                        onStitchSelected: (stitch) {
                          setState(() {
                            _selectedStitch = stitch;
                          });
                        },
                        onStitchAdded: _addStitch,
                      ),
                      const SizedBox(height: 20),
                      ControlButtons(
                        onRemoveStitch: _removeLastStitch,
                        onCompleteRow: _completeRow,
                        onReset: _showRewardedAdAndReset,
                        canRemoveStitch: _stitchCount > 0,
                        canCompleteRow: _stitchCount > 0,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              height: 200,
              child: StitchHistorySection(
                stitchHistory: _stitchHistory,
                onRowTap: (rowNumber) {
                  // 履歴の段目がタップされた時の処理
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('$rowNumber段目に移動しました'),
                      duration: const Duration(milliseconds: 500),
                      backgroundColor: const Color(0xFFAD1457),
                    ),
                  );
                },
                onRowCompleted: (rowNumber) {
                  // 段が完成した時の処理（ポップアップなし）
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
