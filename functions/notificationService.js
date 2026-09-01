/**
 * notificationService.js
 *
 * Tüm email gönderme işlemleri bu modül içinde kapsüllenir.
 * Cloud Function (index.js) sadece kanal/gönderen metadata'sını ve
 * alıcı email adresini bu servise iletir; email içeriği ve SMTP
 * bağlantısı burada yönetilir.
 */

const nodemailer = require("nodemailer");
const {SENDER_EMAIL} = require("./config");

// ---------------------------------------------------------------------------
// Gmail SMTP transporter
// GMAIL_APP_PASSWORD ortam değişkeninden okunur (.env veya Firebase secrets).
// App Password: Google Hesabı → Güvenlik → 2 Adımlı Doğrulama → Uygulama Şifreleri
// ---------------------------------------------------------------------------
function createTransporter() {
  const appPassword = process.env.GMAIL_APP_PASSWORD;
  if (!appPassword) {
    throw new Error(
        "GMAIL_APP_PASSWORD ortam değişkeni tanımlı değil. " +
      ".env dosyasını veya Firebase secret'ını kontrol et.",
    );
  }

  return nodemailer.createTransport({
    service: "gmail",
    auth: {
      user: SENDER_EMAIL,
      pass: appPassword,
    },
  });
}

// ---------------------------------------------------------------------------
// Kanal tipine (real/test) göre email içeriğini oluşturur.
// ---------------------------------------------------------------------------
function buildEmailContent({channelType, channelId, senderNick, messageText}) {
  const testPrefix = channelType === "test" ? "[TEST] " : "";
  return {
    subject: `${testPrefix}${channelId} kanalında ${senderNick} sana mesaj yazdı`,
    text: `kanal: ${channelId}\n${senderNick}:\n\n${messageText}`,
    html: `<p><b>${channelId}</b> kanalında <b>${senderNick}:</b></p><p>${messageText}</p>`,
  };
}

// ---------------------------------------------------------------------------
// Ana gönderim fonksiyonu — index.js tarafından çağrılır.
//
// Parametreler:
//   channelId     : Firebase kanal adı (örn. "kanal1", "test2")
//   channelType   : "real" | "test" — sadece email içeriğini etkiler
//   senderNick    : Gönderenin gerçek nick adı (örn. "aziz")
//   messageText   : Gönderilen mesajın metni
//   recipientEmail : Alıcının Profil > Bildirim'de kaydettiği gmail adresi
// ---------------------------------------------------------------------------
async function sendNotificationEmail({
  channelId,
  channelType,
  senderNick,
  messageText,
  recipientEmail,
}) {
  const content = buildEmailContent({channelType, channelId, senderNick, messageText});
  const transporter = createTransporter();

  const mailOptions = {
    from: `"Live Chat" <${SENDER_EMAIL}>`,
    to: recipientEmail,
    subject: content.subject,
    text: content.text,
    html: content.html,
  };

  await transporter.sendMail(mailOptions);

  console.log(
      `[NotificationService] Email gönderildi → ${recipientEmail} ` +
    `(kanal: ${channelId}, tip: ${channelType}, gönderen: ${senderNick})`,
  );
}

module.exports = {sendNotificationEmail};
