-- =========================================================
-- ESL PROJECT DATABASE - FINAL SQL SCRIPT
-- Açıklama:
-- Bu script, ESL projesi için PDF'te istenen database yapısını
-- düzenli, yorumlu ve anlaşılır şekilde oluşturur.
--
-- İçerik:
-- 1) Temel tablolar
-- 2) Constraint ve ilişkiler
-- 3) Ek kurallar / iyileştirmeler
-- 4) Indexler
-- 5) Seed data (demo verileri)
-- 6) Test / kontrol sorguları
-- =========================================================


-- =========================================================
-- 1) USERS TABLOSU
-- Bu tablo sistem kullanıcılarını tutar.
-- Admin ve operator gibi rolleri içerir.
-- requested_by alanı bu tabloya bağlanır.
-- =========================================================
CREATE TABLE users (
    id BIGSERIAL PRIMARY KEY, -- Otomatik artan kullanıcı ID
    full_name VARCHAR(150) NOT NULL, -- Kullanıcının adı soyadı
    email VARCHAR(150) NOT NULL UNIQUE, -- E-posta tekil olmalı
    password_hash TEXT NOT NULL, -- Şifre hash olarak tutulur
    role VARCHAR(20) NOT NULL CHECK (role IN ('admin', 'operator')), -- Rol kontrolü
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP -- Oluşturulma zamanı
);


-- =========================================================
-- 2) PRODUCTS TABLOSU
-- Bu tablo ürün bilgilerini tutar.
-- Her ürünün benzersiz bir sku_or_barcode değeri vardır.
-- =========================================================
CREATE TABLE products (
    id BIGSERIAL PRIMARY KEY, -- Otomatik artan ürün ID
    sku_or_barcode VARCHAR(100) NOT NULL UNIQUE, -- Ürün barkodu / SKU, tekil
    name VARCHAR(200) NOT NULL, -- Ürün adı
    price NUMERIC(10,2) NOT NULL CHECK (price > 0), -- Fiyat, 0'dan büyük olmalı
    campaign_text VARCHAR(255), -- Kampanya metni (opsiyonel)
    stock_status VARCHAR(50), -- Stok bilgisi (opsiyonel)
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP -- Oluşturulma zamanı
);


-- =========================================================
-- 3) DEVICES TABLOSU
-- Bu tablo fiziksel ESL cihazlarını tutar.
-- Her cihazın benzersiz bir device_id değeri vardır.
-- =========================================================
CREATE TABLE devices (
    id BIGSERIAL PRIMARY KEY, -- Otomatik artan cihaz ID
    device_id VARCHAR(100) NOT NULL UNIQUE, -- Cihazın benzersiz kimliği
    status VARCHAR(50) NOT NULL DEFAULT 'OFFLINE', -- Cihaz durumu
    last_seen_at TIMESTAMP, -- Cihazın en son görüldüğü zaman
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP -- Oluşturulma zamanı
);


-- =========================================================
-- 4) DEVICE_PRODUCT_BINDINGS TABLOSU
-- Bu tablo cihaz ile ürün eşleşmesini tutar.
-- Hangi cihaz hangi ürünü gösteriyor bilgisi burada tutulur.
-- Prototip kuralı:
-- Bir cihazın aynı anda yalnızca 1 aktif ürünü olabilir.
-- =========================================================
CREATE TABLE device_product_bindings (
    id BIGSERIAL PRIMARY KEY, -- Otomatik artan binding ID
    device_id BIGINT NOT NULL, -- Bağlanan cihaz
    product_id BIGINT NOT NULL, -- Bağlanan ürün
    is_active BOOLEAN NOT NULL DEFAULT TRUE, -- Aktif eşleşme mi?
    bound_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP, -- Eşleştirme zamanı

    CONSTRAINT fk_device_product_bindings_device
        FOREIGN KEY (device_id) REFERENCES devices(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_device_product_bindings_product
        FOREIGN KEY (product_id) REFERENCES products(id)
        ON DELETE CASCADE
);


-- =========================================================
-- 5) PRICE_UPDATES TABLOSU
-- Bu tablo sistemin audit / izleme tablosudur.
-- Fiyat değişiklikleri burada tutulur.
-- Publish/Ack süreci burada takip edilir.
--
-- Tutulan bilgiler:
-- - Hangi ürün güncellendi?
-- - Hangi cihaza gönderildi?
-- - Eski fiyat / yeni fiyat
-- - İşlemi kim yaptı?
-- - Ne zaman yaptı?
-- - Mesaj kimliği nedir?
-- - Sonuç ne oldu?
-- - Hata varsa neydi?
-- =========================================================
CREATE TABLE price_updates (
    id BIGSERIAL PRIMARY KEY, -- Otomatik artan kayıt ID

    product_id BIGINT NOT NULL, -- Güncellenen ürün
    device_id BIGINT, -- Güncellemenin hedef cihazı

    old_price NUMERIC(10,2), -- Önceki fiyat
    new_price NUMERIC(10,2) NOT NULL, -- Yeni fiyat

    message_id VARCHAR(120) UNIQUE, -- Tekrarlı mesajları engellemek için benzersiz mesaj ID
    version INTEGER, -- Versiyon bilgisi

    status VARCHAR(50), -- Süreç durumu: QUEUED, SENT, SUCCESS, FAIL, TIMEOUT, IGNORED
    result VARCHAR(20), -- Sonuç: SUCCESS, FAIL, IGNORED
    error_message TEXT, -- Hata varsa açıklaması

    requested_by BIGINT NOT NULL, -- İşlemi yapan kullanıcı
    requested_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP, -- İstek zamanı
    acknowledged_at TIMESTAMP, -- ACK alınma zamanı
    applied_at TIMESTAMP, -- Cihaza uygulama zamanı

    CONSTRAINT fk_price_updates_product
        FOREIGN KEY (product_id) REFERENCES products(id),

    CONSTRAINT fk_price_updates_device
        FOREIGN KEY (device_id) REFERENCES devices(id),

    CONSTRAINT fk_price_updates_user
        FOREIGN KEY (requested_by) REFERENCES users(id),

    CONSTRAINT chk_price_updates_status
        CHECK (status IN ('QUEUED', 'SENT', 'SUCCESS', 'FAIL', 'TIMEOUT', 'IGNORED')),

    CONSTRAINT chk_price_updates_result
        CHECK (result IN ('SUCCESS', 'FAIL', 'IGNORED') OR result IS NULL)
);


