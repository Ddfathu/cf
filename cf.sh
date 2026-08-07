#!/bin/bash

#=============================================================
# Cloudflare Manager Pro (Dynamic Auto-Import Modules v34)
#=============================================================

set -e

CONFIG_FILE="$HOME/.cf-worker-kv.conf"
SCCF_DIR="$PWD/SCCF"
MODULES_DIR="$PWD/modules"

mkdir -p "$SCCF_DIR" "$MODULES_DIR"

# ANSI Color Codes
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
PURPLE='\033[1;35m'
WHITE='\033[1;37m'
BOLD='\033[1m'
NC='\033[0m'

if ! command -v jq &> /dev/null; then
    echo -e "${RED}❌ jq tidak ditemukan. Install dulu: pkg install jq${NC}"
    exit 1
fi

save_credentials() {
    echo "CF_EMAIL=\"$CF_EMAIL\"" > "$CONFIG_FILE"
    echo "CF_API_KEY=\"$CF_API_KEY\"" >> "$CONFIG_FILE"
    chmod 600 "$CONFIG_FILE"
    echo -e "${GREEN}💾 Kredensial disimpan di $CONFIG_FILE${NC}"
}

draw_banner() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${PURPLE}   ██████╗██╗     ██████╗ ██╗  ██╗██████╗ ███████╗            ${CYAN}║${NC}"
    echo -e "${CYAN}║${PURPLE}  ██╔════╝██║    ██╔═══██╗██║  ██║██╔══██╗██╔════╝            ${CYAN}║${NC}"
    echo -e "${CYAN}║${PURPLE}  ██║     ██║    ██║   ██║██║  ██║██║  ██║█████╗              ${CYAN}║${NC}"
    echo -e "${CYAN}║${PURPLE}  ██║     ██║    ██║   ██║██║  ██║██║  ██║██╔══╝              ${CYAN}║${NC}"
    echo -e "${CYAN}║${PURPLE}  ╚██████╗███████╗╚██████╔╝╚█████╔╝██████╔╝███████╗            ${CYAN}║${NC}"
    echo -e "${CYAN}║${PURPLE}   ╚═════╝╚══════╝ ╚═════╝  ╚════╝ ╚═════╝ ╚══════╝            ${CYAN}║${NC}"
    echo -e "${CYAN}║${YELLOW}         CLOUDFLARE ENGINE MANAGER v34 (AUTO-IMPORT)          ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo -e " ${WHITE}👤 Active Account :${NC} ${GREEN}$CF_EMAIL${NC}"
    echo -e " ${WHITE}📁 Folder Script   :${NC} ${YELLOW}$SCCF_DIR${NC}"
    echo -e "${CYAN}----------------------------------------------------------------${NC}"
}

login_flow() {
    clear
    echo -e "${CYAN}====== CLOUDFLARE AUTHENTICATION ======${NC}"
    if [ -f "$CONFIG_FILE" ] && [ -z "$FORCE_RELOGIN" ]; then
        source "$CONFIG_FILE"
        echo -e "${YELLOW}🔐 Ditemukan akun tersimpan:${NC} ${GREEN}$CF_EMAIL${NC}"
        read -rp "Gunakan kredensial ini? [Y/n]: " USE_SAVED
        if [[ "$USE_SAVED" =~ ^[Nn] ]]; then
            unset CF_EMAIL CF_API_KEY
        fi
    fi

    if [ -z "$CF_EMAIL" ] || [ -z "$CF_API_KEY" ]; then
        echo ""
        read -rp "✉️  Email CF      : " CF_EMAIL
        # FLAG -s DIHAPUS BIAR TEKS API KEY KELIATAN PAS DIKETIK / DIPASTE
        read -rp "🔑 Global API Key: " CF_API_KEY
        echo ""
        read -rp "💾 Simpan kredensial? [y/N]: " SAVE_CHOICE
        if [[ "$SAVE_CHOICE" =~ ^[Yy] ]]; then
            save_credentials
        fi
    fi

    AUTH_HEADER=(-H "X-Auth-Email: $CF_EMAIL" -H "X-Auth-Key: $CF_API_KEY")
    BASE_URL="https://api.cloudflare.com/client/v4"

    echo -e "\n${YELLOW}📂 Verifikasi Account ID...${NC}"
    MEMBERSHIPS_JSON=$(curl -s "${AUTH_HEADER[@]}" -H "Content-Type: application/json" "$BASE_URL/memberships")
    ACCOUNT_ID=$(echo "$MEMBERSHIPS_JSON" | jq -r '.result[0].account.id // empty')

    if [ -z "$ACCOUNT_ID" ] || [ "$ACCOUNT_ID" == "null" ]; then
        ACCOUNTS_JSON=$(curl -s "${AUTH_HEADER[@]}" -H "Content-Type: application/json" "$BASE_URL/accounts")
        ACCOUNT_ID=$(echo "$ACCOUNTS_JSON" | jq -r '.result[0].id // empty')
    fi

    if [ -z "$ACCOUNT_ID" ] || [ "$ACCOUNT_ID" == "null" ]; then
        echo -e "${RED}❌ Gagal mendeteksi Account ID. Periksa Email/API Key!${NC}"
        unset CF_EMAIL CF_API_KEY
        read -rp "Tekan Enter untuk mencoba lagi..."
        login_flow
    fi
    echo -e "${GREEN}✅ Login Berhasil! (ID: $ACCOUNT_ID)${NC}"
    sleep 1
    unset FORCE_RELOGIN
}

