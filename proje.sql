-- =====================================================================
-- VTYS-1 DÖNEM PROJESİ
-- ÇEVRİMİÇİ YEMEK SİPARİŞ PLATFORMU VERİTABANI TASARIMI
-- DBMS: Microsoft SQL Server (T-SQL)
-- Konum: Batman / Türkiye
-- =====================================================================
-- Bu dosya aşağıdaki bölümleri içerir:
--   1) Veritabanı ve Tablolar (DDL)
--   2) Test Verileri (DML)
--   3) Indexler
--   4) Görünümler (Views)
--   5) Tetikleyiciler (Triggers)
--   6) İleri Düzey Sorgular (JOIN, GROUP BY/HAVING, Subquery)
-- =====================================================================

-- Eski veritabanını temizle (geliştirme amaçlı)
IF DB_ID('YemekSiparisDB') IS NOT NULL
BEGIN
    ALTER DATABASE YemekSiparisDB SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE YemekSiparisDB;
END
GO

CREATE DATABASE YemekSiparisDB;
GO
USE YemekSiparisDB;
GO

-- =====================================================================
-- 1. DDL : TABLO TANIMLARI
-- =====================================================================

-- 1.1 Kategori (yemek kategorileri)
CREATE TABLE Kategori (
    KategoriID   INT IDENTITY(1,1) PRIMARY KEY,
    KategoriAdi  NVARCHAR(50) NOT NULL UNIQUE,
    IsActive     BIT NOT NULL DEFAULT 1
);
GO

-- 1.2 Restoran
CREATE TABLE Restoran (
    RestoranID     INT IDENTITY(1,1) PRIMARY KEY,
    RestoranAdi    NVARCHAR(100) NOT NULL,
    MutfakTuru     NVARCHAR(50)  NOT NULL,
    Sehir          NVARCHAR(50)  NOT NULL DEFAULT 'Batman',
    Ilce           NVARCHAR(50)  NOT NULL,
    Telefon        NVARCHAR(20)  NOT NULL UNIQUE,
    Puan           DECIMAL(3,2)  NOT NULL DEFAULT 0,
    ToplamCiro     DECIMAL(15,2) NOT NULL DEFAULT 0,
    AcilisTarihi   DATE          NOT NULL DEFAULT GETDATE(),
    IsActive       BIT           NOT NULL DEFAULT 1,
    CONSTRAINT CK_Restoran_Puan CHECK (Puan BETWEEN 0 AND 5)
);
GO

-- 1.3 Müşteri
CREATE TABLE Musteri (
    MusteriID                  INT IDENTITY(1,1) PRIMARY KEY,
    Ad                         NVARCHAR(50) NOT NULL,
    Soyad                      NVARCHAR(50) NOT NULL,
    Email                      NVARCHAR(100) NOT NULL UNIQUE,
    Telefon                    NVARCHAR(20)  NOT NULL UNIQUE,
    Sifre                      NVARCHAR(255) NOT NULL,
    KayitTarihi                DATETIME      NOT NULL DEFAULT GETDATE(),
    IhtiyacSahibiMi            BIT           NOT NULL DEFAULT 0,
    IhtiyacSahibiDogrulandiMi  BIT           NOT NULL DEFAULT 0,
    IsActive                   BIT           NOT NULL DEFAULT 1,
    CONSTRAINT CK_Musteri_Email CHECK (Email LIKE '%_@_%._%')
);
GO

-- 1.4 Müşteri Adres (bir müşterinin birden fazla adresi olabilir)
CREATE TABLE MusteriAdres (
    AdresID    INT IDENTITY(1,1) PRIMARY KEY,
    MusteriID  INT NOT NULL,
    AdresBasligi NVARCHAR(50) NOT NULL,
    Sehir      NVARCHAR(50) NOT NULL DEFAULT 'Batman',
    Ilce       NVARCHAR(50) NOT NULL,
    AcikAdres  NVARCHAR(300) NOT NULL,
    IsActive   BIT NOT NULL DEFAULT 1,
    CONSTRAINT FK_MusteriAdres_Musteri FOREIGN KEY (MusteriID)
        REFERENCES Musteri(MusteriID)
);
GO

-- 1.5 Ürün (menü kalemleri)
CREATE TABLE Urun (
    UrunID       INT IDENTITY(1,1) PRIMARY KEY,
    RestoranID   INT NOT NULL,
    KategoriID   INT NOT NULL,
    UrunAdi      NVARCHAR(100) NOT NULL,
    Aciklama     NVARCHAR(300) NULL,
    Fiyat        DECIMAL(10,2) NOT NULL,
    IsActive     BIT NOT NULL DEFAULT 1,
    CONSTRAINT FK_Urun_Restoran FOREIGN KEY (RestoranID) REFERENCES Restoran(RestoranID),
    CONSTRAINT FK_Urun_Kategori FOREIGN KEY (KategoriID) REFERENCES Kategori(KategoriID),
    CONSTRAINT CK_Urun_Fiyat   CHECK (Fiyat > 0)
);
GO

-- 1.6 Kurye
CREATE TABLE Kurye (
    KuryeID    INT IDENTITY(1,1) PRIMARY KEY,
    Ad         NVARCHAR(50) NOT NULL,
    Soyad      NVARCHAR(50) NOT NULL,
    Telefon    NVARCHAR(20) NOT NULL UNIQUE,
    AracTuru   NVARCHAR(30) NOT NULL,
    IsActive   BIT NOT NULL DEFAULT 1
);
GO

-- 1.7 Askıda Yemek Havuzu (tek satır - global havuz)
CREATE TABLE AskidaYemekHavuz (
    HavuzID         INT IDENTITY(1,1) PRIMARY KEY,
    HavuzAdi        NVARCHAR(50) NOT NULL DEFAULT 'Genel Askıda Yemek Havuzu',
    GuncelBakiye    DECIMAL(15,2) NOT NULL DEFAULT 0,
    ToplamBagis     DECIMAL(15,2) NOT NULL DEFAULT 0,
    ToplamKullanim  DECIMAL(15,2) NOT NULL DEFAULT 0,
    SonGuncelleme   DATETIME NOT NULL DEFAULT GETDATE(),
    CONSTRAINT CK_Havuz_Bakiye CHECK (GuncelBakiye >= 0)
);
GO

-- 1.8 Askıda Bağış (hayırsever bağışları)
CREATE TABLE AskidaBagis (
    BagisID       INT IDENTITY(1,1) PRIMARY KEY,
    MusteriID     INT NOT NULL,
    HavuzID       INT NOT NULL,
    BagisTutari   DECIMAL(10,2) NOT NULL,
    BagisTarihi   DATETIME NOT NULL DEFAULT GETDATE(),
    AnonimMi      BIT NOT NULL DEFAULT 0,
    Aciklama      NVARCHAR(200) NULL,
    CONSTRAINT FK_Bagis_Musteri FOREIGN KEY (MusteriID) REFERENCES Musteri(MusteriID),
    CONSTRAINT FK_Bagis_Havuz   FOREIGN KEY (HavuzID)   REFERENCES AskidaYemekHavuz(HavuzID),
    CONSTRAINT CK_Bagis_Tutar   CHECK (BagisTutari > 0)
);
GO

