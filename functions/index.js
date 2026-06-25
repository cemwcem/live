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
 *   3. Kanal konfigürasyonu okunur; tanımlı değilse çıkılır.
 *   4. Gönderenin hangi rol (nick1/nick2) olduğu tespit edilir.
 *   5. Gönderenin lastSeen değeri Firebase'den okunur.
 *   6. Geçen süre eşik ile karşılaştırılır.
 *   7. Eşik aşıldıysa NotificationService aracılığıyla email gönderilir.
 *   8. Başarılı gönderim sonrası mesaja notifiedAt damgası yazılır.
 */

const {setGlobalOptions} = require("firebase-functions");
const {onValueCreated} = require("firebase-functions/v2/database");
const {logger} = require("firebase-functions");
const admin = require("firebase-admin");

const {CHANNELS, THRESHOLDS, EVENT_TYPES} = require("./config");
const {sendNotificationEmail} = require("./notificationService");

admin.initializeApp();

// Cloud Function başına maksimum eşzamanlı container sayısı.
// Yüksek trafik durumunda maliyeti kontrol altında tutar.
setGlobalOptions({maxInstances: 10});

// ---------------------------------------------------------------------------
// Gönderenin kanal konfigürasyonundaki rolünü döndürür.
// "nick1" veya "nick2" — tanımlı değilse null.
// ---------------------------------------------------------------------------
function getSenderRole(senderNick, channelConfig) {
  if (senderNick === channelConfig.nick1.name) return "nick1";
  if (senderNick === channelConfig.nick2.name) return "nick2";
  return null;
}

// ---------------------------------------------------------------------------
// Event tipini gönderen rolüne ve kanal tipine göre belirler.
// ---------------------------------------------------------------------------
function resolveEventType(senderRole, channelType) {
  if (channelType === "real") {
    // nick1 yazdı → nick2 bilgilendirilir (REAL_NOTIFY_NICK2)
    // nick2 yazdı → nick1 bilgilendirilir (REAL_NOTIFY_NICK1)
    return senderRole === "nick1" ?
      EVENT_TYPES.REAL_NOTIFY_NICK2 :
      EVENT_TYPES.REAL_NOTIFY_NICK1;
  }

  if (channelType === "test") {
    // Her iki kullanıcı da aynı event tipini tetikler
    return EVENT_TYPES.TEST_NOTIFY_NICK1;
  }

  return null;
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
      const messageText = message.text || "";
      // Mesaj timestamp'i lastSeen farkı hesabında referans olarak kullanılır.
      const messageTimestamp = message.timestamp || Date.now();

      // --- Kanal konfigürasyonu ---
      const channelConfig = CHANNELS[channelId];
      if (!channelConfig) {
        logger.info(`[${channelId}] Bildirim konfigürasyonunda tanımlı değil, atlanıyor.`);
        return null;
      }

      // --- Gönderen rolü ---
      const senderRole = getSenderRole(senderNick, channelConfig);
      if (!senderRole) {
        logger.info(
            `[${channelId}] Gönderen "${senderNick}" bu kanalda tanımlı değil, atlanıyor.`,
        );
        return null;
      }

      // --- lastSeen okuma ---
      // Flutter, sendMessage() içinde lastSeen'i mesaj yazılmadan ÖNCE okur
      // ve "senderLastSeen" alanı olarak mesaj payload'ına ekler.
      // Bu yaklaşım race condition'ı ortadan kaldırır:
      // _touchPresence() lastSeen'i anında günceller; DB'den okusaydık
      // güncellenmiş (yani "şu an") değeri alırdık → elapsed ≈ 0 → bildirim gitmezdi.
      const lastSeen = message.senderLastSeen || 0;

      // --- Eşik süre kontrolü ---
      const threshold = THRESHOLDS[channelConfig.type];
      const elapsed = messageTimestamp - lastSeen;

      if (lastSeen > 0 && elapsed <= threshold) {
        logger.info(
            `[${channelId}/${senderNick}] Eşik süresi geçmedi ` +
        `(${Math.round(elapsed / 1000)}s < ${Math.round(threshold / 1000)}s), bildirim atlanıyor.`,
        );
        return null;
      }

      // --- Event tipi ---
      const eventType = resolveEventType(senderRole, channelConfig.type);
      if (!eventType) {
        logger.warn(`[${channelId}] Event tipi belirlenemedi (type: ${channelConfig.type}).`);
        return null;
      }

      logger.info(
          `[${channelId}/${senderNick}] Bildirim tetiklendi → event: ${eventType}, ` +
      `geçen süre: ${Math.round(elapsed / 1000)}s`,
      );

      // --- Email gönder ---
      await sendNotificationEmail({
        eventType,
        channelId,
        senderRole,
        senderNick,
        messageText,
        channelConfig,
      });

      // --- Duplicate önleme damgası ---
      // Fonksiyon yeniden denense bile aynı mesaj için email tekrar gitmez.
      await event.data.ref.child("notifiedAt").set(Date.now());

      return null;
    },
);
