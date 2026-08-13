# MENU_TITLE: 🚀 Kelola Service Worker (Buat / Edit / Env Var / Cron Trigger / Custom Domain / List / Hapus)
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
        DEPLOY_RES=$(curl -s -X PUT "${AUTH_HEADER[@]}" -F "metadata=@$METADATA_FILE;type=application/json" -F "$filename=@$js_file;type=application/javascript+module" "$BASE_URL/accounts/$ACCOUNT_ID/workers/services/$target_worker/environments/production/content" || echo "")
    else
        jq -n '{body_part: "script", compatibility_date: "2026-01-01"}' > "$METADATA_FILE"
        DEPLOY_RES=$(curl -s -X PUT "${AUTH_HEADER[@]}" -F "metadata=@$METADATA_FILE;type=application/json" -F "script=@$js_file;type=application/javascript" "$BASE_URL/accounts/$ACCOUNT_ID/workers/services/$target_worker/environments/production/content" || echo "")
    fi
    rm -f "$METADATA_FILE"

    if [ "$(echo "$DEPLOY_RES" | jq -r '.success // false' 2>/dev/null)" == "true" ]; then
        curl -s -X POST "${AUTH_HEADER[@]}" -H "Content-Type: application/json" -d '{"enabled":true}' "$BASE_URL/accounts/$ACCOUNT_ID/workers/services/$target_worker/environments/production/subdomain" > /dev/null 2>&1 || true
        SUB_RES=$(curl -s "${AUTH_HEADER[@]}" -H "Content-Type: application/json" "$BASE_URL/accounts/$ACCOUNT_ID/workers/subdomain" || echo "")
        CF_SUBDOMAIN=$(echo "$SUB_RES" | jq -r '.result.subdomain // empty' 2>/dev/null)

        echo -e "\n${GREEN}🎉 WORKER BERHASIL DI-DEPLOY!${NC}"
        echo -e "📌 Nama Worker : $target_worker"
        [ -n "$CF_SUBDOMAIN" ] && echo -e "🔗 Live URL    : ${CYAN}https://$target_worker.$CF_SUBDOMAIN.workers.dev${NC}"
    else
        echo -e "${RED}❌ Gagal Deploy:${NC}"
        echo "$DEPLOY_RES" | jq -r '.errors[] | "Code: \(.code) - \(.message)"' 2>/dev/null || echo "$DEPLOY_RES"
    fi
}

