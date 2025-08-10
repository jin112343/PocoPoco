import 'package:flutter/material.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:url_launcher/url_launcher.dart';
import 'stitch_customization_screen.dart';
import 'terms_screen.dart';
import 'privacy_policy_screen.dart';
import 'upgrade_screen.dart';
import 'home_screen.dart';
import 'package:provider/provider.dart';
import '../services/subscription_provider.dart';
import '../services/storage_service.dart';
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
                  'v1.0.1',
                  style: TextStyle(fontWeight: FontWeight.bold),
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
      print('アプリ評価エラー: $e');
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
