# Flutter Gerçek Zamanlı Sohbet Uygulaması — VS Code Asistan Komutu

---

## PROJE TANIMI

Flutter ile web tabanlı (sonradan mobil uyumlu) 2 kişilik gerçek zamanlı sohbet uygulaması geliştir. Backend olarak Firebase Realtime Database kullanılacak. State management için Riverpod kullanılacak.

---

## MİMARİ

### Proje Klasör Yapısı

```
lib/
├── core/
│   ├── firebase/
│   │   └── firebase_service.dart
│   ├── models/
│   │   ├── channel_model.dart
│   │   ├── message_model.dart
│   │   └── slot_model.dart
│   └── utils/
│       └── hash_utils.dart
├── features/
│   ├── auth/
│   │   ├── data/
│   │   │   └── auth_repository.dart
│   │   ├── domain/
│   │   │   └── auth_service.dart
│   │   └── presentation/
│   │       ├── login_screen.dart
│   │       └── login_provider.dart
│   └── chat/
│       ├── data/
│       │   └── chat_repository.dart
│       ├── domain/
│       │   └── chat_service.dart
│       └── presentation/
│           ├── chat_screen.dart
│           ├── chat_provider.dart
│           ├── widgets/
│           │   ├── message_history.dart
│           │   ├── live_typing_box.dart
│           │   └── cursor_badge.dart
└── main.dart
```

---

## FIREBASE REALTIME DATABASE ŞEMASI

Uygulama bu şemayı otomatik oluşturmalı. Kullanıcının Firebase'de elle açması gereken bir node yoktur.

```json
{
  "channels": {
    "{kanalAdi}": {
      "meta": {
        "passwordHash": "sha256_hash_string",
        "createdAt": 1718000000
      },
      "slots": {
        "slot1": {
          "nick": "ali",
          "sessionId": "uuid_string",
          "online": true,
          "lastSeen": 1718000100
        },
        "slot2": {
          "nick": "veli",
          "sessionId": "uuid_string",
          "online": false,
          "lastSeen": 1718000090
        }
      },
      "liveTyping": {
        "slot1": "kullanıcının şu an yazdığı metin",
        "slot2": "diğerinin şu an yazdığı metin"
      },
      "messages": {
        "{messageId}": {
          "senderNick": "ali",
          "text": "Mesaj metni",
          "timestamp": 1718000050
        }
      }
    }
  }
}
```

---

## GİRİŞ EKRANI (login_screen.dart)

### Alanlar
- Nick (text field)
- Şifre (text field, obscure)
- Kanal Adı (text field)
- Giriş butonu

### Mantık — Sırayla Şu Adımlar İzlenecek

1. Firebase'de `/channels/{kanalAdi}/meta` kontrol et.
2. **Node yoksa** → yeni kanal oluştur:
   - Şifreyi SHA-256 ile hash'le, `passwordHash` olarak yaz.
   - `createdAt` timestamp yaz.
   - Kullanıcıyı `slot1`'e yerleştir.
   - localStorage'a `{kanalAdi}_{nick}_sessionId` olarak UUID kaydet.
3. **Node varsa** → girilen şifreyi hash'le, `passwordHash` ile karşılaştır:
   - Eşleşmiyorsa → "Yanlış şifre" hatası göster, giriş yok.
   - Eşleşiyorsa → slot kontrolüne geç.
4. **Slot kontrolü:**
   - Slot1 ve slot2'ye bak.
   - Kullanıcının nick'i veya sessionId'si bir slotta varsa → o slota `online: true` yaz, aynı slota geri bağlan.
   - Slot1 boşsa → slot1'e yerleş.
   - Slot1 doluysa slot2 boşsa → slot2'ye yerleş.
   - Her iki slot da doluysa (online: true) → "Kanal dolu" hatası göster, giriş yok.
   - Bir slot `online: false` ise (düşmüş kullanıcı) ve nick/sessionId eşleşmiyorsa → o slot reserved sayılır, giriş yok.
5. Başarılı girişte chat ekranına yönlendir, kanal adı + nick + slotId parametrelerini taşı.

### SessionId
- Browser localStorage'a kaydedilir: anahtar = `session_{kanalAdi}_{nick}`, değer = UUID.
- Sayfa yenilense bile aynı sessionId okunur, kullanıcı kendi slotuna döner.

---

## SOHBET EKRANI (chat_screen.dart)

### Genel Düzen (yukarıdan aşağıya)

```
┌─────────────────────────────────┐
│  Üst Bar: kanal adı, bağlantı  │
├─────────────────────────────────┤
│                                 │
│  MESAJ GEÇMİŞİ                 │
│  (scroll ile yukarı → eski     │
│   mesajlar lazy load ile gelir) │
│                                 │
├─────────────────────────────────┤
│  KARŞI TARAFIN CANLI YAZISI    │
│  (üst yazma kutusu)            │
│  imleç rozeti: karşı nick      │
│  gönder butonu: pasif (disabled│
│  sadece o kullanıcı gönderebilir│
├─────────────────────────────────┤
│  KENDİ CANLI YAZIN             │
│  (alt yazma kutusu)            │
│  imleç rozeti: kendi nick      │
│  gönder butonu: aktif          │
└─────────────────────────────────┘
```

### Canlı Yazma Kutularının Davranışı