-- 1.9 Sipariş
CREATE TABLE Siparis (
    SiparisID      INT IDENTITY(1,1) PRIMARY KEY,
    MusteriID      INT NOT NULL,
    RestoranID     INT NOT NULL,
    KuryeID        INT NULL,
    AdresID        INT NOT NULL,
    SiparisTarihi  DATETIME NOT NULL DEFAULT GETDATE(),
    Tutar          DECIMAL(10,2) NOT NULL,
    Durum          NVARCHAR(30)  NOT NULL DEFAULT 'Hazırlanıyor',
    OdemeYontemi   NVARCHAR(30)  NOT NULL DEFAULT 'Kredi Kartı',
    AskidanMi      BIT NOT NULL DEFAULT 0,
    IsActive       BIT NOT NULL DEFAULT 1,
    CONSTRAINT FK_Siparis_Musteri  FOREIGN KEY (MusteriID)  REFERENCES Musteri(MusteriID),
    CONSTRAINT FK_Siparis_Restoran FOREIGN KEY (RestoranID) REFERENCES Restoran(RestoranID),
    CONSTRAINT FK_Siparis_Kurye    FOREIGN KEY (KuryeID)    REFERENCES Kurye(KuryeID),
    CONSTRAINT FK_Siparis_Adres    FOREIGN KEY (AdresID)    REFERENCES MusteriAdres(AdresID),
    CONSTRAINT CK_Siparis_Tutar    CHECK (Tutar >= 0),
    CONSTRAINT CK_Siparis_Durum    CHECK (Durum IN ('Hazırlanıyor','Yolda','Teslim Edildi','İptal Edildi'))
);
GO

-- 1.10 Sipariş Detayı (sipariş kalemleri)
CREATE TABLE SiparisDetay (
    SiparisDetayID INT IDENTITY(1,1) PRIMARY KEY,
    SiparisID      INT NOT NULL,
    UrunID         INT NOT NULL,
    Adet           INT NOT NULL,
    BirimFiyat     DECIMAL(10,2) NOT NULL,
    CONSTRAINT FK_Detay_Siparis FOREIGN KEY (SiparisID) REFERENCES Siparis(SiparisID),
    CONSTRAINT FK_Detay_Urun    FOREIGN KEY (UrunID)    REFERENCES Urun(UrunID),
    CONSTRAINT CK_Detay_Adet    CHECK (Adet > 0),
    CONSTRAINT CK_Detay_Fiyat   CHECK (BirimFiyat > 0)
);
GO

-- 1.11 Askıda Kullanım (ihtiyaç sahibi müşterinin havuzdan yararlanması)
CREATE TABLE AskidaKullanim (
    KullanimID      INT IDENTITY(1,1) PRIMARY KEY,
    SiparisID       INT NOT NULL UNIQUE, -- her sipariş tek bir kullanım kaydına bağlanır
    HavuzID         INT NOT NULL,
    MusteriID       INT NOT NULL,
    KullanilanTutar DECIMAL(10,2) NOT NULL,
    KullanimTarihi  DATETIME NOT NULL DEFAULT GETDATE(),
    CONSTRAINT FK_Kullanim_Siparis FOREIGN KEY (SiparisID) REFERENCES Siparis(SiparisID),
    CONSTRAINT FK_Kullanim_Havuz   FOREIGN KEY (HavuzID)   REFERENCES AskidaYemekHavuz(HavuzID),
    CONSTRAINT FK_Kullanim_Musteri FOREIGN KEY (MusteriID) REFERENCES Musteri(MusteriID),
    CONSTRAINT CK_Kullanim_Tutar   CHECK (KullanilanTutar > 0)
);
GO

PRINT '>> Tablolar oluşturuldu.';
GO

-- =====================================================================
-- 2. DML : TEST VERİLERİ (MOCK DATA)
-- =====================================================================

-- 2.1 Kategoriler
INSERT INTO Kategori (KategoriAdi) VALUES
('Et Yemekleri'), ('Burger'), ('Makarna'), ('Pizza'), ('Tatlı'), ('İçecek');
GO

-- 2.2 Restoranlar (5 adet, hepsi Batman ilçelerinde)
INSERT INTO Restoran (RestoranAdi, MutfakTuru, Sehir, Ilce, Telefon, Puan, AcilisTarihi) VALUES
('Ziyade Et Lokantası', 'Türk Mutfağı / Et',   'Batman', 'Merkez',     '0488-111-2201', 4.70, '2018-03-15'),
('Burger King',         'Fast Food',            'Batman', 'Merkez',     '0488-111-2202', 4.20, '2015-06-01'),
('Mad Mac',             'İtalyan / Makarna',    'Batman', 'Kozluk',     '0488-111-2203', 4.50, '2020-09-10'),
('Vassoli',             'İtalyan / Pizza',      'Batman', 'Merkez',     '0488-111-2204', 4.60, '2019-11-20'),
('Mualla',              'Tatlıcı',              'Batman', 'Sason',      '0488-111-2205', 4.85, '2017-04-08');
GO

-- 2.3 Ürünler (51 adet)
-- Ziyade Et Lokantası (RestoranID=1, Kategori: Et Yemekleri=1)
INSERT INTO Urun (RestoranID, KategoriID, UrunAdi, Aciklama, Fiyat) VALUES
(1, 1, 'Adana Kebap',     'Acılı kıyma kebabı, lavaş ile servis edilir', 220.00),
(1, 1, 'Ciğer',           'Ocakbaşı usulü kuzu ciğer şiş',                190.00),
(1, 1, 'Pide',            'Kıymalı veya kuşbaşılı pide',                  160.00),
(1, 1, 'Lahmacun',        'İnce hamur, acılı kıymalı',                     45.00),
(1, 1, 'Karışık Izgara',  'Adana, urfa, kanat, köfte karışık tabak',     320.00),
(1, 1, 'Tavuk Izgara',    'Marine edilmiş tavuk göğsü ızgara',            180.00),
(1, 1, 'Pirzola',         'Kuzu pirzola, közlenmiş sebzelerle',          340.00),
(1, 1, 'Saç Tava',        'Kuşbaşı et, biber, soğan, domates ile',       260.00),
(1, 1, 'Tavuk Sote',      'Tavuk göğsü sote, mantarlı',                  175.00),
(1, 1, 'Et Sote',         'Kuşbaşı kırmızı et sote',                     280.00);
GO

-- Burger King (RestoranID=2, Kategori: Burger=2)
INSERT INTO Urun (RestoranID, KategoriID, UrunAdi, Aciklama, Fiyat) VALUES
(2, 2, 'Big King Menü',         'Big King + Patates + İçecek',                   215.00),
(2, 2, 'Whopper Menü',          'Whopper + Patates + İçecek',                    230.00),
(2, 2, 'Ekonomix Menü',         'Hamburger + Küçük Patates + İçecek',            120.00),
(2, 2, 'Taraftar Menüsü',       'Çift kişilik fırsat menü',                      385.00),
(2, 2, 'King Chicken Menü',     'King Chicken + Patates + İçecek',               210.00),
(2, 2, 'Long Chicken Menü',     'Uzun tavuk burger + Patates + İçecek',          195.00),
(2, 2, 'Chicken Royale Menü',   'Çıtır tavuk göğsü burger + Patates + İçecek',  205.00),
(2, 2, 'Steakhouse Menü',       'Köfte burger + Patates + İçecek',               240.00),
(2, 2, 'Veggie King Menü',      'Vejetaryen burger + Patates + İçecek',          200.00),
(2, 2, 'Texas BBQ Menü',        'BBQ soslu burger + Patates + İçecek',           225.00);
GO

