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
import 'package:easy_localization/easy_localization.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

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
            // 編み目設定が変更された場合は結果を返してからホーム画面に遷移
            if (_stitchSettingsChanged) {
              // まず結果を返す
              Navigator.of(context).pop(true);
              // 少し待ってからホーム画面に遷移
              Future.delayed(const Duration(milliseconds: 100), () {
                if (context.mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const HomeScreen(),
                    ),
                    (route) => false,
                  );
                }
              });
            } else {
              Navigator.pop(context);
            }
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
            leading: const Icon(Icons.edit),
            title: Text(tr('edit_stitch_buttons')),
            subtitle: Text(tr('edit_stitch_buttons_desc')),
            enabled: context.watch<SubscriptionProvider>().isPremium,
            onTap: () async {
              final isPremium = context.read<SubscriptionProvider>().isPremium;
              if (isPremium) {
                final result = await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const StitchCustomizationScreen(),
                  ),
                );

                // 編み目設定が変更された場合
                if (result == true) {
                  setState(() {
                    _stitchSettingsChanged = true;
                  });
                }
              } else {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(tr('premium_only')),
                    content: Text(tr('premium_only_message')),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(tr('ok')),
                      ),
                    ],
                  ),
                );
              }
            },
          ),
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
              final inAppReview = InAppReview.instance;
              if (await inAppReview.isAvailable()) {
                inAppReview.requestReview();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(tr('rate_app')),
                  ),
                );
              }
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
                  'v1.0.0',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
