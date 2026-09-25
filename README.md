Afet Analiz
Balıkesir için geliştirilen, mahalle nüfusu, ilçe demografisi, haritalanmış faylar ve deprem kayıtlarını bir araya getiren Android uygulaması.
Durum: Geliştirme sürümü / tema öncesi ilk commit. Android cihaz/emülatör üzerinde manuel kabul denemesi ve yayın imzalama hazırlığı henüz tamamlanmamıştır. Tema yenilemesi ve alt menülü ekran düzeni sonraki geliştirme aşamasındadır.

Amaç ve kullanım sınırı
Afet Analiz, farklı kaynaklardaki bölgesel verileri kaynakları ve sınırlılıklarıyla birlikte anlaşılır biçimde sunmayı amaçlar. Flutter ile geliştirilir; bu projenin hedef platformu yalnızca Android'dir.
Uygulama bir binanın veya mahallenin güvenli olup olmadığına karar vermez. Fay mesafesi, nüfus ve demografi göstergeleri tek başına deprem risk puanı değildir. Uygulama; bina dayanıklılık testi, mühendislik değerlendirmesi, deprem tahmini, erken uyarı sistemi veya resmî tahliye talimatı yerine geçmez. AFAD, TÜİK, GEM veya belediyenin resmî uygulaması değildir.
İlk commit kapsamı
- Kaynak mahalle koduyla ilçe/mahalle arama ve nüfus gösterimi; ilçe düzeyindeki çocuk, yaşlı ve toplam yaş bağımlılık göstergeleri.
- OpenStreetMap üzerinde nokta seçimi, bölgesel fay çizgileri ve seçilen noktadan veri kümesindeki en yakın haritalanmış faya yaklaşık mesafe hesabı.
- AFAD Event Web Service entegrasyonu; sorgu filtreleri, sayfalama, veri ayrıştırma ve hata/kısmi sonuç durumları.
- Python ile CSV, KML ve GeoJSON hazırlama araçları; katmanlı uygulama yapısı ve regresyon testleri.
AFAD önbelleği, istek sınırlaması ve kalıcı harita önbelleğine ilişkin geliştirmeler son geliştirme raporuna dahildir; güncel kodun nihai kabul ve cihaz kontrolleri beklemektedir.
Veri kaynakları ve kapsam
Aşağıdaki sayılar bu projede kullanılan kaynak dosya sürümünü tanımlar; bugün için eksiksiz resmî envanter iddiası değildir.
Veri	Kaynak	Projedeki kapsam
Mahalle nüfusu	TÜİK ADNKS CSV aktarımı	2025 yılı, 1.133 mahalle kaydı, 20 ilçe
Yaş bağımlılık göstergeleri	TÜİK ilçe düzeyi CSV aktarımı	2025 yılı, 20 ilçe
Fay çizgileri	GEM Global Active Faults	Bölgesel seçim kutusuyla kesişen 60 kaynak kaydı
Toplanma alanı geometrileri	Balıkesir Açık Veri Portalı KML dosyası	1.682 poligon, iki iç halka; yalnız bir açıklayıcı kaynak kaydı


Kaynaklar: TÜİK Veri Portalı, AFAD Event Web Service, GEM Global Active Faults, Balıkesir Acil Toplanma Alanları, OpenStreetMap contributors.
Önemli veri sınırlamaları
Nüfus ve demografi: Mahalle nüfusu ile ilçe yaş göstergeleri farklı coğrafi düzeylerdedir. İlçe verisi mahalleye özgü yaş dağılımı olarak yorumlanmamalıdır. Kullanılan nüfus CSV'sinin toplamı 1.284.514'tür; önceki kurumsal toplam karşılaştırmasındaki üç kişilik fark kaynak düzeyinde açıklığa kavuşmamıştır ve tahminle değiştirilmemiştir.
Faylar: Seçim kutusu boylam 26.3–28.9, enlem 39.1–40.7 aralığındadır. Bu kutu resmî il sınırı değildir. Hesaplanan mesafe yalnız kullanılan çizgi verisine aittir; zemin koşulu veya bina performansı hakkında hüküm vermez.
Toplanma alanları: KML'deki 1.682 poligon, kimliği doğrulanmış 1.682 ayrı toplanma alanı anlamına gelmez. Tek açıklayıcı kaydın adı ve altyapı bilgileri diğer geometrilere dağıtılmaz. Eşleşmesi doğrulanmamış geometriler normal kullanıcı akışında güvenilir toplanma hedefi olarak sunulmaz.
Konum ve güncellik: Mahalle nüfus dosyaları mahalle merkez koordinatı içermez. Harita kamerası ile hesaplama noktası ayrıdır. Yerel veri dosyaları otomatik olarak güncel resmî veriye dönüşmez. Yeni AFAD kayıtları ve harita görselleri ağ erişimine bağlıdır; önbellek tam çevrimdışı harita garantisi değildir.
Mimari
lib/
├── app/                     # Uygulama başlangıcı ve bağımlılık kurulumu
├── core/                    # Ortak yapılandırma ve yardımcılar
├── domain/
│   ├── entities/            # Saf Dart iş modelleri
│   ├── repositories/        # Veri erişim sözleşmeleri
│   └── services/            # Coğrafi hesaplama kuralları
├── data/
│   ├── datasources/         # Asset, HTTP ve önbellek erişimi
│   ├── models/              # DTO ve kaynak biçimi dönüşümleri
│   └── repositories/        # Veri erişim uygulamaları
└── presentation/
    ├── screens/
    ├── widgets/
    └── viewmodels/          # Seçim, bölgesel metrikler ve depremler
