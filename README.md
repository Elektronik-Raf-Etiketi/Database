# Elektronik Raf Etiketi (ESL) - Database

Bu repository, ESL projesi için PostgreSQL veritabanı şemasını içerir.

## İçerik

- users (kullanıcılar)
- products (ürünler)
- devices (ESP32 cihazlar)
- device_product_bindings (eşleştirme)
- price_updates (audit / güncelleme geçmişi)
- device_logs (log kayıtları)

## Özellikler

- Audit sistemi (price_updates)
- MQTT publish/ack uyumlu yapı
- Device-based update tracking
- Index ve performans optimizasyonları
- Demo veriler (10 ürün, 3 cihaz)

## Kurulum

```sql
-- pgAdmin veya psql ile çalıştır:
schema.sql
```

## Geliştirici

Deniz Kılınç

## 🎯 Not

Bu repo:
- Backend’in bağlanacağı resmi DB yapısıdır
- ESP32 veri formatına referans olur
- Projenin teknik temelidir
