# Güncelleme: Pipetin Yolculuğu v1.1

Yeni özellikler ve başlatma: `GUNCELLEME_v2.md`. Doğrulama sınırları: `VALIDATION.md`.

# Esma: Suyun Koruyucusu

Flutter + Flame ile geliştirilen, resimli ve üç bölümlük çevre eğitimi oyunu. Türkçe arayüz, fare/dokunma etkileşimi, dedesinin kitabı, yeniden deneme ve fotoğraflı kişisel katkı haritası içerir.

## Hızlı başlatma (Windows / VS Code)

1. ZIP'i bir klasöre çıkar ve `esma_game` klasörünü VS Code ile aç.
2. Terminalde çalıştır:

```sh
flutter pub get
flutter run -d chrome
```

Android cihaz için:

```sh
flutter devices
flutter run -d CIHAZ_KIMLIGI
```

Derleme:

```sh
flutter build web --release --no-web-resources-cdn
flutter build apk --release
```

Flutter 3.41.6 / Dart 3.11.4 geliştirme ortamı hedeflenmiştir. İlk paket indirmesi ve harita zemini internet gerektirir. Android için yerel Android SDK kurulumu gereklidir. iOS platform dosyaları bu pakette yer almaz; macOS ve Xcode üzerinde `flutter create --platforms=ios .` ile eklenebilir.

## Oyun akışı

1. **Şamlar Tabiat Parkı / Chapter 1:** 20 saniye boyunca kıyıya yaklaşan atıkları plastik, metal ve kâğıt kutularına sürükle. En az 10 doğru atık toplanmadan sonraki bölüme geçilemez.
2. **Sazlıdere Barajı / Chapter 2:** 30 saniye boyunca balığı mikroplastiklerden kaçır. Balığı geçen parçalar aşağıdaki toplama ağına ulaşır ve ağda birikir; yutulan mikroplastikler ayrıca sayılır.
3. **Küçükçekmece Gölü / Chapter 3:** Su üzerinde seçtiğin noktaya oltayı at, doğru anda çek ve ardından eğitsel inceleme ekranındaki üç mikroplastik izini keşfet.
4. **Hikâyeyi Değiştir finali:** Günlük hayattan 5 kısa senaryoda doğa dostu seçimi yap. Final ekranı; 5 soruluk seçim puanını, Chapter 1'de toplanan atık sayısını ve Chapter 2'de balığın kurtulduğu mikroplastik sayısını ayrı ayrı gösterir.

Finalden sonra güvenli bir kıyıda yaptığın gerçek temizliğin fotoğrafını seçebilir, temizlik noktasını haritada işaretleyebilir ve yer adını yazabilirsin. Kayıt katkı haritasında görünür. Sonrasında isteğe bağlı ad/takma ad ile PDF başarı belgesi indirilebilir.

## Dedesinin kitabı

Üstteki kitap düğmesi ilgili aşamalarla açılan beş resimli sayfayı gösterir. Kitap ve duraklatma menüsü açıldığında oyun durur. Kaynaklar `SOURCES.md` dosyasında listelenmiştir.

## Gerçek dünya kaydı: kapsam ve gizlilik

- Fotoğraf ve konum **bu cihazın uygulama/tarayıcı deposuna** kaydedilir. Çevrimiçi topluluk sunucusuna yüklenmez.
- Harita zemini OpenStreetMap'ten gelir; harita görünümü için ağ bağlantısı gerekir. OSM'ye fotoğraf gönderilmez.
- Temizlik konumunu kullanıcı haritaya dokunarak seçer. GPS izni veya fotoğrafın konum bilgisi kullanılmaz.
- Görsel boyutlandırılır ve EXIF/GPS metaverisi taşınmadan yeniden kodlanır.
- Kayıt bir **kullanıcı beyanıdır**; temizliğin gerçekleştiğini otomatik doğrulamaz.
- Tarayıcı verilerinin silinmesi yerel ilerlemeyi ve katkı kayıtlarını da siler. Bu bir bulut yedeği değildir.
- Kayıtlar haritadan silinebilir. Yerel fotoğraf arşivi için yaklaşık 2,8 MB toplam JSON sınırı vardır; kapasite dolduğunda mevcut kayıtlar sessizce silinmez.
- Fotoğraf finalinde çocuklara bir yetişkinle çalışma, suya girmeme ve kesici/bilinmeyen atıklara dokunmama açıklaması gösterilir.
- İsim yalnızca cihazda PDF oluşturmak için kullanılır; kayda veya sunucuya gönderilmez.

