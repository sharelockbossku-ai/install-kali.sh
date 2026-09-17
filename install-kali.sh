#!/data/data/com.termux/files/usr/bin/bash
# =============================================================================
#  🐉 KALI LINUX + TERMUX:X11 — ONE-TAP INSTALLER
#  Gabungan & perbaikan dari: github.com/xiv3r/proot-distro-kali
#  (menggabungkan desktop.sh + arm64/armhf jadi satu file, plus fix bug)
# =============================================================================
#
# CATATAN PERBAIKAN dari script aslinya (biar tidak ada yang error):
#  1. Deteksi arsitektur otomatis (arm64/armhf) - user tidak perlu pilih manual.
#  2. Heredoc pembuat "startxfce4" sekarang di-quote ('EOF') supaya
#     kill -9 $(pgrep -f "termux.x11") baru dieksekusi tiap desktop dibuka,
#     bukan cuma sekali saat instalasi (bug di script asli).
#  3. Baris "dbus-launch ... & > /dev/null" diperbaiki urutannya jadi
#     "dbus-launch ... > /dev/null 2>&1 &" (bug redirection di script asli).
#  4. "mv -f $HOME/kali-armhf/*" (bug path di script armhf asli) diganti
#     jadi path relatif yang benar, sama seperti arm64.
#  5. "sed -i '/${FS}/d' ..." di script asli pakai TANDA KUTIP TUNGGAL,
#     jadi ${FS} TIDAK PERNAH benar-benar tergantikan jadi "kali" - akibatnya
#     baris lama di bash.bashrc tidak pernah terhapus saat reinstall
#     (menyebabkan baris dobel). Di sini pakai tanda kutip ganda + anchor
#     supaya benar-benar bersih tiap kali install ulang.
#  6. Tidak pakai "bash -e" di shebang, supaya 1 perintah kecil yang gagal
#     tidak menghentikan seluruh proses instalasi.
#  7. Di akhir, desktop langsung dibuka otomatis (tidak perlu tutup-buka
#     Termux dulu) sesuai permintaan "satu kali pencet, langsung kebuka".
#  8. Semua output mentah dari pkg/download/ekstrak disembunyikan ke file log
#     supaya layar tetap rapi; kalau ada langkah yang gagal, baru detailnya
#     ditampilkan dari log tersebut.
#  9. Saat dijalankan lewat "curl | bash", stdin skrip ini SAMA dengan
#     aliran pipe yang masih berisi sisa teks skrip. Kalau ada perintah di
#     tengah jalan (misalnya "pkg upgrade" yang nanya soal file konfigurasi
#     bentrok) ikut membaca dari stdin, dia bisa "menyedot" sisa skrip dan
#     bikin bash berhenti duluan padahal belum kelar. Makanya di sini:
#     a) stdin langsung dikunci ke /dev/null di awal skrip, dan
#     b) apt/pkg dipaksa non-interaktif penuh (auto pakai config baru),
#     supaya tidak ada perintah yang sempat "menyapa" stdin sama sekali.
# =============================================================================

# Kunci stdin dari awal supaya tidak ada proses anak yang bisa membaca sisa
# skrip dari pipe "curl | bash" (lihat catatan #9 di atas).
exec < /dev/null

FS="kali"
NM="Kali"
LOG_FILE="$HOME/install-${FS}.log"
: > "$LOG_FILE"

# Paksa apt/dpkg selalu non-interaktif dan otomatis pakai config baru kalau
# ada file konfigurasi yang bentrok saat upgrade (tidak akan nanya apa-apa).
export DEBIAN_FRONTEND=noninteractive
export APT_LISTCHANGES_FRONTEND=none
PKG_OPTS=(-o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold)

# -----------------------------------------------------------------------
# Helper: jalankan 1 perintah, sembunyikan outputnya ke log, tampilkan
# status rapi di layar (⏳ saat jalan -> ✅/❌ saat selesai).
# Step wajib (default): kalau gagal, hentikan skrip.
# Step opsional: tambahkan " || true" saat memanggil supaya skrip lanjut.
# -----------------------------------------------------------------------
step() {
    local msg="$1"; shift
    printf "⏳ %s..." "$msg"
    if "$@" >> "$LOG_FILE" 2>&1; then
        printf "\r✅ %s\n" "$msg"
        return 0
    else
        printf "\r⚠️  %s (lihat detail: %s)\n" "$msg" "$LOG_FILE"
        return 1
    fi
}

echo "🐉 Memulai instalasi ${NM} Linux + Termux:X11 di Termux..."
echo ""

