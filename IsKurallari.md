# İş Kuralları — Çevrimiçi Yemek Sipariş Platformu

Bu doküman, `YemekSiparisDB` veritabanının üzerine inşa edildiği iş kurallarını açıklar. Tüm tablolar ve ilişkiler bu kurallara göre tasarlanmıştır.

## 1. Genel Sistem

1. Sistem; **müşteri, restoran, kurye, kategori, ürün, sipariş** ve **sipariş detayı** ana varlıklarından oluşur.
2. Veritabanı en az **3. Normal Form (3NF)** seviyesinde tasarlanmıştır. Tekrar eden veri yoktur; her bilgi yalnızca bağlı olduğu tabloda tutulur.
3. **Fiziksel silme yasaktır.** Tüm "silme" işlemleri ilgili tablonun `IsActive` kolonunun `0` yapılması ile gerçekleşir (Soft Delete).
4. Müşteri ve restoran iletişim bilgileri (e-posta, telefon) **tekildir** (`UNIQUE`).

## 2. Müşteri Kuralları

1. Bir müşteri sisteme **e-posta + şifre** ile giriş yapar. E-posta `LIKE '%_@_%._%'` formatına uymalıdır (CHECK constraint).
2. Bir müşterinin **birden fazla adresi** olabilir (1-N ilişki: Musteri → MusteriAdres).
3. Müşteri hesabı pasifleştirilirse (`IsActive = 0`), o müşterinin mevcut siparişlerine dokunulmaz; sadece yeni sipariş veremez.
4. Bir müşteri aynı anda **hem hayırsever** (bağış yapan) **hem ihtiyaç sahibi** olarak işaretlenmez. (Pratikte ihtiyaç sahibi olmak, sistem tarafından doğrulanmış olmasını gerektirir: `IhtiyacSahibiDogrulandiMi = 1`.)

## 3. Restoran ve Menü Kuralları

1. Her restoranın bir **mutfak türü** ve **ilçesi** vardır. Restoran puanı 0 ile 5 arasında olmalıdır (`CHECK CK_Restoran_Puan`).
2. Bir restoranın menüsündeki her **ürün** bir **kategoriye** bağlıdır (Et Yemekleri, Burger, Makarna, Pizza, Tatlı, İçecek).
3. Ürün fiyatı 0'dan büyük olmalıdır (`CHECK CK_Urun_Fiyat`).
4. Bir ürün menüden kaldırıldığında satırı silinmez, `IsActive = 0` ile pasifleştirilir. Eski siparişlerde bu ürün hâlâ görünür kalır.

## 4. Sipariş Kuralları

1. Bir sipariş tek bir **restorana** verilebilir. Birden fazla restorandan tek seferde sipariş verilemez (çoklu sipariş ayrı kayıtlar olarak girilir).
2. Bir sipariş tek bir **kuryeye** atanabilir (atama henüz yapılmamışsa `KuryeID = NULL`).
3. Sipariş durumu aşağıdaki dört değerden biri olabilir (`CHECK CK_Siparis_Durum`):
   - `Hazırlanıyor`
   - `Yolda`
   - `Teslim Edildi`
   - `İptal Edildi`
4. Bir sipariş "Teslim Edildi" durumuna geçtiğinde, ilgili restoranın `ToplamCiro` değeri **otomatik olarak** sipariş tutarı kadar artar (`trg_Siparis_CiroGuncelle`).
5. "İptal Edildi" durumundaki siparişler ciroya yansımaz.
6. Sipariş tutarı 0'dan küçük olamaz (`CHECK CK_Siparis_Tutar`).
7. Her sipariş detayında adet ve birim fiyat 0'dan büyük olmalıdır.

## 5. "Askıda Yemek" Modülü Kuralları (ÖZEL KURAL)

Bu modül, hayırsever müşterilerin doğrulanmış ihtiyaç sahiplerine ücretsiz yemek ulaştırmasını sağlar.

### 5.1 Havuz