delete_worker_env_flow() {
    clear
    echo -e "${CYAN}====== HAPUS VARIABLE WORKER ======${NC}\n"

    WORKERS_JSON=$(curl -s "${AUTH_HEADER[@]}" -H "Content-Type: application/json" "$BASE_URL/accounts/$ACCOUNT_ID/workers/services?per_page=100" || echo "")
    echo "$WORKERS_JSON" | jq -r '.result[] | .id' 2>/dev/null | nl -w2 -s') '
    read -rp "Pilih Nomor Worker Target [0=Batal]: " W_NUM

    if [ "$W_NUM" != "0" ] && [ -n "$W_NUM" ]; then
        TARGET_WORKER_NAME=$(echo "$WORKERS_JSON" | jq -r ".result[$((W_NUM-1))].id" 2>/dev/null)

        if [ -n "$TARGET_WORKER_NAME" ] && [ "$TARGET_WORKER_NAME" != "null" ]; then
            SETTINGS_URL="$BASE_URL/accounts/$ACCOUNT_ID/workers/services/$TARGET_WORKER_NAME/environments/production/settings"
            CURRENT_SETTINGS=$(curl -s "${AUTH_HEADER[@]}" -H "Content-Type: application/json" "$SETTINGS_URL" || echo "")
            EXISTING_BINDINGS=$(echo "$CURRENT_SETTINGS" | jq '.result.bindings // []' 2>/dev/null)

            VAR_NAMES=$(echo "$EXISTING_BINDINGS" | jq -r '.[] | select(.type=="plain_text" or .type=="secret_text") | .name' 2>/dev/null)
            VAR_COUNT=$(echo "$VAR_NAMES" | grep -c . || echo "0")

            if [ "$VAR_COUNT" -eq 0 ] || [ -z "$VAR_NAMES" ]; then
                echo -e "${YELLOW}⚠️ Tidak ada variable (env) yang terpasang di Worker '$TARGET_WORKER_NAME'.${NC}"
                return
            fi

            echo -e "\n📌 Daftar Variable di Worker '$TARGET_WORKER_NAME':"
            echo "$VAR_NAMES" | nl -w2 -s') '
            echo -e "  ${RED}[0] Batal${NC}"
            echo ""
            read -rp "Pilih Nomor Variable yang Ingin Dihapus: " V_NUM

            if [[ "$V_NUM" =~ ^[0-9]+$ ]] && [ "$V_NUM" -ge 1 ] && [ "$V_NUM" -le "$VAR_COUNT" ]; then
                TARGET_VAR_NAME=$(echo "$VAR_NAMES" | sed -n "${V_NUM}p")

                read -rp "⚠️ Yakin menghapus variable '$TARGET_VAR_NAME'? [y/N]: " CONFIRM_DEL
                if [[ "$CONFIRM_DEL" =~ ^[Yy] ]]; then
                    echo -e "${YELLOW}⚙️ Menghapus variable '$TARGET_VAR_NAME'...${NC}"

                    UPDATED_BINDINGS=$(echo "$EXISTING_BINDINGS" | jq --arg name "$TARGET_VAR_NAME" 'map(select(.name != $name))' 2>/dev/null)

                    METADATA_FILE=$(mktemp)
                    jq -n --argjson bindings "$UPDATED_BINDINGS" '{bindings: $bindings}' > "$METADATA_FILE"

                    UPDATE_RESPONSE=$(curl -s -X PATCH "${AUTH_HEADER[@]}" -F "settings=@$METADATA_FILE;type=application/json" "$SETTINGS_URL" || echo "")
                    rm -f "$METADATA_FILE"

                    if echo "$UPDATE_RESPONSE" | jq -e '.success' > /dev/null 2>&1; then
                        echo -e "${GREEN}🗑️ Variable '$TARGET_VAR_NAME' Berhasil Dihapus dari Worker '$TARGET_WORKER_NAME'!${NC}"
                    else
                        echo -e "${RED}❌ Gagal menghapus variable:${NC}"
                        echo "$UPDATE_RESPONSE" | jq -r '.errors[] | "Code: \(.code) - \(.message)"' 2>/dev/null || echo "$UPDATE_RESPONSE"
                    fi
                fi
            fi
        fi
    fi
}