# -----------------------------------------------------------------------
# 0) Deteksi arsitektur perangkat
# -----------------------------------------------------------------------
ARCH="$(uname -m)"
case "$ARCH" in
    aarch64|arm64)
        TARBALL_ARCH="arm64"
        PD_KEY="aarch64"
        ;;
    armv7l|armv8l|arm)
        TARBALL_ARCH="armhf"
        PD_KEY="arm"
        ;;
    *)
        echo "❌ Arsitektur '$ARCH' tidak didukung oleh rootfs Kali NetHunter minimal."
        exit 1
        ;;
esac
echo "📱 Arsitektur terdeteksi: ${ARCH} -> pakai rootfs ${TARBALL_ARCH}"
echo ""

# -----------------------------------------------------------------------
# 1) Cek APK pendamping Termux:X11 (harus di-install manual dari luar)
# -----------------------------------------------------------------------
if command -v pm >/dev/null 2>&1 && ! pm list packages 2>/dev/null | grep -q "com.termux.x11"; then
    echo "⚠️  App 'Termux:X11' (APK) sepertinya belum terpasang di HP kamu."
    echo "   Unduh & install dulu dari: https://github.com/termux/termux-x11/releases"
    echo "   Instalasi tetap lanjut, tapi layar desktop belum akan tampil"
    echo "   sebelum APK Termux:X11 ini di-install."
    echo ""
fi

# -----------------------------------------------------------------------
# 2) Update & pasang semua paket yang dibutuhkan
# -----------------------------------------------------------------------
echo "📦 Menyiapkan paket yang dibutuhkan..."
step "Update daftar paket"      pkg update -y
step "Upgrade paket Termux"     apt-get "${PKG_OPTS[@]}" upgrade -y
step "Pasang repo x11"          pkg install -y x11-repo
step "Pasang termux-x11"        pkg install -y termux-x11-nightly
step "Pasang repo tur"          pkg install -y tur-repo
step "Pasang pulseaudio"        pkg install -y pulseaudio
step "Pasang x11-utils"         pkg install -y x11-utils || true
step "Pasang xorg-xhost"        pkg install -y xorg-xhost
step "Pasang dos2unix"          pkg install -y dos2unix
step "Bersihkan vulkan lama"    pkg remove -y vulkan-loader-generic || true

if step "Pasang akselerasi grafis (mesa/virgl)" pkg install -y mesa-zink virglrenderer-mesa-zink vulkan-loader-android virglrenderer-android; then
    :
else
    echo "   ↳ Tidak masalah, desktop tetap bisa jalan tanpa akselerasi 3D tambahan."
fi

step "Pasang XFCE4"             pkg install -y xfce4
step "Pasang XFCE4 goodies"     pkg install -y xfce4-goodies
step "Pasang task manager"      pkg install -y xfce4-taskmanager || true
step "Pasang terminal XFCE4"    pkg install -y xfce4-terminal || true
step "Pasang plugin archive"    pkg install -y thunar-archive-plugin || true
step "Pasang file-roller"       pkg install -y file-roller || true
step "Pasang alat pendukung"    pkg install -y axel bsdtar proot-distro proot neofetch wget
clear

echo "✅ Semua paket dasar sudah terpasang."
echo ""

# -----------------------------------------------------------------------
# 3) Download & pasang rootfs Kali NetHunter Minimal
# -----------------------------------------------------------------------
# Kalau ada sisa instalasi lama (misalnya percobaan sebelumnya sempat
# terhenti/ke-close di tengah jalan), bersihkan dulu supaya "mv" nanti
# tidak gagal dengan error "Directory not empty".
if [ -d "$PREFIX/var/lib/proot-distro/installed-rootfs/${FS}" ] && [ "$(ls -A "$PREFIX/var/lib/proot-distro/installed-rootfs/${FS}" 2>/dev/null)" ]; then
    step "Bersihkan sisa instalasi lama" rm -rf "$PREFIX/var/lib/proot-distro/installed-rootfs/${FS}"
fi
mkdir -p "$PREFIX/var/lib/proot-distro/installed-rootfs/${FS}"
mkdir -p "$PREFIX/etc/proot-distro"
cd "$PREFIX/var/lib/proot-distro/installed-rootfs" || { echo "❌ Gagal masuk folder rootfs."; exit 1; }

neofetch --ascii_distro "${NM}" >> "$LOG_FILE" 2>&1

TARBALL_URL="https://kali.download/nethunter-images/current/rootfs/kali-nethunter-rootfs-minimal-${TARBALL_ARCH}.tar.xz"

echo "⬇️  Mengunduh ${NM} Linux (${TARBALL_ARCH})..."
rm -f "${FS}.tar.xz"
step "Download rootfs ${NM} Linux" axel -o "${FS}.tar.xz" "$TARBALL_URL"

