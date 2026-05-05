# Elektronik Raf Etiketi - Database

Bu repository, Elektronik Raf Etiketi projesinin PostgreSQL veritabanı şemasını içerir.

## İçerik

- users
- products
- devices
- device_product_bindings
- price_updates
- device_logs

## Kullanım

pgAdmin 4 üzerinden yeni bir PostgreSQL database oluşturulur:

```sql
CREATE DATABASE esl_project;

Notlar

Bu veritabanı yapısı backend ile uyumlu olacak şekilde hazırlanmıştır.
MQTT publish/ack akışı için price_updates tablosu kullanılır.
Cihaz logları device_logs tablosunda tutulur.