manage_cron_triggers_flow() {
    clear
    echo -e "${CYAN}====== KELOLA CRON TRIGGER (SCHEDULES) ======${NC}\n"

    WORKERS_JSON=$(curl -s "${AUTH_HEADER[@]}" -H "Content-Type: application/json" "$BASE_URL/accounts/$ACCOUNT_ID/workers/services?per_page=100" || echo "")
    echo "$WORKERS_JSON" | jq -r '.result[] | .id' 2>/dev/null | nl -w2 -s') '
    read -rp "Pilih Nomor Worker Target [0=Batal]: " W_NUM

    if [ "$W_NUM" != "0" ] && [ -n "$W_NUM" ]; then
        TARGET_WORKER_NAME=$(echo "$WORKERS_JSON" | jq -r ".result[$((W_NUM-1))].id" 2>/dev/null)

        if [ -n "$TARGET_WORKER_NAME" ] && [ "$TARGET_WORKER_NAME" != "null" ]; then
            CRON_URL="$BASE_URL/accounts/$ACCOUNT_ID/workers/services/$TARGET_WORKER_NAME/environments/production/schedules"
            CURRENT_CRONS_RES=$(curl -s "${AUTH_HEADER[@]}" -H "Content-Type: application/json" "$CRON_URL" || echo "")
            EXISTING_CRONS=$(echo "$CURRENT_CRONS_RES" | jq -r '.result.schedules[]?.cron // empty' 2>/dev/null)

            echo -e "\n📌 Cron Triggers Terpasang Saat Ini:"
            if [ -z "$EXISTING_CRONS" ]; then
                echo -e "   ${YELLOW}(Belum ada Cron Trigger)${NC}"
            else
                echo "$EXISTING_CRONS" | sed 's/^/   ⏰ /'
            fi

            echo -e "\n${BOLD}Pilihan Aksi:${NC}"
            echo -e "  ${CYAN}[1]${NC} ➕ Tambah / Set Cron Expression Baru"
            echo -e "  ${RED}[2]${NC} 🗑️  Hapus Semua Cron Trigger"
            echo -e "  ${RED}[0]${NC} ↩️  Batal"
            read -rp "Pilih opsi [1/2/0]: " CRON_ACT

            if [ "$CRON_ACT" == "1" ]; then
                echo -e "\n💡 Contoh format: ${CYAN}*/5 * * * *${NC} (setiap 5 menit), ${CYAN}0 0 * * *${NC} (setiap jam 12 malam)"
                read -rp "⏰ Masukkan Expression Cron [0=Batal]: " CRON_EXP

                if [ "$CRON_EXP" != "0" ] && [ -n "$CRON_EXP" ]; then
                    echo -e "${YELLOW}⚙️ Memasang Cron Trigger '$CRON_EXP' ke Worker '$TARGET_WORKER_NAME'...${NC}"
                    
                    PAYLOAD=$(jq -n --arg cron "$CRON_EXP" '[{cron: $cron}]')
                    SET_CRON_RES=$(curl -s -X PUT "${AUTH_HEADER[@]}" -H "Content-Type: application/json" -d "$PAYLOAD" "$CRON_URL" || echo "")

                    if echo "$SET_CRON_RES" | jq -e '.success' > /dev/null 2>&1; then
                        echo -e "${GREEN}🎉 BERHASIL! Cron Trigger '$CRON_EXP' berhasil dipasang!${NC}"
                    else
                        echo -e "${RED}❌ Gagal memasang Cron Trigger:${NC}"
                        echo "$SET_CRON_RES" | jq -r '.errors[] | "Code: \(.code) - \(.message)"' 2>/dev/null || echo "$SET_CRON_RES"
                    fi
                fi

            elif [ "$CRON_ACT" == "2" ]; then
                read -rp "⚠️ Yakin ingin menghapus semua Cron Trigger pada Worker ini? [y/N]: " CONFIRM_CRON_DEL
                if [[ "$CONFIRM_CRON_DEL" =~ ^[Yy] ]]; then
                    echo -e "${YELLOW}⚙️ Menghapus semua Cron Trigger...${NC}"
                    
                    SET_CRON_RES=$(curl -s -X PUT "${AUTH_HEADER[@]}" -H "Content-Type: application/json" -d '[]' "$CRON_URL" || echo "")

                    if echo "$SET_CRON_RES" | jq -e '.success' > /dev/null 2>&1; then
                        echo -e "${GREEN}🗑️ Semua Cron Trigger berhasil dihapus!${NC}"
                    else
                        echo -e "${RED}❌ Gagal menghapus Cron Trigger:${NC}"
                        echo "$SET_CRON_RES" | jq -r '.errors[] | "Code: \(.code) - \(.message)"' 2>/dev/null || echo "$SET_CRON_RES"
                    fi
                fi
            fi
        fi
    fi
}

