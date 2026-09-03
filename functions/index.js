/**
 * index.js
 *
 * Firebase Cloud Functions giriş noktası.
 *
 * Trigger: /channels/{channelId}/messages/{messageId} → onCreate
 *
 * Akış:
 *   1. Yeni mesaj oluşturulduğunda tetiklenir.
 *   2. Duplicate kontrolü yapılır (aynı mesaj için tekrar çalışmaz).
 *   3. Gönderenin slotId'sinden karşı taraf (alıcı) slotId'si belirlenir.
 *   4. Gönderenin son mesajından bu yana geçen süre eşik ile karşılaştırılır.
 *   5. Eşik aşıldıysa alıcının Profil'de kaydettiği bildirim email adresi okunur.
 *   6. Alıcı bir email tanımlamışsa NotificationService ile email gönderilir.
 *   7. Başarılı gönderim sonrası mesaja notifiedAt damgası yazılır.
 *
 * NOT: Kanal adı serbest metin (Flutter tarafında Giriş ekranında kullanıcı
 * istediği kanalı yazabiliyor), bu yüzden burada sabit bir kanal whitelist'i
 * YOKTUR — her kanal aynı mantıkla işlenir. Kanal tipi (real/test) sadece
 * eşik süresini ve email içeriğini etkiler, resolveChannelType() ile kanal
 * adından türetilir.
 */

const {setGlobalOptions} = require("firebase-functions");
const {onValueCreated} = require("firebase-functions/v2/database");
const {logger} = require("firebase-functions");
const admin = require("firebase-admin");

const {THRESHOLDS} = require("./config");
const {sendNotificationEmail} = require("./notificationService");

admin.initializeApp();

// Cloud Function başına maksimum eşzamanlı container sayısı.
// Yüksek trafik durumunda maliyeti kontrol altında tutar.
setGlobalOptions({maxInstances: 10});

// ---------------------------------------------------------------------------
// Kanal tipini kanal adından türetir ("real" | "test").
// Adı "deneme" veya "test" ile başlayan kanallar test kanalı sayılır
// (kısa eşik süresi, [TEST] ön ekli email); diğer tüm kanallar real'dir.
// ---------------------------------------------------------------------------
function resolveChannelType(channelId) {
  const normalized = (channelId || "").toLowerCase();
  if (normalized.startsWith("deneme") || normalized.startsWith("test")) {
    return "test";
  }
  return "real";
}

// ---------------------------------------------------------------------------
// Ana Cloud Function
// Trigger: /channels/{channelId}/messages/{messageId} — onCreate
//
// NOT: Bu path Flutter kodundaki FirebaseService.channelReference() fonksiyonunun
// kullandığı "channels/{channelName}" yapısıyla eşleşmektedir.
// ---------------------------------------------------------------------------
exports.onNewMessage = onValueCreated(
    "/channels/{channelId}/messages/{messageId}",
    async (event) => {
      const {channelId, messageId} = event.params;
      const message = event.data.val();

      if (!message) {
        logger.warn(`[${messageId}] Mesaj verisi boş, atlanıyor.`);
        return null;
      }

      // --- Duplicate önleme ---
      // Fonksiyon yeniden çalıştırılırsa (Firebase retry) tekrar email gitmesin.
      if (message.notifiedAt) {
        logger.info(`[${messageId}] Daha önce bildirim gönderilmiş, atlanıyor.`);
        return null;
      }

      const senderNick = message.senderNick;
      const messageText = message.text ||
        (message.attachmentUrl ? "📎 Dosya/resim gönderdi" : "");
      // Mesaj timestamp'i lastSeen farkı hesabında referans olarak kullanılır.
      const messageTimestamp = message.timestamp || Date.now();

      // --- Gönderen/alıcı slot'ları ---
      // Her kanalda tam olarak iki katılımcı slotu vardır: slot1 ve slot2.
      const senderSlotId = message.senderSlotId;
      if (senderSlotId !== "slot1" && senderSlotId !== "slot2") {
        logger.warn(`[${channelId}] Mesajda geçerli bir senderSlotId yok, atlanıyor.`);
        return null;
      }
      const recipientSlotId = senderSlotId === "slot1" ? "slot2" : "slot1";

      // --- lastSeen okuma ---
      // Flutter, sendMessage() içinde lastSeen'i mesaj yazılmadan ÖNCE okur
      // ve "senderLastSeen" alanı olarak mesaj payload'ına ekler.
      // Bu yaklaşım race condition'ı ortadan kaldırır:
      // _touchPresence() lastSeen'i anında günceller; DB'den okusaydık
      // güncellenmiş (yani "şu an") değeri alırdık → elapsed ≈ 0 → bildirim gitmezdi.
      const lastSeen = message.senderLastSeen || 0;

      // --- Eşik süre kontrolü ---
      const channelType = resolveChannelType(channelId);
      const threshold = THRESHOLDS[channelType];
      const elapsed = messageTimestamp - lastSeen;

      if (lastSeen > 0 && elapsed <= threshold) {
        logger.info(
            `[${channelId}/${senderNick}] Eşik süresi geçmedi ` +
        `(${Math.round(elapsed / 1000)}s < ${Math.round(threshold / 1000)}s), bildirim atlanıyor.`,
        );
        return null;
      }

      // --- Alıcının Profil ekranından kaydettiği bildirim email'i ---
      // Kullanıcı Profil > Bildirim altında kendi gmail adresini girip
      // /channels/{channelId}/slots/{slotId}/notificationEmail alanına yazıyor.
      // Alıcı bunu hiç ayarlamamışsa gönderilecek bir adres yoktur, atlanır.
      const recipientEmailSnap = await admin
          .database()
          .ref(`/channels/${channelId}/slots/${recipientSlotId}/notificationEmail`)
          .get();
      const recipientEmail = recipientEmailSnap.exists() ? recipientEmailSnap.val() : null;

      if (!recipientEmail) {
        logger.info(
            `[${channelId}] Alıcının (${recipientSlotId}) bildirim email adresi tanımlı değil, ` +
        `atlanıyor.`,
        );
        return null;
      }

      logger.info(
          `[${channelId}/${senderNick}] Bildirim tetiklendi → tip: ${channelType}, ` +
      `geçen süre: ${Math.round(elapsed / 1000)}s, alıcı: ${recipientEmail}`,
      );

      // --- Email gönder ---
      await sendNotificationEmail({
        channelId,
        channelType,
        senderNick,
        messageText,
        recipientEmail,
      });

      // --- Duplicate önleme damgası ---
      // Fonksiyon yeniden denense bile aynı mesaj için email tekrar gitmez.
      await event.data.ref.child("notifiedAt").set(Date.now());

      return null;
    },
);
