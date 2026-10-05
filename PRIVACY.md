# RUYA Gizlilik Politikası

* RUYA hiçbir veriyi cihazından dışarı göndermez. Sunucu, hesap, analitik, reklam veya izleyici yoktur.
* Uygulamanın release sürümü `INTERNET` izni istemez.
* Android otomatik bulut yedeği (`allowBackup`) ve cihazdan cihaza aktarım kapalıdır.
* Veritabanının tamamı cihazda SQLCipher (AES-256) ile şifrelenir; notlar ve ilaçlar ayrıca AES-GCM ile şifrelenir. Anahtarlar Android Keystore'da tutulur.
* Verilerin yalnızca senin oluşturduğun şifreli yedek dosyası veya klinik PDF ile cihaz dışına çıkabilir; dosyanın nereye kaydedileceğini sen seçersin.
* Wear OS eşlemesi kullanılırsa saat ile telefon arasında yalnızca geri sayım bilgisi ve "bugün kaydet" isteği aktarılır.
* Uygulamadaki dış bağlantılar (GitHub vb.) yalnızca sen dokunduğunda tarayıcıda açılır.
