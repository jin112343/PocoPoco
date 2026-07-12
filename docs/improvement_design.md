# PocoPoco 改善設計書

作成日: 2026-07-02
対象バージョン: 2.0.3+18 以降
ステータス: レビュー待ち（この設計書の承認後に実装開始）

---

## 1. 目的と背景

直近のバグ修正で判明した構造的な問題（可変Listの共有、神クラス化、フラグ乱立）を解消し、
同時にカウンターアプリとしての基本体験（片手操作・自動保存・進捗の見やすさ）を引き上げる。

「網目追加時にスクロールしない」バグの根本原因は、`_stitchHistory` という
**可変Listを親子でインスタンス共有**していたことにある。同種のバグを構造的に防ぐことが本設計の中心。

---

## 2. スコープ一覧と優先度

| # | 項目 | 種別 | 優先度 | フェーズ |
|---|------|------|--------|---------|
| A1 | `StitchHistoryEntry` 型付きモデル + `ProjectController` | 設計 | 高 | 1 |
| A2 | 広告ロジックを `AdService` に分離 | 設計 | 高 | 1 |
| A3 | busyフラグ5個 → enum 1個 | 設計 | 中 | 1 |
| A4 | 画面表示ごとのストレージ再読み込み（ポーリング）廃止 | 設計 | 中 | 1 |
| A5 | 履歴一覧の `ListView.builder` 化 | 性能 | 中 | 2 |
| A6 | `name` getter廃止 / `SaveResult` enum / 共通Logger | 品質 | 低 | 2 |
| B1 | 編み目追加時の触覚フィードバック（設定でON/OFF） | UX | 高 | 2 |
| B2 | 画面スリープ防止（wakelock、設定でON/OFF） | UX | 高 | 2 |
| B3 | 現在段・目数の大型表示 | UX | 高 | 2 |
| B4 | 段削除スワイプの初回ヒント | UX | 中 | 2 |
| B5 | バナー広告の領域を事前確保（レイアウトシフト防止） | UX | 中 | 2 |
| B6 | 自動保存（デバウンス）+ 保存状態インジケーター | UX | 高 | 3 |
| B7 | 段ごとの目標目数と進捗表示・到達通知 | 機能 | 中 | 3 |
| B8 | 段削除の取り消し（SnackBarの「元に戻す」） | UX | 中 | 3 |
| B9 | 編み目名の ko/es/de ローカライズ | i18n | 中 | 4 |
| B10 | プロジェクトのメモ（使用糸・針サイズ等） | 機能 | 低 | 4 |
| B12 | 統計画面（累計目数・日別進捗） | 機能 | 低 | 4 |
| B11 | 音量ボタンでカウント | 機能 | — | **見送り** |

**B11を見送る理由**: iOSでは音量ボタンの用途転用がApp Store審査ガイドライン違反として
リジェクト事例が多い。Android限定でもネイティブ実装（MethodChannel）が必要で、
メンテ済みのFlutterパッケージが存在しない。要望が強ければAndroid限定で別途検討。

**実施済み**: `wakelock_plus: ^1.4.0` を pubspec に追加済み（コードは未変更）。

---

## 3. 詳細設計

### 3.1 A1: 型付きモデルとProjectController（本設計の中核）

#### 現状の問題
- `_stitchHistory: List<Map<String, dynamic>>` を in-place 変更して子Widgetに渡すため、
  新旧比較が不可能（今回のスクロールバグの根本原因）
- `'row'` / `'position'` / `'isRowStart'` という文字列キーへの依存が全域に散在
- カウンター画面（1,275行）が状態・広告・保存・課金監視を全部保持

#### 新規ファイル: `lib/models/stitch_history_entry.dart`

```dart
/// 編み目履歴の1エントリ。row は段削除時の振り直しで変更されるため mutable。
class StitchHistoryEntry {
  int row;
  final int position;      // 0 = 段開始マーカー
  final dynamic stitch;    // StitchDef（通常） / Map / String（旧データ互換）
  final DateTime timestamp;
  final bool isRowStart;

  bool get isMarker => position == 0;

  /// 保存形式は既存JSONと完全互換（キー名・値の型を変えない）
  Map<String, dynamic> toMap();
  factory StitchHistoryEntry.fromMap(Map<String, dynamic> map);
}
```

