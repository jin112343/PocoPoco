const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");
const nodemailer = require("nodemailer");

admin.initializeApp();

// Secret Manager values are read only while handling an event.
// Configure GMAIL_APP_PASSWORD in the existing Firebase project before deployment.
const { defineSecret } = require("firebase-functions/params");
const gmailPassword = defineSecret("GMAIL_APP_PASSWORD");
const escapeHtml = (value) => String(value ?? "").replace(/[&<>"']/g, (char) => ({
  "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;",
}[char]));

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
exports.sendFeedbackNotification = functions.runWith({ secrets: [gmailPassword] }).firestore
    .document("feedback/{feedbackId}")
    .onCreate(async (snap, context) => {
      const feedback = snap.data();
      const feedbackId = context.params.feedbackId;

      const typeLabel = getTypeLabel(feedback.type);
      const password = gmailPassword.value();
      if (!password) throw new Error("GMAIL_APP_PASSWORD is not configured");
      const transporter = nodemailer.createTransport({
        service: "gmail",
        auth: { user: "mizoijin.0201@gmail.com", pass: password },
      });
      const createdAt = feedback.createdAt ?
        feedback.createdAt.toDate().toLocaleString("ja-JP", {
          timeZone: "Asia/Tokyo",
        }) : "不明";

      const mailOptions = {
        from: "PocoPoco App <mizoijin.0201@gmail.com>",
        to: "mizoijin.0201@gmail.com",
        subject: `【PocoPoco】新しいお問い合わせ: ${String(typeLabel).replace(/[\r\n]/g, " ")}`,
        html: `
          <div style="font-family: sans-serif; max-width: 600px; margin: 0 auto;">
            <h2 style="color: #EC407A;">新しいお問い合わせが届きました</h2>

            <table style="width: 100%; border-collapse: collapse; margin: 20px 0;">
              <tr>
                <td style="padding: 10px; border: 1px solid #ddd; background: #f9f9f9; width: 120px;"><strong>種類</strong></td>
                <td style="padding: 10px; border: 1px solid #ddd;">${escapeHtml(typeLabel)}</td>
              </tr>
              <tr>
                <td style="padding: 10px; border: 1px solid #ddd; background: #f9f9f9;"><strong>プラットフォーム</strong></td>
                <td style="padding: 10px; border: 1px solid #ddd;">${escapeHtml(feedback.platform || "不明")}</td>
              </tr>
              <tr>
                <td style="padding: 10px; border: 1px solid #ddd; background: #f9f9f9;"><strong>送信日時</strong></td>
                <td style="padding: 10px; border: 1px solid #ddd;">${escapeHtml(createdAt)}</td>
              </tr>
              <tr>
                <td style="padding: 10px; border: 1px solid #ddd; background: #f9f9f9;"><strong>ID</strong></td>
                <td style="padding: 10px; border: 1px solid #ddd; font-size: 12px; color: #666;">${escapeHtml(feedbackId)}</td>
              </tr>
            </table>

            <h3 style="color: #333;">メッセージ内容:</h3>
            <div style="padding: 15px; background: #f5f5f5; border-left: 4px solid #EC407A; white-space: pre-wrap;">
${escapeHtml(feedback.message)}
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
        console.error("Feedback email delivery failed");
        throw new Error("Feedback email delivery failed");
      }
    });
