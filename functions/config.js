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
// "Karşı taraf çevrimiçi olunca bildir" ayarı
// Ayar: /channels/{kanal}/slots/{slotId}/onlineNotification = {enabled, hours}
// Profil ekranında 1/2/4/8/24 saat seçilebilir; Firebase'den elle başka
// pozitif bir saat değeri de girilebilir. Geçersiz değerde varsayılan kullanılır.
// Test kanallarında süre ONLINE_TEST_DIVISOR'a bölünür (1 saat → 36 saniye).
// Flutter: profile_screen.dart → _onlineTestDivisor ile aynı tutulmalı.
// ---------------------------------------------------------------------------
const ONLINE_DEFAULT_HOURS = 1;
const ONLINE_TEST_DIVISOR = 100;

// ---------------------------------------------------------------------------
// Email gönderici hesabı
// Bu adres Gmail SMTP ile oturum açacak adrestir.
// Şifre .env dosyasındaki GMAIL_APP_PASSWORD değişkeninden okunur.
// ---------------------------------------------------------------------------
const SENDER_EMAIL = "denememavis@gmail.com";

module.exports = {
  THRESHOLDS,
  ONLINE_DEFAULT_HOURS,
  ONLINE_TEST_DIVISOR,
  SENDER_EMAIL,
};
