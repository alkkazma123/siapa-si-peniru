# Siapa Si Peniru — Roblox Social Deduction Game

Game Roblox **non-violent social deduction** yang dibangun **fully programmatic** (tanpa GUI/asset manual).
Saat server start, semuanya di-build otomatis: map kota, lobby, penjara, UI, sound, dan logika ronde.

## Fitur

- **Ronde 30–60 detik**, minimal **3 pemain**, **1 Peniru** + sisanya **Warga**.
- **Disguise system** — Peniru dapat menyamar persis target terdekat (DisplayName, avatar via `HumanoidDescription`, dan overhead level tag).
- **Capture ability** — `[E]` (PC) / tombol mobile, jangkauan ~12 studs, cooldown.
- **Voting dramatis** — overlay full-screen, kamera zoom, hasil tally + animasi reveal.
- **Win conditions**:
  - **Peniru menang** jika menyisakan ≤ 1 Warga hidup.
  - **Warga menang** jika berhasil vote Peniru di akhir ronde.
- **Coin + XP/Level system** dengan persistensi DataStore + global leaderboard (`OrderedDataStore`).
- **Overhead level tag** di atas kepala (BillboardGui, server-side, replikasi otomatis).
- **Backsound minigame**, **alarm**, **suspense**, **chime** menang/kalah.
- **Notifikasi top-screen**, **animasi role reveal**, **animasi hasil voting**.
- **UI dark theme modern minimalis** — support **PC + Mobile** (tombol on-screen otomatis).

## Struktur

```
default.project.json   ← Rojo entry, otomatis sync ke Studio
aftman.toml            ← versi Rojo + selene + stylua (opsional)
src/
├── shared/            ← ReplicatedStorage.Shared
│   ├── Config.luau    ← semua konstanta game (durasi, theme, dll.)
│   ├── Remotes.luau   ← auto-create RemoteEvents/Functions
│   └── Util.luau
├── server/            ← ServerScriptService.GameServer
│   ├── Main.server.luau
│   ├── MapBuilder.luau
│   ├── DataManager.luau
│   ├── OverheadManager.luau
│   ├── DisguiseSystem.luau
│   └── GameManager.luau
└── client/            ← StarterPlayer.StarterPlayerScripts.GameClient
    ├── Main.client.luau
    ├── UIBuilder.luau
    ├── SoundController.luau
    └── CameraController.luau
```

## Cara Menjalankan (PowerShell baru, dari nol)

### 1. Install Aftman (toolchain manager)

```powershell
# Buka PowerShell baru sebagai user (BUKAN Admin)
iwr https://github.com/LPGhatguy/aftman/releases/latest/download/aftman-windows.zip -OutFile aftman.zip
Expand-Archive aftman.zip -DestinationPath $env:USERPROFILE\.aftman\bin -Force
[Environment]::SetEnvironmentVariable("Path", "$env:Path;$env:USERPROFILE\.aftman\bin", "User")
$env:Path = "$env:Path;$env:USERPROFILE\.aftman\bin"
aftman self-install
```

> Atau pakai installer: https://github.com/LPGhatguy/aftman/releases

### 2. Clone & install tool versi sesuai `aftman.toml`

```powershell
git clone https://github.com/<your-username>/siapa-si-peniru.git
cd siapa-si-peniru
aftman install
```

Ini akan menginstall **Rojo 7.4.4** + **selene** + **stylua** sesuai project.

### 3. Jalankan Rojo

```powershell
rojo serve
```

Default-nya buka port `34872`.

### 4. Hubungkan dari Roblox Studio

1. Buka Roblox Studio → buat tempat baru kosong (Baseplate boleh).
2. Install **Rojo plugin** dari toolbox jika belum: https://github.com/rojo-rbx/rojo/releases (`Rojo.rbxm` plugin file).
3. Klik tab **Plugins** → **Rojo** → **Connect** → port `34872`.
4. Studio akan auto-sync seluruh tree (`ReplicatedStorage.Shared`, `ServerScriptService.GameServer`, `StarterPlayer.StarterPlayerScripts.GameClient`).
5. Klik **Play** (atau **Start Server** + simulate ≥3 player) untuk test.

### 5. (Opsional) Build .rbxl one-shot tanpa serve

```powershell
rojo build -o "SiapaSiPeniru.rbxlx"
```

Buka file `.rbxlx` langsung di Studio.

## Kontrol

| Aksi          | PC    | Mobile           |
|---------------|-------|------------------|
| Tangkap       | `E`   | tombol "TANGKAP" |
| Menyamar      | `Q`   | tombol "MENYAMAR"|
| Vote          | klik  | tombol "VOTE" + tap candidate |
| Leaderboard   | klik  | klik 🏆          |

## Test Multi-Player

- Studio → menu **Test** → set **Players** ke ≥3, klik **Start**.
- Atau publish ke Roblox dan invite teman.

## Catatan

- DataStore hanya aktif di server publish (atau Studio dengan **Enable Studio Access to API Services** ON di Game Settings → Security).
- Sound asset IDs adalah Roblox stock free sounds.
- Map dibangun pakai primitives — aman dari copyright.

Selamat bermain!
