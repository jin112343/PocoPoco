const functions = require("firebase-functions");
const admin = require("firebase-admin");
const nodemailer = require("nodemailer");

admin.initializeApp();

// Gmailのトランスポーター設定
// 注意: アプリパスワードを使用する必要があります
const transporter = nodemailer.createTransport({
  service: "gmail",
  auth: {
    user: "mizoijin.0201@gmail.com",
    pass: functions.config().gmail.password, // firebase functions:config:set gmail.password="YOUR_APP_PASSWORD"
  },
});

// お問い合わせの種類を日本語に変換
function getTypeLabel(type) {
  switch (type) {
    case "bug":
      return "バグ報告";
    case "feature_request":
      return "機能改善";
    case "other":
      return "その他";
    default:
      return type;
  }
}

// Firestoreにfeedbackが追加されたときにメール送信
exports.sendFeedbackNotification = functions.firestore
    .document("feedback/{feedbackId}")
    .onCreate(async (snap, context) => {
      const feedback = snap.data();
      const feedbackId = context.params.feedbackId;

      const typeLabel = getTypeLabel(feedback.type);
      const createdAt = feedback.createdAt ?
        feedback.createdAt.toDate().toLocaleString("ja-JP", {
          timeZone: "Asia/Tokyo",
        }) : "不明";

      const mailOptions = {
        from: "PocoPoco App <mizoijin.0201@gmail.com>",
        to: "mizoijin.0201@gmail.com",
        subject: `【PocoPoco】新しいお問い合わせ: ${typeLabel}`,
        html: `
          <div style="font-family: sans-serif; max-width: 600px; margin: 0 auto;">
            <h2 style="color: #EC407A;">新しいお問い合わせが届きました</h2>

            <table style="width: 100%; border-collapse: collapse; margin: 20px 0;">
              <tr>
                <td style="padding: 10px; border: 1px solid #ddd; background: #f9f9f9; width: 120px;"><strong>種類</strong></td>
                <td style="padding: 10px; border: 1px solid #ddd;">${typeLabel}</td>
              </tr>
              <tr>
                <td style="padding: 10px; border: 1px solid #ddd; background: #f9f9f9;"><strong>プラットフォーム</strong></td>
                <td style="padding: 10px; border: 1px solid #ddd;">${feedback.platform || "不明"}</td>
              </tr>
              <tr>
                <td style="padding: 10px; border: 1px solid #ddd; background: #f9f9f9;"><strong>送信日時</strong></td>
                <td style="padding: 10px; border: 1px solid #ddd;">${createdAt}</td>
              </tr>
              <tr>
                <td style="padding: 10px; border: 1px solid #ddd; background: #f9f9f9;"><strong>ID</strong></td>
                <td style="padding: 10px; border: 1px solid #ddd; font-size: 12px; color: #666;">${feedbackId}</td>
              </tr>
            </table>

            <h3 style="color: #333;">メッセージ内容:</h3>
            <div style="padding: 15px; background: #f5f5f5; border-left: 4px solid #EC407A; white-space: pre-wrap;">
${feedback.message}
            </div>

            <p style="color: #999; font-size: 12px; margin-top: 30px;">
              このメールはPocoPocoアプリから自動送信されました。
            </p>
          </div>
        `,
      };

      try {
        await transporter.sendMail(mailOptions);
        console.log("Feedback notification email sent successfully");
        return null;
      } catch (error) {
        console.error("Error sending email:", error);
        return null;
      }
    });
