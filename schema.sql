-- ============================================================
-- ESL PROJECT DATABASE - FINAL SQL SCRIPT
-- Açıklama:
-- Bu SQL dosyası Elektronik Raf Etiketi projesi için
-- gerekli tüm veritabanı tablolarını, enum tiplerini,
-- ilişkileri, kısıtları, indeksleri ve demo verilerini oluşturur.
-- ============================================================


-- ============================================================
-- 1) TEMİZ BAŞLANGIÇ
-- Açıklama:
-- Eğer aynı isimde tablolar veya enum tipleri önceden varsa silinir.
-- Böylece script tekrar çalıştırıldığında çakışma yaşanmaz.
-- ============================================================

DROP TABLE IF EXISTS device_logs CASCADE;
DROP TABLE IF EXISTS price_updates CASCADE;
DROP TABLE IF EXISTS device_product_bindings CASCADE;
DROP TABLE IF EXISTS devices CASCADE;
DROP TABLE IF EXISTS products CASCADE;
DROP TABLE IF EXISTS users CASCADE;

DROP TYPE IF EXISTS user_role CASCADE;
DROP TYPE IF EXISTS device_status CASCADE;
DROP TYPE IF EXISTS stock_status CASCADE;
DROP TYPE IF EXISTS update_result CASCADE;
DROP TYPE IF EXISTS log_level CASCADE;


-- ============================================================
-- 2) ENUM TİPLERİ
-- Açıklama:
-- Belirli alanlarda sadece önceden tanımlanmış değerlerin
-- kullanılmasını sağlar.
-- ============================================================

-- Kullanıcı rolleri: admin, operator, viewer
CREATE TYPE user_role AS ENUM (
    'ADMIN',
    'OPERATOR',
    'VIEWER'
);

-- Cihaz durumları: online, offline, bakımda
CREATE TYPE device_status AS ENUM (
    'ONLINE',
    'OFFLINE',
    'MAINTENANCE'
);

-- Ürün stok durumları
CREATE TYPE stock_status AS ENUM (
    'IN_STOCK',
    'LOW_STOCK',
    'OUT_OF_STOCK'
);

-- Fiyat güncelleme / publish sonucu durumları
CREATE TYPE update_result AS ENUM (
    'QUEUED',
    'SENT',
    'SUCCESS',
    'FAIL',
    'TIMEOUT',
    'IGNORED'
);

-- Cihaz log seviyeleri
CREATE TYPE log_level AS ENUM (
    'INFO',
    'WARN',
    'ERROR',
    'DEBUG'
);


-- ============================================================
-- 3) USERS TABLOSU
-- Açıklama:
-- Web panel kullanıcılarını tutar.
-- price_updates.requested_by alanı bu tabloya bağlanır.
-- ============================================================

CREATE TABLE users (
    -- Kullanıcının benzersiz ID değeri
    id BIGSERIAL PRIMARY KEY,

    -- Kullanıcı e-posta adresi, sistemde tekil olmalıdır
    email VARCHAR(150) NOT NULL UNIQUE,

    -- Şifre hash değeri tutulur, gerçek şifre tutulmaz
    password_hash TEXT NOT NULL,

    -- Kullanıcı rolü
    role user_role NOT NULL DEFAULT 'OPERATOR',

    -- Kullanıcının oluşturulma zamanı
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


-- ============================================================
-- 4) PRODUCTS TABLOSU
-- Açıklama:
-- Raf etiketlerinde gösterilecek ürün bilgilerini tutar.
-- Her ürünün barkod/SKU değeri benzersizdir.
-- ============================================================

