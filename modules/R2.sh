# MENU_TITLE: 📦 Kelola Cloudflare R2 Bucket & Binding Worker
# MENU_ACTION: run_r2_module

run_r2_module() {
    while true; do
        clear
        echo -e "${CYAN}================================================================${NC}"
        echo -e "${BOLD}📌 SUB-MENU MANAJEMEN R2 OBJECT STORAGE:${NC}"
        echo -e "${CYAN}----------------------------------------------------------------${NC}"
        echo -e "  ${CYAN}[1]${NC} 🆕 Buat R2 Bucket Baru"
        echo -e "  ${CYAN}[2]${NC} 🗑️  Hapus R2 Bucket"
        echo -e "  ${CYAN}[3]${NC} 🔗 Ikat / Hubungkan R2 Bucket Binding ke Worker"
        echo -e "  ${CYAN}[4]${NC} ❌ Cabut / Hapus R2 Bucket Binding dari Worker"
        echo -e "  ${CYAN}[5]${NC} 📋 Lihat Semua Daftar R2 Bucket"
        echo -e "  ${RED}[0]${NC} ↩️  Kembali ke Menu Utama"
        echo -e "${CYAN}----------------------------------------------------------------${NC}"
        read -rp "Pilih [1/2/3/4/5/0]: " R2_CHOICE

        case "$R2_CHOICE" in
            1)
                read -rp "📦 Masukkan Nama R2 Bucket Baru [0=Batal]: " NEW_BUCKET_NAME
                if [ "$NEW_BUCKET_NAME" != "0" ] && [ -n "$NEW_BUCKET_NAME" ]; then
                    NEW_BUCKET_NAME=$(echo "$NEW_BUCKET_NAME" | sed 's/[^-a-zA-Z0-9_]//g' | tr '[:upper:]' '[:lower:]')
                    echo -e "${YELLOW}⏳ Membuat R2 Bucket '$NEW_BUCKET_NAME'...${NC}"
                    CREATE_R2_RES=$(curl -s -X POST "${AUTH_HEADER[@]}" -H "Content-Type: application/json" -d "{\"name\":\"$NEW_BUCKET_NAME\"}" "$BASE_URL/accounts/$ACCOUNT_ID/r2/buckets")

                    if [ "$(echo "$CREATE_R2_RES" | jq -r '.success')" == "true" ]; then
                        echo -e "${GREEN}🎉 BERHASIL! R2 Bucket '$NEW_BUCKET_NAME' sukses dibuat!${NC}"
                    else
                        echo -e "${RED}❌ Gagal membuat R2 Bucket:${NC}"
                        echo "$CREATE_R2_RES" | jq -r '.errors[] | "Code: \(.code) - \(.message)"' 2>/dev/null || echo "$CREATE_R2_RES"
                    fi
                fi
                read -rp "Tekan Enter untuk kembali ke Sub-Menu..."
                ;;

            2)
                echo -e "${YELLOW}📦 Mengambil daftar R2 Bucket...${NC}"
                R2_JSON=$(curl -s "${AUTH_HEADER[@]}" -H "Content-Type: application/json" "$BASE_URL/accounts/$ACCOUNT_ID/r2/buckets")
                R2_COUNT=$(echo "$R2_JSON" | jq '.result.buckets | length')

                if [ -z "$R2_COUNT" ] || [ "$R2_COUNT" -eq 0 ]; then
                    echo -e "${RED}❌ Tidak ada R2 Bucket ditemukan di akun ini.${NC}"
                else
                    echo -e "\n${BOLD}Pilih R2 Bucket yang Mau DIHAPUS:${NC}"
                    echo "$R2_JSON" | jq -r '.result.buckets[] | .name' | nl -w2 -s') '
                    read -rp "Nomor Bucket [0=Batal]: " R2_DEL_NUM

                    if [ "$R2_DEL_NUM" != "0" ] && [ -n "$R2_DEL_NUM" ]; then
                        TARGET_BUCKET=$(echo "$R2_JSON" | jq -r ".result.buckets[$((R2_DEL_NUM-1))].name")
                        read -rp "⚠️ Yakin menghapus R2 Bucket '$TARGET_BUCKET'? [y/N]: " CONFIRM_R2_DEL
                        if [[ "$CONFIRM_R2_DEL" =~ ^[Yy] ]]; then
                            echo -e "${YELLOW}🗑️ Menghapus R2 Bucket '$TARGET_BUCKET'...${NC}"
                            DEL_R2_RES=$(curl -s -X DELETE "${AUTH_HEADER[@]}" -H "Content-Type: application/json" "$BASE_URL/accounts/$ACCOUNT_ID/r2/buckets/$TARGET_BUCKET")

                            if [ "$(echo "$DEL_R2_RES" | jq -r '.success')" == "true" ]; then
                                echo -e "${GREEN}✅ R2 Bucket '$TARGET_BUCKET' Berhasil Dihapus Permanen!${NC}"
                            else
                                echo -e "${RED}❌ Gagal menghapus R2 Bucket:${NC}"
                                echo "$DEL_R2_RES" | jq -r '.errors[] | "Code: \(.code) - \(.message)"' 2>/dev/null || echo "$DEL_R2_RES"
                            fi
                        fi
                    fi
                fi
                read -rp "Tekan Enter untuk kembali ke Sub-Menu..."
                ;;

            3)
                echo -e "${YELLOW}📜 Mengambil daftar worker...${NC}"
                WORKERS_JSON=$(curl -s "${AUTH_HEADER[@]}" -H "Content-Type: application/json" "$BASE_URL/accounts/$ACCOUNT_ID/workers/services?per_page=100")
                WORKER_COUNT=$(echo "$WORKERS_JSON" | jq '.result | length')

                if [ -z "$WORKER_COUNT" ] || [ "$WORKER_COUNT" -eq 0 ]; then
                    echo -e "${RED}❌ Tidak ada worker ditemukan di akun ini.${NC}"
                else
                    echo -e "\n${BOLD}Pilih Worker Target:${NC}"
                    echo "$WORKERS_JSON" | jq -r '.result[] | .id' | nl -w2 -s') '
                    read -rp "Pilih Worker Target [0=Batal]: " W_NUM
                    
                    if [ "$W_NUM" != "0" ] && [ -n "$W_NUM" ]; then
                        WORKER_NAME=$(echo "$WORKERS_JSON" | jq -r ".result[$((W_NUM-1))].id")
                        read -rp "🔤 Nama variabel binding (contoh: MY_BUCKET) [0=Batal]: " BINDING_NAME

                        if [ "$BINDING_NAME" != "0" ] && [ -n "$BINDING_NAME" ]; then
                            echo -e "\n${YELLOW}📦 Mengambil daftar R2 Bucket...${NC}"
                            R2_JSON=$(curl -s "${AUTH_HEADER[@]}" -H "Content-Type: application/json" "$BASE_URL/accounts/$ACCOUNT_ID/r2/buckets")
                            echo "$R2_JSON" | jq -r '.result.buckets[] | .name' | nl -w2 -s') '
                            read -rp "Pilih Bucket [0=Batal]: " R2_NUM

                            if [ "$R2_NUM" != "0" ] && [ -n "$R2_NUM" ]; then
                                BUCKET_NAME=$(echo "$R2_JSON" | jq -r ".result.buckets[$((R2_NUM-1))].name")
                                SETTINGS_URL="$BASE_URL/accounts/$ACCOUNT_ID/workers/services/$WORKER_NAME/environments/production/settings"
                                CURRENT_SETTINGS=$(curl -s "${AUTH_HEADER[@]}" -H "Content-Type: application/json" "$SETTINGS_URL")
                                EXISTING_BINDINGS=$(echo "$CURRENT_SETTINGS" | jq '.result.bindings // []')

                                NEW_BINDING=$(jq -n --arg name "$BINDING_NAME" --arg bname "$BUCKET_NAME" '{type: "r2_bucket", name: $name, bucket_name: $bname}')
                                UPDATED_BINDINGS=$(echo "$EXISTING_BINDINGS" | jq --argjson new "$NEW_BINDING" --arg name "$BINDING_NAME" 'map(select(.name != $name)) + [$new]')

                                METADATA_FILE=$(mktemp)
                                jq -n --argjson bindings "$UPDATED_BINDINGS" '{bindings: $bindings}' > "$METADATA_FILE"
                                UPDATE_RESPONSE=$(curl -s -X PATCH "${AUTH_HEADER[@]}" -F "settings=@$METADATA_FILE;type=application/json" "$SETTINGS_URL")
                                rm -f "$METADATA_FILE"

                                if echo "$UPDATE_RESPONSE" | jq -e '.success' > /dev/null; then
                                    echo -e "${GREEN}🎉 BERHASIL! Variabel 'env.$BINDING_NAME' terikat ke R2 Bucket '$BUCKET_NAME'!${NC}"
                                else
                                    echo -e "${RED}❌ Gagal update binding R2:${NC}"
                                    echo "$UPDATE_RESPONSE" | jq -r '.errors[] | "Code: \(.code) - \(.message)"' 2>/dev/null || echo "$UPDATE_RESPONSE"
                                fi
                            fi
                        fi
                    fi
                fi
                read -rp "Tekan Enter untuk kembali ke Sub-Menu..."
                ;;

            4)
                echo -e "${YELLOW}📜 Mengambil daftar worker...${NC}"
                WORKERS_JSON=$(curl -s "${AUTH_HEADER[@]}" -H "Content-Type: application/json" "$BASE_URL/accounts/$ACCOUNT_ID/workers/services?per_page=100")
                echo "$WORKERS_JSON" | jq -r '.result[] | .id' | nl -w2 -s') '
                read -rp "Pilih Worker Target [0=Batal]: " W_NUM

                if [ "$W_NUM" != "0" ] && [ -n "$W_NUM" ]; then
                    WORKER_NAME=$(echo "$WORKERS_JSON" | jq -r ".result[$((W_NUM-1))].id")
                    SETTINGS_URL="$BASE_URL/accounts/$ACCOUNT_ID/workers/services/$WORKER_NAME/environments/production/settings"
                    CURRENT_SETTINGS=$(curl -s "${AUTH_HEADER[@]}" -H "Content-Type: application/json" "$SETTINGS_URL")
                    R2_BINDINGS=$(echo "$CURRENT_SETTINGS" | jq '.result.bindings // [] | map(select(.type == "r2_bucket"))')
                    R2_BIND_COUNT=$(echo "$R2_BINDINGS" | jq 'length')

                    if [ -z "$R2_BIND_COUNT" ] || [ "$R2_BIND_COUNT" -eq 0 ]; then
                        echo -e "${RED}❌ Worker '$WORKER_NAME' tidak memiliki binding R2 Bucket sama sekali.${NC}"
                    else
                        echo -e "\n${BOLD}Pilih Binding R2 yang Mau DICABUT:${NC}"
                        echo "$R2_BINDINGS" | jq -r '.[] | "Variable: env.\(.name) (Target Bucket: \(.bucket_name))"' | nl -w2 -s') '
                        read -rp "Pilih Binding [0=Batal]: " BIND_DEL_NUM

                        if [ "$BIND_DEL_NUM" != "0" ] && [ -n "$BIND_DEL_NUM" ]; then
                            TARGET_BIND_NAME=$(echo "$R2_BINDINGS" | jq -r ".[$((BIND_DEL_NUM-1))].name")
                            ALL_BINDINGS=$(echo "$CURRENT_SETTINGS" | jq '.result.bindings // []')
                            UPDATED_BINDINGS=$(echo "$ALL_BINDINGS" | jq --arg name "$TARGET_BIND_NAME" 'map(select(.name != $name))')

                            METADATA_FILE=$(mktemp)
                            jq -n --argjson bindings "$UPDATED_BINDINGS" '{bindings: $bindings}' > "$METADATA_FILE"
                            UPDATE_RESPONSE=$(curl -s -X PATCH "${AUTH_HEADER[@]}" -F "settings=@$METADATA_FILE;type=application/json" "$SETTINGS_URL")
                            rm -f "$METADATA_FILE"

                            if echo "$UPDATE_RESPONSE" | jq -e '.success' > /dev/null; then
                                echo -e "${GREEN}✅ R2 Binding 'env.$TARGET_BIND_NAME' Sukses Dicabut!${NC}"
                            else
                                echo -e "${RED}❌ Gagal cabut binding R2:${NC}"
                                echo "$UPDATE_RESPONSE" | jq -r '.errors[] | "Code: \(.code) - \(.message)"' 2>/dev/null || echo "$UPDATE_RESPONSE"
                            fi
                        fi
                    fi
                fi
                read -rp "Tekan Enter untuk kembali ke Sub-Menu..."
                ;;

            5)
                echo -e "${YELLOW}📦 Mengambil daftar R2 Bucket...${NC}"
                R2_JSON=$(curl -s "${AUTH_HEADER[@]}" -H "Content-Type: application/json" "$BASE_URL/accounts/$ACCOUNT_ID/r2/buckets")
                R2_COUNT=$(echo "$R2_JSON" | jq '.result.buckets | length')

                if [ -z "$R2_COUNT" ] || [ "$R2_COUNT" -eq 0 ]; then
                    echo -e "${RED}❌ Tidak ada R2 Bucket terdaftar di akun ini.${NC}"
                else
                    echo -e "\n📋 ${BOLD}DAFTAR R2 BUCKET AKUN INI ($R2_COUNT total):${NC}"
                    echo -e "${CYAN}----------------------------------------------------------------${NC}"
                    echo "$R2_JSON" | jq -r '.result.buckets[] | "📦 Name         : \(.name)\n📅 Created Date : \(.creation_date)\n------------------------------------------------"'
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
