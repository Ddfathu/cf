# MENU_TITLE: 🗃️ Kelola KV Namespace & Binding Worker
# MENU_ACTION: run_kv_module

run_kv_module() {
    echo -e "${BOLD}📌 MANAJEMEN KV NAMESPACE & BINDING:${NC}"
    echo -e "  ${CYAN}[1]${NC} 🆕 Buat KV Namespace Baru"
    echo -e "  ${CYAN}[2]${NC} 🗑️  Hapus KV Namespace"
    echo -e "  ${CYAN}[3]${NC} 🔗 Ikat / Hubungkan KV Binding ke Worker"
    echo -e "  ${CYAN}[4]${NC} ❌ Mencabut / Hapus KV Binding dari Worker"
    echo -e "  ${CYAN}[5]${NC} 📋 Lihat Semua Daftar KV Namespace"
    echo -e "  ${RED}[0]${NC} ↩️  Batal / Kembali"
    read -rp "Pilih [1/2/3/4/5/0]: " KV_CHOICE

    case "$KV_CHOICE" in
        1)
            read -rp "🔤 Nama KV Namespace Baru [0=Batal]: " NEW_KV_NAME
            if [ "$NEW_KV_NAME" != "0" ] && [ -n "$NEW_KV_NAME" ]; then
                CREATE_KV_RES=$(curl -s -X POST "${AUTH_HEADER[@]}" -H "Content-Type: application/json" -d "{\"title\":\"$NEW_KV_NAME\"}" "$BASE_URL/accounts/$ACCOUNT_ID/storage/kv/namespaces")
                if [ "$(echo "$CREATE_KV_RES" | jq -r '.success')" == "true" ]; then
                    echo -e "${GREEN}✅ KV Namespace '$NEW_KV_NAME' Berhasil Dibuat! (ID: $(echo "$CREATE_KV_RES" | jq -r '.result.id'))${NC}"
                else
                    echo -e "${RED}❌ Gagal buat KV:${NC}"
                    echo "$CREATE_KV_RES" | jq -r '.errors[] | "Code: \(.code) - \(.message)"' 2>/dev/null || echo "$CREATE_KV_RES"
                fi
            fi
            ;;
        2)
            KV_JSON=$(curl -s "${AUTH_HEADER[@]}" -H "Content-Type: application/json" "$BASE_URL/accounts/$ACCOUNT_ID/storage/kv/namespaces?page=1&per_page=100")
            echo "$KV_JSON" | jq -r '.result[] | "\(.title) (ID: \(.id))"' | nl -w2 -s') '
            read -rp "Nomor KV yang Mau Dihapus [0=Batal]: " KV_DEL_NUM
            if [ "$KV_DEL_NUM" != "0" ] && [ -n "$KV_DEL_NUM" ]; then
                KV_DEL_ID=$(echo "$KV_JSON" | jq -r ".result[$((KV_DEL_NUM-1))].id")
                KV_DEL_TITLE=$(echo "$KV_JSON" | jq -r ".result[$((KV_DEL_NUM-1))].title")
                read -rp "⚠️ Yakin menghapus KV '$KV_DEL_TITLE'? [y/N]: " CONFIRM_KV
                if [[ "$CONFIRM_KV" =~ ^[Yy] ]]; then
                    curl -s -X DELETE "${AUTH_HEADER[@]}" -H "Content-Type: application/json" "$BASE_URL/accounts/$ACCOUNT_ID/storage/kv/namespaces/$KV_DEL_ID" > /dev/null
                    echo -e "${GREEN}✅ KV Namespace '$KV_DEL_TITLE' Berhasil Dihapus!${NC}"
                fi
            fi
            ;;
        3)
            WORKERS_JSON=$(curl -s "${AUTH_HEADER[@]}" -H "Content-Type: application/json" "$BASE_URL/accounts/$ACCOUNT_ID/workers/services?per_page=100")
            echo "$WORKERS_JSON" | jq -r '.result[] | .id' | nl -w2 -s') '
            read -rp "Pilih Worker Target [0=Batal]: " W_NUM; [ "$W_NUM" == "0" ] && return
            WORKER_NAME=$(echo "$WORKERS_JSON" | jq -r ".result[$((W_NUM-1))].id")

            read -rp "Nama variabel binding (contoh: MY_KV) [0=Batal]: " BINDING_NAME; [ "$BINDING_NAME" == "0" ] && return

            KV_JSON=$(curl -s "${AUTH_HEADER[@]}" -H "Content-Type: application/json" "$BASE_URL/accounts/$ACCOUNT_ID/storage/kv/namespaces?page=1&per_page=100")
            echo "$KV_JSON" | jq -r '.result[] | "\(.title) (ID: \(.id))"' | nl -w2 -s') '
            read -rp "Pilih KV Namespace [0=Batal]: " KV_NUM; [ "$KV_NUM" == "0" ] && return
            KV_ID=$(echo "$KV_JSON" | jq -r ".result[$((KV_NUM-1))].id")

            SETTINGS_URL="$BASE_URL/accounts/$ACCOUNT_ID/workers/services/$WORKER_NAME/environments/production/settings"
            CURRENT_SETTINGS=$(curl -s "${AUTH_HEADER[@]}" -H "Content-Type: application/json" "$SETTINGS_URL")
            EXISTING_BINDINGS=$(echo "$CURRENT_SETTINGS" | jq '.result.bindings // []')

            NEW_BINDING=$(jq -n --arg name "$BINDING_NAME" --arg nsid "$KV_ID" '{type: "kv_namespace", name: $name, namespace_id: $nsid}')
            UPDATED_BINDINGS=$(echo "$EXISTING_BINDINGS" | jq --argjson new "$NEW_BINDING" --arg name "$BINDING_NAME" 'map(select(.name != $name)) + [$new]')

            METADATA_FILE=$(mktemp)
            jq -n --argjson bindings "$UPDATED_BINDINGS" '{bindings: $bindings}' > "$METADATA_FILE"
            UPDATE_RESPONSE=$(curl -s -X PATCH "${AUTH_HEADER[@]}" -F "settings=@$METADATA_FILE;type=application/json" "$SETTINGS_URL")
            rm -f "$METADATA_FILE"

            if echo "$UPDATE_RESPONSE" | jq -e '.success' > /dev/null; then
                echo -e "${GREEN}✅ Variabel 'env.$BINDING_NAME' Sukses Terikat ke Worker '$WORKER_NAME'!${NC}"
            else
                echo -e "${RED}❌ Gagal update binding:${NC}"
                echo "$UPDATE_RESPONSE" | jq -r '.errors[] | "Code: \(.code) - \(.message)"' 2>/dev/null || echo "$UPDATE_RESPONSE"
            fi
            ;;
        4)
            WORKERS_JSON=$(curl -s "${AUTH_HEADER[@]}" -H "Content-Type: application/json" "$BASE_URL/accounts/$ACCOUNT_ID/workers/services?per_page=100")
            echo "$WORKERS_JSON" | jq -r '.result[] | .id' | nl -w2 -s') '
            read -rp "Pilih Worker Target [0=Batal]: " W_NUM; [ "$W_NUM" == "0" ] && return
            WORKER_NAME=$(echo "$WORKERS_JSON" | jq -r ".result[$((W_NUM-1))].id")

            SETTINGS_URL="$BASE_URL/accounts/$ACCOUNT_ID/workers/services/$WORKER_NAME/environments/production/settings"
            CURRENT_SETTINGS=$(curl -s "${AUTH_HEADER[@]}" -H "Content-Type: application/json" "$SETTINGS_URL")
            KV_BINDINGS=$(echo "$CURRENT_SETTINGS" | jq '.result.bindings // [] | map(select(.type == "kv_namespace"))')

            echo "$KV_BINDINGS" | jq -r '.[] | "Variable: env.\(.name) (KV ID: \(.namespace_id))"' | nl -w2 -s') '
            read -rp "Pilih Binding yang Mau Dicabut [0=Batal]: " BIND_DEL_NUM; [ "$BIND_DEL_NUM" == "0" ] && return
            TARGET_BIND_NAME=$(echo "$KV_BINDINGS" | jq -r ".[$((BIND_DEL_NUM-1))].name")

            ALL_BINDINGS=$(echo "$CURRENT_SETTINGS" | jq '.result.bindings // []')
            UPDATED_BINDINGS=$(echo "$ALL_BINDINGS" | jq --arg name "$TARGET_BIND_NAME" 'map(select(.name != $name))')

            METADATA_FILE=$(mktemp)
            jq -n --argjson bindings "$UPDATED_BINDINGS" '{bindings: $bindings}' > "$METADATA_FILE"
            UPDATE_RESPONSE=$(curl -s -X PATCH "${AUTH_HEADER[@]}" -F "settings=@$METADATA_FILE;type=application/json" "$SETTINGS_URL")
            rm -f "$METADATA_FILE"

            if echo "$UPDATE_RESPONSE" | jq -e '.success' > /dev/null; then
                echo -e "${GREEN}✅ Binding 'env.$TARGET_BIND_NAME' Sukses Dicabut dari Worker '$WORKER_NAME'!${NC}"
            else
                echo -e "${RED}❌ Gagal cabut binding:${NC}"
                echo "$UPDATE_RESPONSE" | jq -r '.errors[] | "Code: \(.code) - \(.message)"' 2>/dev/null || echo "$UPDATE_RESPONSE"
            fi
            ;;
        5)
            KV_JSON=$(curl -s "${AUTH_HEADER[@]}" -H "Content-Type: application/json" "$BASE_URL/accounts/$ACCOUNT_ID/storage/kv/namespaces?page=1&per_page=100")
            echo -e "\n📋 DAFTAR KV NAMESPACE AKUN INI:"
            echo "$KV_JSON" | jq -r '.result[] | "🗃️ Title : \(.title)\n🔑 ID    : \(.id)\n------------------------------------------------"'
            ;;
    esac
    read -rp "Tekan Enter untuk kembali..."
}
