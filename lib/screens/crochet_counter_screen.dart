import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import '../models/crochet_stitch.dart';
import '../models/crochet_project.dart';
import '../services/storage_service.dart';
import '../widgets/stitch_pattern_grid.dart';
import '../widgets/stitch_history_section.dart';
import '../widgets/control_buttons.dart';
import 'settings_screen.dart';
import 'home_screen.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'dart:io';

class CrochetCounterScreen extends StatefulWidget {
  final CrochetProject? project;

  const CrochetCounterScreen({super.key, this.project});

  @override
  State<CrochetCounterScreen> createState() => _CrochetCounterScreenState();
}

class _CrochetCounterScreenState extends State<CrochetCounterScreen> {
  final Logger _logger = Logger();
  final StorageService _storageService = StorageService();
  int _stitchCount = 0;
  int _rowNumber = 1;
  CrochetStitch _selectedStitch = CrochetStitch.singleCrochet;
  final List<Map<String, dynamic>> _stitchHistory = [];
  RewardedAd? _rewardedAd;
  bool _isRewardedAdLoaded = false;
  BannerAd? _bannerAd;
  bool _isBannerAdLoaded = false;
  String _projectId = '';
  String _projectTitle = '新しいプロジェクト';
  bool _hasUnsavedChanges = false;

  @override
  void initState() {
    super.initState();
    _loadRewardedAd();
    _loadBannerAd();
    _initializeProject();
  }

