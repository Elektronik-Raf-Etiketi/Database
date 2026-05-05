DROP TABLE IF EXISTS device_logs CASCADE;
DROP TABLE IF EXISTS price_updates CASCADE;
DROP TABLE IF EXISTS device_product_bindings CASCADE;
DROP TABLE IF EXISTS devices CASCADE;
DROP TABLE IF EXISTS products CASCADE;
DROP TABLE IF EXISTS users CASCADE;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE users (
    id BIGSERIAL PRIMARY KEY,
    full_name VARCHAR(150) NOT NULL,
    email VARCHAR(150) NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,
    role VARCHAR(20) NOT NULL CHECK (role IN ('admin', 'operator', 'viewer')),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE products (
    id BIGSERIAL PRIMARY KEY,
    sku_or_barcode VARCHAR(100) NOT NULL UNIQUE,
    name VARCHAR(200) NOT NULL,
    price NUMERIC(10,2) NOT NULL CHECK (price > 0),
    campaign_text VARCHAR(255),
    stock_status VARCHAR(50),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE devices (
    id BIGSERIAL PRIMARY KEY,
    device_id VARCHAR(100) NOT NULL UNIQUE,
    status VARCHAR(50) NOT NULL DEFAULT 'OFFLINE'
        CHECK (status IN ('ACTIVE', 'OFFLINE', 'ONLINE', 'ERROR')),
    last_seen_at TIMESTAMP,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE device_product_bindings (
    id BIGSERIAL PRIMARY KEY,
    device_id BIGINT NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
    product_id BIGINT NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    bound_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE UNIQUE INDEX uq_device_product_bindings_one_active_per_device
ON device_product_bindings(device_id)
WHERE is_active = TRUE;

CREATE TABLE price_updates (
    id BIGSERIAL PRIMARY KEY,
    product_id BIGINT NOT NULL REFERENCES products(id),
    device_id BIGINT REFERENCES devices(id),
    old_price NUMERIC(10,2),
    new_price NUMERIC(10,2) NOT NULL,
    message_id VARCHAR(120) UNIQUE,
    version INTEGER,
    status VARCHAR(50) CHECK (status IN ('QUEUED', 'SENT', 'SUCCESS', 'FAIL', 'TIMEOUT', 'IGNORED')),
    result VARCHAR(20) CHECK (result IN ('SUCCESS', 'FAIL', 'IGNORED') OR result IS NULL),
    payload_json JSONB,
    error_message TEXT,
    requested_by BIGINT NOT NULL REFERENCES users(id),
    requested_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    acknowledged_at TIMESTAMP,
    applied_at TIMESTAMP
);

CREATE TABLE device_logs (
    id BIGSERIAL PRIMARY KEY,
    device_id BIGINT REFERENCES devices(id) ON DELETE CASCADE,
    log_message TEXT,
    log_level VARCHAR(20),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_price_updates_device_requested_at
ON price_updates(device_id, requested_at);

CREATE INDEX idx_price_updates_status
ON price_updates(status);

CREATE INDEX idx_device_logs_device_created_at
ON device_logs(device_id, created_at);

CREATE INDEX idx_devices_status
ON devices(status);

INSERT INTO users (full_name, email, password_hash, role)
VALUES
('Admin User', 'admin@esl.local', 'dummy_hash', 'admin'),
('Operator User', 'operator@esl.local', 'dummy_hash', 'operator'),
('Viewer User', 'viewer@esl.local', 'dummy_hash', 'viewer');

INSERT INTO products (sku_or_barcode, name, price, campaign_text, stock_status)
VALUES
('SKU001', 'Coca Cola 1L', 25.50, NULL, 'IN_STOCK'),
('SKU002', 'Pepsi 1L', 24.00, NULL, 'IN_STOCK'),
('SKU003', 'Su 0.5L', 5.00, NULL, 'IN_STOCK'),
('SKU004', 'Ekmek', 10.00, NULL, 'IN_STOCK'),
('SKU005', 'Süt 1L', 22.00, '2 al 1 öde', 'IN_STOCK'),
('SKU006', 'Yoğurt', 30.00, NULL, 'LOW_STOCK'),
('SKU007', 'Çikolata', 15.00, NULL, 'IN_STOCK'),
('SKU008', 'Cips', 20.00, NULL, 'IN_STOCK'),
('SKU009', 'Kahve', 80.00, NULL, 'IN_STOCK'),
('SKU010', 'Çay', 70.00, NULL, 'OUT_OF_STOCK');

INSERT INTO devices (device_id, status)
VALUES
('ESL001', 'ACTIVE'),
('ESL002', 'ACTIVE'),
('ESL003', 'OFFLINE');

INSERT INTO device_product_bindings (device_id, product_id, is_active)
VALUES
(1, 1, TRUE),
(2, 2, TRUE),
(3, 3, TRUE);

INSERT INTO price_updates
(product_id, device_id, old_price, new_price, message_id, version, status, result, requested_by, acknowledged_at, applied_at, error_message)
VALUES
(1, 1, 25.50, 27.00, 'msg-0001', 1, 'SUCCESS', 'SUCCESS', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, NULL);

INSERT INTO device_logs (device_id, log_message, log_level)
VALUES
(1, 'Device boot completed', 'INFO'),
(2, 'MQTT connected', 'INFO'),
(3, 'Device offline timeout', 'WARN');

SELECT 'Backend ile uyumlu ESL database başarıyla kuruldu.' AS sonuc;


SELECT * FROM users;
SELECT * FROM products;
SELECT * FROM devices;
SELECT * FROM device_product_bindings;
SELECT * FROM price_updates;
SELECT * FROM device_logs;