-- =========================================================
-- 6) DEVICE_LOGS TABLOSU
-- Bu tablo cihazlardan gelen log kayıtlarını tutar.
-- Örnek:
-- - Device boot completed
-- - MQTT connected
-- - Device offline timeout
-- =========================================================
CREATE TABLE device_logs (
    id BIGSERIAL PRIMARY KEY, -- Otomatik artan log ID
    device_id BIGINT, -- Logun ait olduğu cihaz
    log_message TEXT, -- Log metni
    log_level VARCHAR(20), -- INFO, WARN, ERROR gibi log seviyesi
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, -- Log zamanı

    CONSTRAINT fk_device_logs_device
        FOREIGN KEY (device_id) REFERENCES devices(id)
        ON DELETE CASCADE
);


-- =========================================================
-- 7) BUSINESS RULE INDEX
-- Amaç:
-- Aynı cihaz için aynı anda sadece 1 aktif binding olabilsin.
-- Böylece "1 cihaz = 1 aktif ürün" kuralı DB seviyesinde korunur.
-- =========================================================
CREATE UNIQUE INDEX uq_device_product_bindings_one_active_per_device
ON device_product_bindings(device_id)
WHERE is_active = TRUE;


-- =========================================================
-- 8) PERFORMANS INDEXLERİ
-- Bu indexler sık sorgulanan alanlarda performansı artırır.
-- =========================================================

-- price_updates tablosunda cihaz + istek zamanı bazlı sorgular için
CREATE INDEX idx_price_updates_device_requested_at
ON price_updates(device_id, requested_at);

-- price_updates tablosunda status bazlı sorgular için
CREATE INDEX idx_price_updates_status
ON price_updates(status);

-- device_logs tablosunda cihaz + zaman bazlı sorgular için
CREATE INDEX idx_device_logs_device_created_at
ON device_logs(device_id, created_at);

-- devices tablosunda status bazlı filtreleme için
CREATE INDEX idx_devices_status
ON devices(status);


-- =========================================================
-- 9) SEED DATA - DEMO VERİLERİ
-- PDF beklentisine uygun:
-- 10 ürün
-- 3 cihaz
-- 3 binding
-- =========================================================

-- ---------------------------------------------------------
-- 9.1 ADMIN KULLANICI
-- requested_by alanında kullanılacak örnek admin kullanıcı
-- ---------------------------------------------------------
INSERT INTO users (full_name, email, password_hash, role)
VALUES ('Admin User', 'admin@esl.local', 'dummy_hash', 'admin');


-- ---------------------------------------------------------
-- 9.2 ÜRÜNLER (10 ADET)
-- ---------------------------------------------------------
INSERT INTO products (sku_or_barcode, name, price)
VALUES
('SKU001', 'Coca Cola 1L', 25.50),
('SKU002', 'Pepsi 1L', 24.00),
('SKU003', 'Su 0.5L', 5.00),
('SKU004', 'Ekmek', 10.00),
('SKU005', 'Süt 1L', 22.00),
('SKU006', 'Yoğurt', 30.00),
('SKU007', 'Çikolata', 15.00),
('SKU008', 'Cips', 20.00),
('SKU009', 'Kahve', 80.00),
('SKU010', 'Çay', 70.00);


