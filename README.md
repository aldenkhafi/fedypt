# FITNESS JOURNEY V105 — Supabase Free Setup

## Setup dari project Supabase baru

File yang digunakan untuk setup awal:

**`V105_SUPABASE_FREE_NEW_PROJECT.sql`**

Urutan:

1. Buat **Project baru** di Supabase.
2. Buka **SQL Editor** pada project baru tersebut.
3. Copy seluruh isi `V105_SUPABASE_FREE_NEW_PROJECT.sql`.
4. Jalankan SQL tersebut satu kali.
5. Pastikan hasil terakhir menunjukkan:
   - `setup_status = V105 NEW PROJECT DATABASE READY`
   - `required_table_count = 7`
6. Hubungkan `index.html` dengan **Project URL** dan **Publishable/Anon Key** project Supabase baru melalui konfigurasi aplikasi.
7. Login Google menggunakan akun Master Admin atau akun baru.
8. Akun selain Master Admin akan masuk ke status **Pending Approval** sampai disetujui Master Admin.

## PENTING — jangan jalankan migration untuk setup awal

**`V105_SESSION_MIGRATION.sql` bukan file pembuatan database dari nol.**

File tersebut adalah migration/hardening tambahan untuk database yang sudah memiliki tabel V105. Jangan menjalankannya sebelum database dasar dari `V105_SUPABASE_FREE_NEW_PROJECT.sql` selesai dibuat.

Jika database baru dibuat menggunakan SQL setup ini, struktur session dasar yang diperlukan migration sudah disiapkan, termasuk:

- `pt_schedules.session_state`
- `pt_schedules.package_id`
- `pt_schedules.sync_id`
- `pt_packages.scheduled_sessions`
- unique index `pt_schedules_sync_id_unique`
- function `fj_consume_package_session(...)`

Karena itu migration tetap disertakan sebagai file opsional untuk kompatibilitas/hardening, tetapi **tidak diperlukan untuk setup pertama**.

## Tabel V105

SQL setup membuat tujuh tabel yang dipakai aplikasi:

- `user_access`
- `pt_directory`
- `pt_clients`
- `pt_packages`
- `pt_schedules`
- `pt_conducts`
- `pt_extension_requests`

RLS juga diaktifkan. Master Admin yang digunakan aplikasi adalah:

`aldenkhafi0203@gmail.com`

## Jika SQL gagal

Jangan lanjut menjalankan `V105_SESSION_MIGRATION.sql`. Simpan pesan error dari SQL Editor dan perbaiki error pada setup database terlebih dahulu.
