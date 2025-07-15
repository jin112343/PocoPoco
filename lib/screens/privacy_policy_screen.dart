import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('privacy')),
        backgroundColor: Color(0xFFEC407A),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr('privacy'),
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              Text(
                'プライバシーポリシー\n\n'
                '本アプリは、ユーザーのプライバシーを尊重し、個人情報の保護に努めます。\n\n'
                '1. 収集する情報\n'
                '・個人情報の収集は行いません。\n'
                '・アプリ内で作成された編み物プロジェクトデータは、デバイス内に保存されます。\n'
                '・サブスクリプション情報はApp Storeを通じて管理されます。\n\n'
                '2. データの使用\n'
                '・編み物プロジェクトデータは、アプリの機能提供のみに使用されます。\n'
                '・広告表示や分析のために一部データが外部サービスに送信される場合があります。\n'
                '・取得した情報は適切に管理し、第三者に提供することはありません。\n\n'
                '3. データの保存\n'
                '・ユーザーデータはデバイス内に安全に保存されます。\n'
                '・クラウド同期機能はありません。\n\n'
                '4. 外部サービス\n'
                '・Google Mobile Ads：広告表示のため\n'
                '・App Store：サブスクリプション管理のため\n\n'
                '5. お問い合わせ\n'
                '・プライバシーに関するお問い合わせは、アプリ内の設定画面からご連絡ください。\n\n'
                '内容は予告なく変更される場合があります。\n\n'
                '最終更新日：2024年12月',
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