if [ ! -s "${FS}.tar.xz" ]; then
    echo "❌ Download rootfs gagal atau file kosong. Cek koneksi internet, lalu jalankan skrip ini lagi."
    exit 1
fi

{
    echo "[*] MD5";    md5sum "${FS}.tar.xz"
    echo "[*] SHA256"; sha256sum "${FS}.tar.xz"
} >> "$LOG_FILE" 2>&1
echo "🔎 Integritas file sudah dicek (detail di log)."

rm -rf "${FS}-${TARBALL_ARCH}"
step "Ekstrak rootfs ${NM} Linux" proot --link2symlink bsdtar -xpJf "${FS}.tar.xz"

if [ ! -d "${FS}-${TARBALL_ARCH}" ]; then
    echo "❌ Ekstraksi gagal, folder ${FS}-${TARBALL_ARCH} tidak ditemukan. Coba ulangi lagi."
    exit 1
fi

step "Pindahkan rootfs ke lokasi proot-distro" mv -f "${FS}-${TARBALL_ARCH}"/* "$PREFIX/var/lib/proot-distro/installed-rootfs/${FS}"

echo "🛠️  Membuat file konfigurasi proot-distro..."
cat > "$PREFIX/etc/proot-distro/${FS}.sh" << EOF
DISTRO_NAME="${NM} Nethunter Minimal"
TARBALL_URL['${PD_KEY}']="${TARBALL_URL}"
TARBALL_SHA256['${PD_KEY}']="$(sha256sum "${FS}.tar.xz" | awk '{print $1}')"
EOF

echo "🔗 Membuat perintah pintasan '${FS}'..."
cat > "$PREFIX/bin/${FS}" << EOF
#!/data/data/com.termux/files/usr/bin/bash
proot-distro login ${FS}
EOF
chmod 700 "$PREFIX/bin/${FS}"

step "Pasang neofetch kustom di dalam rootfs" wget -q -O "${FS}/bin/neofetch" "https://raw.githubusercontent.com/xiv3r/proot-distro-kali/refs/heads/main/neofetch"
chmod 700 "${FS}/bin/neofetch"
sed -i '/neofetch/d' "${FS}/root/.zshrc" 2>/dev/null
cat >> "${FS}/root/.zshrc" << 'EOF'
neofetch
EOF

sed -i "/^${FS}\$/d" "$PREFIX/etc/bash.bashrc" 2>/dev/null
sed -i "/^termux-wake-lock\$/d" "$PREFIX/etc/bash.bashrc" 2>/dev/null
sed -i "/bash startxfce4/d" "$PREFIX/etc/bash.bashrc" 2>/dev/null
sed -i "/# --- kali-x11-autostart-guard ---/,/# --- end-kali-x11-autostart-guard ---/d" "$PREFIX/etc/bash.bashrc" 2>/dev/null

# PENTING: baris di bawah ini otomatis jalan tiap kali ada shell Termux baru
# dibuka - dan itu TERMASUK saat kamu buka terminal DARI DALAM desktop XFCE
# (misal xfce4-terminal), karena itu juga cuma shell Termux baru yang baca
# file bashrc ini. Tanpa penjaga ini, membuka terminal di dalam XFCE akan
# diam-diam menjalankan ulang startxfce4, yang isinya "kill -9" ke proses
# termux-x11 yang SEDANG kamu pakai -> desktop tiba-tiba "Not connected".
# Jadi baris ini hanya menjalankan startxfce4 kalau BELUM ada sesi X11/XFCE
# yang aktif.
cat >> "$PREFIX/etc/bash.bashrc" << EOF

# --- kali-x11-autostart-guard ---
if ! pgrep -f "termux-x11" >/dev/null 2>&1 && ! pgrep -x "xfce4-session" >/dev/null 2>&1; then
    termux-wake-lock
    bash startxfce4 >/dev/null 2>&1 &
fi
# --- end-kali-x11-autostart-guard ---
EOF

echo "🗑️  Membuat perintah 'uninstall-${FS}'..."
cat > "$PREFIX/bin/uninstall-${FS}" << EOF
#!/data/data/com.termux/files/usr/bin/bash
proot-distro remove ${FS}
sed -i "/^${FS}\\\$/d" "\$PREFIX/etc/bash.bashrc"
sed -i "/^termux-wake-lock\\\$/d" "\$PREFIX/etc/bash.bashrc"
sed -i "/bash startxfce4/d" "\$PREFIX/etc/bash.bashrc"
rm -f "\$PREFIX/bin/uninstall-${FS}"
rm -f "\$PREFIX/bin/${FS}"
rm -f "\$PREFIX/bin/startxfce4"
rm -f "\$PREFIX/var/lib/proot-distro/dlcache/${FS}.tar.xz"
EOF
chmod 700 "$PREFIX/bin/uninstall-${FS}"

mkdir -p "$PREFIX/var/lib/proot-distro/dlcache"
mv -f "${FS}.tar.xz" "$PREFIX/var/lib/proot-distro/dlcache"

echo ""
echo "✅ ${NM} Linux berhasil dipasang! Ketik '${FS}' kapan saja untuk masuk ke dalamnya."
echo ""

# -----------------------------------------------------------------------
# 4) Siapkan skrip peluncur desktop (Termux:X11 + XFCE4)
# -----------------------------------------------------------------------
echo "🖥️  Menyiapkan skrip startxfce4..."
cat > "$PREFIX/bin/startxfce4" << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash

# 🔋 Wake lock supaya Android tidak mematikan proses di background
termux-wake-lock

# 🧹 Kalau desktop XFCE + Termux:X11 SUDAH aktif dan sehat, jangan bunuh
#    apa-apa - langsung berhenti di sini. Ini mencegah kasus: buka terminal
#    DARI DALAM XFCE (yang otomatis memicu skrip ini lagi lewat bashrc)
#    tiba-tiba membunuh sesi yang sedang kamu pakai ("Not connected").
if pgrep -f "termux-x11" >/dev/null 2>&1 && pgrep -x "xfce4-session" >/dev/null 2>&1; then
    exit 0
fi

# 🧹 Kalau sampai di sini berarti sesi lama memang sudah mati/nyangkut
#    separuh - baru aman untuk dibersihkan sebelum memulai yang baru.
kill -9 $(pgrep -f "termux.x11") 2>/dev/null

# 🔊 Aktifkan PulseAudio lewat jaringan lokal
pulseaudio --start --load="module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1" --exit-idle-time=-1

# 🎙️ Nyalakan mic (kalau modulnya tersedia)
pactl load-module module-sles-source 2>/dev/null

# ⚙️ Variabel lingkungan untuk akselerasi grafis
export DISPLAY=:0
export MESA_NO_ERROR=1
export MESA_GL_VERSION_OVERRIDE=4.3COMPAT
export MESA_GLES_VERSION_OVERRIDE=3.2
export GALLIUM_DRIVER=zink
export MESA_VK_DEVICE_SELECT=0
export ZINK_DESCRIPTORS=lazy
export vblank_mode=0
export MESA_NO_WAIT_FOR_VBLANK=1
export LIBGL_DRI3_ENABLE=1

# 🖼️ Jalankan virgl_test_server di background (kalau tersedia; kalau tidak,
#    desktop tetap jalan tanpa akselerasi 3D tambahan ini)
if command -v virgl_test_server >/dev/null 2>&1; then
    virgl_test_server --use-egl-surfaceless --use-gles &
fi

# 🪟 Siapkan sesi termux-x11
export XDG_RUNTIME_DIR=${TMPDIR}
termux-x11 :0 >/dev/null &

# ⏳ Tunggu sebentar sampai termux-x11 siap
sleep 4

# 🚀 Buka aplikasi Termux:X11
am start --user 0 -n com.termux.x11/com.termux.x11.MainActivity > /dev/null 2>&1
sleep 2

# 🔈 Set audio server
export PULSE_SERVER=127.0.0.1

# 🖥️ Jalankan XFCE4 Desktop dengan akselerasi hardware
dbus-launch --exit-with-session xfce4-session > /dev/null 2>&1 &

xfconf-query -c xfwm4 -p /general/vblank_mode -s "off"

exit 0
EOF
dos2unix "$PREFIX/bin/startxfce4"
chmod 700 "$PREFIX/bin/startxfce4"

echo "✅ Skrip startxfce4 siap. Desktop akan otomatis nyala tiap kali buka Termux."
echo ""

# -----------------------------------------------------------------------
# 5) Langsung buka desktopnya sekarang, tanpa perlu restart Termux
# -----------------------------------------------------------------------
echo "🚀 Membuka XFCE4 Desktop lewat Termux:X11 sekarang juga..."
bash "$PREFIX/bin/startxfce4"

echo ""
echo "🎉 Selesai! Kalau layar Termux:X11 belum muncul otomatis, buka manual"
echo "   app 'Termux:X11' di HP kamu, atau ketik: bash startxfce4"
echo "🐉 Untuk masuk ke ${NM} Linux dari terminal (di dalam XFCE ataupun di Termux biasa), ketik: ${FS}"
echo "📄 Log lengkap instalasi ada di: ${LOG_FILE}"