-- Mad Mac (RestoranID=3, Kategori: Makarna=3)
INSERT INTO Urun (RestoranID, KategoriID, UrunAdi, Aciklama, Fiyat) VALUES
(3, 3, 'Arabiatta',                       'Acılı domates soslu makarna',           135.00),
(3, 3, 'Napoliten Soslu Makarna',         'Klasik domates soslu',                  125.00),
(3, 3, 'Kremalı Tavuklu Makarna',         'Beşamel soslu tavuk parçacıklı',        165.00),
(3, 3, 'Kremalı Mantarlı Makarna',        'Beşamel soslu mantar parçalı',          155.00),
(3, 3, 'Kıymalı Makarna',                 'Bolonez usulü kıymalı',                 170.00),
(3, 3, 'Pesto Soslu Makarna',             'Fesleğen, çam fıstığı, parmesan',       160.00),
(3, 3, 'Mac and Cheese',                  'Üç peynirli klasik mac and cheese',     175.00),
(3, 3, 'Kırmızı Biber Soslu Makarna',     'Közlenmiş kırmızı biber sosu',          150.00),
(3, 3, 'Sebzeli Makarna',                 'Mevsim sebzeleri ile',                  140.00),
(3, 3, 'Köri Soslu Makarna',              'Hindistan cevizi sütlü köri sosu',      165.00);
GO

-- Vassoli (RestoranID=4, Kategori: Pizza=4)
INSERT INTO Urun (RestoranID, KategoriID, UrunAdi, Aciklama, Fiyat) VALUES
(4, 4, 'Karışık Pizza',     'Sucuk, sosis, mantar, mısır, biber',         210.00),
(4, 4, 'Kavurmalı Pizza',   'El kavurması, kaşar, soğan',                  255.00),
(4, 4, 'Margarita',         'Domates sos, mozzarella, fesleğen',           175.00),
(4, 4, 'Tavuklu Pizza',     'Marine tavuk, mantar, biber',                 220.00),
(4, 4, 'Pepperoni',         'Sucuk, mozzarella, domates sos',              230.00),
(4, 4, '4 Peynirli Pizza',  'Mozzarella, parmesan, gorgonzola, çedar',    245.00),
(4, 4, 'Mantarlı Pizza',    'Bol mantar, kaşar, beyaz sos',                205.00),
(4, 4, 'Vejetaryen Pizza',  'Bol sebzeli, et içermez',                     195.00),
(4, 4, 'Hawai Pizza',       'Ananas, tavuk, mozzarella',                   215.00),
(4, 4, 'Diavola Pizza',     'Acılı pepperoni, soğan, jalapeno',            240.00);
GO

-- Mualla (RestoranID=5, Kategori: Tatlı=5)
INSERT INTO Urun (RestoranID, KategoriID, UrunAdi, Aciklama, Fiyat) VALUES
(5, 5, 'Meftun',                     'Geleneksel Batman tatlısı',            95.00),
(5, 5, 'Çikolatalı Waffle',          'Belçika çikolatası soslu',            145.00),
(5, 5, 'Beyaz Çikolatalı Waffle',    'Beyaz çikolata + meyveli',            150.00),
(5, 5, 'Muhallebi',                  'Sütlü, vanilyalı klasik muhallebi',    65.00),
(5, 5, 'Sütlaç',                     'Fırın sütlaç',                          70.00),
(5, 5, 'Fondü',                      'Çikolata fondü meyve tabağı ile',     180.00),
(5, 5, 'Maksude',                    'Şerbetli geleneksel tatlı',            85.00),
(5, 5, 'Magnolia',                   'Bisküvili sütlü tatlı',                110.00),
(5, 5, 'Pankek',                     'Akçaağaç şuruplu pankek',             120.00),
(5, 5, 'Tiramisu',                   'Mascarpone + kahveli klasik İtalyan', 130.00),
(5, 5, 'Trileçe',                    'Üç sütlü kek',                         100.00);
GO

-- 2.4 Müşteriler (20 adet, bazıları hayırsever bazıları ihtiyaç sahibi)
INSERT INTO Musteri (Ad, Soyad, Email, Telefon, Sifre, IhtiyacSahibiMi, IhtiyacSahibiDogrulandiMi) VALUES
('Mehmet',   'Yılmaz',   'mehmet.yilmaz@mail.com',  '0530-100-0001', 'sifre001', 0, 0), -- Hayırsever
('Fatma',    'Demir',    'fatma.demir@mail.com',    '0530-100-0002', 'sifre002', 0, 0),
('Ahmet',    'Kaya',     'ahmet.kaya@mail.com',     '0530-100-0003', 'sifre003', 0, 0), -- Hayırsever
('Ayşe',     'Çelik',    'ayse.celik@mail.com',     '0530-100-0004', 'sifre004', 0, 0),
('Mustafa',  'Şahin',    'mustafa.sahin@mail.com',  '0530-100-0005', 'sifre005', 0, 0),
('Zeynep',   'Aydın',    'zeynep.aydin@mail.com',   '0530-100-0006', 'sifre006', 0, 0), -- Anonim hayırsever
('Hasan',    'Öztürk',   'hasan.ozturk@mail.com',   '0530-100-0007', 'sifre007', 1, 1), -- İhtiyaç sahibi (doğrulanmış)
('Elif',     'Yıldız',   'elif.yildiz@mail.com',    '0530-100-0008', 'sifre008', 0, 0),
('Ali',      'Doğan',    'ali.dogan@mail.com',      '0530-100-0009', 'sifre009', 0, 0), -- Hayırsever
('Hatice',   'Arslan',   'hatice.arslan@mail.com',  '0530-100-0010', 'sifre010', 0, 0),
('Hüseyin',  'Kurt',     'huseyin.kurt@mail.com',   '0530-100-0011', 'sifre011', 1, 1), -- İhtiyaç sahibi (doğrulanmış)
('Emine',    'Bulut',    'emine.bulut@mail.com',    '0530-100-0012', 'sifre012', 0, 0),
('İbrahim',  'Aslan',    'ibrahim.aslan@mail.com',  '0530-100-0013', 'sifre013', 0, 0), -- Hayırsever
('Hacer',    'Polat',    'hacer.polat@mail.com',    '0530-100-0014', 'sifre014', 0, 0),
('Ramazan',  'Erdem',    'ramazan.erdem@mail.com',  '0530-100-0015', 'sifre015', 0, 0),
('Sevgi',    'Çakır',    'sevgi.cakir@mail.com',    '0530-100-0016', 'sifre016', 1, 1), -- İhtiyaç sahibi (doğrulanmış)
('Yusuf',    'Akın',     'yusuf.akin@mail.com',     '0530-100-0017', 'sifre017', 0, 0),
('Meryem',   'Koç',      'meryem.koc@mail.com',     '0530-100-0018', 'sifre018', 0, 0), -- Hayırsever
('Süleyman', 'Türkmen',  'suleyman.turkmen@mail.com','0530-100-0019', 'sifre019', 0, 0),
('Halime',   'Acar',     'halime.acar@mail.com',    '0530-100-0020', 'sifre020', 1, 0); -- İhtiyaç sahibi (henüz doğrulanmamış)
GO

