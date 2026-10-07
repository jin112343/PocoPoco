import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';

import '../controllers/project_controller.dart';
import '../models/crochet_project.dart';
import '../models/stitch_info.dart';
import '../services/ads_initializer.dart';
import '../services/stitch_settings_service.dart';
import '../services/storage_service.dart';
import '../services/subscription_provider.dart';
import '../services/user_prefs_service.dart';
import '../widgets/control_buttons.dart';
import '../widgets/counter_display.dart';
import '../widgets/markers_dialog.dart';
import '../widgets/project_notes_sheet.dart';
import '../widgets/stitch_history_section.dart';
import '../widgets/stitch_pattern_grid.dart';
import 'settings_screen.dart';
import 'upgrade_screen.dart';

class CrochetCounterScreen extends StatefulWidget {
  final CrochetProject? project;

  const CrochetCounterScreen({super.key, this.project});

  @override
  State<CrochetCounterScreen> createState() => _CrochetCounterScreenState();
}

class _CrochetCounterScreenState extends State<CrochetCounterScreen>
    with WidgetsBindingObserver {
  final Logger _logger = Logger();

  // 作品の状態と自動保存
  late final ProjectController _controller;

  // 広告関連
  RewardedAd? _rewardedAd;
  bool _isRewardedAdLoaded = false;
  BannerAd? _bannerAd;
  bool _isBannerAdLoaded = false;
  Widget? _adWidget; // AdWidgetをキャッシュして重複使用エラーを防ぐ
  // バナー領域を画面構成（縦/横/スクロール表示）が切り替わっても作り直さず
  // 移動させるためのキー。AdWidgetは同じフレームで作り直されると
  // 「already in the Widget tree」の例外になる
  final GlobalKey _bannerAreaKey = GlobalKey();

  // サブスクリプション状態
  SubscriptionProvider? _subscriptionProvider;
  bool? _wasPremium;

  List<dynamic>? _defaultStitches;
  bool _isSaving = false;
  bool _isLeaving = false;

  // スナックバーを操作ボタンや広告に重ねないための下余白
  double _snackBarBottomMargin = 0;

  bool get _isPremium => _subscriptionProvider?.isPremium ?? false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _subscriptionProvider = context.read<SubscriptionProvider>();

    _controller = ProjectController(isPremium: () => _isPremium);
    final project = widget.project;
    if (project != null) {
      _controller.loadExisting(project);
    } else {
      _controller.startNew(title: tr('new_project'));
    }
    _controller.addListener(_onControllerChanged);

    // 広告SDKの初期化完了を待ってから読み込む
    AdsInitializer.ready.then((_) {
      if (!mounted) return;
      _loadRewardedAd();
      _loadBannerAd();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkPremiumStatusChange();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 着信・ホームに戻るなどでアプリが前面でなくなったら、すぐに保存する
    // （このあと強制終了されても記録が残るようにする）
    if (state != AppLifecycleState.resumed) {
      unawaited(_controller.flush());
    }
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  /// プレミアム状態の変化を検知する。
  /// 解約時は基本の編み目表示に戻すだけで、作品に保存されたボタン設定や
  /// 編み目の記録には手を加えない（再加入・購入復元で元に戻る）。
  void _checkPremiumStatusChange() {
    final isPremium = _isPremium;
    final wasPremium = _wasPremium;
    _wasPremium = isPremium;

    if (wasPremium == true && !isPremium) {
      _logger.i('プレミアム解約を検知');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showSnackBar(tr('premium_ended_basic_stitches'));
      });
    }
  }

  /// 画面に出す編み方ボタン。カスタム設定はプレミアムの間だけ使う
  List<dynamic> _currentStitches() {
    final saved = _controller.projectStitches;
    if (_isPremium && saved.isNotEmpty) return saved;
    return _defaultStitches ??= StitchSettingsService.getDefaultStitches();
  }

  /// 編み方ボタンの並びが変わったらグリッドを作り直すためのキー
  int _stitchesHash(List<dynamic> stitches) {
    return Object.hashAll(
        stitches.map((s) => StitchInfo.of(s)?.key ?? s.toString()));
  }

  // ---- 編み目の操作 ----

  void _addStitch(dynamic stitch) {
    // 「元に戻す」は直後だけ有効にする（次の操作をしたら閉じる）
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    _controller.addStitch(stitch);
  }

  void _removeLastStitch() {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    _controller.removeLastStitch();
  }

  void _completeRow() {
    final completion = _controller.completeRow();
    if (completion == null) return;

    final completedRow = completion.completedRow;
    final markers = _controller.markers;
    final lines = <String>[
      tr('row_completed', namedArgs: {
        'row': '$completedRow',
        'next': '${_controller.currentRow}',
      }),
    ];
    var reachedMarker = false;

    if (markers.isCheckRow(completedRow)) {
      lines.add(tr('marker_check_reached',
          namedArgs: {'n': '${markers.checkEveryRows}'}));
      reachedMarker = true;
    }
    final finishedRepeat = markers.repeatCompletedByRow(completedRow);
    if (finishedRepeat != null) {
      final total = markers.repeatTotal!;
      lines.add(finishedRepeat >= total
          ? tr('marker_repeat_all_done')
          : tr('marker_repeat_one_done', namedArgs: {
              'current': '$finishedRepeat',
              'total': '$total',
              'remaining': '${total - finishedRepeat}',
            }));
      reachedMarker = true;
    }

    if (reachedMarker) {
      // 目印の段は手元を見ていなくても気付けるよう振動でも知らせる
      HapticFeedback.mediumImpact();
    }
    _showUndoSnackBar(
      lines.join('\n'),
      completion.before,
      duration: Duration(seconds: reachedMarker ? 7 : 4),
    );
  }

  void _removeRow(int rowNumber) {
    final before = _controller.removeRow(rowNumber);
    if (before == null) {
      _logger.w('削除対象の段が見つかりません: $rowNumber段目');
      return;
    }
    _showUndoSnackBar(
      tr('row_deleted', namedArgs: {'row': '$rowNumber'}),
      before,
    );
  }

  /// リセット確認ダイアログ表示
  Future<void> _showResetConfirmDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('reset_confirm_title')),
        content: Text(tr('reset_confirm_message')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(tr('cancel')),
          ),
          TextButton(
            key: const ValueKey('reset_confirm_button'),
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: Text(tr('reset')),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      final before = _controller.resetAll();
      _showUndoSnackBar(
        tr('reset_done'),
        before,
        duration: const Duration(seconds: 8),
      );
    }
  }

  // ---- メモ・目印・タイトル ----

  Future<void> _openNotes() async {
    await showProjectNotesSheet(context, controller: _controller);
  }

  Future<void> _editMarkers() async {
    final result = await showMarkersDialog(
      context,
      markers: _controller.markers,
      currentRow: _controller.currentRow,
    );
    if (result != null) {
      _controller.setMarkers(result);
    }
  }

  /// プロジェクトタイトル編集
  Future<String?> _editProjectTitle() async {
    final TextEditingController controller =
        TextEditingController(text: _controller.title);

    return await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('edit_project_title')),
        content: TextField(
          key: const ValueKey('project_title_field'),
          controller: controller,
          decoration: InputDecoration(
            labelText: tr('project_title'),
            hintText: tr('project_title_hint'),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(tr('cancel')),
          ),
          TextButton(
            key: const ValueKey('project_title_save_button'),
            onPressed: () {
              final newTitle = controller.text.trim();
              if (newTitle.isNotEmpty) {
                Navigator.of(context).pop(newTitle);
                _controller.setTitle(newTitle);
              }
            },
            child: Text(tr('save')),
          ),
        ],
      ),
    );
  }

  /// 編み方ボタンの設定が変更された
  Future<void> _onProjectStitchesChanged(List<dynamic> newStitches) async {
    // 今の編み目の記録ごと保存する（古い状態で上書きしない）
    _controller.setProjectStitches(newStitches);
  }

  // ---- 保存 ----

  /// 保存ボタンでの保存。
  /// [announce] がfalseの場合は「保存完了」の通知を出さない（保存してすぐ画面を閉じる時）
  Future<bool> _saveManually({bool announce = true}) async {
    if (_isSaving) {
      _logger.w('保存処理中、重複保存をスキップ');
      return false;
    }
    setState(() {
      _isSaving = true;
    });

    SaveResult result;
    try {
      result = await _controller.saveNow();
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
    if (!mounted) return result == SaveResult.saved;

    switch (result) {
      case SaveResult.saved:
        if (announce) _showSnackBar(tr('save_complete'));
        return true;
      case SaveResult.limitReached:
        _showSaveLimitDialog();
        return false;
      case SaveResult.error:
        _showDialog(tr('save_failed'));
        return false;
    }
  }

  /// 保存状態の表示（未保存・再試行）をタップした
  Future<void> _retrySave() async {
    if (_controller.saveStatus == SaveStatus.limitReached) {
      _showSaveLimitDialog();
      return;
    }
    await _controller.flush();
    if (!mounted) return;
    switch (_controller.saveStatus) {
      case SaveStatus.saved:
        _showSnackBar(tr('save_complete'));
      case SaveStatus.limitReached:
        _showSaveLimitDialog();
      case SaveStatus.failed:
        _showDialog(tr('save_failed'));
      case SaveStatus.none:
      case SaveStatus.pending:
        break;
    }
  }

  void _showSaveLimitDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(tr('save_limit_reached')),
        content: Text(tr('save_limit_message')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(tr('cancel')),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const UpgradeScreen(),
                ),
              );
            },
            child: Text(tr('upgrade')),
          ),
        ],
      ),
    );
  }

  // ---- 通知 ----

  /// 一時的な通知（成功・情報）用のスナックバー表示ヘルパー
  /// 操作を妨げるモーダルダイアログの代わりに使用する
  void _showSnackBar(
    String message, {
    SnackBarAction? action,
    Duration duration = const Duration(seconds: 2),
  }) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          // 下の操作ボタンや広告に重ならない位置に出す
          margin: EdgeInsets.fromLTRB(12, 0, 12, _snackBarBottomMargin + 10),
          duration: duration,
          action: action,
          // アクション付きでも時間が来たら自動で閉じる
          persist: false,
        ),
      );
  }

  /// 「元に戻す」付きの通知
  void _showUndoSnackBar(
    String message,
    HistorySnapshot before, {
    Duration duration = const Duration(seconds: 4),
  }) {
    _showSnackBar(
      message,
      duration: duration,
      action: SnackBarAction(
        label: tr('undo_action'),
        onPressed: () => _controller.restore(before),
      ),
    );
  }

  /// ダイアログ表示のヘルパー
  void _showDialog(String message) {
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(tr('ok')),
            ),
          ],
        ),
      );
    }
  }

  // ---- 広告 ----

  /// 広告読み込み
  void _loadRewardedAd() {
    final adUnitId = Platform.isAndroid
        ? 'ca-app-pub-1187210314934709/4892788853'
        : 'ca-app-pub-1187210314934709/8887874189';
    RewardedAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() {
            _rewardedAd = ad;
            _isRewardedAdLoaded = true;
          });
        },
        onAdFailedToLoad: (error) {
          if (!mounted) return;
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
        ? 'ca-app-pub-1187210314934709/2203046337'
        : 'ca-app-pub-1187210314934709/2458197200';
    _bannerAd = BannerAd(
      adUnitId: adUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() {
            _isBannerAdLoaded = true;
            _adWidget = AdWidget(ad: ad as BannerAd);
          });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          _bannerAd = null;
          if (!mounted) return;
          setState(() {
            _isBannerAdLoaded = false;
          });
        },
      ),
    );
    _bannerAd!.load();
  }

  // ---- 画面 ----

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // 購読状態の変化（購入・解約）を監視して即時反映する
    // （watchしないとバナー広告の非表示化やプレミアム解約検知が次の画面遷移まで遅れる）
    _subscriptionProvider = context.watch<SubscriptionProvider>();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (!didPop) {
          // AppBarの戻るボタンと同じ保存フローを通す
          await _handleBackButton();
        }
      },
      child: Scaffold(
        appBar: _buildAppBar(),
        // 入力欄はダイアログやシート側にしかないので、キーボードが出ても
        // この画面は縮めない（裏で画面構成が切り替わるのを防ぐ）
        resizeToAvoidBottomInset: false,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isLandscape = constraints.maxWidth > constraints.maxHeight;
              final isTablet = constraints.maxWidth >= 600;

              if (isLandscape && isTablet) {
                // iPad横向き: 左右分割レイアウト
                return _buildLandscapeLayout(constraints, isDarkMode);
              } else {
                // 縦向きまたはiPhone: 縦並びレイアウト
                return _buildPortraitLayout(constraints);
              }
            },
          ),
        ),
      ),
    );
  }

  /// 縦向きレイアウト。
  /// 大きな段数・目数表示と操作ボタンは常に画面内に収め、残りを履歴に使う。
  Widget _buildPortraitLayout(BoxConstraints constraints) {
    final stitches = _currentStitches();
    final bannerHeight =
        _isPremium ? 0.0 : AdSize.banner.height.toDouble();
    final layout = _PortraitLayout.choose(
      context,
      availableHeight: constraints.maxHeight - bannerHeight,
      stitchCount: stitches.length,
    );
    _snackBarBottomMargin =
        layout.scrolls ? 0 : layout.controlsHeight + bannerHeight;

    final display = _buildCounterDisplay(compact: layout.compactDisplay);
    final history = _buildHistory(stitches);
    final controls = Padding(
      padding: _PortraitLayout.controlsPadding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildStitchGrid(
            stitches,
            buttonHeight: layout.stitchButtonHeight,
            maxVisibleRows: layout.maxVisibleRows,
          ),
          _ControlsSeparator(height: layout.separatorHeight),
          _buildControlButtons(height: layout.controlButtonHeight),
        ],
      ),
    );
    final banner = _buildBannerArea();

    if (layout.scrolls) {
      // 画面が極端に低い場合（分割画面など）は、ボタンが隠れないよう
      // 表示の下をスクロールできるようにする
      return Column(
        children: [
          display,
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  SizedBox(
                    height: _PortraitLayout.scrollingHistoryHeight,
                    child: history,
                  ),
                  controls,
                ],
              ),
            ),
          ),
          if (banner != null) banner,
        ],
      );
    }

    return Column(
      children: [
        display,
        Expanded(child: history),
        controls,
        if (banner != null) banner,
      ],
    );
  }

  /// 横向きレイアウト（iPad用）
  Widget _buildLandscapeLayout(BoxConstraints constraints, bool isDarkMode) {
    final stitches = _currentStitches();
    final banner = _buildBannerArea();
    _snackBarBottomMargin = 0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 左側: 編み目履歴
        Expanded(
          flex: 1,
          child: _buildHistory(stitches),
        ),
        // 右側: 段数・目数表示と、編み目パターン・コントロール
        Expanded(
          flex: 1,
          child: Container(
            color: isDarkMode ? const Color(0xFF1A1A1A) : const Color(0xFFFCE4EC),
            child: Column(
              children: [
                _buildCounterDisplay(compact: false),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Column(
                      children: [
                        _buildStitchGrid(
                          stitches,
                          buttonHeight: 88,
                          maxVisibleRows: 4,
                          isLandscape: true,
                        ),
                        const _ControlsSeparator(height: 28),
                        _buildControlButtons(height: 64),
                        if (banner != null) ...[
                          const SizedBox(height: 16),
                          banner,
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCounterDisplay({required bool compact}) {
    return CounterDisplay(
      currentRow: _controller.currentRow,
      currentStitchCount: _controller.currentStitchCount,
      saveStatus: _controller.saveStatus,
      isNewUnconfirmed: _controller.isNewUnconfirmed,
      markers: _controller.markers,
      memo: _controller.memo,
      compact: compact,
      onSaveStatusTap: _retrySave,
      onMarkersTap: _editMarkers,
      onNotesTap: _openNotes,
    );
  }

  Widget _buildHistory(List<dynamic> stitches) {
    return StitchHistorySection(
      stitchHistory: _controller.history,
      currentStitches: stitches,
      currentRow: _controller.currentRow,
      markers: _controller.markers,
      onStitchRemoved: _removeRow,
    );
  }

  Widget _buildStitchGrid(
    List<dynamic> stitches, {
    required double buttonHeight,
    required int maxVisibleRows,
    bool isLandscape = false,
  }) {
    return StitchPatternGrid(
      key: ValueKey(
          'stitch_grid_${isLandscape ? 'landscape' : 'portrait'}_${_stitchesHash(stitches)}'),
      onStitchAdded: _addStitch,
      projectStitches: stitches,
      onProjectStitchesChanged: _onProjectStitchesChanged,
      isLandscape: isLandscape,
      buttonHeight: buttonHeight,
      maxVisibleRows: maxVisibleRows,
    );
  }

  Widget _buildControlButtons({required double height}) {
    return ValueListenableBuilder<bool>(
      valueListenable: UserPrefsService.leftHanded,
      builder: (context, leftHanded, _) => ControlButtons(
        onRemoveStitch: _removeLastStitch,
        onCompleteRow: _completeRow,
        onReset: _showResetConfirmDialog,
        canRemoveStitch: _controller.canUndo,
        canCompleteRow: _controller.canCompleteRow,
        canReset: _controller.canReset,
        leftHanded: leftHanded,
        height: height,
      ),
    );
  }

  /// バナー広告の表示領域（プレミアムの場合はnull）。
  /// 読み込み前から高さを確保しておき、広告が出た瞬間にボタンの位置が
  /// ずれて押し間違えるのを防ぐ。
  Widget? _buildBannerArea() {
    if (_isPremium) return null;
    final bannerAd = _bannerAd;
    return SizedBox(
      key: _bannerAreaKey,
      height: AdSize.banner.height.toDouble(),
      child: (_isBannerAdLoaded && _adWidget != null && bannerAd != null)
          ? Center(
              child: SizedBox(
                width: bannerAd.size.width.toDouble(),
                height: bannerAd.size.height.toDouble(),
                child: _adWidget!,
              ),
            )
          : null,
    );
  }

  /// AppBarの構築
  PreferredSizeWidget _buildAppBar() {
    final title = _controller.title;
    return AppBar(
      title: GestureDetector(
        onTap: _editProjectTitle,
        child: Text(
          title.isEmpty ? tr('app_title') : title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      centerTitle: true,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: _handleBackButton,
      ),
      actions: [
        IconButton(
          key: const ValueKey('save_button'),
          icon: const Icon(Icons.save),
          tooltip: tr('save'),
          onPressed: _isSaving
              ? null
              : () async {
                  final result = await _saveManually();
                  if (result) {
                    _showRewardedAdAfterSave();
                  }
                },
        ),
        IconButton(
          icon: const Icon(Icons.settings),
          tooltip: tr('settings'),
          onPressed: _navigateToSettings,
        ),
      ],
    );
  }

  // ---- 画面遷移 ----

  /// 戻るボタンの処理。
  /// 保存済みの作品は自動保存してそのまま戻る。新規作品だけ、残すかどうかを確認する。
  Future<void> _handleBackButton() async {
    if (_isLeaving) return;
    _isLeaving = true;
    try {
      // 非同期処理の前にNavigatorなどへの参照を保存
      final navigator = Navigator.of(context);
      final messenger = ScaffoldMessenger.of(context);

      // この画面の通知（「元に戻す」など）を前の画面に持ち越さずに閉じる
      void leave() {
        messenger
          ..clearSnackBars()
          ..removeCurrentSnackBar();
        navigator.pop();
      }

      if (_controller.isNewUnconfirmed) {
        if (!_controller.hasContent) {
          _logger.d('変更なし、直接戻る');
          await _controller.discardNew();
          if (mounted) leave();
          return;
        }

        final shouldSave = await _showSaveDialog();
        if (shouldSave == null || !mounted) return; // ダイアログを閉じただけ

        if (!shouldSave) {
          await _controller.discardNew();
          if (mounted) leave();
          return;
        }

        final title = _controller.title;
        if (title == tr('new_project') || title.isEmpty) {
          final titleResult = await _editProjectTitle();
          if (titleResult == null) return;
        }

        final saveSuccess = await _saveManually(announce: false);
        if (saveSuccess) {
          // ダイアログを閉じてから画面遷移する（遷移が先だとダイアログが即座に消える）
          await _showRewardedAdAfterSave();
          if (mounted) leave();
        }
        return;
      }

      // 保存済みの作品: 残っている変更を書き込んでから戻る
      while (true) {
        await _controller.flush();
        if (!mounted) return;
        if (!_controller.hasUnsavedChanges) break;

        // 保存できなかった場合は、黙って戻らずにどうするか確認する
        final leaveAnyway = await _showLeaveWithoutSavingDialog();
        if (leaveAnyway == null || !mounted) return; // 閉じただけなら画面に残る
        if (leaveAnyway) break;
        // 「再試行」が選ばれたら、もう一度保存を試す
      }
      leave();
    } finally {
      _isLeaving = false;
    }
  }

  /// 新規作品を残すかどうかの確認。保存する=true / 保存しない=false / 閉じただけ=null
  Future<bool?> _showSaveDialog() {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(tr('save_changes_title')),
        content: Text(tr('save_new_project_message')),
        actions: [
          TextButton(
            key: const ValueKey('dont_save_button'),
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(tr('dont_save')),
          ),
          TextButton(
            key: const ValueKey('save_dialog_save_button'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(tr('save')),
          ),
        ],
      ),
    );
  }

  /// 保存に失敗したまま戻ろうとした時の確認。
  /// 保存せずに戻る=true / 再試行=false / 閉じただけ=null
  Future<bool?> _showLeaveWithoutSavingDialog() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('save_failed')),
        content: Text(tr('leave_without_saving_message')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(tr('leave_without_saving')),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(tr('retry')),
          ),
        ],
      ),
    );
  }

  /// 設定画面への遷移
  Future<void> _navigateToSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SettingsScreen(
          isFromProject: true,
          currentProject: widget.project,
        ),
      ),
    );
  }

  /// 保存後の報酬広告表示
  Future<void> _showRewardedAdAfterSave() async {
    if (_isPremium || !mounted) return;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('watch_ad_title')),
        content: Text(tr('watch_ad_message')),
        actions: [
          TextButton(
            key: const ValueKey('no_thanks_button'),
            onPressed: () => Navigator.of(context).pop(),
            child: Text(tr('no_thanks')),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _showRewardedAd();
            },
            child: Text(tr('watch_ad')),
          ),
        ],
      ),
    );
  }

  /// 報酬広告の表示
  void _showRewardedAd() {
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
          _logger.i('報酬広告視聴完了');
        },
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // 画面が閉じられる時点で未保存の変更が残っていれば書き込む
    unawaited(_controller.flush());
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    _rewardedAd?.dispose();
    _bannerAd?.dispose();
    super.dispose();
  }
}

