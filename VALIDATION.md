# v1.1 doğrulama

- Tüm Dart kaynakları Dart 3.13.4 format/parçalama kontrolünden geçti.
- Gerçek `StoryController` kodunun izole kopyası üzerinde 24 davranış kontrolü geçti. Yalnızca Flutter'a bağlı `ChangeNotifier` bildirimi boş adaptörle değiştirildi; oyun kuralları değiştirilmedi. İzole kontrolörde `dart analyze` sorun bulmadı.
- Kontroller: mekân eşlemesi, başlangıç kirliliği, doğru/yanlış ayrıştırma, süre duraklaması, berraklığın kademeli değişimi, ağda toplama/yutma ayrımı, 45 saniyelik turlar, üç yakalama, tekrar turu başarısı/başarısızlığı ve sıfırlama.
- Flutter UI ve Flame entegrasyonu bu ortamda çalıştırılmadı. Açılış hatasının cihazda giderildiği henüz doğrulanmadı. `test/widget_test.dart` açılış, devam eden kareler, sahne geçişleri ve boyut değişikliği için regresyon testi içerir.
- Tam paket çözümü, Flutter analiz/test/derleme, Android cihazı, harita/fotoğraf ve PDF akışları henüz doğrulanmadı.

Yerel doğrulama:

```sh
flutter pub get
flutter analyze
flutter test
flutter run -d chrome
```

Manuel kontrol: yeni macera başlatın, üç görselin farklı olduğunu ve her mekânın başlangıçta kirli olduğunu görün. Doğru ayrıştırma yapın, balığı hareket ettirip parçaları ağa yönlendirin, iki atık yakalayın. Suyun kademeli berraklaştığını kontrol edin. Duraklat/devam ve yeni oyun davranışlarını deneyin. Tarayıcı boyutunu değiştirirken terminalde build hatası oluşmadığını kontrol edin.