-- 2.5 Müşteri Adresleri (her müşteri için en az 1 adres)
INSERT INTO MusteriAdres (MusteriID, AdresBasligi, Sehir, Ilce, AcikAdres) VALUES
(1,  'Ev',  'Batman', 'Merkez', 'Yeşiltepe Mah. 100. Sok. No:5'),
(2,  'Ev',  'Batman', 'Merkez', 'Bahçelievler Mah. Gül Cad. No:12'),
(3,  'Ev',  'Batman', 'Kozluk', 'Cumhuriyet Mah. No:8'),
(4,  'Ev',  'Batman', 'Merkez', 'Çarşı Mah. 15. Sok. No:3'),
(5,  'İş',  'Batman', 'Merkez', 'Petrol Mah. Sanayi Cad. No:21'),
(6,  'Ev',  'Batman', 'Sason',  'Yenimahalle 7. Sok. No:1'),
(7,  'Ev',  'Batman', 'Merkez', 'Karşıyaka Mah. 22. Sok. No:9'),
(8,  'Ev',  'Batman', 'Merkez', 'İncirli Mah. Park Cad. No:14'),
(9,  'Ev',  'Batman', 'Beşiri', 'Atatürk Mah. No:6'),
(10, 'Ev',  'Batman', 'Merkez', 'Kültür Mah. Lale Sok. No:11'),
(11, 'Ev',  'Batman', 'Kozluk', 'Yeni Mah. 5. Sok. No:18'),
(12, 'Ev',  'Batman', 'Merkez', 'Fatih Mah. Selvi Sok. No:7'),
(13, 'Ev',  'Batman', 'Merkez', 'Yavuz Selim Mah. No:34'),
(14, 'Ev',  'Batman', 'Hasankeyf', 'Tarihi Mah. No:2'),
(15, 'Ev',  'Batman', 'Merkez', 'Gültepe Mah. Bahar Sok. No:13'),
(16, 'Ev',  'Batman', 'Merkez', 'Esentepe Mah. Sevgi Sok. No:4'),
(17, 'Ev',  'Batman', 'Gercüş', 'Yeni Cami Mah. No:9'),
(18, 'Ev',  'Batman', 'Merkez', 'Kuruçeşme Mah. Yıldız Sok. No:6'),
(19, 'Ev',  'Batman', 'Merkez', 'Petrolkent Mah. 88. Sok. No:17'),
(20, 'Ev',  'Batman', 'Merkez', 'Şehit Tuncay Mah. No:3');
GO

-- 2.6 Kuryeler (7 adet)
INSERT INTO Kurye (Ad, Soyad, Telefon, AracTuru) VALUES
('Cemal',    'Bozkurt',  '0532-200-3001', 'Motosiklet'),
('Selim',    'Yavuz',    '0532-200-3002', 'Motosiklet'),
('Murat',    'Tekin',    '0532-200-3003', 'Bisiklet'),
('Osman',    'Dağ',      '0532-200-3004', 'Motosiklet'),
('Veli',     'Korkmaz',  '0532-200-3005', 'Otomobil'),
('Bekir',    'Sönmez',   '0532-200-3006', 'Motosiklet'),
('Yavuz',    'Çetin',    '0532-200-3007', 'Bisiklet');
GO

-- 2.7 Askıda Yemek Havuzu (tek satır - tek havuz)
INSERT INTO AskidaYemekHavuz (HavuzAdi, GuncelBakiye, ToplamBagis, ToplamKullanim) VALUES
('Batman Askıda Yemek Havuzu', 0, 0, 0);
GO

