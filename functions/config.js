/**
 * config.js
 *
 * Tüm kanal, kullanıcı ve bildirim ayarları burada tanımlanır.
 * Yeni kanal eklemek için sadece CHANNELS nesnesine yeni bir giriş eklemek yeterlidir.
 * index.js veya notificationService.js'e dokunmaya gerek yoktur.
 */

// ---------------------------------------------------------------------------
// Eşik süreler (millisecond cinsinden)
// Gönderenin lastSeen değerinden bu süre geçmişse bildirim tetiklenir.
// ---------------------------------------------------------------------------
const THRESHOLDS = {
  real: 10 * 60 * 1000, // gerçek kanallar: 10 dakika
  test: 10 * 1000, // test kanalları:  10 saniye
};

// ---------------------------------------------------------------------------
// Üretilen event tipleri
// Bu sabitler index.js ve notificationService.js tarafından kullanılır;
// ileride yeni event tipi eklemek için buraya sabit eklenmeli.
// ---------------------------------------------------------------------------
const EVENT_TYPES = {
  REAL_NOTIFY_NICK1: "REAL_NOTIFY_NICK1", // nick2 yazdı → nick1'e bildirim
  REAL_NOTIFY_NICK2: "REAL_NOTIFY_NICK2", // nick1 yazdı → nick2'ye bildirim
  TEST_NOTIFY_NICK1: "TEST_NOTIFY_NICK1", // test kanalında herhangi biri yazdı
};

// ---------------------------------------------------------------------------
// Kanal konfigürasyonları
//
// Her kanalda:
//   type    : "real" | "test"   → eşik süresini belirler
//   nick1   : { name, email }   → slot1 kullanıcısı ve bildirim alacağı adres
//   nick2   : { name, email }   → slot2 kullanıcısı ve bildirim alacağı adres
//
// Kural (her iki tip için çapraz bildirim geçerlidir):
//   - nick1 yazarsa → nick2.email'e bildirim gönderilir
//   - nick2 yazarsa → nick1.email'e bildirim gönderilir
//   Fark: real → 10 dakika eşik + REAL_NOTIFY_* event
//         test → 10 saniye eşik + TEST_NOTIFY_NICK1 event
// ---------------------------------------------------------------------------
const CHANNELS = {
  // --- Gerçek kanallar ---
  buldum: {
    type: "real",
    nick1: {name: "aziz", email: "denememavis@gmail.com"},
    nick2: {name: "Esin", email: "essiinnnes@gmail.com"},
  },
  kanal2: {
    type: "real",
    nick1: {name: "ahmet", email: "NICK1_KANAL2_EMAIL@example.com"},
    nick2: {name: "mehmet", email: "NICK2_KANAL2_EMAIL@example.com"},
  },

  // --- Test kanalları ---
  // nick1.email test bildirimlerinin gideceği adresi tutar.
  deneme: {
    type: "test",
    nick1: {name: "aziz", email: "denememavis@gmail.com"},
    nick2: {name: "muro", email: "denememavis@gmail.com"},
  },
  deneme1: {
    type: "test",
    nick1: {name: "aziz", email: "denememavis@gmail.com"},
    nick2: {name: "muro", email: "denememavis@gmail.com"},
  },
};

// ---------------------------------------------------------------------------
// Email gönderici hesabı
// Bu adres Gmail SMTP ile oturum açacak adrestir.
// Şifre .env dosyasındaki GMAIL_APP_PASSWORD değişkeninden okunur.
// ---------------------------------------------------------------------------
const SENDER_EMAIL = "denememavis@gmail.com";

module.exports = {THRESHOLDS, EVENT_TYPES, CHANNELS, SENDER_EMAIL};