Durum yönetiminde Provider/ChangeNotifier kullanılır. Seçim, bölgesel metrikler ve deprem sorguları ayrı sorumluluklar olarak düzenlenmiştir. Kullanılan paketler ve sürümleri için pubspec.yaml ve pubspec.lock esas alınmalıdır.
Yerel kurulum
Flutter/Dart SDK, Android SDK ve uyumlu Java kurulumu gerekir. Dart sürümü pubspec.yaml kısıtını karşılamalıdır. Veri hazırlama araçları Python 3 kullanır.
Proje kökünde:
flutter doctor -v
flutter pub get
flutter devices
flutter run
Birden fazla cihaz listelenirse Android cihazı veya Android emülatörü seçin. Debug APK üretmek için:
flutter build apk --debug
Çıktı: build/app/outputs/flutter-apk/app-debug.apk. Debug APK, üretim imzasıyla hazırlanmış yayın paketi değildir.
Veri hazırlama ve testler
assets/data/ uygulamanın kullandığı işlenmiş dosyaları tutar. İlk commit düzeninde ham dosyalar Git'e eklenmez; bunları silmeden yerel data/raw/ altında saklayın:
data/raw/
├── nüfus-mahalle.csv
├── yaş-mahalle.csv
├── toplanma-alanlari-.kml
└── gem_active_faults.geojson
Kaynakları yenileyip çıktıları üretmek için proje kökünde:
python scripts/convert_demography.py
python scripts/convert_assembly_areas.py
python scripts/convert_faults.py
Doğrulama komutları:
python -m unittest discover -s scripts -p "test_*.py" -v
flutter analyze
flutter test --reporter expanded
Gerçek ham veriye bağlı testler için data/raw/ dosyaları ayrıca gereklidir. Otomatik test sonuçları kullanılan commit ve ortam için değerlendirilmelidir; manuel Android kabul denemesi henüz tamamlanmamıştır.
Sonraki aşamalar
Tema öncesi Android kabul denemesi ve varsa işlevsel hataların giderilmesinin ardından, tema yenilemesi ve 4–5 ana ekranlı alt navigasyon ayrı commitlerle geliştirilecektir. Ekran görüntüleri ve güncel kullanım açıklamaları bu çalışmadan sonra eklenecektir. Üretim imzalama ve yayın hazırlığı ayrı işlerdir.
Lisans ve atıf
GEM fay verisi CC BY-SA 4.0 kapsamında yayımlanır. Projedeki bölgesel fay çıktısı, kaynak kayıtlardan çizgi–kutu kesişimiyle seçilmiş bir alt kümedir. Kaynak atfı: Styron, R. ve Pagani, M. (2020), The GEM Global Active Faults Database, Earthquake Spectra, DOI: 10.1177/8755293020944182.
Harita için © OpenStreetMap contributors atfı ve ilgili kullanım koşulları korunmalıdır. Diğer veri kaynakları ve yazılım bağımlılıkları kendi lisans/kullanım koşullarına tabidir. Bu README, bütün kaynaklar için sınırsız yeniden dağıtım izni vermez. Bu README uygulama koduna kendiliğinden bir lisans atamaz; veri lisansları otomatik olarak bütün uygulama kodunun lisansı sayılmamalıdır.