  void _initializeProject() {
    try {
      if (widget.project != null) {
        // 既存のプロジェクトを読み込み
        final project = widget.project!;
        print('既存プロジェクトを読み込み: ${project.title}');
        _projectId = project.id;
        _projectTitle = project.title;
        _stitchCount = project.currentStitchCount;
        _rowNumber = project.currentRow;
        _stitchHistory.clear();
        _stitchHistory.addAll(project.stitchHistory);
        _hasUnsavedChanges = false; // 既存プロジェクトは変更なしとして初期化
        print('プロジェクト読み込み完了: ${_stitchHistory.length}件の履歴');
      } else {
        // 新しい編みものを作成
        _projectId = _storageService.generateProjectId();
        _projectTitle = '新しい編みもの';
        _hasUnsavedChanges = false; // 新規プロジェクトは変更なしとして初期化
        print('新規編みもの作成: $_projectId');
      }
    } catch (e) {
      print('プロジェクト初期化エラー: $e');
      // エラーが発生した場合は新規プロジェクトとして初期化
      _projectId = _storageService.generateProjectId();
      _projectTitle = '新しい編みもの';
      _stitchCount = 0;
      _rowNumber = 1;
      _stitchHistory.clear();
      _hasUnsavedChanges = false;
    }
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

  void _loadBannerAd() {
    final adUnitId = Platform.isAndroid
        ? 'ca-app-pub-3940256099942544/6300978111'
        : 'ca-app-pub-3940256099942544/2934735716';
    _bannerAd = BannerAd(
      adUnitId: adUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          setState(() {
            _isBannerAdLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          setState(() {
            _isBannerAdLoaded = false;
          });
        },
      ),
    );
    _bannerAd!.load();
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
        _hasUnsavedChanges = true;
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
          _hasUnsavedChanges = true;
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
          _hasUnsavedChanges = true;
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
        _hasUnsavedChanges = true;
      });
      _logger.i('resetAll: すべてをリセットしました');
    } catch (e, stackTrace) {
      _logger.e('関数名: _resetAll, '
          'パラメータ: なし, '
          '例外内容: $e, '
          'スタックトレース: $stackTrace');
    }
  }

  void _showRewardedAdAndReset() {
    if (_isRewardedAdLoaded && _rewardedAd != null) {
      _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _resetAll();
          _loadRewardedAd();
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          ad.dispose();
          _resetAll();
          _loadRewardedAd();
        },
      );
      _rewardedAd!.show(
        onUserEarnedReward: (ad, reward) {
          // 報酬を付与
        },
      );
    } else {
      _resetAll();
    }
  }

  Future<String?> _editProjectTitle() async {
    final TextEditingController controller =
        TextEditingController(text: _projectTitle);

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('編みもの名を編集'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '編みもの名',
            hintText: '例: マフラー',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () async {
              final newTitle = controller.text.trim();
              if (newTitle.isNotEmpty) {
                Navigator.of(context).pop(newTitle);
                // タイトルを更新
                setState(() {
                  _projectTitle = newTitle;
                  _hasUnsavedChanges = true;
                });
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );

    return result;
  }

  Future<bool> _saveProject() async {
    // タイトルがデフォルトの場合でも保存を許可（戻るボタンからの呼び出しの場合は既にタイトル編集済み）
    // 保存ボタンからの呼び出しの場合のみタイトル編集を促す
    if (_projectTitle == '新しい編みもの' || _projectTitle.isEmpty) {
      // 戻るボタンからの呼び出しの場合はタイトル編集をスキップ
      // 保存ボタンからの呼び出しの場合のみタイトル編集を促す
      // この部分は戻るボタンの処理で既に処理済みなので、ここでは何もしない
    }

    try {
      print('プロジェクト保存開始');

      final project = CrochetProject(
        id: _projectId,
        title: _projectTitle,
        createdAt: widget.project?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
        stitchHistory: _stitchHistory,
        currentRow: _getCurrentRow(),
        currentStitchCount: _getCurrentStitchCount(),
        iconName: widget.project?.iconName ?? 'work',
        iconColor: widget.project?.iconColor ?? '0xFF000000',
        backgroundColor: widget.project?.backgroundColor ?? '0xFFFFFFFF',
      );

      print(
          'プロジェクト作成完了: ${project.title}, 履歴数: ${project.stitchHistory.length}');

      final success = await _storageService.saveProject(project);
      print('保存結果: $success');

      if (success) {
        setState(() {
          _hasUnsavedChanges = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('編みものを保存しました'),
            backgroundColor: Colors.green,
          ),
        );
        return true;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('編みものの保存に失敗しました'),
            backgroundColor: Colors.red,
          ),
        );
        return false;
      }
    } catch (e) {
      print('保存エラー: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('保存エラー: $e'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }
  }

  Future<bool> _showSaveDialog() async {
    // 変更がない場合は直接戻る
    if (!_hasUnsavedChanges) {
      return true;
    }

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('変更を保存'),
        content: const Text('変更を保存しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('保存しない'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop(true);
              await _saveProject();
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  int _getCurrentRow() {
    if (_stitchHistory.isEmpty) return 0;
    return _stitchHistory.last['row'] as int;
  }

  int _getCurrentStitchCount() {
    if (_stitchHistory.isEmpty) return 0;
    return _stitchHistory.where((stitch) => stitch['position'] != 0).length;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _showSaveDialog,
      child: Scaffold(
        backgroundColor: const Color(0xFFFCE4EC),
        appBar: AppBar(
          title: GestureDetector(
            onTap: _editProjectTitle,
            child: Text(
              _projectTitle,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          backgroundColor: const Color(0xFFEC407A),
          centerTitle: true,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              print('戻るボタンが押されました');
              // 変更がない場合は直接戻る
              if (!_hasUnsavedChanges) {
                print('変更なし、直接戻る');
                Navigator.of(context).pop();
                return;
              }

              print('変更あり、保存確認ダイアログを表示');
              // 変更がある場合は保存確認ダイアログを表示
              final result = await showDialog<bool>(
                context: context,
                barrierDismissible: false,
                builder: (context) => AlertDialog(
                  title: const Text('変更を保存'),
                  content: const Text('変更を保存しますか？'),
                  actions: [
                    TextButton(
                      onPressed: () {
                        print('保存しないを選択');
                        Navigator.of(context).pop(false);
                      },
                      child: const Text('保存しない'),
                    ),
                    TextButton(
                      onPressed: () {
                        print('保存を選択');
                        Navigator.of(context).pop(true);
                      },
                      child: const Text('保存'),
                    ),
                  ],
                ),
              );

              print('ダイアログ結果: $result');

              if (result == true) {
                print('保存処理開始');
                // 保存を選択した場合
                if (_projectTitle == '新しい編みもの' || _projectTitle.isEmpty) {
                  print('タイトル編集開始');
                  final titleResult = await _editProjectTitle();
                  if (titleResult == null) {
                    print('タイトル編集キャンセル');
                    return;
                  }
                  print('タイトル編集完了: $titleResult');
                }

                print('保存処理実行');
                final saveSuccess = await _saveProject();
                if (saveSuccess) {
                  print('保存成功、ホーム画面に遷移');
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (context) => const HomeScreen(),
                    ),
                    (route) => false,
                  );
                }
              } else if (result == false) {
                print('保存しない、直接戻る');
                Navigator.of(context).pop();
              }
            },
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveProject,
            ),
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
              // 編み目履歴をトップに配置（面積をさらに調整）
              Expanded(
                flex: 1,
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
                  currentRow: _getCurrentRow(),
                  currentStitchCount: _getCurrentStitchCount(),
                ),
              ),
              const SizedBox(height: 10),
              // 編み方を選択から下を固定配置
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
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
              // バナー広告を一番下に固定配置
              if (_isBannerAdLoaded && _bannerAd != null)
                Container(
                  width: _bannerAd!.size.width.toDouble(),
                  height: _bannerAd!.size.height.toDouble(),
                  child: AdWidget(ad: _bannerAd!),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _rewardedAd?.dispose();
    _bannerAd?.dispose();
    super.dispose();
  }
}
