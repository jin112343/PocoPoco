import 'package:flutter/material.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'terms_screen.dart';
import 'privacy_policy_screen.dart';
import 'upgrade_screen.dart';
import 'package:provider/provider.dart';
import '../services/subscription_provider.dart';
import '../services/backup_service.dart';
import 'package:easy_localization/easy_localization.dart';
import '../models/crochet_project.dart';

class SettingsScreen extends StatefulWidget {
  final bool isFromProject;
  final CrochetProject? currentProject;

  const SettingsScreen({
    super.key,
    this.isFromProject = false,
    this.currentProject,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _stitchSettingsChanged = false;

  void _launchMail(BuildContext context) async {
    final Uri emailLaunchUri = Uri.parse(
        'mailto:mizoijin.0201@gmail.com?subject=${Uri.encodeComponent('【PocoPoco】ご意見・お問い合わせ')}&body=${Uri.encodeComponent('ご意見・お問い合わせ内容をご記入ください。\n\n---\n')}');

    try {
      if (await launchUrl(emailLaunchUri,
          mode: LaunchMode.externalApplication)) {
        // 成功
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('contact_error'))),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('contact_error'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('設定'),
        backgroundColor: const Color(0xFFEC407A),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // 編み目設定が変更された場合でもホーム画面には戻らない
            Navigator.pop(context);
          },
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // トライアル期間表示
          Consumer<SubscriptionProvider>(
            builder: (context, subscriptionProvider, child) {
              if (subscriptionProvider.isInTrialPeriod &&
                  subscriptionProvider.isTrialActive) {
                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 24),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.timer,
                        color: Colors.white,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '無料トライアル期間中',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '残り${subscriptionProvider.trialDaysRemaining}日',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const UpgradeScreen(),
                            ),
                          );
                        },
                        icon: const Icon(
                          Icons.arrow_forward_ios,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
          Card(
            color: Colors.white,
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const UpgradeScreen(),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Icon(Icons.star_rounded, color: Colors.amber, size: 40),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tr('premium_plan'),
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.pink),
                          ),
                          const SizedBox(height: 6),
                          Text(tr('premium_features'),
                              style: const TextStyle(fontSize: 15)),
                          const SizedBox(height: 6),
                          Text(tr('premium_price'),
                              style: const TextStyle(
                                  fontSize: 14, color: Colors.grey)),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios, color: Colors.pink, size: 20),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          // データバックアップ・復元セクション
          Text(
            'データ管理',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            color: Colors.white,
            elevation: 1,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                ListTile(
                  leading:
                      const Icon(Icons.backup_outlined, color: Colors.blue),
                  title: const Text('データをバックアップ'),
                  subtitle: const Text('プロジェクトと編み目設定を保存'),
                  onTap: () => _exportBackup(context),
                ),
                const Divider(height: 1),
                ListTile(
                  leading:
                      const Icon(Icons.restore_outlined, color: Colors.green),
                  title: const Text('データを復元'),
                  subtitle: const Text('バックアップファイルから復元'),
                  onTap: () => _importBackup(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          ListTile(
            leading: const Icon(Icons.mail_outline),
            title: Text(tr('contact')),
            onTap: () => _launchMail(context),
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: Text(tr('terms')),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const TermsScreen(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: Text(tr('privacy')),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const PrivacyPolicyScreen(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.star_rate),
            title: Text(tr('rate_app')),
            onTap: () async {
              await _requestAppReview();
            },
          ),
          const SizedBox(height: 32),
          Center(
            child: Column(
              children: [
                Text(
                  tr('version'),
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 4),
                const Text(
                  'v1.0.6',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // バックアップをエクスポート
  Future<void> _exportBackup(BuildContext context) async {
    try {
      // ローディングダイアログを表示
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // バックアップを実行
      final success = await BackupService.exportBackup();

      // ローディングダイアログを閉じる
      if (mounted) {
        Navigator.of(context).pop();

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('バックアップを作成しました'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('バックアップの作成に失敗しました'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      // ローディングダイアログを閉じる
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('エラーが発生しました: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // バックアップをインポート
  Future<void> _importBackup(BuildContext context) async {
    try {
      // ファイルピッカーを開く
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null || result.files.isEmpty) {
        // ユーザーがキャンセルした場合
        return;
      }

      final file = File(result.files.single.path!);
      final jsonString = await file.readAsString();

      // バックアップファイルを検証
      final isValid = await BackupService.validateBackupFile(jsonString);
      if (!isValid) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('無効なバックアップファイルです'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }

      // 確認ダイアログを表示
      final shouldRestore = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('データを復元'),
          content: const Text(
            '現在のデータは上書きされます。\n本当に復元しますか？',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('キャンセル'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('復元'),
            ),
          ],
        ),
      );

      if (shouldRestore != true) {
        return;
      }

      // ローディングダイアログを表示
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );
      }

      // バックアップを復元
      final success = await BackupService.restoreBackup(jsonString);

      // ローディングダイアログを閉じる
      if (mounted) {
        Navigator.of(context).pop();

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('データを復元しました。アプリを再起動してください。'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('データの復元に失敗しました'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      // ローディングダイアログを閉じる（表示されている場合）
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('エラーが発生しました: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // iOSのみでアプリ内評価を実行
  Future<void> _requestAppReview() async {
    try {
      final inAppReview = InAppReview.instance;

      // iOSのみで評価機能を利用可能かチェック
      if (await inAppReview.isAvailable()) {
        // アプリ内評価をリクエスト
        await inAppReview.requestReview();

        // 評価完了後のフィードバック
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(tr('rate_thanks')),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        // 評価機能が利用できない場合（Androidなど）
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(tr('rate_ios_only')),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('rate_error')),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }
}