login_flow

while true; do
    draw_banner
    echo -e " ${BOLD}MAIN MENU OPTIONS:${NC}\n"

    MODULE_ACTIONS=()
    index=1

    # 1. BACA & IMPORT SEMUA FILE .sh DI FOLDER modules/ DENGAN NAMA BEBAS
    shopt -s nullglob
    for mod_file in "$MODULES_DIR"/*.sh; do
        # Import seluruh isi fungsi file modul
        source "$mod_file"

        # Baca judul & nama fungsi dari header komentar di dalam file
        TITLE=$(grep -m1 "^# MENU_TITLE:" "$mod_file" | cut -d':' -f2- | sed 's/^[[:space:]]*//')
        ACTION=$(grep -m1 "^# MENU_ACTION:" "$mod_file" | cut -d':' -f2- | sed 's/^[[:space:]]*//')

        if [ -n "$TITLE" ] && [ -n "$ACTION" ]; then
            MODULE_ACTIONS+=("$ACTION")
            echo -e "  ${CYAN}[$index]${NC} $TITLE"
            ((index++))
        fi
    done
    shopt -u nullglob

    if [ ${#MODULE_ACTIONS[@]} -eq 0 ]; then
        echo -e "  ${YELLOW}⚠️ Belum ada file menu di folder 'modules/'.${NC}"
    fi

    echo ""
    echo -e "  ${YELLOW}[00]${NC}🔄 ${YELLOW}Switch / Ganti Akun Cloudflare${NC}"
    echo -e "  ${RED}[e]${NC}  🚪 ${RED}Keluar dari Script${NC}"
    echo ""
    echo -e "${CYAN}----------------------------------------------------------------${NC}"
    read -rp " Pilih Menu [1-$((index-1)) / e]: " MAIN_CHOICE
    echo ""

    if [ "$MAIN_CHOICE" == "00" ]; then
        echo -e "${YELLOW}🔄 Mengganti Akun Cloudflare...${NC}"
        unset CF_EMAIL CF_API_KEY ACCOUNT_ID
        FORCE_RELOGIN=true
        login_flow
    elif [ "$MAIN_CHOICE" == "e" ] || [ "$MAIN_CHOICE" == "E" ]; then
        echo -e "${GREEN}👋 Terima kasih bos! Keluar dari Cloudflare Manager Pro.${NC}"
        exit 0
    elif [[ "$MAIN_CHOICE" =~ ^[0-9]+$ ]] && [ "$MAIN_CHOICE" -ge 1 ] && [ "$MAIN_CHOICE" -lt "$index" ]; then
        # Eksekusi fungsi sesuai nomor pilihan
        TARGET_ACTION="${MODULE_ACTIONS[$((MAIN_CHOICE-1))]}"
        $TARGET_ACTION
    else
        echo -e "${RED}❌ Pilihan tidak valid, silakan coba lagi.${NC}"
        sleep 1
    fi
done
