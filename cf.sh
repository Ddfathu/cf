#!/bin/bash

#=============================================================
# Cloudflare Manager Pro (Multi-Account & Auto-Update v37)
# Banner: CF PROJECT
#=============================================================

# HAPUS set -e AGAR SCRIPT GAK CRASH KE TERMINAL KALAU ADA COMMAND ERROR
set +e

ACCOUNTS_FILE="$HOME/.cf-accounts.json"
ACTIVE_ACC_FILE="$HOME/.cf-active-account.json"
SCCF_DIR="$PWD/SCCF"
MODULES_DIR="$PWD/modules"

mkdir -p "$SCCF_DIR" "$MODULES_DIR"

if [ ! -f "$ACCOUNTS_FILE" ]; then
    echo "[]" > "$ACCOUNTS_FILE"
fi

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
    echo -e "${RED}❌ jq tidak ditemukan. Install dulu: pkg install jq atau apt install jq${NC}"
    exit 1
fi

draw_banner() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${PURPLE}    ██████╗███████╗  ██████╗ ██████╗  ██████╗      ██╗${CYAN}║${NC}"
    echo -e "${CYAN}║${PURPLE}   ██╔════╝██╔════╝  ██╔══██╗██╔══██╗██╔═══██╗     ██║${CYAN}║${NC}"
    echo -e "${CYAN}║${PURPLE}   ██║     █████╗    ██████╔╝██████╔╝██║   ██║     ██║${CYAN}║${NC}"
    echo -e "${CYAN}║${PURPLE}   ██║     ██╔══╝    ██╔═══╝ ██╔══██╗██║   ██║██   ██║${CYAN}║${NC}"
    echo -e "${CYAN}║${PURPLE}   ╚██████╗██║       ██║     ██║  ██║╚██████╔╝╚█████╔╝${CYAN}║${NC}"
    echo -e "${CYAN}║${PURPLE}    ╚═════╝╚═╝       ╚═╝     ╚═╝  ╚═╝ ╚═════╝  ╚════╝ ${CYAN}║${NC}"
    echo -e "${CYAN}║${YELLOW}        CLOUDFLARE ENGINE MANAGER v37 (MULTI-ACCOUNT)         ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo -e " ${WHITE}👤 Active Account :${NC} ${GREEN}${CF_EMAIL:-Belum Set}${NC}"
    echo -e " ${WHITE}🆔 Account ID     :${NC} ${YELLOW}${ACCOUNT_ID:-Belum Set}${NC}"
    echo -e " ${WHITE}📁 Folder Script   :${NC} ${YELLOW}$SCCF_DIR${NC}"
    echo -e "${CYAN}----------------------------------------------------------------${NC}"
}

# SETUP VARIABEL GLOBAL UNTUK DIGUNAKAN DI MODUL
export BASE_URL="https://api.cloudflare.com/client/v4"

update_auth_header() {
    export AUTH_HEADER=(-H "X-Auth-Email: $CF_EMAIL" -H "X-Auth-Key: $CF_API_KEY")
}

save_account_to_json() {
    local email="$1"
    local key="$2"
    local acc_id="$3"

    tmp=$(mktemp)
    jq --arg email "$email" --arg key "$key" --arg id "$acc_id" \
       'map(select(.email != $email)) + [{"email": $email, "api_key": $key, "account_id": $id}]' \
       "$ACCOUNTS_FILE" > "$tmp" && mv "$tmp" "$ACCOUNTS_FILE"
    
    chmod 600 "$ACCOUNTS_FILE"
}

set_active_account() {
    CF_EMAIL="$1"
    CF_API_KEY="$2"
    ACCOUNT_ID="$3"

    update_auth_header

    echo "{\"email\":\"$CF_EMAIL\",\"api_key\":\"$CF_API_KEY\",\"account_id\":\"$ACCOUNT_ID\"}" > "$ACTIVE_ACC_FILE"
    chmod 600 "$ACTIVE_ACC_FILE"
}

verify_and_login() {
    local email="$1"
    local key="$2"

    echo -e "\n${YELLOW}📂 Verifikasi Account ID untuk $email...${NC}"
    TEMP_HEADER=(-H "X-Auth-Email: $email" -H "X-Auth-Key: $key")

    MEMBERSHIPS_JSON=$(curl -s "${TEMP_HEADER[@]}" -H "Content-Type: application/json" "$BASE_URL/memberships" || echo "")
    DETECTED_ID=$(echo "$MEMBERSHIPS_JSON" | jq -r '.result[0].account.id // empty' 2>/dev/null)

    if [ -z "$DETECTED_ID" ] || [ "$DETECTED_ID" == "null" ]; then
        ACCOUNTS_JSON=$(curl -s "${TEMP_HEADER[@]}" -H "Content-Type: application/json" "$BASE_URL/accounts" || echo "")
        DETECTED_ID=$(echo "$ACCOUNTS_JSON" | jq -r '.result[0].id // empty' 2>/dev/null)
    fi

    if [ -z "$DETECTED_ID" ] || [ "$DETECTED_ID" == "null" ]; then
        echo -e "${RED}❌ Gagal mendeteksi Account ID. Periksa Email/API Key!${NC}"
        return 1
    fi

    save_account_to_json "$email" "$key" "$DETECTED_ID"
    set_active_account "$email" "$key" "$DETECTED_ID"

    echo -e "${GREEN}✅ Login Berhasil! (ID: $DETECTED_ID)${NC}"
    sleep 1
    return 0
}