- Her iki kutu da `TextField` (veya `TextFormField`) olacak.
- Her iki kutu da her iki kullanıcı tarafından da **odaklanılabilir ve yazılabilir** (focus ve edit her ikisinde de mümkün).
- `onChanged` callback'i tetiklendiğinde, hangi kutuysa o kutunun sahibinin Firebase liveTyping node'unu güncelle (`/channels/{kanalAdi}/liveTyping/{slotId}`).
- Firebase'den karşı tarafın liveTyping değeri `Stream` ile dinlenir ve anlık güncellenir — her harf, her silme, her düzeltme anında karşıya yansır.
- **İmleç rozeti (cursor badge):** Hangi kullanıcının imleci hangi kutudaysa, o kutunun üst köşesinde küçük renkli bir isim rozeti gösterilir. Slot1 için yeşil, slot2 için kırmızı renk.
- **Gönder butonu yetki kuralı:**
  - Alt kutu (kendi alanı) → gönder butonu aktif, Enter/gönder çalışır.
  - Üst kutu (karşının alanı) → gönder butonu disabled (görünür ama tıklanamaz). Tooltip: "Bu alanı sadece {karşıNick} gönderebilir".
  - Kullanıcı karşının alanına yazıp Enter'a basarsa hiçbir şey olmaz, engellenir.

### Mesaj Gönderme

- Gönder/Enter tetiklendiğinde:
  1. Kendi yazma kutusundaki metin alınır.
  2. `/channels/{kanalAdi}/messages/` altına push edilir: `{senderNick, text, timestamp}`.
  3. Kendi liveTyping node'u temizlenir (boş string yazılır).
  4. Kendi yazma kutusunun içeriği temizlenir.
- Mesaj geçmişinde kimin mesajı olduğu `senderNick` ile belirlenir.

### Mesaj Geçmişi — Lazy Loading

- Sayfalama mantığı: başlangıçta son 30 mesaj yüklenir (`limitToLast(30)`).
- Kullanıcı yukarı scroll ettiğinde ve listenin başına yaklaştığında (`ScrollController` ile izle) bir önceki 30 mesaj çekilir (`endAt` + `limitToLast(30)`).
- Yükleme sırasında küçük bir loading indicator gösterilir.
- Ekran donmaması için `ListView.builder` kullanılır.
- Kendi mesajları sağa hizalı, yeşil baloncuk. Karşının mesajları sola hizalı, beyaz/gri baloncuk. Her balonun üstünde nick yazar.

### Bağlantı Kopma / Yeniden Bağlanma

- Firebase `onDisconnect()` kullanılır: bağlantı kesilince `/channels/{kanalAdi}/slots/{slotId}/online` otomatik olarak `false` yapılır, `lastSeen` güncellenir.
- Uygulama açıkken her 30 saniyede bir `lastSeen` güncellenir (heartbeat).

---

## KULLANILACAK FLUTTER PAKETLERİ

```yaml
dependencies:
  flutter:
    sdk: flutter
  firebase_core: latest
  firebase_database: latest      # Realtime Database
  flutter_riverpod: latest
  uuid: latest                   # sessionId üretimi
  crypto: latest                 # SHA-256 şifre hash
  shared_preferences: latest     # localStorage (web + mobil uyumlu)
  intl: latest                   # timestamp formatlama
```

---

## MOBİL UYUMLULUK NOTLARI

- `shared_preferences` paketi kullanılacak, `dart:html` localStorage değil — bu sayede mobilde de çalışır.
- UI'da `MediaQuery` ile ekran genişliği kontrol edilecek. Dar ekranlarda yazma kutuları tam genişlik olacak.
- Firebase paketleri zaten cross-platform.
- `LayoutBuilder` ile responsive düzen kurulacak.

---

## GÜVENLİK

- Şifre hiçbir zaman düz metin olarak Firebase'e yazılmaz. SHA-256 hash'i yazılır.
- Firebase Security Rules: okuma ve yazma işlemleri sadece kanal path'i üzerinden olacak. Anonim auth veya kuralları açık bırakma — hangisini tercih edersen belirt.
- Önerim: Firebase Anonymous Auth aktif et, her kullanıcı oturum açar, Security Rules `auth != null` şartı koy.

---

## BAŞLANGIÇ ADIMLARI (asistana hatırlat)

1. `flutter create live_chat_app --platforms web` komutu ile proje oluştur.
2. `pubspec.yaml`'a yukarıdaki paketleri ekle.
3. Firebase Console'dan yeni proje oluştur, Realtime Database aktif et, `firebase_options.dart` dosyasını projeye ekle (`flutterfire configure` komutu ile).
4. `main.dart`'ta Firebase initialize et.
5. Önce `auth` feature'ını yaz, sonra `chat` feature'ına geç.
6. Her feature için önce model ve repository, sonra provider, sonra UI yaz.

---

## ÖZET — NE YAPILACAK

| Özellik | Detay |
|---|---|
| Platform | Flutter Web (mobil uyumlu mimari) |
| Backend | Firebase Realtime Database |
| State | Riverpod |
| Giriş | Nick + şifre + kanal adı |
| Kanal | İlk girişte oluşur, şifre kalıcı |
| Slot sistemi | 2 slot, düşen kullanıcı kendi slotuna döner |
| Canlı yazma | Her tuşta Firebase güncellenir, karşı anlık görür |
| Çift imleç | Her iki kutu da her iki kullanıcıya açık, Google Docs mantığı |
| Gönder yetkisi | Sadece kendi kutusunu gönderebilir |
| Mesaj geçmişi | Kalıcı, lazy load, 30'ar mesaj sayfalama |
| Bağlantı kopma | onDisconnect ile online:false, sessionId ile geri bağlanma |
