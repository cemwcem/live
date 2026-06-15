# Live Chat App

Flutter web tabanlı gerçek zamanlı sohbet uygulaması.

## Firebase Kurulumu

1. Firebase Console'da yeni proje oluştur.
2. Realtime Database'i etkinleştir.
3. Authentication bölümünde Anonymous provider'ı aç.
4. FlutterFire CLI ile platform yapılandırmasını üret:

```bash
flutterfire configure
```

5. Üretilen `firebase_options.dart` dosyasını projeye dahil et. Bu projedeki mevcut yer tutucu dosyayı gerçek yapılandırma ile değiştir.
6. Güvenlik kurallarını deploy et:

```bash
firebase deploy --only database
```

## Güvenlik Kuralları

Projede kökte bulunan [database.rules.json](database.rules.json) dosyası Realtime Database kurallarını içerir.

Kuralların özeti:

- Okuma ve yazma sadece oturum açmış kullanıcılar için açık.
- Kanal, slot, canlı yazım ve mesaj kayıtları şema kontrolü ile doğrulanır.
- Anonim kimlik doğrulama aktif olmalıdır.

## Çalıştırma Sırası

1. `flutter pub get`
2. `flutterfire configure`
3. Firebase Console'da Anonymous Auth ve Realtime Database'i aç
4. `firebase deploy --only database`
5. `flutter run -d chrome`