-- 2.8 Askıda Bağışlar (hayırsever müşterilerden)
-- Not: Bu kayıtlar tetikleyici eklenmeden ÖNCE yapıldığı için bakiyeyi
--      manuel UPDATE ile de güncelliyoruz (aşağıdaki UPDATE'e bakınız).
INSERT INTO AskidaBagis (MusteriID, HavuzID, BagisTutari, BagisTarihi, AnonimMi, Aciklama) VALUES
( 1, 1, 500.00, '2026-04-01', 0, 'Ramazan ayı bağışı'),
( 3, 1, 750.00, '2026-04-03', 0, 'Aylık düzenli bağış'),
( 6, 1, 300.00, '2026-04-05', 1, NULL),                    -- Anonim
( 9, 1, 400.00, '2026-04-10', 0, 'Çocuklar için'),
(13, 1, 600.00, '2026-04-12', 0, 'Bayram bağışı'),
(18, 1, 250.00, '2026-04-18', 0, NULL),
( 1, 1, 350.00, '2026-04-22', 1, 'Anonim katkı'),          -- Anonim
( 3, 1, 200.00, '2026-04-28', 0, 'Cuma bağışı'),
( 9, 1, 450.00, '2026-05-02', 0, NULL),
(13, 1, 500.00, '2026-05-08', 1, NULL);                    -- Anonim
GO

-- Havuz bakiyesini ilk INSERT'ler için manuel güncelle
UPDATE AskidaYemekHavuz
SET ToplamBagis    = (SELECT SUM(BagisTutari) FROM AskidaBagis WHERE HavuzID = 1),
    GuncelBakiye   = (SELECT SUM(BagisTutari) FROM AskidaBagis WHERE HavuzID = 1),
    SonGuncelleme  = GETDATE()
WHERE HavuzID = 1;
GO

PRINT '>> Temel veriler yüklendi.';
GO

-- =====================================================================
-- 3. INDEXLER (Performans için, PK'lar zaten clustered index'tir)
-- =====================================================================

-- 3.1 Sipariş tarihine göre arama (analitik raporlar için)
CREATE NONCLUSTERED INDEX IX_Siparis_SiparisTarihi
    ON Siparis (SiparisTarihi DESC);
GO

-- 3.2 Müşteri email araması (login işlemleri için)
CREATE NONCLUSTERED INDEX IX_Musteri_Email
    ON Musteri (Email)
    WHERE IsActive = 1;
GO

-- 3.3 Restoran bazlı ürün araması (menü listeleme için)
CREATE NONCLUSTERED INDEX IX_Urun_Restoran_Active
    ON Urun (RestoranID, IsActive)
    INCLUDE (UrunAdi, Fiyat);
GO

PRINT '>> Indexler oluşturuldu.';
GO

-- =====================================================================
-- 4. GÖRÜNÜMLER (VIEWS)
-- =====================================================================

-- 4.1 Aktif Restoran Menüleri
CREATE VIEW vw_AktifRestoranMenuleri AS
SELECT
    r.RestoranID,
    r.RestoranAdi,
    r.MutfakTuru,
    r.Ilce,
    k.KategoriAdi,
    u.UrunID,
    u.UrunAdi,
    u.Fiyat
FROM Restoran r
INNER JOIN Urun u     ON u.RestoranID = r.RestoranID
INNER JOIN Kategori k ON k.KategoriID = u.KategoriID
WHERE r.IsActive = 1 AND u.IsActive = 1;
GO

-- 4.2 Askıda Yemek Havuzu Durumu
CREATE VIEW vw_AskidaYemekHavuzDurumu AS
SELECT
    h.HavuzID,
    h.HavuzAdi,
    h.GuncelBakiye,
    h.ToplamBagis,
    h.ToplamKullanim,
    (SELECT COUNT(DISTINCT MusteriID) FROM AskidaBagis    WHERE HavuzID = h.HavuzID) AS ToplamBagisciSayisi,
    (SELECT COUNT(DISTINCT MusteriID) FROM AskidaKullanim WHERE HavuzID = h.HavuzID) AS ToplamYararlanansayisi,
    h.SonGuncelleme
FROM AskidaYemekHavuz h;
GO

-- 4.3 Restoran Ciro Özeti
CREATE VIEW vw_RestoranCiroOzeti AS
SELECT
    r.RestoranID,
    r.RestoranAdi,
    r.MutfakTuru,
    COUNT(s.SiparisID)            AS ToplamSiparisSayisi,
    ISNULL(SUM(s.Tutar), 0)       AS ToplamSatis,
    ISNULL(AVG(s.Tutar), 0)       AS OrtalamaSepetTutari,
    r.ToplamCiro
FROM Restoran r
LEFT JOIN Siparis s
       ON s.RestoranID = r.RestoranID
      AND s.Durum = 'Teslim Edildi'
      AND s.IsActive = 1
GROUP BY r.RestoranID, r.RestoranAdi, r.MutfakTuru, r.ToplamCiro;
GO

PRINT '>> Görünümler (View) oluşturuldu.';
GO

-- =====================================================================
-- 5. TETİKLEYİCİLER (TRIGGERS)
-- =====================================================================

-- 5.1 Sipariş "Teslim Edildi" durumuna geçtiğinde restoran cirosunu güncelle
-- Toplu UPDATE'lerde aynı restorana ait birden fazla siparişin doğru toplanabilmesi için
-- inserted/deleted tabloları önce SUM ile agrege edilir.
CREATE TRIGGER trg_Siparis_CiroGuncelle
ON Siparis
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    -- Sadece Durum değişti ise işle
    IF UPDATE(Durum)
    BEGIN
        UPDATE r
        SET r.ToplamCiro = r.ToplamCiro + t.EklenecekCiro
        FROM Restoran r
        INNER JOIN (
            SELECT i.RestoranID, SUM(i.Tutar) AS EklenecekCiro
            FROM inserted i
            INNER JOIN deleted d ON d.SiparisID = i.SiparisID
            WHERE i.Durum = 'Teslim Edildi'
              AND d.Durum <> 'Teslim Edildi'
              AND i.AskidanMi = 0   -- Askıda siparişler ciroya yazılmaz
            GROUP BY i.RestoranID
        ) t ON t.RestoranID = r.RestoranID;
    END
END
GO

-- 5.2 Askıda yemek kullanıldığında havuz bakiyesini düşür
-- Toplu INSERT'leri doğru işlemek için inserted tablosu agregasyonu (SUM) ile güncellenir.
CREATE TRIGGER trg_AskidaKullanim_HavuzGuncelle
ON AskidaKullanim
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE h
    SET h.GuncelBakiye   = h.GuncelBakiye   - ISNULL(t.ToplamDusum, 0),
        h.ToplamKullanim = h.ToplamKullanim + ISNULL(t.ToplamDusum, 0),
        h.SonGuncelleme  = GETDATE()
    FROM AskidaYemekHavuz h
    INNER JOIN (
        SELECT HavuzID, SUM(KullanilanTutar) AS ToplamDusum
        FROM inserted
        GROUP BY HavuzID
    ) t ON t.HavuzID = h.HavuzID;

    -- Bakiye sıfırın altına düştüyse hata fırlat ve geri al
    IF EXISTS (SELECT 1 FROM AskidaYemekHavuz WHERE GuncelBakiye < 0)
    BEGIN
        RAISERROR('Askıda yemek havuzunda yeterli bakiye yok!', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END
END
GO

-- 5.3 Askıda bağış yapıldığında havuz bakiyesini artır
-- Toplu INSERT'leri doğru işlemek için inserted tablosu agregasyonu (SUM) ile güncellenir.
CREATE TRIGGER trg_AskidaBagis_HavuzGuncelle
ON AskidaBagis
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE h
    SET h.GuncelBakiye  = h.GuncelBakiye  + ISNULL(t.ToplamBagis, 0),
        h.ToplamBagis   = h.ToplamBagis   + ISNULL(t.ToplamBagis, 0),
        h.SonGuncelleme = GETDATE()
    FROM AskidaYemekHavuz h
    INNER JOIN (
        SELECT HavuzID, SUM(BagisTutari) AS ToplamBagis
        FROM inserted
        GROUP BY HavuzID
    ) t ON t.HavuzID = h.HavuzID;
END
GO

PRINT '>> Tetikleyiciler (Trigger) oluşturuldu.';
GO

-- =====================================================================
-- 6. SİPARİŞLER (100+ ADET)
-- =====================================================================
-- Aşağıdaki siparişlerin bir kısmı "Teslim Edildi" durumunda eklenmiş
-- ve trg_Siparis_CiroGuncelle henüz devrede olmadığı için cirolar
-- manuel olarak güncellenecektir (en alttaki UPDATE bloguna bakınız).

-- Açıklama:
-- AskidanMi = 1 olan siparişler havuzdan karşılanır ve müşteriye 0 TL yansır.
-- Tutar alanı yine de gerçek menü tutarını gösterir (raporlama için).

INSERT INTO Siparis (MusteriID, RestoranID, KuryeID, AdresID, SiparisTarihi, Tutar, Durum, OdemeYontemi, AskidanMi) VALUES
-- Nisan 2026 siparişleri
( 1, 1, 1,  1, '2026-04-02 12:15', 410.00, 'Teslim Edildi', 'Kredi Kartı', 0),
( 2, 2, 2,  2, '2026-04-02 13:30', 215.00, 'Teslim Edildi', 'Nakit',        0),
( 3, 3, 3,  3, '2026-04-03 19:00', 290.00, 'Teslim Edildi', 'Kredi Kartı', 0),
( 4, 4, 4,  4, '2026-04-04 20:10', 245.00, 'Teslim Edildi', 'Kredi Kartı', 0),
( 5, 5, 5,  5, '2026-04-05 16:00', 195.00, 'Teslim Edildi', 'Nakit',        0),
( 6, 1, 6,  6, '2026-04-06 18:45', 380.00, 'Teslim Edildi', 'Kredi Kartı', 0),
( 7, 2, 7,  7, '2026-04-07 12:00', 215.00, 'Teslim Edildi', 'Askıda',       1), -- ASKIDA
( 8, 3, 1,  8, '2026-04-08 14:00', 160.00, 'Teslim Edildi', 'Kredi Kartı', 0),
( 9, 4, 2,  9, '2026-04-09 19:30', 420.00, 'Teslim Edildi', 'Kredi Kartı', 0),
(10, 5, 3, 10, '2026-04-09 21:00', 130.00, 'Teslim Edildi', 'Nakit',        0),
(11, 1, 4, 11, '2026-04-10 13:15', 220.00, 'Teslim Edildi', 'Askıda',       1), -- ASKIDA
(12, 2, 5, 12, '2026-04-11 20:00', 230.00, 'Teslim Edildi', 'Kredi Kartı', 0),
(13, 3, 6, 13, '2026-04-12 18:45', 305.00, 'Teslim Edildi', 'Kredi Kartı', 0),
(14, 4, 7, 14, '2026-04-13 21:15', 175.00, 'Teslim Edildi', 'Kredi Kartı', 0),
(15, 5, 1, 15, '2026-04-14 17:00', 180.00, 'Teslim Edildi', 'Nakit',        0),
(16, 1, 2, 16, '2026-04-15 12:30', 190.00, 'Teslim Edildi', 'Askıda',       1), -- ASKIDA
(17, 2, 3, 17, '2026-04-15 19:00', 240.00, 'Teslim Edildi', 'Kredi Kartı', 0),
(18, 3, 4, 18, '2026-04-16 20:00', 165.00, 'Teslim Edildi', 'Kredi Kartı', 0),
(19, 4, 5, 19, '2026-04-17 21:00', 215.00, 'Teslim Edildi', 'Kredi Kartı', 0),
(20, 5, 6, 20, '2026-04-18 16:45', 110.00, 'Teslim Edildi', 'Nakit',        0),
( 1, 2, 7,  1, '2026-04-19 13:20', 215.00, 'Teslim Edildi', 'Kredi Kartı', 0),
( 2, 1, 1,  2, '2026-04-19 19:15', 280.00, 'Teslim Edildi', 'Kredi Kartı', 0),
( 3, 4, 2,  3, '2026-04-20 20:30', 230.00, 'Teslim Edildi', 'Kredi Kartı', 0),
( 4, 3, 3,  4, '2026-04-20 21:00', 135.00, 'Teslim Edildi', 'Nakit',        0),
( 5, 5, 4,  5, '2026-04-21 17:30', 145.00, 'Teslim Edildi', 'Kredi Kartı', 0),
( 7, 1, 5,  7, '2026-04-22 12:45', 220.00, 'Teslim Edildi', 'Askıda',       1), -- ASKIDA
( 8, 4, 6,  8, '2026-04-22 19:45', 175.00, 'Teslim Edildi', 'Kredi Kartı', 0),
( 9, 2, 7,  9, '2026-04-23 13:00', 230.00, 'Teslim Edildi', 'Kredi Kartı', 0),
(10, 3, 1, 10, '2026-04-23 20:00', 165.00, 'Teslim Edildi', 'Nakit',        0),
(11, 5, 2, 11, '2026-04-24 21:30', 100.00, 'Teslim Edildi', 'Askıda',       1), -- ASKIDA
(12, 1, 3, 12, '2026-04-25 12:30', 340.00, 'Teslim Edildi', 'Kredi Kartı', 0),
(13, 4, 4, 13, '2026-04-25 20:00', 245.00, 'Teslim Edildi', 'Kredi Kartı', 0),
(14, 2, 5, 14, '2026-04-26 19:00', 195.00, 'Teslim Edildi', 'Kredi Kartı', 0),
(15, 3, 6, 15, '2026-04-27 13:30', 155.00, 'Teslim Edildi', 'Nakit',        0),
(16, 5, 7, 16, '2026-04-27 21:00', 130.00, 'Teslim Edildi', 'Askıda',       1), -- ASKIDA
(17, 1, 1, 17, '2026-04-28 12:00', 260.00, 'Teslim Edildi', 'Kredi Kartı', 0),
(18, 4, 2, 18, '2026-04-29 20:00', 195.00, 'Teslim Edildi', 'Kredi Kartı', 0),
(19, 2, 3, 19, '2026-04-29 13:45', 205.00, 'Teslim Edildi', 'Kredi Kartı', 0),
(20, 3, 4, 20, '2026-04-30 19:30', 170.00, 'Teslim Edildi', 'Nakit',        0),
( 1, 5, 5,  1, '2026-04-30 21:00',  95.00, 'Teslim Edildi', 'Kredi Kartı', 0),
-- Mayıs 2026 siparişleri
( 2, 1, 6,  2, '2026-05-01 12:30', 320.00, 'Teslim Edildi', 'Kredi Kartı', 0),
( 3, 2, 7,  3, '2026-05-01 19:30', 240.00, 'Teslim Edildi', 'Kredi Kartı', 0),
( 4, 4, 1,  4, '2026-05-02 20:00', 220.00, 'Teslim Edildi', 'Kredi Kartı', 0),
( 5, 3, 2,  5, '2026-05-02 21:15', 175.00, 'Teslim Edildi', 'Nakit',        0),
( 7, 5, 3,  7, '2026-05-03 18:45', 110.00, 'Teslim Edildi', 'Askıda',       1), -- ASKIDA
( 8, 1, 4,  8, '2026-05-04 13:00', 220.00, 'Teslim Edildi', 'Kredi Kartı', 0),
( 9, 2, 5,  9, '2026-05-04 19:00', 385.00, 'Teslim Edildi', 'Kredi Kartı', 0),
(10, 4, 6, 10, '2026-05-05 20:30', 205.00, 'Teslim Edildi', 'Kredi Kartı', 0),
(11, 3, 7, 11, '2026-05-05 21:00', 170.00, 'Teslim Edildi', 'Askıda',       1), -- ASKIDA
(12, 5, 1, 12, '2026-05-06 17:00', 145.00, 'Teslim Edildi', 'Kredi Kartı', 0),
(13, 1, 2, 13, '2026-05-06 19:30', 410.00, 'Teslim Edildi', 'Kredi Kartı', 0),
(14, 2, 3, 14, '2026-05-07 13:15', 210.00, 'Teslim Edildi', 'Kredi Kartı', 0),
(15, 4, 4, 15, '2026-05-07 20:00', 240.00, 'Teslim Edildi', 'Kredi Kartı', 0),
(16, 3, 5, 16, '2026-05-08 21:30', 175.00, 'Teslim Edildi', 'Askıda',       1), -- ASKIDA
(17, 5, 6, 17, '2026-05-08 12:30', 100.00, 'Teslim Edildi', 'Nakit',        0),
(18, 1, 7, 18, '2026-05-09 19:00', 280.00, 'Teslim Edildi', 'Kredi Kartı', 0),
(19, 4, 1, 19, '2026-05-09 20:45', 195.00, 'Teslim Edildi', 'Kredi Kartı', 0),
(20, 2, 2, 20, '2026-05-10 13:00', 230.00, 'Teslim Edildi', 'Kredi Kartı', 0),
( 1, 3, 3,  1, '2026-05-10 20:30', 165.00, 'Teslim Edildi', 'Kredi Kartı', 0),
( 2, 5, 4,  2, '2026-05-11 21:00', 130.00, 'Teslim Edildi', 'Nakit',        0),
( 3, 1, 5,  3, '2026-05-11 12:00', 220.00, 'Teslim Edildi', 'Kredi Kartı', 0),
( 4, 2, 6,  4, '2026-05-11 19:30', 215.00, 'Teslim Edildi', 'Kredi Kartı', 0),
( 5, 4, 7,  5, '2026-05-12 20:00', 215.00, 'Teslim Edildi', 'Kredi Kartı', 0),
( 7, 3, 1,  7, '2026-05-12 21:00', 150.00, 'Teslim Edildi', 'Askıda',       1), -- ASKIDA
( 8, 5, 2,  8, '2026-05-13 17:30', 110.00, 'Teslim Edildi', 'Kredi Kartı', 0),
( 9, 1, 3,  9, '2026-05-13 19:00', 340.00, 'Teslim Edildi', 'Kredi Kartı', 0),
(10, 2, 4, 10, '2026-05-13 12:30', 240.00, 'Teslim Edildi', 'Kredi Kartı', 0),
-- "Yolda" ve "Hazırlanıyor" durumlarındaki güncel siparişler
(11, 4, 5, 11, '2026-05-14 11:15', 245.00, 'Yolda',        'Askıda',       1), -- ASKIDA
(12, 3, 6, 12, '2026-05-14 11:30', 175.00, 'Yolda',        'Kredi Kartı', 0),
(13, 5, 7, 13, '2026-05-14 11:45', 145.00, 'Yolda',        'Kredi Kartı', 0),
(14, 1, 1, 14, '2026-05-14 12:00', 260.00, 'Hazırlanıyor', 'Kredi Kartı', 0),
(15, 2, 2, 15, '2026-05-14 12:05', 215.00, 'Hazırlanıyor', 'Kredi Kartı', 0),
(16, 4, 3, 16, '2026-05-14 12:10', 230.00, 'Hazırlanıyor', 'Kredi Kartı', 0),
(17, 3, 4, 17, '2026-05-14 12:15', 165.00, 'Hazırlanıyor', 'Kredi Kartı', 0),
(18, 5, 5, 18, '2026-05-14 12:20', 130.00, 'Hazırlanıyor', 'Nakit',        0),
(19, 1, 6, 19, '2026-05-14 12:22', 410.00, 'Hazırlanıyor', 'Kredi Kartı', 0),
(20, 2, 7, 20, '2026-05-14 12:25', 195.00, 'Hazırlanıyor', 'Kredi Kartı', 0),
-- İptal edilen siparişler (ciroyu etkilemez)
( 4, 3, NULL,  4, '2026-04-15 22:30', 125.00, 'İptal Edildi', 'Kredi Kartı', 0),
( 5, 1, NULL,  5, '2026-04-25 14:00', 320.00, 'İptal Edildi', 'Nakit',        0),
(10, 5, NULL, 10, '2026-05-01 23:00',  85.00, 'İptal Edildi', 'Kredi Kartı', 0),
-- Eski siparişler (analitik için)
( 1, 1, 1,  1, '2026-03-15 12:00', 220.00, 'Teslim Edildi', 'Kredi Kartı', 0),
( 2, 2, 2,  2, '2026-03-16 13:30', 230.00, 'Teslim Edildi', 'Kredi Kartı', 0),
( 3, 3, 3,  3, '2026-03-17 19:00', 165.00, 'Teslim Edildi', 'Nakit',        0),
( 4, 4, 4,  4, '2026-03-18 20:30', 210.00, 'Teslim Edildi', 'Kredi Kartı', 0),
( 5, 5, 5,  5, '2026-03-19 17:00', 110.00, 'Teslim Edildi', 'Kredi Kartı', 0),
( 6, 1, 6,  6, '2026-03-20 19:30', 220.00, 'Teslim Edildi', 'Kredi Kartı', 0),
( 9, 2, 7,  9, '2026-03-21 13:15', 215.00, 'Teslim Edildi', 'Kredi Kartı', 0),
(13, 4, 1, 13, '2026-03-22 20:00', 230.00, 'Teslim Edildi', 'Kredi Kartı', 0),
(15, 3, 2, 15, '2026-03-23 18:45', 140.00, 'Teslim Edildi', 'Nakit',        0),
(18, 5, 3, 18, '2026-03-24 21:00', 145.00, 'Teslim Edildi', 'Kredi Kartı', 0),
( 2, 1, 4,  2, '2026-03-25 12:30', 175.00, 'Teslim Edildi', 'Kredi Kartı', 0),
( 4, 2, 5,  4, '2026-03-26 19:00', 240.00, 'Teslim Edildi', 'Kredi Kartı', 0),
( 8, 4, 6,  8, '2026-03-27 20:30', 195.00, 'Teslim Edildi', 'Kredi Kartı', 0),
(10, 3, 7, 10, '2026-03-28 21:00', 155.00, 'Teslim Edildi', 'Kredi Kartı', 0),
(12, 5, 1, 12, '2026-03-29 17:30', 120.00, 'Teslim Edildi', 'Nakit',        0),
(14, 1, 2, 14, '2026-03-30 19:00', 320.00, 'Teslim Edildi', 'Kredi Kartı', 0),
(17, 2, 3, 17, '2026-03-31 13:00', 200.00, 'Teslim Edildi', 'Kredi Kartı', 0),
(19, 4, 4, 19, '2026-04-01 20:00', 245.00, 'Teslim Edildi', 'Kredi Kartı', 0),
( 7, 5, 5,  7, '2026-03-15 17:00',  95.00, 'Teslim Edildi', 'Askıda',       1), -- ASKIDA
(11, 3, 6, 11, '2026-03-20 18:30', 135.00, 'Teslim Edildi', 'Askıda',       1), -- ASKIDA
(16, 1, 7, 16, '2026-03-25 19:45', 180.00, 'Teslim Edildi', 'Askıda',       1); -- ASKIDA
GO

PRINT '>> 100+ sipariş eklendi.';
GO

-- =====================================================================
-- 7. SİPARİŞ DETAYLARI (her sipariş için en az 1 kalem)
-- =====================================================================

-- Her siparişe makul bir ürün ataması yapıyoruz.
-- Restoran ile UrunID eşleşmesi: Restoran 1 → 1-10, Restoran 2 → 11-20,
-- Restoran 3 → 21-30, Restoran 4 → 31-40, Restoran 5 → 41-51

INSERT INTO SiparisDetay (SiparisID, UrunID, Adet, BirimFiyat)
SELECT s.SiparisID,
       -- Restorana göre rastgele ürün
       CASE s.RestoranID
            WHEN 1 THEN 1  + (s.SiparisID % 10)   -- 1..10
            WHEN 2 THEN 11 + (s.SiparisID % 10)   -- 11..20
            WHEN 3 THEN 21 + (s.SiparisID % 10)   -- 21..30
            WHEN 4 THEN 31 + (s.SiparisID % 10)   -- 31..40
            WHEN 5 THEN 41 + (s.SiparisID % 11)   -- 41..51
       END AS UrunID,
       1 AS Adet,
       s.Tutar AS BirimFiyat
FROM Siparis s;
GO

-- Bazı siparişlere ikinci kalem ekleyerek çeşitlilik sağlayalım
INSERT INTO SiparisDetay (SiparisID, UrunID, Adet, BirimFiyat)
SELECT TOP 30 s.SiparisID,
       CASE s.RestoranID
            WHEN 1 THEN 4   -- lahmacun
            WHEN 2 THEN 13  -- ekonomix
            WHEN 3 THEN 22  -- napoliten
            WHEN 4 THEN 33  -- margarita
            WHEN 5 THEN 44  -- muhallebi
       END,
       2,
       CASE s.RestoranID
            WHEN 1 THEN 45.00
            WHEN 2 THEN 120.00
            WHEN 3 THEN 125.00
            WHEN 4 THEN 175.00
            WHEN 5 THEN 65.00
       END
FROM Siparis s
WHERE s.Durum = 'Teslim Edildi'
ORDER BY s.SiparisID;
GO

PRINT '>> Sipariş detayları eklendi.';
GO

-- =====================================================================
-- 8. ASKIDA YEMEK KULLANIMLARI
-- =====================================================================
-- AskidanMi = 1 olan siparişler için kullanım kaydı oluştur.
-- Bu INSERT, trg_AskidaKullanim_HavuzGuncelle tetikleyicisini çalıştırır
-- ve havuz bakiyesinden otomatik düşüm yapar.

INSERT INTO AskidaKullanim (SiparisID, HavuzID, MusteriID, KullanilanTutar, KullanimTarihi)
SELECT s.SiparisID, 1, s.MusteriID, s.Tutar, s.SiparisTarihi
FROM Siparis s
WHERE s.AskidanMi = 1 AND s.Durum IN ('Teslim Edildi', 'Yolda');
GO

PRINT '>> Askıda yemek kullanımları eklendi.';
GO

-- =====================================================================
-- 9. SOFT DELETE ÖRNEKLERİ
-- =====================================================================
-- Vassoli (RestoranID=4) menüsünden "Hawai Pizza" (UrunID=39) çıkarılıyor.
-- Fiziksel silme YAPILMAZ, IsActive = 0 ile pasifleştirilir.
UPDATE Urun SET IsActive = 0 WHERE UrunID = 39;
GO

-- 20 numaralı müşteri (Halime Acar) hesabını kapatıyor.
UPDATE Musteri SET IsActive = 0 WHERE MusteriID = 20;
GO

-- =====================================================================
-- 10. CİRO BİRİKMİŞ DEĞERLERİNİ MANUEL GÜNCELLE
-- =====================================================================
-- Trigger eklenmeden önce yapılan INSERT'ler için cirolar manuel hesaplanır
UPDATE r
SET r.ToplamCiro = ISNULL((
    SELECT SUM(s.Tutar)
    FROM Siparis s
    WHERE s.RestoranID = r.RestoranID
      AND s.Durum = 'Teslim Edildi'
      AND s.AskidanMi = 0
), 0)
FROM Restoran r;
GO

PRINT '>> Cirolar güncellendi. Veritabanı hazır.';
GO

-- =====================================================================
-- =====================================================================
-- 11. İLERİ DÜZEY SORGULAR (DQL & ANALİTİK)
-- =====================================================================
-- Aşağıdaki üç sorgu, projenin gerekli analitik isterlerini karşılar.
-- Çalıştırmak için her bloğun altındaki SELECT'i seçip Execute edebilirsiniz.
-- =====================================================================

-- ------------------------------------------------------
-- SORGU 1: JOIN KULLANIMI
-- En az 3 tabloyu bağlayan detaylı SİPARİŞ FİŞİ sorgusu
-- (Sipariş + Müşteri + Restoran + Kurye + Sipariş Detayı + Ürün)
-- ------------------------------------------------------
SELECT
    s.SiparisID,
    s.SiparisTarihi,
    (m.Ad + ' ' + m.Soyad)                  AS Musteri,
    r.RestoranAdi,
    ISNULL(k.Ad + ' ' + k.Soyad, '(Atanmadı)') AS Kurye,
    u.UrunAdi,
    sd.Adet,
    sd.BirimFiyat,
    (sd.Adet * sd.BirimFiyat)               AS KalemTutari,
    s.Tutar                                 AS SiparisTutari,
    s.Durum,
    CASE WHEN s.AskidanMi = 1 THEN 'EVET' ELSE 'HAYIR' END AS AskidaMi
FROM Siparis s
INNER JOIN Musteri      m  ON m.MusteriID  = s.MusteriID
INNER JOIN Restoran     r  ON r.RestoranID = s.RestoranID
LEFT  JOIN Kurye        k  ON k.KuryeID    = s.KuryeID         -- LEFT JOIN: kurye atanmamış olabilir
INNER JOIN SiparisDetay sd ON sd.SiparisID = s.SiparisID
INNER JOIN Urun         u  ON u.UrunID     = sd.UrunID
WHERE s.IsActive = 1
ORDER BY s.SiparisTarihi DESC, s.SiparisID;
GO

-- ------------------------------------------------------
-- SORGU 2: AGGREGASYON + GROUP BY + HAVING
-- Son 1 ayda 5'ten FAZLA sipariş alan restoranların
-- ortalama sepet tutarları, toplam ciro ve sipariş sayıları
-- ------------------------------------------------------
SELECT
    r.RestoranID,
    r.RestoranAdi,
    r.MutfakTuru,
    COUNT(s.SiparisID)               AS SiparisSayisi,
    SUM(s.Tutar)                     AS ToplamSatis,
    CAST(AVG(s.Tutar) AS DECIMAL(10,2)) AS OrtalamaSepetTutari,
    CAST(MIN(s.Tutar) AS DECIMAL(10,2)) AS EnDusukSiparis,
    CAST(MAX(s.Tutar) AS DECIMAL(10,2)) AS EnYuksekSiparis
FROM Restoran r
INNER JOIN Siparis s ON s.RestoranID = r.RestoranID
WHERE s.Durum = 'Teslim Edildi'
  AND s.SiparisTarihi >= DATEADD(DAY, -30, GETDATE())   -- Son 30 gün
GROUP BY r.RestoranID, r.RestoranAdi, r.MutfakTuru
HAVING COUNT(s.SiparisID) > 5
ORDER BY ToplamSatis DESC;
GO

-- ------------------------------------------------------
-- SORGU 3: ALT SORGU (SUBQUERY) - NOT EXISTS
-- Platformu aktif kullanan AMA hiç "Askıda Yemek" bağışı
-- yapmamış müşteriler.
-- (En az 1 sipariş vermiş, hiç bağış kaydı olmayan)
-- ------------------------------------------------------
SELECT
    m.MusteriID,
    m.Ad + ' ' + m.Soyad AS AdSoyad,
    m.Email,
    (SELECT COUNT(*) FROM Siparis sx
       WHERE sx.MusteriID = m.MusteriID
         AND sx.IsActive = 1
         AND sx.Durum <> 'İptal Edildi') AS SiparisSayisi,
    (SELECT ISNULL(SUM(sx.Tutar),0) FROM Siparis sx
       WHERE sx.MusteriID = m.MusteriID
         AND sx.Durum = 'Teslim Edildi'
         AND sx.AskidanMi = 0) AS ToplamHarcama
FROM Musteri m
WHERE m.IsActive = 1
  AND m.IhtiyacSahibiMi = 0                    -- ihtiyaç sahibi değil
  AND EXISTS (                                  -- aktif kullanıcı: en az 1 siparişi var
        SELECT 1 FROM Siparis s
        WHERE s.MusteriID = m.MusteriID
          AND s.IsActive = 1
  )
  AND NOT EXISTS (                              -- hiç bağış yapmamış
        SELECT 1 FROM AskidaBagis b
        WHERE b.MusteriID = m.MusteriID
  )
ORDER BY ToplamHarcama DESC;
GO

-- ------------------------------------------------------
-- EK SORGU (Görünüm Kullanımı): Havuz durumu
-- ------------------------------------------------------
SELECT * FROM vw_AskidaYemekHavuzDurumu;
GO

-- ------------------------------------------------------
-- EK SORGU (Görünüm Kullanımı): Aktif menüler
-- ------------------------------------------------------
SELECT TOP 20 * FROM vw_AktifRestoranMenuleri
ORDER BY RestoranAdi, KategoriAdi;
GO

-- ------------------------------------------------------
-- EK SORGU (Görünüm Kullanımı): Restoran ciro özeti
-- ------------------------------------------------------
SELECT * FROM vw_RestoranCiroOzeti
ORDER BY ToplamSatis DESC;
GO

-- =====================================================================
-- TRIGGER DEMO: Sipariş durumu değiştiğinde ciro otomatik artar
-- =====================================================================
-- "Hazırlanıyor" durumundaki bir siparişi "Teslim Edildi"ye çekiyoruz.
-- trg_Siparis_CiroGuncelle çalışacak ve ilgili restoranın ToplamCiro'su artacak.
--
-- ÖRNEK:
-- UPDATE Siparis SET Durum = 'Teslim Edildi' WHERE SiparisID = 75;
-- SELECT RestoranID, RestoranAdi, ToplamCiro FROM Restoran;
-- =====================================================================

PRINT '====================================================';
PRINT '  Proje veritabanı kurulumu BAŞARIYLA tamamlandı.';
PRINT '  YemekSiparisDB hazır. İyi çalışmalar.';
PRINT '====================================================';
GO