**互換性方針**: `CrochetProject.stitchHistory` は `List<Map>` のまま変更しない
（ストレージ・バックアップ・PDF出力への影響をゼロにする）。
変換はコントローラの load / save 境界でのみ行う。

#### 新規ファイル: `lib/controllers/project_controller.dart`

```dart
class ProjectController extends ChangeNotifier {
  // ---- 状態（外部には読み取り専用ビューを公開）----
  List<StitchHistoryEntry> get entries;   // UnmodifiableListView
  int get currentRow;                      // 履歴末尾から導出（空なら1）
  int get currentStitchCount;              // 現在段のposition!=0の数
  String projectId / projectTitle;
  bool get hasUnsavedChanges;
  SaveStatus get saveStatus;               // saved / saving / unsaved / none
  int? targetStitchesPerRow;               // B7: 段あたり目標目数
  List<dynamic> customStitches;            // 編み目設定キャッシュ（A4も参照）

  // ---- 操作（すべて notifyListeners で通知）----
  void loadFrom(CrochetProject? project);
  void addStitch(dynamic stitch);          // 戻り値: 目標到達したか（B7用）
  void removeLastStitch();
  void completeRow();
  List<StitchHistoryEntry> removeRow(int row); // 戻り値: スナップショット（B8用）
  void restoreSnapshot(List<StitchHistoryEntry> snapshot); // B8: 元に戻す
  void resetAll();
  void setTitle(String title);
  void setTargetStitchesPerRow(int? target);

  // ---- 保存（B6）----
  Future<SaveResult> saveNow({required bool isPremium});
  void scheduleAutosave({required bool isPremium}); // 3秒デバウンス
}
```

**設計ルール**
1. `entries` は外部から変更不可（`UnmodifiableListView`）。変更は必ずコントローラのメソッド経由
2. 変更メソッドは内部で **新しいリスト参照を作らない**が、`notifyListeners()` で通知するため
   子Widgetは `AnimatedBuilder` / `ListenableBuilder` 経由で確実に再構築される
   （didUpdateWidget比較に依存しない = 今回のバグの再発防止）
3. 段の振り直し・現在段/目数の再計算はコントローラ内に一本化
   （現在4箇所に重複しているロジックを1箇所に）

#### 画面側の変更
- `CrochetCounterScreen` は `ProjectController` を `initState` で生成し
  `ListenableBuilder` でぶら下がる。編み目データ関連のフィールドと約10メソッドを削除
- `StitchHistorySection` の props は `List<StitchHistoryEntry>` を受け取る形に変更。
  スクロール判定は従来どおり State 側記録値との比較（`_lastHistoryLength` 等）を維持

### 3.2 A2: AdService

#### 新規ファイル: `lib/services/ad_service.dart`

```dart
/// カウンター画面用の広告管理。画面のStateからライフサイクル委譲される。
class AdService {
  void loadBannerAd({required VoidCallback onChanged});
  void loadRewardedAd({required VoidCallback onChanged});
  bool get isBannerLoaded;
  Widget? get bannerWidget;   // AdWidgetキャッシュ
  double get bannerHeight;    // B5: 未ロードでも AdSize.banner.height を返す
  void showRewardedAd();
  void dispose();
}
```

- 広告ユニットID（iOS/Android）もこのファイルに集約
- `onChanged` コールバックで画面に再描画を依頼（mounted判定は画面側）

### 3.3 A3: busy状態のenum化

```dart
enum ScreenBusyState { idle, initializing, saving, deleting, processing }
```

- `_isSaving` / `_isProcessing` / `_isRemovingRow` / `_isInitializing` を置き換え
- オーバーレイ表示条件は `busy != idle`、文言は `switch (busy)` で決定
- `_isReloadingStitches`（オーバーレイ無しの再入ガード）はA4で消滅

### 3.4 A4: ポーリング再読み込みの廃止

`didChangeDependencies` の postFrame で毎回 `getProjects()` を読む処理を**削除**する。

編み目設定が変わる経路は以下の3つのみで、いずれも既に明示的なコールバック/戻り値で伝搬している:
1. パターングリッド長押し/編集ボタン → カスタマイズ画面 → `result == true` で再読込（既存）
2. カスタマイズ画面の `onProjectStitchesChanged` コールバック（既存）
3. プレミアム解約検知 → `_resetStitchSettingsToDefault`（既存）

