/**
 * notificationService.js
 *
 * Tüm email gönderme işlemleri bu modül içinde kapsüllenir.
 * Cloud Function (index.js) sadece event tipini ve gerekli metadata'yı
 * bu servise iletir; email içeriği ve SMTP bağlantısı burada yönetilir.
 */

const nodemailer = require("nodemailer");
const {SENDER_EMAIL, EVENT_TYPES} = require("./config");

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
// Event tipine göre email içeriğini oluşturur.
// Yeni event tipi eklenirse buraya yeni bir case eklenmeli.
// ---------------------------------------------------------------------------
function buildEmailContent({eventType, channelId, senderNick, messageText}) {
  switch (eventType) {
    case EVENT_TYPES.REAL_NOTIFY_NICK1:
      return {
        subject: `${channelId} kanalında ${senderNick} sana mesaj yazdı`,
        text: `kanal: ${channelId}\n${senderNick}:\n\n${messageText}`,
        html: `<p><b>${channelId}</b> kanalında <b>${senderNick}:</b></p><p>${messageText}</p>`,
      };

    case EVENT_TYPES.REAL_NOTIFY_NICK2:
      return {
        subject: `${channelId} kanalında ${senderNick} sana mesaj yazdı`,
        text: `kanal: ${channelId}\n${senderNick}:\n\n${messageText}`,
        html: `<p><b>${channelId}</b> kanalında <b>${senderNick}:</b></p><p>${messageText}</p>`,
      };

    case EVENT_TYPES.TEST_NOTIFY_NICK1:
      return {
        subject: `[TEST] ${channelId} kanalında ${senderNick} mesaj yazdı`,
        text: `kanal: ${channelId}\n${senderNick}:\n\n${messageText}`,
        html: `<p><b>${channelId}</b> kanalında <b>${senderNick}:</b></p><p>${messageText}</p>`,
      };

    default:
      return {
        subject: "Bildirim",
        text: `Yeni bir event: ${eventType}\n\n${messageText}`,
        html: `<p>Yeni bir event: <code>${eventType}</code></p><p>${messageText}</p>`,
      };
  }
}

// ---------------------------------------------------------------------------
// Alıcı email adresini event tipine ve kanal konfigürasyonuna göre seçer.
// ---------------------------------------------------------------------------
function resolveRecipientEmail({eventType, channelConfig, senderRole}) {
  if (eventType === EVENT_TYPES.TEST_NOTIFY_NICK1) {
    // Test kanallarında da çapraz bildirim yapılır:
    // nick1 yazdı → nick2.email, nick2 yazdı → nick1.email
    return senderRole === "nick1" ?
      channelConfig.nick2.email :
      channelConfig.nick1.email;
  }

  if (eventType === EVENT_TYPES.REAL_NOTIFY_NICK1) {
    // nick2 yazdı → nick1 bilgilendirilecek
    return channelConfig.nick1.email;
  }

  if (eventType === EVENT_TYPES.REAL_NOTIFY_NICK2) {
    // nick1 yazdı → nick2 bilgilendirilecek
    return channelConfig.nick2.email;
  }

  return null;
}

// ---------------------------------------------------------------------------
// Ana gönderim fonksiyonu — index.js tarafından çağrılır.
//
// Parametreler:
//   eventType     : EVENT_TYPES sabitlerinden biri
//   channelId     : Firebase kanal adı (örn. "kanal1", "test2")
//   senderRole    : "nick1" veya "nick2"
//   senderNick    : Gönderenin gerçek nick adı (örn. "aziz")
//   messageText   : Gönderilen mesajın metni
//   channelConfig : config.js'deki kanal nesnesi
// ---------------------------------------------------------------------------
async function sendNotificationEmail({
  eventType,
  channelId,
  senderRole,
  senderNick,
  messageText,
  channelConfig,
}) {
  const recipientEmail = resolveRecipientEmail({
    eventType,
    channelConfig,
    senderRole,
  });

  if (!recipientEmail) {
    console.warn(`[NotificationService] ${eventType} için alıcı email bulunamadı.`);
    return;
  }

  const content = buildEmailContent({eventType, channelId, senderNick, messageText});
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
    `(event: ${eventType}, kanal: ${channelId}, gönderen: ${senderRole})`,
  );
}

module.exports = {sendNotificationEmail};