/// 編み方ボタンと「1つ戻す/段完成/リセット」の間を空けて、押し間違いを防ぐ区切り
class _ControlsSeparator extends StatelessWidget {
  const _ControlsSeparator({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: height,
      child: Center(
        child: Container(
          width: 56,
          height: 3,
          decoration: BoxDecoration(
            color: isDarkMode ? Colors.white24 : const Color(0x33AD1457),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}

/// 縦向き画面の寸法。画面の高さに合わせて、ボタンの大きさを段階的に選ぶ。
class _PortraitLayout {
  const _PortraitLayout({
    required this.compactDisplay,
    required this.stitchButtonHeight,
    required this.controlButtonHeight,
    required this.separatorHeight,
    required this.maxVisibleRows,
    required this.controlsHeight,
    this.scrolls = false,
  });

  /// 段数・目数表示を小さめにするか
  final bool compactDisplay;

  /// 編み方ボタン1つの高さ
  final double stitchButtonHeight;

  /// 「1つ戻す」「段完成」の高さ
  final double controlButtonHeight;

  /// 編み方ボタンと操作ボタンの間隔
  final double separatorHeight;

  /// 編み方ボタンをスクロールなしで見せる行数
  final int maxVisibleRows;

  /// 編み方ボタン〜操作ボタンの領域全体の高さ
  final double controlsHeight;

  /// 画面に収まらず、スクロールで見せる必要があるか
  final bool scrolls;

  static const EdgeInsets controlsPadding = EdgeInsets.fromLTRB(16, 8, 16, 10);

  // 履歴にこれだけ残せるなら、その大きさを採用する
  static const double _comfortableHistoryHeight = 170;
  // 履歴に最低限必要な高さ。これも確保できなければスクロール表示にする
  static const double _minimumHistoryHeight = 88;

  /// スクロール表示にした時の履歴の高さ
  static const double scrollingHistoryHeight = 150;

  // 大きい順の候補（表示を小さめに, 編み方ボタン, 操作ボタン, 間隔, 行数）
  static const List<(bool, double, double, double, int)> _candidates = [
    (false, 88, 64, 28, 3),
    (false, 80, 60, 26, 3),
    (false, 72, 60, 22, 3),
    (true, 64, 56, 18, 2),
    (true, 56, 52, 14, 2),
  ];

  static _PortraitLayout choose(
    BuildContext context, {
    required double availableHeight,
    required int stitchCount,
  }) {
    _PortraitLayout build((bool, double, double, double, int) c,
        {bool scrolls = false}) {
      final (compact, stitchHeight, controlHeight, separator, rows) = c;
      return _PortraitLayout(
        compactDisplay: compact,
        stitchButtonHeight: stitchHeight,
        controlButtonHeight: controlHeight,
        separatorHeight: separator,
        maxVisibleRows: rows,
        scrolls: scrolls,
        controlsHeight: controlsPadding.vertical +
            StitchPatternGrid.heightFor(
              stitchCount: stitchCount,
              isLandscape: false,
              buttonHeight: stitchHeight,
              maxVisibleRows: rows,
            ) +
            separator +
            controlHeight,
      );
    }

    double historyHeight(_PortraitLayout layout) =>
        availableHeight -
        CounterDisplay.heightFor(context, compact: layout.compactDisplay) -
        layout.controlsHeight;

    final layouts = _candidates.map(build).toList();
    for (final layout in layouts) {
      if (historyHeight(layout) >= _comfortableHistoryHeight) return layout;
    }
    for (final layout in layouts) {
      if (historyHeight(layout) >= _minimumHistoryHeight) return layout;
    }
    return build(_candidates.last, scrolls: true);
  }
}
