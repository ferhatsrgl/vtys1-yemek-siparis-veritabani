# Çevrimiçi Yemek Sipariş Platformu — Veritabanı Projesi

**Ders:** VTYS-1 (Veri Tabanı Yönetim Sistemleri)
**DBMS:** Microsoft SQL Server (T-SQL)
**Lokasyon:** Batman / Türkiye
**Veritabanı Adı:** `YemekSiparisDB`

## Proje Özeti

Bu proje, hayırsever müşterilerin ihtiyaç sahibi kullanıcılara ücretsiz yemek ulaştırabildiği bir **"Askıda Yemek"** modülüne sahip, klasik bir çevrimiçi yemek sipariş platformunun veritabanını tasarlar.

## Dosya Yapısı

| Dosya | Açıklama |
|-------|----------|
| `proje.sql` | Ana SQL dosyası: DDL, DML (mock data), View, Trigger, Index, analitik sorgular |
| `IsKurallari.md` | Tüm iş kuralları ve Askıda Yemek modülünün çalışma mantığı |
| `ER_Diyagrami.html` | Görsel Varlık-İlişki (ER) Diyagramı (tarayıcıda açın) |
| `YapayZekaBeyani.md` | AI kullanım dürüstlük raporu |
| `README.md` | Bu dosya |

## Kurulum

1. Microsoft SQL Server Management Studio (SSMS) açın.
2. `proje.sql` dosyasını açın.
3. Tüm dosyayı seçin ve **Execute** (F5) edin.
4. Çıktıda şu mesajları göreceksiniz:
   ```
   >> Tablolar oluşturuldu.
   >> Temel veriler yüklendi.
   >> Indexler oluşturuldu.
   >> Görünümler (View) oluşturuldu.
   >> Tetikleyiciler (Trigger) oluşturuldu.
   >> 100+ sipariş eklendi.
   >> Sipariş detayları eklendi.
   >> Askıda yemek kullanımları eklendi.
   >> Cirolar güncellendi. Veritabanı hazır.
   ```

## Tablo Listesi

| # | Tablo | İçerik |
|---|-------|--------|
| 1 | `Kategori` | Yemek kategorileri (Et, Burger, Makarna, Pizza, Tatlı, İçecek) |
| 2 | `Restoran` | 5 restoran (Ziyade Et, Burger King, Mad Mac, Vassoli, Mualla) |
| 3 | `Musteri` | 20 müşteri (bazıları hayırsever, bazıları doğrulanmış ihtiyaç sahibi) |
| 4 | `MusteriAdres` | Her müşterinin teslimat adresi |
| 5 | `Urun` | 51 ürün (5 restoranın menüleri) |
| 6 | `Kurye` | 7 kurye |
| 7 | `Siparis` | 100+ sipariş hareketi |
| 8 | `SiparisDetay` | Sipariş kalemleri (1-N) |
| 9 | `AskidaYemekHavuz` | Tek satırlı global havuz |
| 10 | `AskidaBagis` | Hayırsever bağışları (anonim seçeneği ile) |
| 11 | `AskidaKullanim` | İhtiyaç sahibi yararlanmaları |

## Zorunlu Gereksinimler Kontrol Listesi

- [x] 11 tablo, 3NF uyumlu
- [x] Primary Key + Foreign Key tüm tablolarda
- [x] CHECK Constraints (`CK_Restoran_Puan`, `CK_Urun_Fiyat`, `CK_Siparis_Tutar`, `CK_Detay_Adet`, `CK_Bagis_Tutar`, `CK_Havuz_Bakiye`, `CK_Siparis_Durum`, `CK_Musteri_Email`)
- [x] UNIQUE constraint (`Musteri.Email`, `Musteri.Telefon`, `Restoran.Telefon`, `Kurye.Telefon`, `AskidaKullanim.SiparisID`)
- [x] NOT NULL gerekli kolonlarda
- [x] Mock data: 5 restoran, 51 ürün, 20 müşteri, 100+ sipariş, 10 askıda bağışı
- [x] Soft Delete (`IsActive = 0`)
- [x] JOIN sorgusu (Sipariş + Müşteri + Restoran + Kurye + Detay + Ürün — 6 tablo)
- [x] GROUP BY + HAVING ile analitik sorgu (son 30 günde 5+ siparişi olan restoranların ortalama sepet tutarı)
- [x] Subquery (NOT EXISTS) — hiç bağış yapmamış aktif müşteriler
- [x] 3 adet View (`vw_AktifRestoranMenuleri`, `vw_AskidaYemekHavuzDurumu`, `vw_RestoranCiroOzeti`)
- [x] 3 adet Trigger (`trg_Siparis_CiroGuncelle`, `trg_AskidaKullanim_HavuzGuncelle`, `trg_AskidaBagis_HavuzGuncelle`)
- [x] 3 adet Index (`IX_Siparis_SiparisTarihi`, `IX_Musteri_Email`, `IX_Urun_Restoran_Active`)
- [x] AI Kullanım Beyanı

## "Askıda Yemek" Modülü — Hızlı Akış

```
  ┌──────────────┐    bağış    ┌──────────────────┐    kullanım    ┌─────────────────┐
  │  Hayırsever  │ ─────────► │ AskidaYemekHavuz │ ──────────────► │ İhtiyaç Sahibi  │
  │   Müşteri    │            │  (Global Bakiye) │                 │ (Doğrulanmış)   │
  └──────────────┘             └──────────────────┘                 └─────────────────┘
        │                              ▲                                    │
        │ AskidaBagis  ◄── trigger ────┤                                    │
        │  + GuncelBakiye              │                                    │
        ▼                              │ AskidaKullanim ── trigger ─────────┘
   trg_AskidaBagis_                    │  - GuncelBakiye
   HavuzGuncelle                       │  (negatife düşerse ROLLBACK)
                                       │
                                trg_AskidaKullanim_
                                HavuzGuncelle
```

Detaylar için `IsKurallari.md` dosyasını inceleyin.

## Test Senaryoları

`proje.sql` dosyasının en altındaki yorum satırlarında trigger'ın çalıştığını gösteren bir demo bulunur:

```sql
UPDATE Siparis SET Durum = 'Teslim Edildi' WHERE SiparisID = 75;
SELECT RestoranID, RestoranAdi, ToplamCiro FROM Restoran;
-- İlgili restoranın ToplamCiro değeri otomatik olarak artmış olmalıdır.
```

Havuz durumunu görmek için:

```sql
SELECT * FROM vw_AskidaYemekHavuzDurumu;
```
