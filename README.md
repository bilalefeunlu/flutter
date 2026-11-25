<div align="center">

# QR Scanner

Minimalist ve modern bir **Flutter** QR kod tarayıcı uygulaması.

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![License: MIT](https://img.shields.io/badge/License-MIT-10B981.svg)](LICENSE)

<!-- Ekran görüntülerini screenshots/ klasörüne ekleyip aşağıdaki satırların başındaki yorum işaretlerini kaldırın -->
<!--
<p>
  <img src="screenshots/scanner.png" width="240" alt="Tarayıcı Ekranı" />
  <img src="screenshots/history.png" width="240" alt="Geçmiş Ekranı" />
  <img src="screenshots/result.png" width="240" alt="Sonuç Paneli" />
</p>
-->

</div>

---

## Özellikler

| Özellik | Açıklama |
|---|---|
| **Canlı Kamera Tarama** | Gerçek zamanlı QR/barkod okuma, fener kontrolü ve ön/arka kamera değiştirme |
| **Galeriden Tarama** | Cihaz galerisindeki fotoğraflardan çevrimdışı QR kod çözümleme |
| **Tarih Gruplu Geçmiş** | Taramaları **Bugün**, **Dün**, **27 Kasım** gibi başlıklar altında gruplar |
| **Arama & Favoriler** | Geçmişte anahtar kelime/tür bazlı arama yapma ve önemli kodları yıldızlama |
| **Çoklu Seçim & Toplu Silme** | Uzun basarak çoklu seçim modunu açma, tümünü seçme veya toplu silme |
| **Güvenli Link Önizleme** | URL'leri `HTTPS` / `HTTP`, kısaltılmış bağlantı ve doğrudan IP adresi açısından analiz eder |
| **Akıllı İçerik Algılama** | URL, Wi-Fi, telefon, e-posta, SMS ve düz metin türlerini otomatik sınıflandırır |
| **Material 3 & Karanlık Mod** | Sistem temasına otomatik uyum sağlayan sade arayüz |

---

## Proje Mimarisi

```text
lib/
├── core/
│   ├── theme/
│   │   └── app_theme.dart                # Material 3 açık ve koyu tema tanımları
│   └── utils/
│       ├── date_formatter.dart           # Türkçe tarih formatlama ve gruplama
│       └── qr_parser.dart                # İçerik algılama, Wi-Fi ayrıştırma & URL güvenlik analizi
├── data/
│   ├── models/
│   │   └── qr_scan_item.dart             # JSON serileştirme destekli tarama modeli
│   └── repositories/
│       └── scan_history_repository.dart  # SharedPreferences tabanlı yerel depolama
├── logic/
│   └── scan_history_provider.dart        # ChangeNotifier ile durum yönetimi ve filtreleme
├── presentation/
│   ├── screens/
│   │   ├── main_navigation_screen.dart   # 2 sekmeli alt gezinme kabuğu
│   │   ├── scanner_screen.dart           # Canlı kamera ve galeri tarama ekranı
│   │   └── history_screen.dart           # Arama, favori ve çoklu seçimli geçmiş ekranı
│   └── widgets/
│       ├── scanner_overlay.dart          # Animasyonlu tarama vizörü
│       ├── history_item_card.dart        # Kaydırarak silme ve seçim destekli liste kartı
│       └── result_bottom_sheet.dart      # Güvenli link kartı ve aksiyon alt paneli
└── main.dart                             # Uygulama giriş noktası
```

---

## Kullanılan Paketler

| Paket | Amaç |
|---|---|
| [`mobile_scanner`](https://pub.dev/packages/mobile_scanner) | Kamera ve görsel tabanlı QR/barkod tarama |
| [`image_picker`](https://pub.dev/packages/image_picker) | Galeriden fotoğraf seçimi |
| [`shared_preferences`](https://pub.dev/packages/shared_preferences) | Tarama geçmişini yerel olarak saklama |
| [`intl`](https://pub.dev/packages/intl) | Tarih ve saat biçimlendirme |
| [`url_launcher`](https://pub.dev/packages/url_launcher) | Tarayıcı, arama, e-posta ve SMS yönlendirmeleri |
| [`share_plus`](https://pub.dev/packages/share_plus) | Sistem paylaşım menüsü entegrasyonu |

---

## Kurulum ve Çalıştırma

### Gereksinimler

- Flutter SDK `3.14.0+`
- Android SDK (API 21+) veya Xcode (iOS 12+)

### Adımlar

```bash
# Depoyu klonlayın
git clone https://github.com/bilalefe/flutter-qr-scanner.git
cd flutter-qr-scanner

# Bağımlılıkları yükleyin
flutter pub get

# Bağlı cihazda veya emülatörde çalıştırın
flutter run

# Debug APK oluşturun
flutter build apk --debug
```

---

## Test ve Analiz

```bash
# Statik kod analizi
flutter analyze

# Birim ve widget testleri
flutter test
```

---

## Lisans

Bu proje [MIT Lisansı](LICENSE) altında lisanslanmıştır.
