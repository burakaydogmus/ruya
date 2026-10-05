# RUYA — Analiz ve Mimari Plan

RUYA, [Menstrudel](https://github.com/J-shw/Menstrudel) (GPL-3.0) üzerine kurulu bir Flutter uygulamasıdır.
[Mooneva Cycle](https://github.com/aradar46/Mooneva-Cycle-Private-Period-Tracker) (GPL-3.0) yalnızca davranış referansıdır:
hiçbir React/TypeScript kodu taşınmaz, WebView kullanılmaz. Her iki proje de GPL-3.0 olduğu için RUYA da GPL-3.0'dır.

---

## 1. Mevcut Menstrudel mimarisi

| Katman | Yapı |
|---|---|
| UI | Material 3, `DynamicColorBuilder` (Material You) + seed color, light/dark/system |
| State | `provider` — `ChangeNotifier` servisleri (`SettingsService`, `LogService`, `PeriodService`, `UserService`, `SymptomService`), `DataRefreshCoordinator`, UI controller'ları (bottom sheet akışları) |
| Veri | `sqflite`, tek dosya `app_database.db`, **şema v11**, kümülatif `if (oldVersion < N)` migration'ları (`DatabaseMigrator`) |
| Repolar | `LogsRepository`, `PeriodsRepository` (+ JSON export/import `Manager`), `PillsRepository`, `ReversibleContraceptiveRepository`, `SanitaryProductRepository`, `SexRepository`, `UserRepository` |
| Tahmin | `PeriodPredictor` (son 180 gündeki geçerli döngülerin aritmetik ortalaması, 10–130 gün), `CyclePhasePredictor` (sabit 14 gün luteal; `PredictedCycle.getPhaseForDate`) |
| Bildirim | `flutter_local_notifications` + `timezone`, 6 kanal (regl, hijyen, hap, LARC, kayıt hatırlatıcı, faz) |
| Widget | `home_widget` + Kotlin `HomeScreenWidgetProvider` (dairesel ilerleme) |
| Wear OS | ayrı Flutter `wear_app/`, `watch_connectivity` application-context senkronu; aynı applicationId zorunlu |
| L10n | `gen-l10n`, 13 ARB (Türkçe yok), şablon `app_en.arb` |
| Güvenlik | Sadece açılışta `local_auth` (biyometri/cihaz kilidi); PIN, şifreleme, yeniden kilitleme yok |

Tablolar: `periods`, `period_logs`, `log_symptoms`, `PillRegimen`, `PillIntake`, `PillReminder`, `larc_logs`,
`sanitary_product_logs`, `sexual_activity_logs`, `user`.

### Upstream'de tespit edilen sorunlar
* Güncel Flutter (3.47) ile derlenmiyordu: Gradle 8.13 / Kotlin 2.1.0 minimumun altında, `file_picker 12.3` API'si değişmiş → **düzeltildi**.
* `PRAGMA foreign_keys` kapalı: `ON DELETE CASCADE` hiç çalışmıyor (bir test bu davranışa dayanıyor, o yüzden açılmadı; RUYA'da çocuk satırlar elle siliniyor).
* `readLogsSince` TEXT tarihi milisaniye ile karşılaştırıyor (filtre işlemiyor).
* Regl "due" ve "overdue" bildirimleri aynı ID'yi kullanıyor.
* Saatten gelen kayıt, o gün başka bir kayıt varsa sessizce yok sayılıyor ve UI yenilenmiyor.
* `android:allowBackup="true"` → veriler Google Drive otomatik yedeğine gidebilir (**bulut bağımlılığı**).

### İnternet gerektiren Menstrudel özellikleri (rapor — kaldırılmadı)
* Release manifest'te **INTERNET izni yok**. `debug`/`profile` manifest'lerindeki INTERNET yalnızca Flutter tooling içindir.
* HTTP istemcisi yok. Dış bağlantılar yalnızca `url_launcher` ile tarayıcıda açılan linkler (Hakkında ekranı: menstrudel.app, Discord, GitHub; onboarding gizlilik linki). Uygulamanın kendisi ağa çıkmaz.
* Wear OS senkronu Google Play Services Wearable Data Layer kullanır (Bluetooth/yerel; internet değil ama GMS bağımlılığı).
* `allowBackup=true` (Android Auto Backup → bulut). RUYA'da **kapatıldı** (gizlilik gereği; aynı zamanda Keystore anahtarlarıyla tutarlılık için zorunlu).

---

## 2. Önerilen RUYA mimarisi

Menstrudel'ın katmanları korunur; yeni modüller yanına eklenir:

```
lib/
  cycle/               ← Cycle Intelligence (saf Dart, test edilebilir)
    cycle_forecast.dart        tahmini regl, faz, yumurtlama, doğurgan dönem, PMS
  security/            ← Privacy & Security
    crypto/aes_gcm.dart        AES-256-GCM (+ PBKDF2-SHA256, native hızlandırma)
    crypto/pbkdf2.dart
    key_store.dart             flutter_secure_storage (Android Keystore) soyutlaması
    field_cipher.dart          DB'deki serbest metin alanları için alan şifreleme
    pin_service.dart           PIN hash/doğrulama, deneme kilidi
    app_lock_controller.dart   yaşam döngüsü, zaman aşımı, biyometri
  backup/              ← Şifreli yedek
    backup_format.dart         ikili zarf (magic, versiyon, KDF, salt, IV)
    backup_service.dart        export/restore, schemaVersion, önizleme
  import/              ← (M2) flo_importer.dart, clue_importer.dart, drip_importer.dart
  screens/
    today/today_screen.dart
    calendar/calendar_screen.dart
    log/log_screen.dart        geçmiş + takipçiler (hap, LARC, hijyen, cinsellik)
    insights/insights_screen.dart
    lock/lock_screen.dart
    settings/sections/privacy_settings_screen.dart
  widgets/daily_log/...        günlük kayıt formu parçaları
```

**Navigasyon:** `Bugün · Takvim · Kayıt · İçgörüler · Ayarlar`.
Menstrudel'ın isteğe bağlı sekmeleri (Hap, LARC, Hijyen, Cinsellik) kaybolmaz: ayarlarda açık olanlar **Kayıt** sekmesinde
kart olarak görünür ve kendi ekranlarını (FAB'larıyla birlikte) açar. Böylece alt bar her zaman 5 öğedir.

**Kilit akışı:** `RootGate → (onboarding) → AuthGate → MainScreen`, üstüne `AppLockGate` (uygulama genelinde overlay).
Arka plana geçişte zaman damgası tutulur, dönüşte `elapsed >= timeout` ise kilit ekranı gösterilir. Dosya seçici/paylaşım
sırasında kısa bir muafiyet (Mooneva'daki 20 sn picker grace yaklaşımı).

### Şifreleme yaklaşımı
| Konu | Mooneva | RUYA (M1) |
|---|---|---|
| Veri anahtarı | rastgele cihaz sırrı → PBKDF2 → AES-GCM | rastgele 256-bit DEK, `flutter_secure_storage` (Android Keystore ile sarılı) |
| Kalıcı veri | tüm localStorage blob'ları AES-GCM | SQLite + **alan düzeyi AES-GCM** (notlar, ilaç adları); Android sandbox + FBE; `allowBackup=false` |
| PIN | PBKDF2-SHA256 100k, 5 deneme → 30 sn | PBKDF2-SHA256 150k, salt, Keystore'da; 5 deneme → artan bekleme (30 sn → 15 dk) |
| Biyometri | yok | `local_auth`, PIN'e alternatif (PIN zorunlu yedek) |
| Yedek | `[ver][salt16][iv12][ct+tag]`, PBKDF2 600k | `RUYA` magic + format ver + KDF params + salt + IV + AES-256-GCM; PBKDF2-SHA256 600k (native) |

Tam veritabanı şifrelemesi (SQLCipher) M2 adayıdır: test altyapısı (sqflite_common_ffi), native kütüphane boyutu ve
`sqlcipher_export` migration'ı ayrı bir risk paketi olduğu için ilk milestone'a bağlanmadı.

---

## 3. Veritabanı değişiklikleri (v11 → v12)

```sql
ALTER TABLE period_logs ADD COLUMN notes TEXT;          -- AES-GCM ile şifreli ("enc:v1:" önekli)
ALTER TABLE period_logs ADD COLUMN medications TEXT;    -- şifreli JSON dizi ["ibuprofen", ...]
ALTER TABLE period_logs ADD COLUMN discharge TEXT;      -- dry | sticky_creamy | egg_white | watery | unusual
ALTER TABLE period_logs ADD COLUMN libido TEXT;         -- low | medium | high
ALTER TABLE period_logs ADD COLUMN sex_activity TEXT;   -- none | protected | unprotected
ALTER TABLE period_logs ADD COLUMN contraception TEXT;  -- JSON dizi: pill, condom, iud, implant, ...
CREATE TABLE log_moods (
  log_id_fk INTEGER NOT NULL,
  mood TEXT NOT NULL,
  PRIMARY KEY (log_id_fk, mood)
);
```
* Yalnızca **ekleme** yapılır (nullable kolonlar, yeni tablo) → v1–v11 migration zinciri ve mevcut kayıtlar aynen korunur.
* Menstrudel JSON export'ları (eksik kolonlarla) içe aktarılmaya devam eder; RUYA export'u `log_moods`'u da içerir.
* Migration testleri: v11 şemasıyla gerçek veri oluşturup v12'ye yükseltme, verinin korunduğunu doğrulama.

---

## 4. Özellik eşleme

### Menstrudel → RUYA
| Menstrudel | RUYA |
|---|---|
| Logs ekranı (Today/Logs/Insights sekmeleri) | Bugün, Takvim, Kayıt, İçgörüler ayrı ana sekmeler |
| Journal takvim (`scrollable_clean_calendar`) | Yeni Takvim: kayıtlı/tahmini regl, doğurgan dönem, yumurtlama, PMS, cinsellik, doğum kontrolü işaretleri |
| `SymptomEntrySheet` | `DailyLogSheet`: akış, ağrı, belirti + ruh hali, akıntı, ilaç, not, libido, cinsellik, doğum kontrolü |
| `PredictedCycle` | aynen korunur; luteal süresi ayarlanabilir, `fertileWindowEnd`, `pmsStart` eklenir |
| Hap / LARC / Hijyen / Cinsellik sekmeleri | Kayıt sekmesinde kartlar (aynı ekranlar) |
| Biyometrik kilit (açılışta) | Gizlilik: PIN + biyometri + zaman aşımı, arka plandan dönüşte kilit |
| JSON export/import | korunur + şifreli tam yedek |
| Bildirimler, widget, Wear OS | korunur (paket adı değişikliğiyle uyumlu) |

### Mooneva → RUYA
| Mooneva davranışı | RUYA karşılığı | Milestone |
|---|---|---|
| AES-GCM + Keystore'da sır | `security/` modülü | M1 |
| PIN (4–12 hane, PBKDF2, 5 deneme kilidi, 0/30/120 sn zaman aşımı) | `PinService`, `AppLockController` (0 / 30 sn / 1 / 2 / 5 / 15 dk) | M1 |
| Şifreli yedek (versiyonlu ikili zarf) | `backup/` + `schemaVersion: 1` | M1 |
| Faz hesabı (ov = sonraki regl − luteal, doğurgan [ov−5, ov], PMS [sonraki−pms, sonraki−1]) | `cycle/cycle_forecast.dart` | M1 |
| Ruh hali (12 seçenek, en fazla 5), akıntı, libido, cinsellik, ilaç, not | `period_logs` v12 + `log_moods` | M1 |
| Discrete mode (activity-alias ile ikon/isim değişimi, gizli bildirim kanalı) | `activity-alias` + MethodChannel | M2 |
| Clinical PDF | `pdf` paketiyle cihazda vektörel PDF | M2 |
| Flo / Clue / drip import (önizleme, birleştirme, mevcut gün kazanır) | `import/` adapter mimarisi | M2 |
| Doğum kontrolü modu, çocuk modu, gebelik modu | ayar bayrakları + görünürlük kuralları | M2/M3 |

---

## 5. Değişecek dosyalar (M1)
* `pubspec.yaml` (ad `ruya`, bağımlılıklar), tüm `package:menstrudel/` importları → `package:ruya/`
* `android/app/build.gradle.kts`, `AndroidManifest.xml` (label, `allowBackup=false`), Kotlin paketi `com.burakaydogmus.ruya`
* `HomeScreenWidgetProvider.kt` (URI şeması), `MainActivity.kt` (crypto MethodChannel)
* `lib/l10n/*.arb` (marka, yeni anahtarlar), `l10n.dart` (Türkçe + eksik diller)
* `database/app_database.dart` (v12), `database_migrator.dart`, `repositories/logs_repository.dart`, `periods_repository.dart` (export/import)
* `models/period_logs/log_day.dart`
* `utils/cycle_phase_predictor.dart`, `models/cycle_phase/cycle_phase.dart`
* `services/settings_service.dart`, `utils/constants.dart`
* `screens/main_screen.dart`, `widgets/main/main_navigation_bar.dart`, `screens/settings/settings_screen.dart`
* `screens/gates/auth_gate.dart`, `main.dart`, `controllers/log_ui_controller.dart`
* `wear_app/` (paket adı, applicationId, etiket)

## 6. Yeni dosyalar (M1)
`lib/cycle/cycle_forecast.dart`, `lib/security/*`, `lib/backup/*`, `lib/models/period_logs/{mood,discharge,libido,sex_activity,contraception}.dart`,
`lib/screens/today/today_screen.dart`, `lib/screens/calendar/calendar_screen.dart`, `lib/screens/log/log_screen.dart`,
`lib/screens/lock/lock_screen.dart`, `lib/screens/settings/sections/privacy_settings_screen.dart`, `lib/widgets/sheets/daily_log_sheet.dart`,
`lib/l10n/app_tr.arb`, testler: `test/cycle/`, `test/security/`, `test/backup/`, `test/database/migration_test.dart`.

## 7. Uygulama sırası
1. Upstream'i derlenir hale getir (✔), baseline test 38/38 (✔), baseline debug APK (✔)
2. Rebrand: paket adı, applicationId, etiket, ikon, ARB, Wear app
3. DB v12 + LogDay genişletme + migration testleri
4. Cycle Intelligence + testler
5. Security: crypto, key store, alan şifreleme, PIN, kilit, biyometri + testler
6. Daily Log sheet, Today, Takvim, Kayıt, İçgörüler, 5'li navigasyon
7. Şifreli yedek + önizleme + testler
8. Gizlilik ayarları ekranı, Türkçe metinler
9. analyze / test / debug + release APK → `RUYA.apk`

## 8. Riskler
| Risk | Etki | Önlem |
|---|---|---|
| applicationId değişimi | Menstrudel kullanıcıları otomatik taşınmaz; Wear app aynı ID ve imzayla derlenmeli | Menstrudel JSON import korunur; wear_app ID güncellenir |
| Keystore anahtarı kaybı (cihaz sıfırlama/yedekten geri yükleme) | Şifreli not alanları okunamaz | `allowBackup=false`; okunamayan alan "🔒" olarak gösterilir, çökme yok; şifreli yedek parola tabanlı (cihazdan bağımsız) |
| PIN unutulması | Uygulamaya erişim kaybı | PIN yedeğe girmez; yeniden kurulum + yedekten dönüş (Mooneva yaklaşımı); biyometri alternatif |
| Saf Dart PBKDF2 yavaşlığı (600k) | Yedekte saniyelerce donma | Android'de `javax.crypto` native PBKDF2 (MethodChannel); diğer ortamda isolate |
| Tahminlerin tıbbi sanılması | Yanlış güven | Tüm metinlerde "tahmini/beklenen/yaklaşık", Bugün ekranında uyarı satırı |
| Yumurtlama formülü değişimi | Menstrudel'a göre 1 gün kayma (eski: sonraki − 15) | Bilinçli düzeltme: sonraki − luteal (varsayılan 14); testlerle sabitlendi |
| Upstream bağımlılıkları beta (`file_picker 12`) | API kırılması | `pubspec.lock` commit'lendi |
| Tam DB şifrelemesi yok (M1) | Root'lu cihazda yapısal veriler okunabilir | Alan şifreleme + sandbox + FBE; SQLCipher M2'de |
| Release imzası | `key.properties` yok | Yoksa debug anahtarıyla imzalanır (yerel kurulum için); dağıtım için kendi keystore'unu ekle |

---

## Milestone 1 — durum (tamamlandı)

| Özellik | Durum |
|---|---|
| RUYA adı, `com.burakaydogmus.ruya`, ikon, Türkçe dil | ✔ |
| Menstrudel regl/akış/ağrı/belirti, hap, LARC, hijyen, cinsellik, bildirim, widget, Wear OS | ✔ korunuyor (takipçiler Kayıt sekmesinde) |
| Bugün ekranı (kalan gün, faz, ruh hali, hızlı kayıt) | ✔ |
| Faz hesabı, doğurgan dönem, yumurtlama, PMS (luteal/PMS ayarlanabilir) | ✔ |
| Günlük kayıt: ruh hali, akıntı, ilaç, not, libido, cinsellik, doğum kontrolü | ✔ (not + ilaç AES-GCM şifreli) |
| PIN kilidi, biyometri, zaman aşımı | ✔ |
| Şifreli yerel yedek (schemaVersion 1, önizleme, transaction'lı geri yükleme) | ✔ |
| Release `INTERNET` izni | yok ✔ |

Doğrulama: `flutter analyze` (yalnızca upstream deprecation info'ları), `flutter test` 94/94,
JVM unit test (Kotlin PBKDF2, RFC 7914), debug + release build, Android 15 emülatöründe release APK ile
onboarding → Bugün → takvim → PIN kilidi → şifreli yedek kaydet/geri yükle akışı.

Release APK'daki izinler: POST_NOTIFICATIONS, (USE/SCHEDULE)_EXACT_ALARM, RECEIVE_BOOT_COMPLETED,
USE_BIOMETRIC/USE_FINGERPRINT, VIBRATE, WAKE_LOCK, FOREGROUND_SERVICE, ACCESS_NETWORK_STATE.
Son üçü bir eklentinin bağımlılığı olan androidx WorkManager'dan gelir; internet erişimi vermezler.

## Milestone 2 — durum (tamamlandı)

| Özellik | Uygulama | Doğrulama |
|---|---|---|
| Flo / Clue / drip içe aktarma | `lib/import/` adapter'ları + otomatik format tespiti; önizleme; mevcut gün asla değişmez (tek transaction) | 17 birim testi, UI erişim testi |
| Clinical PDF | `lib/report/`: cihazda vektörel PDF, A4 yatay, özet, döngü geçmişi (kayıt boşlukları ayrı), günlük tablo, bölüm seçimi, isim isteğe bağlı; Roboto gömülü | Testler + emülatörde SAF ile kaydedilen PDF |
| Discrete mode | `activity-alias` (RUYA ↔ "Ajanda"), nötr bildirim metni + tek gizli kanal (kilit ekranında görünmez), widget yalnızca sayı, nötr kilit ekranı/başlık, son uygulamalar küçük resmi gizli | UI testi + emülatörde launcher/kilit/recents |
| İçgörüler | Hap uyumu, faza göre ruh hali (tahmin motoruyla gün gün tutarlı), döngü geçmişi listesi | 5 birim testi + UI testi |

Discrete mode için Android sınırları: uygulamanın Ayarlar › Uygulamalar'daki adı ve sistemin bildirimlerin üstüne
yazdığı uygulama adı çalışma zamanında değiştirilemez (RUYA kalır); bazı launcher'lar simgeyi birkaç saniye sonra
yeniler; uygulamadan son uygulamalar ekranına geçiş animasyonu anlık olarak canlı içeriği gösterebilir (kaydedilen
küçük resim boştur). LARC hatırlatması bir sonraki LARC ekranı açılışında nötr metne geçer.

## Sonraki milestone'lar
* **M3:** Gebelik modu, doğum kontrolü modu (withdrawal bleeding etiketi), çocuk modu, SQLCipher ile tam DB şifreleme,
  FLAG_SECURE / son uygulamalarda içeriği gizleme, Wear OS'tan gelen kaydın UI'ı anında yenilemesi.
* **Teknik borç:** upstream `deprecated_member_use` uyarıları (Radio/RadioGroup, `year2023`), regl "due/overdue"
  bildirimlerinin aynı ID'yi paylaşması, `setNotificationsEnabled(false)` hatası, 10 dildeki yeni anahtarların çevirisi.
