import 'package:flutter/material.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:flutter/foundation.dart';
import 'terms_screen.dart';
import 'privacy_policy_screen.dart';
import 'upgrade_screen.dart';
import 'feedback_dialog.dart';
import 'package:provider/provider.dart';
import '../services/subscription_provider.dart';
import '../services/theme_provider.dart';
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
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  void _showFeedbackDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const FeedbackDialog(),
    );
  }

  void _showThemeModeDialog(BuildContext context, ThemeProvider themeProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('dark_mode')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<ThemeModeSetting>(
              title: Text(tr('theme_system')),
              value: ThemeModeSetting.system,
              groupValue: themeProvider.themeModeSetting,
              onChanged: (value) {
                if (value != null) {
                  themeProvider.setThemeMode(value);
                  Navigator.pop(context);
                }
              },
            ),
            RadioListTile<ThemeModeSetting>(
              title: Text(tr('theme_light')),
              value: ThemeModeSetting.light,
              groupValue: themeProvider.themeModeSetting,
              onChanged: (value) {
                if (value != null) {
                  themeProvider.setThemeMode(value);
                  Navigator.pop(context);
                }
              },
            ),
            RadioListTile<ThemeModeSetting>(
              title: Text(tr('theme_dark')),
              value: ThemeModeSetting.dark,
              groupValue: themeProvider.themeModeSetting,
              onChanged: (value) {
                if (value != null) {
                  themeProvider.setThemeMode(value);
                  Navigator.pop(context);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('設定'),
        backgroundColor: isDarkMode ? const Color(0xFFAD1457) : const Color(0xFFEC407A),
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
            color: isDarkMode ? const Color(0xFF2D2D2D) : Colors.white,
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
                    const Icon(Icons.star_rounded, color: Colors.amber, size: 40),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tr('premium_plan'),
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isDarkMode ? const Color(0xFFEC407A) : Colors.pink),
                          ),
                          const SizedBox(height: 6),
                          Text(tr('premium_features'),
                              style: TextStyle(
                                fontSize: 15,
                                color: isDarkMode ? Colors.white : Colors.black87,
                              )),
                          const SizedBox(height: 6),
                          Text(tr('premium_price'),
                              style: TextStyle(
                                  fontSize: 14,
                                  color: isDarkMode ? Colors.grey[400] : Colors.grey)),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios,
                        color: isDarkMode ? const Color(0xFFEC407A) : Colors.pink,
                        size: 20),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          Consumer<ThemeProvider>(
            builder: (context, themeProvider, child) {
              String themeModeText;
              switch (themeProvider.themeModeSetting) {
                case ThemeModeSetting.system:
                  themeModeText = tr('theme_system');
                  break;
                case ThemeModeSetting.light:
                  themeModeText = tr('theme_light');
                  break;
                case ThemeModeSetting.dark:
                  themeModeText = tr('theme_dark');
                  break;
              }
              return ListTile(
                leading: const Icon(Icons.dark_mode_outlined),
                title: Text(tr('dark_mode')),
                subtitle: Text(themeModeText),
                onTap: () => _showThemeModeDialog(context, themeProvider),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.mail_outline),
            title: Text(tr('contact')),
            onTap: () => _showFeedbackDialog(context),
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
                  style: TextStyle(color: isDarkMode ? Colors.grey[400] : Colors.grey),
                ),
                const SizedBox(height: 4),
                Text(
                  defaultTargetPlatform == TargetPlatform.android ? 'v1.0.7' : 'v2.0.0',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
          _showDialog(tr('rate_thanks'));
        }
      } else {
        // 評価機能が利用できない場合（Androidなど）
        if (mounted) {
          _showDialog(tr('rate_ios_only'));
        }
      }
    } catch (e) {
      if (mounted) {
        _showDialog(tr('rate_error'));
      }
    }
  }
}
