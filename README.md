# ⚡ Cloudflare Engine Manager Pro (Modular Version)

Script CLI Bash berbasis Termux/Linux untuk mengelola seluruh ekosistem **Cloudflare** (Worker, Custom Domain, Argo Tunnel, KV Namespace, R2 Bucket, & Email Routing) secara instan, otomatis, dan praktis tanpa perlu membuka Dashboard Web.

---

## 🚀 Fitur Utama

- 🚀 **Worker Service Manager**: Deploy file `.js` dari folder lokal atau **URL Raw** (GitHub/Pastebin) otomatis, Edit, & Hapus Worker.
- 🌐 **Domain & Custom Domain**: Daftarkan Domain Baru (Create Zone), Cek Status & NS CF, serta Ikat (Bind) / Cabut (Unbind) Custom Domain ke Worker.
- 🗃️ **KV Namespace Manager**: Buat, Hapus, Ikat Variabel `env.KV`, & Cabut Binding KV dari Worker.
- 📦 **R2 Object Storage Suite**: Buat Bucket R2, Hapus Bucket, Ikat Variabel `env.R2`, & Cabut Binding R2 dari Worker.
- ✉️ **Email Routing Complete Suite**: Daftarkan & Verifikasi Email Penerima (OTP Token), Cek/Auto Fix MX & SPF Record, serta Pengaturan Catch-All (*@domain ke Worker / Forwarding).
- 🔗 **Cloudflare Argo Tunnel**: Buat Argo Tunnel Baru, Atur Ingress Routing ke Port Lokal (seperti `localhost:8880`), Auto DNS CNAME, & Cek Status Tunnel/Token.
- 🧩 **Modular Architecture**: Setiap menu dipisah dalam folder `modules/` sehingga sangat gampang untuk ditambahkan menu baru.
- ↩️ **Sub-Menu Loop & Batal/Kembali**: Opsi pembatalan di setiap input dan Sub-Menu yang tetap bertahan tanpa langsung mental ke Menu Utama.

---

## 🛠️ Persyaratan System & Library

Sebelum menjalankan script, pastikan library pendukung sudah terinstall di Termux/Linux kamu:

- `bash`
- `curl`
- `jq`
- `openssl`
- `git`

---

## 📥 Cara Install & Menjalankan Script

Cukup *copy-paste* perintah **One-Line Command** di bawah ini ke aplikasi **Termux**:

### 1. Install Library Wajib
```bash
pkg update -y && pkg install bash curl jq openssl git -y
```

### 2. Clone Repository
```bash
git clone https://github.com/Ddfathu/cf
```
### 3. jalankan script
cd cf

bash cf.sh
