# 🧾 ESL Database (Elektronik Raf Etiketi)

Bu repository, Elektronik Raf Etiketi (ESL) projesi için tasarlanmış **PostgreSQL tabanlı ilişkisel veritabanı yapısını** içerir.

Amaç:  
Cihazlar (ESL), ürünler ve fiyat güncellemeleri arasındaki ilişkiyi yönetmek, aynı zamanda sistemde yapılan işlemleri **audit (izleme)** edebilmektir.

---

# 🧠 Sistem Mantığı

Bu veritabanı şu soruları çözmek için tasarlanmıştır:

- Hangi cihaz hangi ürünü gösteriyor?
- Bir ürünün fiyatı ne zaman değiştirildi?
- Fiyat güncellemesini kim yaptı?
- Güncelleme cihazda başarılı oldu mu?
- Cihazlardan gelen loglar neler?

---

# 🏗️ Kullanılan Teknolojiler

| Teknoloji | Açıklama |
|----------|----------|
| PostgreSQL | İlişkisel veritabanı yönetim sistemi |
| pgAdmin | Veritabanı yönetim arayüzü |
| SQL | Veritabanı komut dili |

---

# ⚙️ Kurulum Adımları

## 1. Gereksinimler
- PostgreSQL kurulu olmalı
- pgAdmin (önerilir)

## 2. Database oluştur
pgAdmin üzerinden:
Create Database → esl_db


## 3. Script çalıştır
- Query Tool aç
- `esl_database.sql` dosyasını aç
- Execute (F5)

---

# 🗄️ Veritabanı Yapısı

## 📌 users
Sistem kullanıcılarını tutar.

| Alan | Açıklama |
|------|---------|
| id | Kullanıcı ID |
| full_name | Ad soyad |
| email | Benzersiz e-posta |
| role | admin / operator |

---

## 📌 products
Ürün bilgilerini tutar.

| Alan | Açıklama |
|------|---------|
| id | Ürün ID |
| sku_or_barcode | Benzersiz ürün kodu |
| name | Ürün adı |
| price | Ürün fiyatı |

---

## 📌 devices
ESL cihazlarını tutar.

| Alan | Açıklama |
|------|---------|
| id | Cihaz ID |
| device_id | Benzersiz cihaz kodu |
| status | ACTIVE / OFFLINE |
| last_seen_at | Son aktif zamanı |

---

## 📌 device_product_bindings
Cihaz ile ürün eşleşmesini tutar.

💡 Kural:  
**Bir cihaz aynı anda sadece 1 aktif ürün gösterebilir**

---

## 📌 price_updates (EN KRİTİK TABLO)

Fiyat değişikliklerini ve sistem akışını tutar.

| Alan | Açıklama |
|------|---------|
| product_id | Güncellenen ürün |
| device_id | Hedef cihaz |
| old_price | Eski fiyat |
| new_price | Yeni fiyat |
| status | Süreç durumu |
| result | Sonuç |
| requested_by | İşlemi yapan kullanıcı |
| message_id | Unique mesaj ID |

💡 Bu tablo:
- Audit sistemi
- Log sistemi
- İşlem takibi

---

## 📌 device_logs
Cihazlardan gelen logları tutar.

---

# 🔗 İlişkiler (Relationships)

- users → price_updates (1:N)
- products → price_updates (1:N)
- devices → price_updates (1:N)
- devices → device_logs (1:N)
- devices ↔ products (binding tablosu üzerinden)

---

# 🚀 Özellikler

- ✔ Relational database yapısı
- ✔ Foreign key ile veri bütünlüğü
- ✔ UNIQUE constraint ile tekrar önleme
- ✔ CHECK constraint ile veri doğrulama
- ✔ Index ile performans optimizasyonu
- ✔ Audit log sistemi
- ✔ Demo veri (10 ürün, 3 cihaz, 3 binding)

---

# 🧪 Test / Kontrol

Script çalıştırıldıktan sonra:

```sql
SELECT * FROM devices;
SELECT * FROM products;
SELECT * FROM price_updates;