list_workers_flow() {
    clear
    echo -e "${CYAN}====== DAFTAR WORKER & URL ======${NC}\n"

    echo -e "${YELLOW}⏳ Mengambil data Worker & Subdomain...${NC}"
    WORKERS_JSON=$(curl -s "${AUTH_HEADER[@]}" -H "Content-Type: application/json" "$BASE_URL/accounts/$ACCOUNT_ID/workers/services?per_page=100" || echo "")
    WORKER_COUNT=$(echo "$WORKERS_JSON" | jq '.result | length' 2>/dev/null || echo "0")

    if [ "$WORKER_COUNT" -eq 0 ] || [ "$WORKER_COUNT" == "null" ]; then
        echo -e "${YELLOW}⚠️ Tidak ada Worker terdaftar di akun ini.${NC}"
        return
    fi

    SUB_RES=$(curl -s "${AUTH_HEADER[@]}" -H "Content-Type: application/json" "$BASE_URL/accounts/$ACCOUNT_ID/workers/subdomain" || echo "")
    CF_SUBDOMAIN=$(echo "$SUB_RES" | jq -r '.result.subdomain // empty' 2>/dev/null)

    DOMAINS_JSON=$(curl -s "${AUTH_HEADER[@]}" -H "Content-Type: application/json" "$BASE_URL/accounts/$ACCOUNT_ID/workers/domains" || echo "")

    echo -e "\n📋 DAFTAR WORKER TERPASANG ($WORKER_COUNT):"
    echo -e "${CYAN}----------------------------------------------------------------${NC}"

    for (( i=0; i<WORKER_COUNT; i++ )); do
        W_NAME=$(echo "$WORKERS_JSON" | jq -r ".result[$i].id")
        echo -e "🚀 ${BOLD}Worker:${NC} ${GREEN}$W_NAME${NC}"

        if [ -n "$CF_SUBDOMAIN" ]; then
            echo -e "   🔗 workers.dev   : ${CYAN}https://$W_NAME.$CF_SUBDOMAIN.workers.dev${NC}"
        fi

        CUSTOM_DOMS=$(echo "$DOMAINS_JSON" | jq -r ".result[] | select(.service == \"$W_NAME\") | .hostname" 2>/dev/null || echo "")

        if [ -n "$CUSTOM_DOMS" ]; then
            while IFS= read -r c_dom; do
                [ -n "$c_dom" ] && echo -e "   🌐 Custom Domain : ${PURPLE}https://$c_dom${NC}"
            done <<< "$CUSTOM_DOMS"
        fi
        echo -e "${CYAN}----------------------------------------------------------------${NC}"
    done
}