-- ---------------------------------------------------------
-- 9.3 CİHAZLAR (3 ADET)
-- ---------------------------------------------------------
INSERT INTO devices (device_id, status)
VALUES
('ESL001', 'ACTIVE'),
('ESL002', 'ACTIVE'),
('ESL003', 'OFFLINE');


-- ---------------------------------------------------------
-- 9.4 DEVICE - PRODUCT BINDING (3 ADET)
-- ---------------------------------------------------------
INSERT INTO device_product_bindings (device_id, product_id, is_active)
VALUES
(1, 1, TRUE),
(2, 2, TRUE),
(3, 3, TRUE);


-- ---------------------------------------------------------
-- 9.5 ÖRNEK PRICE UPDATE KAYDI
-- Amaç:
-- Sistemin audit mantığını göstermek
-- ---------------------------------------------------------
INSERT INTO price_updates
(product_id, device_id, old_price, new_price, message_id, version, status, result, requested_by, requested_at, acknowledged_at, applied_at, error_message)
VALUES
(1, 1, 25.50, 27.00, 'msg-0001', 1, 'SUCCESS', 'SUCCESS', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, NULL);


-- ---------------------------------------------------------
-- 9.6 ÖRNEK DEVICE LOG KAYITLARI
-- ---------------------------------------------------------
INSERT INTO device_logs (device_id, log_message, log_level)
VALUES
(1, 'Device boot completed', 'INFO'),
(2, 'MQTT connected', 'INFO'),
(3, 'Device offline timeout', 'WARN');


-- =========================================================
-- 10) TEST / KONTROL SORGULARI
-- Bu sorgular scriptin sonunda kontrol amaçlı kullanılabilir.
-- İstersen ayrı ayrı çalıştırabilirsin.
-- =========================================================

-- ---------------------------------------------------------
-- 10.1 Tüm tabloları listele
-- Amaç:
-- public şeması altında hangi tablolar oluşmuş görmek
-- ---------------------------------------------------------
SELECT tablename
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY tablename;


-- ---------------------------------------------------------
-- 10.2 Tüm cihazları listele
-- Amaç:
-- devices tablosundaki kayıtları görmek
-- ---------------------------------------------------------
SELECT * FROM devices;


-- ---------------------------------------------------------
-- 10.3 Tüm ürünleri listele
-- Amaç:
-- products tablosundaki kayıtları görmek
-- ---------------------------------------------------------
SELECT * FROM products;


-- ---------------------------------------------------------
-- 10.4 Tüm binding kayıtlarını listele
-- Amaç:
-- cihaz - ürün eşleşmelerini görmek
-- ---------------------------------------------------------
SELECT * FROM device_product_bindings;


-- ---------------------------------------------------------
-- 10.5 Tüm price update kayıtlarını listele
-- Amaç:
-- audit / price update süreç kayıtlarını görmek
-- ---------------------------------------------------------
SELECT
    id,
    product_id,
    device_id,
    old_price,
    new_price,
    message_id,
    version,
    status,
    result,
    requested_by,
    requested_at,
    acknowledged_at,
    applied_at,
    error_message
FROM price_updates;


-- ---------------------------------------------------------
-- 10.6 Tüm device log kayıtlarını listele
-- Amaç:
-- cihaz loglarını görmek
-- ---------------------------------------------------------
SELECT * FROM device_logs;


-- ---------------------------------------------------------
-- 10.7 Indexleri listele
-- Amaç:
-- Hangi tabloda hangi index var görmek
-- ---------------------------------------------------------
SELECT indexname, tablename
FROM pg_indexes
WHERE schemaname = 'public'
ORDER BY tablename, indexname;


-- ---------------------------------------------------------
-- 10.8 requested_by boş kayıt var mı kontrol et
-- Amaç:
-- Audit için zorunlu olan kullanıcı bağlantısı eksik mi görmek
-- ---------------------------------------------------------
SELECT * FROM price_updates
WHERE requested_by IS NULL;


-- ---------------------------------------------------------
-- 10.9 PDF doğrulama sayımları
-- Amaç:
-- 10 ürün, 3 cihaz, 3 binding var mı kontrol etmek
-- ---------------------------------------------------------
SELECT
    (SELECT COUNT(*) FROM products) AS products,
    (SELECT COUNT(*) FROM devices) AS devices,
    (SELECT COUNT(*) FROM device_product_bindings) AS bindings;


