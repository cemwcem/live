/**
 * config.js
 *
 * Kanal-bağımsız statik ayarlar burada tutulur. Kanal listesi artık
 * burada sabit değildir — herhangi bir kanal adı, index.js tarafından
 * dinamik olarak işlenir (bkz. resolveChannelType).
 */

// ---------------------------------------------------------------------------
// Eşik süreler (millisecond cinsinden)
// Gönderenin son mesajından bu süre geçmişse yeni mesajda bildirim tetiklenir.
// Kanal tipi (real/test) index.js → resolveChannelType() ile kanal adından
// belirlenir (adı "deneme" veya "test" ile başlıyorsa test, aksi halde real).
// ---------------------------------------------------------------------------
const THRESHOLDS = {
  real: 10 * 60 * 1000, // gerçek kanallar: 10 dakika
  test: 10 * 1000, // test kanalları:  10 saniye
};

// ---------------------------------------------------------------------------
// Email gönderici hesabı
// Bu adres Gmail SMTP ile oturum açacak adrestir.
// Şifre .env dosyasındaki GMAIL_APP_PASSWORD değişkeninden okunur.
// ---------------------------------------------------------------------------
const SENDER_EMAIL = "denememavis@gmail.com";

module.exports = {THRESHOLDS, SENDER_EMAIL};