CREATE TABLE products (
    -- Ürünün benzersiz ID değeri
    id BIGSERIAL PRIMARY KEY,

    -- Ürün barkodu veya SKU kodu
    sku_or_barcode VARCHAR(100) NOT NULL UNIQUE,

    -- Ürün adı
    name VARCHAR(150) NOT NULL,

    -- Ürün fiyatı, negatif olamaz
    price NUMERIC(10,2) NOT NULL CHECK (price >= 0),

    -- Para birimi
    currency VARCHAR(10) NOT NULL DEFAULT 'TRY',

    -- Kampanya metni, boş olabilir
    campaign_text VARCHAR(255),

    -- Ürünün stok durumu
    stock_status stock_status NOT NULL DEFAULT 'IN_STOCK',

    -- Ürünün son güncellenme zamanı
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


-- ============================================================
-- 5) DEVICES TABLOSU
-- Açıklama:
-- ESP32 tabanlı elektronik raf etiketi cihazlarını tutar.
-- Her cihazın device_id değeri benzersizdir.
-- ============================================================

CREATE TABLE devices (
    -- Cihazın veritabanı ID değeri
    id BIGSERIAL PRIMARY KEY,

    -- ESP32 cihaz kimliği
    device_id VARCHAR(100) NOT NULL UNIQUE,

    -- Cihazın fiziksel konumu
    location VARCHAR(150),

    -- Cihazın son görülme zamanı
    last_seen_at TIMESTAMPTZ,

    -- Cihazın mevcut durumu
    status device_status NOT NULL DEFAULT 'OFFLINE',

    -- Cihazın en son uyguladığı güncelleme versiyonu
    current_version INTEGER NOT NULL DEFAULT 0,

    -- Cihazın sisteme eklenme zamanı
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


-- ============================================================
-- 6) DEVICE_PRODUCT_BINDINGS TABLOSU
-- Açıklama:
-- Cihaz ile ürün eşleştirmesini tutar.
-- Prototip kuralı: Bir cihaz aynı anda sadece bir aktif ürüne bağlıdır.
-- ============================================================

CREATE TABLE device_product_bindings (
    -- Eşleştirme ID değeri
    id BIGSERIAL PRIMARY KEY,

    -- Bağlanan cihaz ID değeri
    device_id BIGINT NOT NULL REFERENCES devices(id) ON DELETE CASCADE,

    -- Bağlanan ürün ID değeri
    product_id BIGINT NOT NULL REFERENCES products(id) ON DELETE CASCADE,

    -- Eşleştirmenin aktif olup olmadığı
    active BOOLEAN NOT NULL DEFAULT TRUE,

    -- Eşleştirmenin oluşturulma zamanı
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


-- ============================================================
-- 7) AKTİF EŞLEŞTİRME KISITI
-- Açıklama:
-- Bir cihazın aynı anda yalnızca bir aktif ürünle eşleşmesini sağlar.
-- ============================================================

CREATE UNIQUE INDEX uq_one_active_product_per_device
ON device_product_bindings(device_id)
WHERE active = TRUE;


-- ============================================================
-- 8) PRICE_UPDATES TABLOSU
-- Açıklama:
-- Web panelden cihaza gönderilen fiyat/ürün güncellemelerini tutar.
-- Audit için zorunlu tablodur.
-- Kim, ne zaman, hangi cihaza, hangi payload ile güncelleme gönderdi
-- ve sonuç ne oldu bilgisi burada saklanır.
-- ============================================================

CREATE TABLE price_updates (
    -- Güncelleme kaydının ID değeri
    id BIGSERIAL PRIMARY KEY,

    -- Her güncelleme için benzersiz mesaj ID değeri
    message_id UUID NOT NULL UNIQUE,

    -- Güncellemenin gönderileceği cihaz
    device_id BIGINT NOT NULL REFERENCES devices(id) ON DELETE CASCADE,

    -- Güncellenen ürün
    product_id BIGINT NOT NULL REFERENCES products(id) ON DELETE CASCADE,

    -- Güncelleme versiyonu
    version INTEGER NOT NULL,

    -- ESP32 cihazına gönderilecek JSON payload
    payload_json JSONB NOT NULL,

    -- Güncellemeyi isteyen kullanıcı
    requested_by BIGINT REFERENCES users(id) ON DELETE SET NULL,

    -- Güncelleme isteğinin oluşturulma zamanı
    requested_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- MQTT ile gönderilme zamanı
    sent_at TIMESTAMPTZ,

    -- Cihaz tarafından uygulanma zamanı
    applied_at TIMESTAMPTZ,

    -- Güncellemenin sonucu
    result update_result NOT NULL DEFAULT 'QUEUED',

    -- Hata varsa açıklaması
    error_message TEXT
);