→ ポーリングは冗長。削除により画面遷移ごとのストレージI/Oとハッシュ計算がなくなる。
`_calculateStitchesHash` は上記2の変更検知に必要なため**残す**（コントローラへ移動）。

### 3.5 A5: 履歴のListView.builder化

- 現状: `SingleChildScrollView(Column)` で全段を毎ビルド生成
- 変更: 段グループのリストを `ListView.builder` で構築（画面内の段のみ）
- `_rowKeys`（GlobalKey）は廃止:
  - `scrollToRow`（段ヘッダータップで自段へスクロール）は自段が見えている時しか
    発火しないため実質no-op → 削除
  - 段完成時の縦スクロールは `scrollController.animateTo(maxScrollExtent)` に変更
    （新しい段は常に末尾のため）
- Dismissible のキー・横スクロールコントローラ管理は現行ロジックを維持

### 3.6 A6: 小粒クリーンアップ

1. **`name` getter廃止**: `CrochetStitch.name` / `CustomStitch.name`（`nameJa`を返す独自getter）は
   enum標準の `name` を隠蔽し誤用を誘発。全呼び出し（`crochet_project.dart:43` の保存箇所と
   ハッシュ計算）を `nameJa` 明示に置換して削除。**保存されるJSON値は変わらない**
2. **SaveResult enum**: `StorageService.saveProject` の戻り値を
   `enum SaveResult { saved, limitReached, error }` に変更。
   呼び出し側（カウンター画面・ホーム画面2箇所）で「上限到達」と「保存失敗」のメッセージを正しく分岐
3. **共通Logger**: `lib/services/app_logger.dart` を新設し
   `Logger(level: kReleaseMode ? Level.warning : Level.debug)` を全サービス/画面で共用。
   リリースビルドでの全ログ出力（性能・情報漏えい）を止める

### 3.7 B1〜B5: 小粒UX

#### B1 触覚フィードバック
- `HapticFeedback.lightImpact()` を編み目追加時、`mediumImpact()` を段完成時に実行
- 設定キー `haptics_enabled`（デフォルトtrue）。読み書きは新設の `UserPrefsService`（下記）

#### B2 画面スリープ防止
- カウンター画面の `initState` で `WakelockPlus.enable()`、`dispose` で `disable()`
- 設定キー `keep_screen_on`（デフォルトtrue）。OFFなら有効化しない
- 設定画面にトグル2つ（B1/B2）を追加（`SwitchListTile`）

#### 新規ファイル: `lib/services/user_prefs_service.dart`
```dart
/// 軽量なユーザー設定（触覚・スリープ防止・ヒント表示済みフラグ）
class UserPrefsService {
  static Future<void> init();          // 起動時にロード（InitializationScreen）
  static bool hapticsEnabled;          // get/set（setは永続化も行う）
  static bool keepScreenOn;
  static bool rowDeleteHintShown;
}
```

#### B3 現在段・目数の大型表示
- 新規Widget `lib/widgets/counter_display.dart`
- 配置: カウンター画面の履歴セクションの直上（縦持ち）/ 右ペイン最上部（iPad横）
- 表示: `5段目  12目`（fontSize 32/bold、`FittedBox`で桁あふれ防止）
- B7実装後は目標があるとき `12 / 16目` + 細い `LinearProgressIndicator`
- タップで目標目数設定ダイアログ（B7）を開く
- 履歴ヘッダー内の小さい「◯段目 ◯目」表示は重複するため削除

#### B4 段削除スワイプの初回ヒント
- 条件: 履歴に1段以上あり、`rowDeleteHintShown == false`
- 表示: SnackBar「← 段を左にスワイプすると削除できます」を1回だけ表示しフラグ保存

#### B5 バナー広告の領域事前確保
- 非プレミアム時は常に `SizedBox(height: AdSize.banner.height)` を確保し、
  ロード完了までは空白（またはグレーのプレースホルダ）を表示
- ロード時の「下からガタッと押し上げ」をなくす

### 3.8 B6: 自動保存

- **発動条件**: 編み目追加/削除/段完成/段削除/リセット/タイトル変更の各操作後、
  3秒間操作がなければ保存（Timerデバウンス。コントローラ内）
- **対象**: **一度保存済みのプロジェクトのみ**（`widget.project != null` または手動保存済み）。
  新規未保存プロジェクトを自動保存すると、無題プロジェクトが無断で作られ
  無料プラン3件制限を勝手に消費してしまうため