Ortak çevrimiçi harita istenirse kimlik doğrulama, erişim kuralları, moderasyon, silme ve depolama politikaları olan ayrı bir sunucu katmanı eklenmelidir. Bu pakette varmış gibi gösterilen bir bulut servisi yoktur.

## Bilimsel anlatım sınırları

- Üç konum **üç su durağıdır**; üç ayrı tatlı su kaynağı olarak etiketlenmez. Küçükçekmece bir lagündür; Şamlar ise park ve baraj gölü çevresidir.
- Plastik çözünüp kayboluyormuş gibi anlatılmaz; küçük parçalara ayrılma ve zaman atlaması kullanılır.
- Sazlıdere'deki balığın fiziksel olarak Küçükçekmece'ye gittiği iddia edilmez. İki durakta farklı örneklerle öğrenme sürer.
- Röntgen ekranı stilize, büyütülmüş eğitsel canlandırmadır. Gerçek röntgenle mikroplastik tespiti iddiası değildir.
- Görseller temsili olarak üretildi; gerçek konumların ölçülü rekonstrüksiyonu değildir.
- Sayaçlar ve puanlar simülasyondur, bilimsel çevre ölçümü değildir.
- Belge oyun içi başarı belgesidir; resmî IEEE sertifikası değildir.

## Proje yapısı

Proje feature-oriented bir yapıya ayrılmıştır. `main.dart` yalnızca uygulama kabuğunu ve sahne geçişlerini yönetir; bölüm oyunları kendi feature klasörlerinde bulunur.

- `lib/main.dart`: Uygulama kabuğu, sahne yönlendirme, ana sayfa ve genel akış.
- `lib/game/story_controller.dart`: Ortak oyun durumu, sayaçlar ve bölümler arası ilerleme.
- `lib/game/lake_game.dart`: Flame tabanlı göl/olta çizimleri ve animasyonlar.
- `lib/features/chapters/chapter_one/chapter_one.dart`: Chapter 1 giriş ekranı ve atık toplama oyunu.
- `lib/features/chapters/chapter_two/chapter_two.dart`: Chapter 2 giriş ekranı ve mikroplastikten kaçınma oyunu.
- `lib/features/chapters/chapter_three/chapter_three.dart`: Chapter 3 olta ve inceleme ekranları.
- `lib/features/final_challenge/`: 5 senaryolu doğa dostu seçim oyunu ve final skor ekranı.
- `lib/features/book/book_sheet.dart`: Dedemin Doğa Kitabı.
- `lib/features/impact/impact_screen.dart`: Fotoğraf seçimi, konum işaretleme ve katkı haritası.
- `lib/services/`: Kalıcı veri ve PDF/sertifika servisleri.
- `lib/ui/widgets.dart`: Bölümler arasında paylaşılan görsel bileşenler.
- `lib/ui/water_scene.dart`: Ortak su ve arka plan katmanı.
- `assets/`: Görseller ve fontlar.
- `test/`: Oyun kuralları ve servis testleri.

Detaylı klasör şeması için `PROJECT_STRUCTURE.md` dosyasına bakabilirsin.

## Kontroller

```sh
flutter analyze
flutter test
```

Testler 45 saniyelik akışı simüle eder; normal oyunun sürelerini değiştirmez. Son doğrulama durumunu `VALIDATION.md` dosyasında bulabilirsin.