1. Sistemde tek bir global **havuz** vardır (`AskidaYemekHavuz`).
2. Havuzun üç temel alanı bulunur:
   - `ToplamBagis` → tüm zamanların toplam bağışı.
   - `ToplamKullanim` → tüm zamanların toplam kullanımı.
   - `GuncelBakiye` → kalan bakiye (ToplamBagis − ToplamKullanim).
3. Havuz bakiyesi **negatif olamaz** (`CHECK CK_Havuz_Bakiye`).

### 5.2 Bağış Akışı

1. Herhangi bir aktif müşteri (ihtiyaç sahibi olmayan) **bağış** yapabilir (`AskidaBagis`).
2. Bağışlar:
   - Açık olabilir → ad-soyad ile birlikte havuz raporlarında görünür.
   - **Anonim** olabilir (`AnonimMi = 1`) → bu durumda müşteri kimliği gizlenir, sadece sistem tarafında tutulur.
3. Bağış tutarı 0'dan büyük olmalıdır (`CHECK CK_Bagis_Tutar`).
4. Bağış kaydı oluşturulduğunda **`trg_AskidaBagis_HavuzGuncelle`** tetikleyicisi otomatik olarak:
   - `GuncelBakiye += BagisTutari`
   - `ToplamBagis += BagisTutari`
   - `SonGuncelleme = GETDATE()`

### 5.3 Kullanım Akışı

1. Yalnızca **`IhtiyacSahibiMi = 1` VE `IhtiyacSahibiDogrulandiMi = 1`** olan müşteriler askıdan yararlanabilir.
2. Müşteri askıda sipariş verdiğinde:
   - Sipariş tablosuna `AskidanMi = 1` olarak yazılır.
   - `OdemeYontemi = 'Askıda'` olarak işaretlenir.
   - Aynı zamanda `AskidaKullanim` tablosuna bir kayıt eklenir.
3. `AskidaKullanim` INSERT'i, **`trg_AskidaKullanim_HavuzGuncelle`** tetikleyicisini çalıştırır:
   - `GuncelBakiye -= KullanilanTutar`
   - `ToplamKullanim += KullanilanTutar`
   - Bakiye sıfırın altına düşerse `ROLLBACK` ile işlem geri alınır (`RAISERROR`).
4. Askıda siparişler restoranın **cirosuna eklenmez**; çünkü tutar müşteriden tahsil edilmez, havuzdan ödenir. (Restoran ödemesi farklı bir muhasebe akışıdır; bu projede kapsam dışıdır.)

### 5.4 Anonimlik

- `AnonimMi = 1` bağışlar için müşteri kimliği veritabanında saklı kalır ama tüm raporlama View'larında ve dış sorgularda `MusteriID` filtrelenmez; bunun yerine "Anonim Hayırsever" ibaresi gösterilebilir. (Bu projede `AnonimMi` bayrağı raporda nasıl gösterileceğine karar vermek için kullanılır.)

## 6. Kurye Kuralları

1. Kurye telefon numarası tekildir.
2. Bir kurye birden fazla siparişe atanabilir (1-N).
3. Pasif kurye (`IsActive = 0`) yeni siparişe atanamaz; mevcut atamaları korunur.

## 7. Performans & Bütünlük

1. Sık aranan kolonlarda Index tanımlıdır:
   - `IX_Siparis_SiparisTarihi` (tarih bazlı raporlama)
   - `IX_Musteri_Email` (login)
   - `IX_Urun_Restoran_Active` (menü listeleme)
2. Tüm tablo ilişkileri `FOREIGN KEY` ile garantilenir. Referans bütünlüğü ihlal edilemez.

## 8. Raporlama Görünümleri

- `vw_AktifRestoranMenuleri` → sadece aktif restoranların aktif ürünleri.
- `vw_AskidaYemekHavuzDurumu` → havuzun anlık durumu, bağışçı ve yararlanan sayısı.
- `vw_RestoranCiroOzeti` → her restoranın toplam ciro, sipariş sayısı, ortalama sepet tutarı.