add_new_account() {
    clear
    echo -e "${CYAN}====== TAMBAH AKUN CLOUDFLARE BARU ======${NC}\n"
    read -rp "✉️  Email CF      : " NEW_EMAIL
    read -rp "🔑 Global API Key: " NEW_KEY
    echo ""

    if [ -z "$NEW_EMAIL" ] || [ -z "$NEW_KEY" ]; then
        echo -e "${RED}❌ Email dan API Key tidak boleh kosong!${NC}"
        sleep 1.5
        return
    fi

    if verify_and_login "$NEW_EMAIL" "$NEW_KEY"; then
        echo -e "${GREEN}💾 Akun $NEW_EMAIL berhasil ditambahkan dan diaktifkan!${NC}"
    else
        echo -e "${RED}❌ Gagal menambahkan akun.${NC}"
    fi
    sleep 1.5
}

delete_account_menu() {
    clear
    echo -e "${CYAN}====== HAPUS AKUN TERPANTAU ======${NC}\n"
    
    count=$(jq '. | length' "$ACCOUNTS_FILE" 2>/dev/null || echo "0")
    if [ "$count" -eq 0 ]; then
        echo -e "${YELLOW}⚠️ Tidak ada akun yang tersimpan.${NC}"
        sleep 1.5
        return
    fi

    for i in $(seq 0 $((count - 1))); do
        acc_email=$(jq -r ".[$i].email" "$ACCOUNTS_FILE")
        echo -e "  ${CYAN}[$((i+1))]${NC} $acc_email"
    done
    echo -e "\n  ${RED}[0] Batal${NC}"
    echo ""
    read -rp " Pilih nomor akun yang ingin dihapus: " DEL_CHOICE

    if [[ "$DEL_CHOICE" =~ ^[0-9]+$ ]] && [ "$DEL_CHOICE" -ge 1 ] && [ "$DEL_CHOICE" -le "$count" ]; then
        TARGET_EMAIL=$(jq -r ".[$((DEL_CHOICE-1))].email" "$ACCOUNTS_FILE")
        
        tmp=$(mktemp)
        jq --arg email "$TARGET_EMAIL" 'map(select(.email != $email))' "$ACCOUNTS_FILE" > "$tmp" && mv "$tmp" "$ACCOUNTS_FILE"
        echo -e "${GREEN}🗑️ Akun $TARGET_EMAIL berhasil dihapus!${NC}"

        if [ "$TARGET_EMAIL" == "$CF_EMAIL" ]; then
            rm -f "$ACTIVE_ACC_FILE"
            unset CF_EMAIL CF_API_KEY ACCOUNT_ID AUTH_HEADER
        fi
    fi
    sleep 1.5
}

account_switch_menu() {
    while true; do
        clear
        echo -e "${CYAN}====== MANAJEMEN & SWITCH AKUN ======${NC}\n"

        count=$(jq '. | length' "$ACCOUNTS_FILE" 2>/dev/null || echo "0")
        
        if [ "$count" -gt 0 ]; then
            echo -e "${WHITE}Daftar Akun Tersimpan:${NC}"
            for i in $(seq 0 $((count - 1))); do
                acc_email=$(jq -r ".[$i].email" "$ACCOUNTS_FILE")
                if [ "$acc_email" == "$CF_EMAIL" ]; then
                    echo -e "  ${GREEN}[$((i+1))] $acc_email (Aktif)${NC}"
                else
                    echo -e "  ${CYAN}[$((i+1))]${NC} $acc_email"
                fi
            done
            echo ""
        else
            echo -e "${YELLOW}⚠️ Belum ada akun yang tersimpan.${NC}\n"
        fi

        echo -e "  ${GREEN}[+] Tambah Akun Baru${NC}"
        if [ "$count" -gt 0 ]; then
            echo -e "  ${RED}[-] Hapus Akun Tersimpan${NC}"
        fi
        echo -e "  ${YELLOW}[0] Kembali ke Menu Utama${NC}"
        echo ""
        read -rp " Pilih Opsi: " ACC_CHOICE

        if [ "$ACC_CHOICE" == "+" ]; then
            add_new_account
            break
        elif [ "$ACC_CHOICE" == "-" ] && [ "$count" -gt 0 ]; then
            delete_account_menu
        elif [ "$ACC_CHOICE" == "0" ]; then
            break
        elif [[ "$ACC_CHOICE" =~ ^[0-9]+$ ]] && [ "$ACC_CHOICE" -ge 1 ] && [ "$ACC_CHOICE" -le "$count" ]; then
            SELECTED_INDEX=$((ACC_CHOICE - 1))
            SEL_EMAIL=$(jq -r ".[$SELECTED_INDEX].email" "$ACCOUNTS_FILE")
            SEL_KEY=$(jq -r ".[$SELECTED_INDEX].api_key" "$ACCOUNTS_FILE")
            
            echo -e "${YELLOW}🔄 Mengalihkan ke akun: $SEL_EMAIL...${NC}"
            if verify_and_login "$SEL_EMAIL" "$SEL_KEY"; then
                echo -e "${GREEN}✅ Berhasil switch akun!${NC}"
            fi
            sleep 1
            break
        else
            echo -e "${RED}❌ Pilihan tidak valid!${NC}"
            sleep 1
        fi
    done
}

