# Deploy Ready

Folder ini berisi paket siap deploy: POS, Self Order, delivery, driver, dan microsite tautan layanan.

Untuk domain `pizzain.id`, gunakan **satu proyek Vercel `pizzain-pos`** dengan Root Directory `deploy-ready` (lihat Opsi 2). Domain tidak perlu dipindahkan ke proyek `pizzain-order`.

## Struktur

- `pos/`
  Aplikasi kasir, admin, dapur, pesanan, produk, laporan, dan settings.

- `self-order/`
  Aplikasi customer self order. Paket ini lebih ringan karena tidak membawa file halaman POS/admin.

- `delivery/` dan `driver/`
  Aplikasi pemesanan delivery dan driver.

- `order/`
  Microsite "Pilih Layanan" dengan tautan menu dan WhatsApp, tersedia di `https://pizzain.id/order/` setelah paket ini dideploy ulang. Halaman utama `/` tetap mengarah ke `/pos/`.

## Cara Deploy

Penting: Vercel mencari `index.html` di root yang dideploy. Jika kamu upload folder `deploy-ready` sebagai folder di repo, root domain akan `404` kecuali Vercel root directory diarahkan ke `deploy-ready`.

### Opsi 1: Dua Repo GitHub

Upload isi folder berikut ke repo yang berbeda:

- Isi `deploy-ready/pos/` ke repo aplikasi kasir/admin.
- Isi `deploy-ready/self-order/` ke repo aplikasi self order.

Keduanya sudah punya `index.html`, jadi bisa langsung dibuka dari root hosting.

### Opsi 2: Satu Repo, Satu Domain (Untuk Pizzain)

Upload isi folder `deploy-ready/` ke root repo, atau set **Root Directory** Vercel ke `deploy-ready`.

Paket yang dirapikan pada 27 Oktober 2026 berisi 83 file, sehingga dapat diunggah sekaligus lewat browser GitHub. Jika repo sudah memakai folder `deploy-ready`, unggah folder ini di root repo agar menggantikan lokasi yang sama, bukan membuat `deploy-ready/deploy-ready`.

Backup disimpan di `.backups/` pada folder sumber aplikasi, di luar paket ini. Jangan ikut mengunggah backup atau seluruh folder sumber aplikasi. Mengunggah ulang tidak menghapus file lama di GitHub yang sudah tidak ada secara lokal.

Contoh URL:

- `https://domain-kamu.com/pos/`
- `https://domain-kamu.com/self-order/?1`
- `https://domain-kamu.com/delivery/`
- `https://domain-kamu.com/driver/`
- `https://domain-kamu.com/order/`

## URL QR Meja

Untuk QR meja, gunakan format pendek berikut agar ganti nomor meja cukup mengganti angka:

```text
https://domain-kamu.com/self-order/?1
https://domain-kamu.com/self-order/?2
...
https://domain-kamu.com/self-order/?20
```

Format lain yang juga didukung:

```text
https://domain-kamu.com/self-order/?m=1
https://domain-kamu.com/self-order/1
https://domain-kamu.com/self-order/?table=A-1#selforder
```

Jika self order dideploy sebagai subdomain:

```text
https://order.domain-kamu.com/?1
```

## Catatan Maintenance

Source utama tetap berada di root project. Jika ada perubahan fitur, lakukan perubahan di source utama dulu, lalu refresh isi folder `deploy-ready`.
