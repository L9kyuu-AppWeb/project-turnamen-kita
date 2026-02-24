Wah, proyek yang menarik! Membuat aplikasi pengelola turnamen sepak bola memang seru karena logikanya cukup menantang, terutama pada bagian penjadwalan (*matchmaking*) dan klasemen.

Berikut adalah rencana implementasi (blueprint) untuk aplikasi Flutter Anda menggunakan SQLite.

---

## 1. Arsitektur Database (SQLite)

Kita perlu merancang skema database yang fleksibel agar bisa menangani mode **League** (1 grup besar) maupun **Group Stage** (banyak grup).

**Tabel Utama:**

* **leagues**: Menyimpan data turnamen (Nama, tipe: league/group, poin menang, poin seri, format: home-away/single).
* **groups**: Jika tipenya 'group', tabel ini membagi tim. Jika 'league', cukup buat 1 grup default.
* **teams**: Daftar tim dan kaitannya ke grup.
* **matches**: Detail pertandingan (Home team ID, Away team ID, skor, status selesai).

---

## 2. Struktur Model Data (Dart)

Gunakan class untuk merepresentasikan entitas database agar mudah dikelola.

```dart
class LeagueConfig {
  final int? id;
  final String name;
  final String type; // 'league' or 'group'
  final int ptsWin;
  final int ptsDraw;
  final bool isHomeAway;
  // ... constructor & toMap
}

```

---

## 3. Logika Penjadwalan (Round Robin)

Untuk membuat jadwal pertandingan otomatis, Anda bisa menggunakan **Circle Method**.

* **Single Match:** Setiap tim bertemu satu kali. Jika ada  tim, total pertandingan adalah .
* **Home & Away:** Cukup balikkan status Home/Away dari daftar Single Match.

> **Tips:** Jika jumlah tim ganjil, tambahkan tim "Bye" (tim bayangan). Tim yang melawan "Bye" berarti libur di pekan tersebut.

---

## 4. Perhitungan Klasemen (Standings)

Anda tidak perlu menyimpan poin di tabel `teams`. Sebaiknya, klasemen dihitung secara **real-time** dari tabel `matches` yang sudah memiliki skor.

**Rumus Klasemen:**

* **Main (P):** Jumlah match dengan status `isFinished = true`.
* **Menang (W):** Match di mana `score_home > score_away` (jika tim tersebut home).
* **Poin:** .

---

## 5. Implementasi UI Flutter

Berikut adalah urutan pembuatan layar (*screens*):

### A. Setup Screen (Form)

Gunakan `DropdownButton` untuk memilih tipe liga dan `Switch` untuk Home/Away. Sediakan `TextField` untuk menginput poin kemenangan dan seri.

### B. Team Entry Screen

Input nama-nama tim berdasarkan jumlah tim per grup yang sudah ditentukan.

### C. Match List & Standings (Tab View)

Gunakan `DefaultTabController` untuk memisahkan antara daftar jadwal pertandingan dan tabel klasemen.

```dart
// Contoh query sederhana untuk klasemen di SQLite
/*
SELECT 
    team_name,
    COUNT(*) as played,
    SUM(CASE WHEN (h_score > a_score AND team_id = h_id) OR (a_score > h_score AND team_id = a_id) THEN 1 ELSE 0 END) as won,
    -- ... dan seterusnya untuk draw, lost, points
FROM matches ...
GROUP BY team_id
ORDER BY points DESC, goal_difference DESC
*/

```

---