update_script() {
    clear
    echo -e "${CYAN}====== UPDATE SCRIPT DARI GITHUB ======${NC}\n"
    if [ -d ".git" ]; then
        echo -e "${YELLOW}🔄 Menarik pembaruan dari repositori...${NC}"
        git fetch origin
        
        BRANCH=$(git branch -r | grep -E 'origin/(main|master)' | head -n 1 | sed 's/origin\///' | tr -d ' ')
        [ -z "$BRANCH" ] && BRANCH="main"

        git reset --hard "origin/$BRANCH"
        echo -e "\n${GREEN}✅ Script berhasil diperbarui ke versi terbaru!${NC}"
        echo -e "${YELLOW}🔄 Silakan jalankan ulang script-nya.${NC}"
    else
        echo -e "${RED}❌ Direktori ini tidak di-clone via Git.${NC}"
    fi
    sleep 2
    exit 0
}

init_auth() {
    if [ -f "$ACTIVE_ACC_FILE" ]; then
        CF_EMAIL=$(jq -r '.email // empty' "$ACTIVE_ACC_FILE")
        CF_API_KEY=$(jq -r '.api_key // empty' "$ACTIVE_ACC_FILE")
        ACCOUNT_ID=$(jq -r '.account_id // empty' "$ACTIVE_ACC_FILE")
        update_auth_header
    fi

    if [ -z "$CF_EMAIL" ] || [ -z "$CF_API_KEY" ]; then
        count=$(jq '. | length' "$ACCOUNTS_FILE" 2>/dev/null || echo "0")
        if [ "$count" -gt 0 ]; then
            CF_EMAIL=$(jq -r '.[0].email' "$ACCOUNTS_FILE")
            CF_API_KEY=$(jq -r '.[0].api_key' "$ACCOUNTS_FILE")
            ACCOUNT_ID=$(jq -r '.[0].account_id' "$ACCOUNTS_FILE")
            set_active_account "$CF_EMAIL" "$CF_API_KEY" "$ACCOUNT_ID"
        fi
    fi

    while [ -z "$CF_EMAIL" ] || [ -z "$CF_API_KEY" ] || [ -z "$ACCOUNT_ID" ]; do
        echo -e "${YELLOW}⚠️ Belum ada akun Cloudflare aktif terkonfigurasi.${NC}"
        sleep 1
        add_new_account
    done
}

# INISIALISASI WAJIB ADA AKUN AKTIF
init_auth

while true; do
    draw_banner
    echo -e " ${BOLD}MAIN MENU OPTIONS:${NC}\n"

    MODULE_ACTIONS=()
    index=1

    shopt -s nullglob
    for mod_file in "$MODULES_DIR"/*.sh; do
        source "$mod_file"

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
    echo -e "  ${YELLOW}[00]${NC} 🔄 ${YELLOW}Switch / Kelola Akun Cloudflare${NC}"
    echo -e "  ${YELLOW}[99]${NC} 🚀 ${YELLOW}Update Script (Git Pull)${NC}"
    echo -e "  ${RED}[e]${NC}  🚪 ${RED}Keluar dari Script${NC}"
    echo ""
    echo -e "${CYAN}----------------------------------------------------------------${NC}"
    read -rp " Pilih Menu: " MAIN_CHOICE
    echo ""

    if [ "$MAIN_CHOICE" == "00" ]; then
        account_switch_menu
    elif [ "$MAIN_CHOICE" == "99" ]; then
        update_script
    elif [ "$MAIN_CHOICE" == "e" ] || [ "$MAIN_CHOICE" == "E" ]; then
        echo -e "${GREEN}👋 Terima kasih bos! Keluar dari CF PROJECT.${NC}"
        exit 0
    elif [[ "$MAIN_CHOICE" =~ ^[0-9]+$ ]] && [ "$MAIN_CHOICE" -ge 1 ] && [ "$MAIN_CHOICE" -lt "$index" ]; then
        TARGET_ACTION="${MODULE_ACTIONS[$((MAIN_CHOICE-1))]}"
        $TARGET_ACTION
    else
        echo -e "${RED}❌ Pilihan tidak valid, silakan coba lagi.${NC}"
        sleep 1
    fi
done
