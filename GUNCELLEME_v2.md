# Pipetin Yolculuğu — v1.1

## Çalıştırma

1. Açık oyunu/terminali kapatın. ZIP'i yeni bir klasöre çıkarın.
2. `esma_game/BASLAT_WINDOWS.bat` dosyasını çalıştırın. Bu dosya Chrome'u açar.
3. Eski kayıt görünürse “Yeni macera”yı seçin.

Alternatif olarak proje klasöründe:

```sh
flutter pub get
flutter run -d chrome
```

## Değişiklikler

- Hikâye: kıyıda bırakılan kırmızı pipet → zamanla parçalanma → canlılara ulaşma riski → başa dönüp atığı önleme. Menü, giriş, bölüm sonuçları, kitap ve final güncellendi. Pipet çizimi ve parçalanma animasyonu eklendi.
- Şamlar: ormanlık su kıyısı; Sazlıdere: tepeler ve baraj; Küçükçekmece: kent, köprü ve iskele. Üç ayrı temsili görsel.
- Her mekân bağımsız, başlangıçta bulanık suya sahip. Toprak rengi su katmanı ve tortu parçacıkları temizlikle yumuşak biçimde kaybolur; gökyüzü ve kıyılar boyanmaz.
- Şamlar: her doğru ayrıştırma %10 görsel temizlik sağlar. Yanlış kutu puan kazandırmaz.
- Sazlıdere: balıktan kaçan parçalar alttaki ağa ulaşınca toplanır; 20 parça %100 görsel temizlik sağlar. Balığın yuttuğu parça temizlik sağlamaz.
- Küçükçekmece: iki atık yakalama sırasıyla %50 ve %100 görsel temizlik sağlar. Üçüncü yakalama balık incelemesine geçer.
- Sonuç ekranları ilgili mekânın berraklığını korur. Tekrar oynama, o turun suyunu sıfırlar; yeni macera tümünü sıfırlar.
- Flame artık hikâyeyi güncellemez. Hikâye Flutter Ticker ile build/layout öncesinde ilerler; `update(0)` çağrısı arayüze bildirim göndermez. GameWidget, AnimatedBuilder'ın sabit child öğesidir. Ticker kapanışta dispose edilir.

## Eğitsel çerçeve

Yolculuk dedenin kitabında kurgulanan üç duraktır; doğrulanmış bir atık taşıma rotası değildir. Küçükçekmece denizle bağlantılı bir lagündür; üç mekânın tümü tatlı su gölü diye sunulmaz. Görseller gerçek yerlerin birebir fotoğrafı değildir. Berraklık oyun geri bildirimidir, gerçek su kalitesini veya içilebilirliği göstermez. Pipet çözünüp yok olmaz; zamanla parçalanabilir.

## Kontrol durumu

Dart sözdizimi/format kontrolü tamamlandı. Kontrolör mantığı, Flutter bildirim sınıfı yerine yalnızca boş bir bildirim adaptörü kullanılan izole Dart ortamında 24 davranış kontrolünden geçti. Bu, Flutter widget/cihaz testi yerine geçmez. Flutter SDK burada kurulu olmadığı için tam `flutter analyze`, `flutter test`, derleme ve cihaz testi çalıştırılmadı. Yeni su ilerlemesi ve açılış/yeniden boyutlandırma regresyon testleri `test/` içine eklendi.