-- ============================================================
-- 9) DEVICE_LOGS TABLOSU
-- Açıklama:
-- ESP32 cihazlarından veya sistemden gelen log kayıtlarını tutar.
-- Hata analizi ve izlenebilirlik için kullanılır.
-- ============================================================

CREATE TABLE device_logs (
    -- Log kaydının ID değeri
    id BIGSERIAL PRIMARY KEY,

    -- Logun ilişkili olduğu cihaz
    device_id BIGINT REFERENCES devices(id) ON DELETE CASCADE,

    -- Log seviyesi
    level log_level NOT NULL DEFAULT 'INFO',

    -- Log mesajı
    message TEXT NOT NULL,

    -- Logun oluşma zamanı
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


-- ============================================================
-- 10) INDEXLER
-- Açıklama:
-- Sık sorgulanan alanlarda performansı artırır.
-- Özellikle cihaz güncelleme geçmişi ve log ekranları için gereklidir.
-- ============================================================

-- Cihaza göre güncelleme geçmişini hızlı listelemek için
CREATE INDEX idx_price_updates_device_requested
ON price_updates(device_id, requested_at DESC);

-- Güncelleme sonucuna göre filtreleme için
CREATE INDEX idx_price_updates_result
ON price_updates(result);

-- Cihaz loglarını hızlı listelemek için
CREATE INDEX idx_device_logs_device_created
ON device_logs(device_id, created_at DESC);

-- Ürün adına göre arama için
CREATE INDEX idx_products_name
ON products(name);


-- ============================================================
-- 11) DEMO USERS VERİLERİ
-- Açıklama:
-- Web panel testleri için örnek kullanıcılar eklenir.
-- Şifreler gerçek sistemde hashlenmiş olarak tutulmalıdır.
-- ============================================================

INSERT INTO users (email, password_hash, role) VALUES
('admin@esl.local', 'demo_hash_admin', 'ADMIN'),
('operator@esl.local', 'demo_hash_operator', 'OPERATOR'),
('viewer@esl.local', 'demo_hash_viewer', 'VIEWER');


-- ============================================================
-- 12) DEMO PRODUCTS VERİLERİ
-- Açıklama:
-- Demo için 10 adet ürün eklenir.
-- ============================================================

INSERT INTO products (
    sku_or_barcode,
    name,
    price,
    currency,
    campaign_text,
    stock_status
) VALUES
('8690000000001', 'Süt 1L', 49.90, 'TRY', '2 al 1 öde', 'IN_STOCK'),
('8690000000002', 'Ekmek', 12.50, 'TRY', NULL, 'IN_STOCK'),
('8690000000003', 'Yumurta 10lu', 89.90, 'TRY', 'Haftanın ürünü', 'LOW_STOCK'),
('8690000000004', 'Peynir 500g', 139.90, 'TRY', NULL, 'IN_STOCK'),
('8690000000005', 'Çay 1kg', 199.90, 'TRY', 'İndirimli ürün', 'IN_STOCK'),
('8690000000006', 'Şeker 1kg', 39.90, 'TRY', NULL, 'IN_STOCK'),
('8690000000007', 'Makarna 500g', 24.90, 'TRY', '3 al 2 öde', 'IN_STOCK'),
('8690000000008', 'Zeytinyağı 1L', 299.90, 'TRY', NULL, 'LOW_STOCK'),
('8690000000009', 'Yoğurt 1kg', 64.90, 'TRY', NULL, 'IN_STOCK'),
('8690000000010', 'Kahve 100g', 84.90, 'TRY', 'Yeni ürün', 'OUT_OF_STOCK');


