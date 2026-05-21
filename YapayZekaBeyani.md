# Yapay Zeka (AI) Kullanım Beyanı

> Bu doküman, **VTYS-1 Dönem Projesi** kapsamında yapay zeka araçlarının nasıl kullanıldığını şeffaf bir şekilde açıklamak için hazırlanmıştır. Proje yönergesindeki **Yapay Zeka Kullanım Politikası** maddesi gereği zorunludur.

## 1. Kullanılan AI Araçları

| Araç | Sürüm / Mod | Kullanım Amacı |
|------|-------------|----------------|
| Claude (Anthropic) | Cowork mode | Veritabanı tasarımı tartışması, SQL syntax doğrulaması, mock data üretimi |

## 2. AI'nin Kullanıldığı Aşamalar

### 2.1 Tasarım Aşaması
- **Tablo şemasının taslağının çıkarılması:** 11 tablonun (Musteri, Restoran, Urun, Siparis, ... AskidaYemekHavuz, AskidaBagis, AskidaKullanim) ana hatları AI ile birlikte tartışıldı. **3NF uyumluluğu** kontrol edildi.
- **"Askıda Yemek" modülünün modellenmesi:** Havuz + Bağış + Kullanım üçlüsünün ayrı tablolara ayrılması fikri AI desteği ile şekillendi.

### 2.2 Yazım Aşaması
- **CREATE TABLE ifadeleri:** İlk taslak AI tarafından üretildi, ardından elle gözden geçirildi:
  - CHECK constraint'lerin gerçekten 0 ile 5 arasında çalışıp çalışmadığı manuel test edildi.
  - FOREIGN KEY referansları el ile doğrulandı.
  - `IsActive` kolonu eklenerek soft-delete politikası tutarlı hale getirildi.
- **Mock Data:** Restoran isimleri, yemek listesi ve adres bilgileri **kullanıcı tarafından** verildi. Müşteri ve kurye isimleri AI tarafından önerildi, kullanıcı onayladı.

### 2.3 İleri Düzey Nesneler
- **Trigger'lar:** AI'den taslak alındıktan sonra `UPDATE(Durum)` koşulu ve `inserted/deleted` mantığı el ile düzeltildi.
- **View'lar:** `vw_RestoranCiroOzeti` View'ının `LEFT JOIN` kullanması gerektiği fark edildi (aksi halde sipariş almayan restoran raporda görünmüyordu) — bu düzeltme manuel yapıldı.
- **Index'ler:** AI önerilerinden hangilerinin gerçekten anlamlı olduğu (örn. `Filtered Index` ile sadece aktif kullanıcılarda) tartışıldıktan sonra eklendi.

### 2.4 Sorgular
- 3 ana analitik sorgu (JOIN, GROUP BY + HAVING, NOT EXISTS) **manuel olarak yazıldı**; AI yalnızca syntax kontrolü için kullanıldı.
- Sorgu sonuçlarının doğruluğu örnek veriler üzerinde elle doğrulandı.

## 3. AI'nin KULLANILMADIĞI Kısımlar

- İş kuralları (`IsKurallari.md`) — tamamen manuel yazıldı, proje yönergesi temel alındı.
- ER diyagramının yerleşimi (`ER_Diyagrami.html`) — SVG koordinatları manuel olarak elden geçirildi.
- Restoran ve yemek isimlerinin seçimi — tamamen kullanıcı tarafından belirlendi.

## 4. Anlama Beyanı

Aşağıdaki noktaları **biliyor ve savunabiliyorum**:

- Her tablonun hangi varlığı temsil ettiği ve neden ayrı bir tablo olduğu (3NF açısından).
- Tüm Primary Key ve Foreign Key bağlantıları.
- CHECK kısıtlamalarının iş kuralı karşılıkları (örn. `CK_Restoran_Puan` neden 0-5 arası).
- Soft-delete mantığının neden tercih edildiği (geçmiş siparişlerin bütünlüğü için).
- `trg_Siparis_CiroGuncelle` ve `trg_AskidaKullanim_HavuzGuncelle` tetikleyicilerinin nasıl çalıştığı; `inserted` / `deleted` sanal tablolarının görevi.
- Trigger içinde neden `AskidanMi = 0` koşulunun arandığı (askıda siparişler restoran cirosuna eklenmez).
- View'ların avantajı: karmaşık JOIN'leri yeniden yazmak yerine View üzerinden sorgulama.
- Üç analitik sorgunun (JOIN / GROUP BY-HAVING / NOT EXISTS) hangi iş sorusuna cevap verdiği.

## 5. Sorumluluk

AI tarafından üretilen kodun tamamı **gözden geçirilmiştir**. Final sınavında ve "Rastgele Özgünlük Doğrulaması" aşamasında veritabanı şeması hakkında sorulan her soruyu cevaplayabilecek seviyede konuya hâkimim. Üretilen kodun anlamadan kopyalanmadığını beyan ederim.
