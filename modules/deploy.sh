# MENU_TITLE: 🚀 Kelola Service Worker (Buat / Edit / Hapus)
# MENU_ACTION: run_worker_module

get_js_source_input() {
    echo -e "\n${BOLD}📌 Pilih Metode Sumber File JS:${NC}"
    echo -e "  ${CYAN}[1]${NC} Pilih file dari folder SCCF (Lokal)"
    echo -e "  ${CYAN}[2]${NC} Download otomatis via URL Raw (GitHub/Pastebin)"
    echo -e "  ${RED}[0]${NC} ↩️  Batal / Kembali"
    read -rp "Pilih metode [1/2/0]: " METHOD_CHOOSE

    if [ "$METHOD_CHOOSE" == "0" ] || [ "$METHOD_CHOOSE" == "b" ]; then return 1; fi

    if [ "$METHOD_CHOOSE" == "2" ]; then
        read -rp "🔗 Masukkan URL Raw file .js [0=Batal]: " RAW_URL
        if [ "$RAW_URL" == "0" ] || [ -z "$RAW_URL" ]; then return 1; fi

        EXTRACTED_NAME=$(basename "$RAW_URL" | cut -d'?' -f1)
        [[ ! "$EXTRACTED_NAME" == *.js ]] && EXTRACTED_NAME="${EXTRACTED_NAME}.js"

        TEMP_JS_FILE="$SCCF_DIR/$EXTRACTED_NAME"
        echo -e "${YELLOW}⏳ Mendownload file JS ($EXTRACTED_NAME)...${NC}"
        if curl -sL "$RAW_URL" -o "$TEMP_JS_FILE" && [ -s "$TEMP_JS_FILE" ]; then
            SELECTED_JS_FILE="$TEMP_JS_FILE"
            echo -e "${GREEN}✅ Berhasil mendownload: $EXTRACTED_NAME${NC}"
            return 0
        else
            echo -e "${RED}❌ Gagal download / file kosong!${NC}"; return 1
        fi
    else
        shopt -s nullglob
        local js_files=("$SCCF_DIR"/*.js)
        shopt -u nullglob

        if [ ${#js_files[@]} -eq 0 ]; then
            echo -e "${RED}❌ Folder SCCF kosong! Taruh file .js dulu.${NC}"; return 1
        fi

        echo -e "\n${BOLD}📁 Pilih File JS dari Folder SCCF:${NC}"
        local i=1
        for file in "${js_files[@]}"; do
            echo -e "  ${CYAN}[$i]${NC} $(basename "$file")"
            ((i++))
        done
        read -rp "Pilih Nomor File JS [0=Batal]: " FILE_NUM

        if [ "$FILE_NUM" == "0" ] || ! [[ "$FILE_NUM" =~ ^[0-9]+$ ]] || [ "$FILE_NUM" -gt ${#js_files[@]} ]; then
            return 1
        fi
        SELECTED_JS_FILE="${js_files[$((FILE_NUM-1))]}"
        return 0
    fi
}

deploy_universal_worker() {
    local target_worker="$1"
    local js_file="$2"
    local filename=$(basename "$js_file")

    echo -e "${YELLOW}🚀 Mendeploy '$filename' ke Worker '$target_worker'...${NC}"
    METADATA_FILE=$(mktemp)

    if grep -qE "export[[:space:]]+default" "$js_file" || grep -qE "^import[[:space:]]" "$js_file"; then
        jq -n --arg main_file "$filename" '{main_module: $main_file, compatibility_date: "2026-01-01"}' > "$METADATA_FILE"
        DEPLOY_RES=$(curl -s -X PUT "${AUTH_HEADER[@]}" -F "metadata=@$METADATA_FILE;type=application/json" -F "$filename=@$js_file;type=application/javascript+module" "$BASE_URL/accounts/$ACCOUNT_ID/workers/services/$target_worker/environments/production/content")
    else
        jq -n '{body_part: "script", compatibility_date: "2026-01-01"}' > "$METADATA_FILE"
        DEPLOY_RES=$(curl -s -X PUT "${AUTH_HEADER[@]}" -F "metadata=@$METADATA_FILE;type=application/json" -F "script=@$js_file;type=application/javascript" "$BASE_URL/accounts/$ACCOUNT_ID/workers/services/$target_worker/environments/production/content")
    fi
    rm -f "$METADATA_FILE"

    if [ "$(echo "$DEPLOY_RES" | jq -r '.success')" == "true" ]; then
        curl -s -X POST "${AUTH_HEADER[@]}" -H "Content-Type: application/json" -d '{"enabled":true}' "$BASE_URL/accounts/$ACCOUNT_ID/workers/services/$target_worker/environments/production/subdomain" > /dev/null 2>&1 || true
        SUB_RES=$(curl -s "${AUTH_HEADER[@]}" -H "Content-Type: application/json" "$BASE_URL/accounts/$ACCOUNT_ID/workers/subdomain")
        CF_SUBDOMAIN=$(echo "$SUB_RES" | jq -r '.result.subdomain // empty')

        echo -e "\n${GREEN}🎉 WORKER BERHASIL DI-DEPLOY!${NC}"
        echo -e "📌 Nama Worker : $target_worker"
        [ -n "$CF_SUBDOMAIN" ] && echo -e "🔗 Live URL    : ${CYAN}https://$target_worker.$CF_SUBDOMAIN.workers.dev${NC}"
    else
        echo -e "${RED}❌ Gagal Deploy:${NC}"
        echo "$DEPLOY_RES" | jq -r '.errors[] | "Code: \(.code) - \(.message)"' 2>/dev/null || echo "$DEPLOY_RES"
    fi
}

run_worker_module() {
    # DIBUNGKUS LOOP WHILE DIA STAY DI MENU INI
    while true; do
        clear
        echo -e "${CYAN}================================================================${NC}"
        echo -e "${BOLD}📌 SUB-MENU MANAJEMEN SERVICE WORKER:${NC}"
        echo -e "${CYAN}----------------------------------------------------------------${NC}"
        echo -e "  ${CYAN}[1]${NC} 🆕 Buat Worker Baru"
        echo -e "  ${CYAN}[2]${NC} 📝 Edit / Timpa Worker"
        echo -e "  ${CYAN}[3]${NC} 🗑️  Hapus Worker Permanen"
        echo -e "  ${RED}[0]${NC} ↩️  Kembali ke Menu Utama"
        echo -e "${CYAN}----------------------------------------------------------------${NC}"
        read -rp "Pilih [1/2/3/0]: " W_CHOICE

        case "$W_CHOICE" in
            1)
                read -rp "🚀 Masukkan Nama Worker Baru [0=Batal]: " TARGET_WORKER_NAME
                if [ "$TARGET_WORKER_NAME" != "0" ] && [ -n "$TARGET_WORKER_NAME" ]; then
                    TARGET_WORKER_NAME=$(echo "$TARGET_WORKER_NAME" | sed 's/[^-a-zA-Z0-9_]//g' | tr '[:upper:]' '[:lower:]')
                    if get_js_source_input; then
                        deploy_universal_worker "$TARGET_WORKER_NAME" "$SELECTED_JS_FILE"
                    fi
                fi
                read -rp "Tekan Enter untuk kembali ke Sub-Menu..."
                ;;
            2)
                WORKERS_JSON=$(curl -s "${AUTH_HEADER[@]}" -H "Content-Type: application/json" "$BASE_URL/accounts/$ACCOUNT_ID/workers/services?per_page=100")
                echo "$WORKERS_JSON" | jq -r '.result[] | .id' | nl -w2 -s') '
                read -rp "Pilih Nomor Worker [0=Batal]: " W_NUM
                if [ "$W_NUM" != "0" ] && [ -n "$W_NUM" ]; then
                    TARGET_WORKER_NAME=$(echo "$WORKERS_JSON" | jq -r ".result[$((W_NUM-1))].id")
                    if [ -n "$TARGET_WORKER_NAME" ] && get_js_source_input; then
                        deploy_universal_worker "$TARGET_WORKER_NAME" "$SELECTED_JS_FILE"
                    fi
                fi
                read -rp "Tekan Enter untuk kembali ke Sub-Menu..."
                ;;
            3)
                WORKERS_JSON=$(curl -s "${AUTH_HEADER[@]}" -H "Content-Type: application/json" "$BASE_URL/accounts/$ACCOUNT_ID/workers/services?per_page=100")
                echo "$WORKERS_JSON" | jq -r '.result[] | .id' | nl -w2 -s') '
                read -rp "Nomor Worker yang Mau Dihapus [0=Batal]: " W_NUM
                if [ "$W_NUM" != "0" ] && [ -n "$W_NUM" ]; then
                    TARGET_WORKER_NAME=$(echo "$WORKERS_JSON" | jq -r ".result[$((W_NUM-1))].id")
                    read -rp "⚠️ Yakin menghapus Worker '$TARGET_WORKER_NAME'? [y/N]: " CONFIRM_DEL
                    if [[ "$CONFIRM_DEL" =~ ^[Yy] ]]; then
                        curl -s -X DELETE "${AUTH_HEADER[@]}" -H "Content-Type: application/json" "$BASE_URL/accounts/$ACCOUNT_ID/workers/services/$TARGET_WORKER_NAME" > /dev/null
                        echo -e "${GREEN}✅ Worker '$TARGET_WORKER_NAME' Berhasil Dihapus!${NC}"
                    fi
                fi
                read -rp "Tekan Enter untuk kembali ke Sub-Menu..."
                ;;
            0|b|B)
                # PILIH 0/b UNTUK KEMBALI KE MENU UTAMA SCRIPT
                break
                ;;
            *)
                echo -e "${RED}Pilihan tidak valid!${NC}"
                sleep 1
                ;;
        esac
    done
}