- **UI**:
  - AppBarタイトル横に保存状態アイコン: `cloud_done`（保存済み）/ 回転スピナー（保存中）/ `cloud_upload`（未保存）
  - 自動保存の成功時はSnackBarを出さない（うるさいため）。失敗時のみ通知
- **既存フローとの整合**:
  - 手動保存ボタンは残す（安心感のため）。手動時のみ報酬広告ダイアログを表示
  - 戻る時の保存確認ダイアログは「未保存の新規プロジェクト」の場合のみ表示に変更
    （既存プロジェクトは自動保存されるため確認不要 → 離脱時に残っていれば同期保存）
- **競合対策**: `saveNow` 実行中はデバウンスタイマーを再スケジュール（後勝ち）

### 3.9 B7: 段ごとの目標目数

- **データ**: `CrochetProject.targetStitchesPerRow`（`int?`、JSONキー `targetStitchesPerRow`）。
  旧データには存在しない → `fromJson` で null 許容（後方互換）
- **設定UI**: 大型表示（B3）タップ → 数値入力ダイアログ（空欄で解除、1〜999）
- **表示**: 大型表示が `12 / 16目` + プログレスバーに変化
- **到達通知**: `addStitch` で目標到達した瞬間に `HapticFeedback.heavyImpact()` +
  SnackBar「目標の16目に到達しました 🎉」（1段につき1回）
- 段の目標を超えた場合は `17 / 16目` と赤字表示（編みすぎに気づける）

### 3.10 B8: 段削除の取り消し

- `ProjectController.removeRow` が削除前の全エントリのスナップショットを返す
- 削除SnackBarに `SnackBarAction(label: tr('undo'))` を付け、
  タップで `restoreSnapshot` → 段番号・現在段/目数も完全復元
- スナップショット保持は直近1件のみ（SnackBar表示中のみ有効。約4秒）

### 3.11 B9: 編み目名の ko/es/de ローカライズ

- **方式**: JSONの翻訳キーではなく、Dartの定数テーブル
  `lib/models/stitch_name_localizations.dart` を新設
  ```dart
  /// nameEn → { 'ko': ..., 'es': ..., 'de': ... }
  const Map<String, Map<String, String>> stitchNameTranslations = { ... };
  ```
- `StitchDef.getName(context)` の解決順を変更:
  `ja → nameJa` / `en → nameEn` / その他 → `テーブル[nameEn][locale] ?? nameEn`
- 対象: 基本6編み目 + プレミアム編み目リスト（約35種）
- ユーザーが独自に作成したカスタム編み目は対象外（ユーザーデータのため）
- 翻訳はかぎ針編みの標準用語（例: 細編み = single crochet = Feste Masche = punto bajo = 짧은뜨기）

### 3.12 B10: プロジェクトメモ

- **データ**: `CrochetProject.memo`（`String?`、JSONキー `memo`、後方互換）
- **UI**:
  - ホーム画面の編集メニュー（`_editProject`）に「メモを編集」を追加 →
    複数行TextFieldダイアログ（使用糸・針サイズ・メモ書き想定、500字上限）
  - メモがあるプロジェクトはカードのサブタイトル末尾に1行プレビュー（ellipsis）
  - カウンター画面のAppBarメニューからも閲覧/編集可能にする（任意・フェーズ4で判断）

### 3.13 B12: 統計画面

- 新規 `lib/screens/statistics_screen.dart`。設定画面に「統計」ListTileを追加
- 全プロジェクトの `stitchHistory` の `timestamp` から集計（読み取り専用・既存データのみで実現可能）:
  - 累計編み目数 / 累計段数 / プロジェクト数
  - 直近7日間の日別編み目数（棒グラフ。外部chartパッケージは使わず`Container`の高さで簡易描画）
  - 最も編んだ日
- パフォーマンス: 集計は `compute()`（isolate）は不要規模（数千件想定）だが、
  画面initState内の非同期処理として実行しローディング表示を挟む

---

## 4. データ・互換性への影響まとめ