-- ============================================================
-- 13) DEMO DEVICES VERİLERİ
-- Açıklama:
-- Demo için 3 adet ESP32 raf etiketi cihazı eklenir.
-- ============================================================

INSERT INTO devices (
    device_id,
    location,
    status,
    current_version
) VALUES
('ESL-00001', 'Raf A1', 'OFFLINE', 0),
('ESL-00002', 'Raf A2', 'OFFLINE', 0),
('ESL-00003', 'Raf B1', 'OFFLINE', 0);


-- ============================================================
-- 14) DEMO DEVICE-PRODUCT BINDINGS
-- Açıklama:
-- 3 cihaz, ilk 3 ürünle aktif olarak eşleştirilir.
-- ============================================================

INSERT INTO device_product_bindings (
    device_id,
    product_id,
    active
) VALUES
(1, 1, TRUE),
(2, 2, TRUE),
(3, 3, TRUE);


-- ============================================================
-- 15) DEMO DEVICE LOGS
-- Açıklama:
-- Cihazların sisteme eklendiğini gösteren örnek loglar oluşturulur.
-- ============================================================

INSERT INTO device_logs (
    device_id,
    level,
    message
) VALUES
(1, 'INFO', 'ESL-00001 cihazı sisteme demo olarak eklendi.'),
(2, 'INFO', 'ESL-00002 cihazı sisteme demo olarak eklendi.'),
(3, 'INFO', 'ESL-00003 cihazı sisteme demo olarak eklendi.');


-- ============================================================
-- 16) DEMO PRICE UPDATE KAYDI
-- Açıklama:
-- Publish/Ack akışını test etmek için örnek bir güncelleme kaydı oluşturulur.
-- Bu kayıt başlangıçta QUEUED durumundadır.
-- ============================================================

INSERT INTO price_updates (
    message_id,
    device_id,
    product_id,
    version,
    payload_json,
    requested_by,
    result
) VALUES (
    gen_random_uuid(),
    1,
    1,
    1,
    '{
        "device_id": "ESL-00001",
        "version": 1,
        "product": {
            "sku": "8690000000001",
            "name": "Süt 1L",
            "price": 49.90,
            "currency": "TRY",
            "campaign_text": "2 al 1 öde",
            "stock_status": "IN_STOCK"
        },
        "display": {
            "layout": "default_v1"
        }
    }',
    1,
    'QUEUED'
);


-- ============================================================
-- 17) KONTROL SORGULARI
-- Açıklama:
-- Script sonunda tabloların doğru oluşup oluşmadığını kontrol eder.
-- ============================================================

-- Toplam kullanıcı sayısını gösterir
SELECT COUNT(*) AS total_users FROM users;

-- Toplam ürün sayısını gösterir
SELECT COUNT(*) AS total_products FROM products;

-- Toplam cihaz sayısını gösterir
SELECT COUNT(*) AS total_devices FROM devices;

-- Toplam aktif cihaz-ürün eşleştirmesini gösterir
SELECT COUNT(*) AS total_active_bindings
FROM device_product_bindings
WHERE active = TRUE;

-- Toplam fiyat güncelleme kaydını gösterir
SELECT COUNT(*) AS total_price_updates FROM price_updates;

-- Toplam cihaz log sayısını gösterir
SELECT COUNT(*) AS total_device_logs FROM device_logs;


-- ============================================================
-- 18) BAŞARI MESAJI
-- Açıklama:
-- Bu satır görünüyorsa SQL dosyası başarıyla çalışmıştır.
-- ============================================================

SELECT 'ESL Project database başarıyla oluşturuldu.' AS sonuc;



-- TESTELER
SELECT * FROM users;

SELECT * FROM products;

SELECT * FROM devices;

SELECT * FROM device_product_bindings;

SELECT * FROM price_updates;

SELECT * FROM device_logs;