run_worker_module() {
    while true; do
        clear
        echo -e "${CYAN}================================================================${NC}"
        echo -e "${BOLD}📌 SUB-MENU MANAJEMEN SERVICE WORKER:${NC}"
        echo -e "${CYAN}----------------------------------------------------------------${NC}"
        echo -e "  ${CYAN}[1]${NC} 🆕 Buat Worker Baru"
        echo -e "  ${CYAN}[2]${NC} 📝 Edit / Timpa Worker"
        echo -e "  ${CYAN}[3]${NC} 🔑 Tambah Variable (Environment Variable / env)"
        echo -e "  ${CYAN}[4]${NC} 🗑️  Hapus Variable (Environment Variable / env)"
        echo -e "  ${CYAN}[5]${NC} ⏰ Kelola Cron Trigger (Schedules)"
        echo -e "  ${CYAN}[6]${NC} 📋 Tampilkan Semua Worker & URL"
        echo -e "  ${CYAN}[7]${NC} 🌐 Tambah Custom Domain ke Worker"
        echo -e "  ${CYAN}[8]${NC} ❌ Hapus Custom Domain dari Worker"
        echo -e "  ${RED}[9]${NC} 🗑️  Hapus Worker Permanen"
        echo -e "  ${RED}[0]${NC} ↩️  Kembali ke Menu Utama"
        echo -e "${CYAN}----------------------------------------------------------------${NC}"
        read -rp "Pilih [1/2/3/4/5/6/7/8/9/0]: " W_CHOICE

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
                WORKERS_JSON=$(curl -s "${AUTH_HEADER[@]}" -H "Content-Type: application/json" "$BASE_URL/accounts/$ACCOUNT_ID/workers/services?per_page=100" || echo "")
                echo "$WORKERS_JSON" | jq -r '.result[] | .id' 2>/dev/null | nl -w2 -s') '
                read -rp "Pilih Nomor Worker [0=Batal]: " W_NUM
                if [ "$W_NUM" != "0" ] && [ -n "$W_NUM" ]; then
                    TARGET_WORKER_NAME=$(echo "$WORKERS_JSON" | jq -r ".result[$((W_NUM-1))].id" 2>/dev/null)
                    if [ -n "$TARGET_WORKER_NAME" ] && [ "$TARGET_WORKER_NAME" != "null" ] && get_js_source_input; then
                        deploy_universal_worker "$TARGET_WORKER_NAME" "$SELECTED_JS_FILE"
                    fi
                fi
                read -rp "Tekan Enter untuk kembali ke Sub-Menu..."
                ;;
            3)
                WORKERS_JSON=$(curl -s "${AUTH_HEADER[@]}" -H "Content-Type: application/json" "$BASE_URL/accounts/$ACCOUNT_ID/workers/services?per_page=100" || echo "")
                echo "$WORKERS_JSON" | jq -r '.result[] | .id' 2>/dev/null | nl -w2 -s') '
                read -rp "Pilih Nomor Worker Target [0=Batal]: " W_NUM
                
                if [ "$W_NUM" != "0" ] && [ -n "$W_NUM" ]; then
                    TARGET_WORKER_NAME=$(echo "$WORKERS_JSON" | jq -r ".result[$((W_NUM-1))].id" 2>/dev/null)
                    
                    if [ -n "$TARGET_WORKER_NAME" ] && [ "$TARGET_WORKER_NAME" != "null" ]; then
                        read -rp "🔤 Masukkan Nama Variable (contoh: API_KEY) [0=Batal]: " VAR_NAME
                        if [ "$VAR_NAME" != "0" ] && [ -n "$VAR_NAME" ]; then
                            read -rp "💬 Masukkan Isi Value Variable [0=Batal]: " VAR_VALUE
                            if [ "$VAR_VALUE" != "0" ]; then
                                echo -e "${YELLOW}⚙️ Menambahkan variable 'env.$VAR_NAME' ke Worker '$TARGET_WORKER_NAME'...${NC}"
                                
                                SETTINGS_URL="$BASE_URL/accounts/$ACCOUNT_ID/workers/services/$TARGET_WORKER_NAME/environments/production/settings"
                                CURRENT_SETTINGS=$(curl -s "${AUTH_HEADER[@]}" -H "Content-Type: application/json" "$SETTINGS_URL" || echo "")
                                EXISTING_BINDINGS=$(echo "$CURRENT_SETTINGS" | jq '.result.bindings // []' 2>/dev/null)

                                NEW_BINDING=$(jq -n --arg name "$VAR_NAME" --arg text "$VAR_VALUE" '{type: "plain_text", name: $name, text: $text}')
                                UPDATED_BINDINGS=$(echo "$EXISTING_BINDINGS" | jq --argjson new "$NEW_BINDING" --arg name "$VAR_NAME" 'map(select(.name != $name)) + [$new]' 2>/dev/null)

                                METADATA_FILE=$(mktemp)
                                jq -n --argjson bindings "$UPDATED_BINDINGS" '{bindings: $bindings}' > "$METADATA_FILE"
                                
                                UPDATE_RESPONSE=$(curl -s -X PATCH "${AUTH_HEADER[@]}" -F "settings=@$METADATA_FILE;type=application/json" "$SETTINGS_URL" || echo "")
                                rm -f "$METADATA_FILE"

                                if echo "$UPDATE_RESPONSE" | jq -e '.success' > /dev/null 2>&1; then
                                    echo -e "${GREEN}🎉 BERHASIL! Variable 'env.$VAR_NAME' sukses ditambahkan ke Worker '$TARGET_WORKER_NAME'!${NC}"
                                else
                                    echo -e "${RED}❌ Gagal menambahkan variable:${NC}"
                                    echo "$UPDATE_RESPONSE" | jq -r '.errors[] | "Code: \(.code) - \(.message)"' 2>/dev/null || echo "$UPDATE_RESPONSE"
                                fi
                            fi
                        fi
                    fi
                fi
                read -rp "Tekan Enter untuk kembali ke Sub-Menu..."
                ;;
            4)
                delete_worker_env_flow
                read -rp "Tekan Enter untuk kembali ke Sub-Menu..."
                ;;
            5)
                manage_cron_triggers_flow
                read -rp "Tekan Enter untuk kembali ke Sub-Menu..."
                ;;
            6)
                list_workers_flow
                read -rp "Tekan Enter untuk kembali ke Sub-Menu..."
                ;;
            7)
                WORKERS_JSON=$(curl -s "${AUTH_HEADER[@]}" -H "Content-Type: application/json" "$BASE_URL/accounts/$ACCOUNT_ID/workers/services?per_page=100" || echo "")
                echo "$WORKERS_JSON" | jq -r '.result[] | .id' 2>/dev/null | nl -w2 -s') '
                read -rp "Pilih Worker Target [0=Batal]: " W_NUM
                
                if [ "$W_NUM" != "0" ] && [ -n "$W_NUM" ]; then
                    TARGET_WORKER_NAME=$(echo "$WORKERS_JSON" | jq -r ".result[$((W_NUM-1))].id" 2>/dev/null)

                    ZONES_JSON=$(curl -s "${AUTH_HEADER[@]}" -H "Content-Type: application/json" "$BASE_URL/zones?account.id=$ACCOUNT_ID&per_page=50" || echo "")
                    echo "$ZONES_JSON" | jq -r '.result[] | .name' 2>/dev/null | nl -w2 -s') '
                    read -rp "Pilih Domain Utama [0=Batal]: " Z_NUM
                    
                    if [ "$Z_NUM" != "0" ] && [ -n "$Z_NUM" ]; then
                        SELECTED_DOMAIN=$(echo "$ZONES_JSON" | jq -r ".result[$((Z_NUM-1))].name" 2>/dev/null)
                        SELECTED_ZONE_ID=$(echo "$ZONES_JSON" | jq -r ".result[$((Z_NUM-1))].id" 2>/dev/null)

                        read -rp "Subdomain [Ketik '-' jika root domain, 0=Batal]: " SUB_INPUT
                        if [ "$SUB_INPUT" != "0" ] && [ -n "$SUB_INPUT" ]; then
                            [ "$SUB_INPUT" == "-" ] && FULL_HOSTNAME="$SELECTED_DOMAIN" || FULL_HOSTNAME="${SUB_INPUT}.${SELECTED_DOMAIN}"

                            ADD_DOM_RES=$(curl -s -X PUT "${AUTH_HEADER[@]}" -H "Content-Type: application/json" -d "{\"environment\":\"production\",\"hostname\":\"$FULL_HOSTNAME\",\"service\":\"$TARGET_WORKER_NAME\",\"zone_id\":\"$SELECTED_ZONE_ID\"}" "$BASE_URL/accounts/$ACCOUNT_ID/workers/domains" || echo "")
                            if [ "$(echo "$ADD_DOM_RES" | jq -r '.success // false' 2>/dev/null)" == "true" ]; then
                                echo -e "${GREEN}✅ Custom Domain https://$FULL_HOSTNAME Berhasil Terikat ke Worker '$TARGET_WORKER_NAME'!${NC}"
                            else
                                echo -e "${RED}❌ Gagal:${NC}"
                                echo "$ADD_DOM_RES" | jq -r '.errors[] | "Code: \(.code) - \(.message)"' 2>/dev/null || echo "$ADD_DOM_RES"
                            fi
                        fi
                    fi
                fi
                read -rp "Tekan Enter untuk kembali ke Sub-Menu..."
                ;;
            8)
                DOMAINS_JSON=$(curl -s "${AUTH_HEADER[@]}" -H "Content-Type: application/json" "$BASE_URL/accounts/$ACCOUNT_ID/workers/domains" || echo "")
                COUNT_DOM=$(echo "$DOMAINS_JSON" | jq '.result | length' 2>/dev/null || echo "0")

                if [ "$COUNT_DOM" -eq 0 ] || [ "$COUNT_DOM" == "null" ]; then
                    echo -e "${YELLOW}⚠️ Belum ada custom domain yang terhubung ke Worker.${NC}"
                else
                    echo "$DOMAINS_JSON" | jq -r '.result[] | "\(.hostname) (Worker: \(.service))"' 2>/dev/null | nl -w2 -s') '
                    read -rp "Pilih Domain yang Mau Dicabut [0=Batal]: " D_NUM
                    
                    if [ "$D_NUM" != "0" ] && [ -n "$D_NUM" ]; then
                        TARGET_DOM_ID=$(echo "$DOMAINS_JSON" | jq -r ".result[$((D_NUM-1))].id" 2>/dev/null)
                        TARGET_DOM_HOST=$(echo "$DOMAINS_JSON" | jq -r ".result[$((D_NUM-1))].hostname" 2>/dev/null)

                        DEL_DOM_RES=$(curl -s -X DELETE "${AUTH_HEADER[@]}" -H "Content-Type: application/json" "$BASE_URL/accounts/$ACCOUNT_ID/workers/domains/$TARGET_DOM_ID" || echo "")
                        IS_SUCCESS=$(echo "$DEL_DOM_RES" | jq -r '.success // false' 2>/dev/null)
                        if [ "$IS_SUCCESS" == "true" ] || ! echo "$DEL_DOM_RES" | grep -q "error"; then
                            echo -e "${GREEN}✅ Domain '$TARGET_DOM_HOST' Berhasil Dicabut dari Worker!${NC}"
                        else
                            echo -e "${RED}❌ Gagal cabut domain:${NC}"
                            echo "$DEL_DOM_RES" | jq -r '.errors[] | "Code: \(.code) - \(.message)"' 2>/dev/null || echo "$DEL_DOM_RES"
                        fi
                    fi
                fi
                read -rp "Tekan Enter untuk kembali ke Sub-Menu..."
                ;;
            9)
                WORKERS_JSON=$(curl -s "${AUTH_HEADER[@]}" -H "Content-Type: application/json" "$BASE_URL/accounts/$ACCOUNT_ID/workers/services?per_page=100" || echo "")
                echo "$WORKERS_JSON" | jq -r '.result[] | .id' 2>/dev/null | nl -w2 -s') '
                read -rp "Nomor Worker yang Mau Dihapus [0=Batal]: " W_NUM
                if [ "$W_NUM" != "0" ] && [ -n "$W_NUM" ]; then
                    TARGET_WORKER_NAME=$(echo "$WORKERS_JSON" | jq -r ".result[$((W_NUM-1))].id" 2>/dev/null)
                    if [ -n "$TARGET_WORKER_NAME" ] && [ "$TARGET_WORKER_NAME" != "null" ]; then
                        read -rp "⚠️ Yakin menghapus Worker '$TARGET_WORKER_NAME'? [y/N]: " CONFIRM_DEL
                        if [[ "$CONFIRM_DEL" =~ ^[Yy] ]]; then
                            curl -s -X DELETE "${AUTH_HEADER[@]}" -H "Content-Type: application/json" "$BASE_URL/accounts/$ACCOUNT_ID/workers/services/$TARGET_WORKER_NAME" > /dev/null 2>&1
                            echo -e "${GREEN}✅ Worker '$TARGET_WORKER_NAME' Berhasil Dihapus!${NC}"
                        fi
                    fi
                fi
                read -rp "Tekan Enter untuk kembali ke Sub-Menu..."
                ;;
            0|b|B)
                break
                ;;
            *)
                echo -e "${RED}Pilihan tidak valid!${NC}"
                sleep 1
                ;;
        esac
    done
}