| データ | 変更 | 互換性 |
|--------|------|--------|
| stitchHistory の JSON 形式 | **変更なし**（Entry⇔Map変換は境界のみ） | 完全互換 |
| CrochetProject | `targetStitchesPerRow`, `memo` フィールド追加 | 旧データはnull。旧アプリが新データを読んでも未知キーは無視される |
| SharedPreferences | 新キー: `haptics_enabled`, `keep_screen_on`, `row_delete_hint_shown` | 追加のみ |
| 翻訳ファイル | 新キー約25個 ×5言語（トグル・目標・統計・メモ・保存状態等） | 追加のみ |

マイグレーション処理は**不要**（すべて追加的変更）。

---

## 5. 実装フェーズと検証

### フェーズ1: 基盤リファクタ（A1〜A4）
最重要かつ他の全項目の土台。**このフェーズ単体で動作確認してから次へ進む。**
- 新規: `stitch_history_entry.dart` / `project_controller.dart` / `ad_service.dart`
- 改修: `crochet_counter_screen.dart`（大幅縮小）/ `stitch_history_section.dart`
- 検証: 編み目追加→自動スクロール / 段完成 / 1目戻す / 段削除 / リセット /
  保存→再読込で完全一致 / 旧データ読込

### フェーズ2: 小粒UX + 品質（A5, A6, B1〜B5)
- 新規: `counter_display.dart` / `user_prefs_service.dart` / `app_logger.dart`
- 改修: 設定画面（トグル追加）/ ストレージ（SaveResult）/ 各サービスのLogger差し替え
- 検証: 設定トグルの反映 / 長い履歴でのスクロール性能 / 広告未ロード時のレイアウト

### フェーズ3: 保存体験 + 目標（B6〜B8）
- 改修: コントローラ（autosave/target/undo）/ カウンター画面（インジケーター・ダイアログ）/
  `crochet_project.dart`（targetフィールド）
- 検証: 自動保存のデバウンス / 新規プロジェクトで自動保存されないこと /
  無料プラン上限時の挙動 / 取り消しの完全復元

### フェーズ4: 機能追加（B9, B10, B12）
- 相互に独立しているため並行実装可能（エージェント委任候補）
- 検証: 各言語での編み目名表示 / メモの保存・表示 / 統計の集計値の正しさ

### 全フェーズ共通
- `flutter analyze` エラー・警告0件
- `flutter test` 全件パス
- 手動確認: iPhone縦 / iPad横の両レイアウト、ダークモード、日本語/英語

---

## 6. リスクと対応

| リスク | 対応 |
|--------|------|
| フェーズ1のリファクタで挙動が変わる | JSON形式を不変に保ち、保存→再読込の一致を必ず確認。フェーズごとにコミット分離 |
| 自動保存が無料プランの保存制限と衝突 | 未保存の新規プロジェクトは自動保存対象外。上限到達時は自動保存を停止しインジケーターで通知 |
| 自動保存とアプリ強制終了のタイミング | デバウンス3秒は許容損失とする（従来は全損だったため大幅改善） |
| wakelockによる電池消費への不満 | デフォルトONだが設定でOFF可能。設定項目に説明文を付ける |
| ListView.builder化で段ジャンプ機能が消える | 現状の実機挙動が実質no-opであることをフェーズ2実装時に再確認してから削除 |
| 編み目名翻訳（B9）の用語誤り | かぎ針編みの標準用語対訳を使用。リリース前にネイティブチェック推奨と明記 |

---

## 7. 変更ファイル一覧（予定）

**新規（8ファイル）**
- lib/models/stitch_history_entry.dart
- lib/models/stitch_name_localizations.dart
- lib/controllers/project_controller.dart
- lib/services/ad_service.dart
- lib/services/user_prefs_service.dart
- lib/services/app_logger.dart
- lib/widgets/counter_display.dart
- lib/screens/statistics_screen.dart

**改修（主要）**
- lib/screens/crochet_counter_screen.dart（約1,275行 → 500行前後を想定）
- lib/widgets/stitch_history_section.dart
- lib/models/crochet_project.dart（フィールド2つ追加）
- lib/models/crochet_stitch.dart（getName解決順、name getter削除）
- lib/services/storage_service.dart（SaveResult）
- lib/screens/settings_screen.dart（トグル2つ + 統計導線）
- lib/screens/home_screen.dart（SaveResult対応、メモ編集）
- assets/lang/*.json（新キー約25個 ×5言語）

**依存追加**
- wakelock_plus ^1.4.0（追加済み）
