# MENU_TITLE: 🌐 Kelola Domain (Zone CF & Custom Domain Worker)
# MENU_ACTION: run_domain_module

run_domain_module() {
    echo -e "${BOLD}📌 MANAJEMEN DOMAIN:${NC}"
    echo -e "  ${CYAN}[1]${NC} 🆕 Daftarkan Domain Baru ke Cloudflare (Zone)"
    echo -e "  ${CYAN}[2]${NC} 🔍 Cek Status Keaktifan & NS Domain CF"
    echo -e "  ${CYAN}[3]${NC} 🔗 Ikat / Tambah Custom Domain ke Worker"
    echo -e "  ${CYAN}[4]${NC} ❌ Cabut / Hapus Custom Domain dari Worker"
    echo -e "  ${RED}[0]${NC} ↩️  Batal / Kembali"
    read -rp "Pilih [1/2/3/4/0]: " DOM_CHOICE

    case "$DOM_CHOICE" in
        1)
            read -rp "🌐 Masukkan Nama Domain Baru [0=Batal]: " NEW_DOMAIN
            if [ "$NEW_DOMAIN" != "0" ] && [ -n "$NEW_DOMAIN" ]; then
                NEW_DOMAIN=$(echo "$NEW_DOMAIN" | sed 's/https:\/\///g; s/http:\/\///g; s/\///g' | tr '[:upper:]' '[:lower:]')
                ADD_ZONE_RES=$(curl -s -X POST "${AUTH_HEADER[@]}" -H "Content-Type: application/json" -d "{\"account\":{\"id\":\"$ACCOUNT_ID\"},\"name\":\"$NEW_DOMAIN\",\"jump_start\":true}" "$BASE_URL/zones")
                if [ "$(echo "$ADD_ZONE_RES" | jq -r '.success')" == "true" ]; then
                    NS1=$(echo "$ADD_ZONE_RES" | jq -r '.result.name_servers[0]')
                    NS2=$(echo "$ADD_ZONE_RES" | jq -r '.result.name_servers[1]')
                    echo -e "${GREEN}✅ Domain '$NEW_DOMAIN' Berhasil Didaftarkan!${NC}"
                    echo -e "📢 WAJIB PASANG NS DI REGISTRAR:\n 1. $NS1\n 2. $NS2"
                else
                    echo -e "${RED}❌ Gagal daftarkan domain:${NC}"
                    echo "$ADD_ZONE_RES" | jq -r '.errors[] | "Code: \(.code) - \(.message)"' 2>/dev/null || echo "$ADD_ZONE_RES"
                fi
            fi
            ;;
        2)
            ZONES_JSON=$(curl -s "${AUTH_HEADER[@]}" -H "Content-Type: application/json" "$BASE_URL/zones?account.id=$ACCOUNT_ID&per_page=50")
            ZONE_COUNT=$(echo "$ZONES_JSON" | jq '.result | length')
            echo -e "\n📋 STATUS KEAKTIFAN DOMAIN AKUN INI:"
            for (( idx=0; idx<ZONE_COUNT; idx++ )); do
                DNAME=$(echo "$ZONES_JSON" | jq -r ".result[$idx].name")
                DSTATUS=$(echo "$ZONES_JSON" | jq -r ".result[$idx].status")
                DNS1=$(echo "$ZONES_JSON" | jq -r ".result[$idx].name_servers[0]")
                DNS2=$(echo "$ZONES_JSON" | jq -r ".result[$idx].name_servers[1]")
                [ "$DSTATUS" == "active" ] && S_LABEL="${GREEN}🟢 ACTIVE${NC}" || S_LABEL="${YELLOW}🟡 PENDING / UNVERIFIED${NC}"
                echo -e "🌐 Domain: ${CYAN}$DNAME${NC} | Status: $S_LABEL | NS: $DNS1, $DNS2"
            done
            ;;
        3)
            WORKERS_JSON=$(curl -s "${AUTH_HEADER[@]}" -H "Content-Type: application/json" "$BASE_URL/accounts/$ACCOUNT_ID/workers/services?per_page=100")
            echo "$WORKERS_JSON" | jq -r '.result[] | .id' | nl -w2 -s') '
            read -rp "Pilih Worker Target [0=Batal]: " W_NUM; [ "$W_NUM" == "0" ] && return
            TARGET_WORKER_NAME=$(echo "$WORKERS_JSON" | jq -r ".result[$((W_NUM-1))].id")

            ZONES_JSON=$(curl -s "${AUTH_HEADER[@]}" -H "Content-Type: application/json" "$BASE_URL/zones?account.id=$ACCOUNT_ID&per_page=50")
            echo "$ZONES_JSON" | jq -r '.result[] | .name' | nl -w2 -s') '
            read -rp "Pilih Domain Utama [0=Batal]: " Z_NUM; [ "$Z_NUM" == "0" ] && return
            SELECTED_DOMAIN=$(echo "$ZONES_JSON" | jq -r ".result[$((Z_NUM-1))].name")
            SELECTED_ZONE_ID=$(echo "$ZONES_JSON" | jq -r ".result[$((Z_NUM-1))].id")

            read -rp "Subdomain [Ketik '-' jika root, 0=Batal]: " SUB_INPUT; [ "$SUB_INPUT" == "0" ] && return
            [ "$SUB_INPUT" == "-" ] && FULL_HOSTNAME="$SELECTED_DOMAIN" || FULL_HOSTNAME="${SUB_INPUT}.${SELECTED_DOMAIN}"

            ADD_DOM_RES=$(curl -s -X PUT "${AUTH_HEADER[@]}" -H "Content-Type: application/json" -d "{\"environment\":\"production\",\"hostname\":\"$FULL_HOSTNAME\",\"service\":\"$TARGET_WORKER_NAME\",\"zone_id\":\"$SELECTED_ZONE_ID\"}" "$BASE_URL/accounts/$ACCOUNT_ID/workers/domains")
            if [ "$(echo "$ADD_DOM_RES" | jq -r '.success')" == "true" ]; then
                echo -e "${GREEN}✅ Custom Domain https://$FULL_HOSTNAME Berhasil Terikat ke Worker '$TARGET_WORKER_NAME'!${NC}"
            else
                echo -e "${RED}❌ Gagal:${NC}"
                echo "$ADD_DOM_RES" | jq -r '.errors[] | "Code: \(.code) - \(.message)"' 2>/dev/null || echo "$ADD_DOM_RES"
            fi
            ;;
        4)
            DOMAINS_JSON=$(curl -s "${AUTH_HEADER[@]}" -H "Content-Type: application/json" "$BASE_URL/accounts/$ACCOUNT_ID/workers/domains")
            echo "$DOMAINS_JSON" | jq -r '.result[] | "\(.hostname) (Worker: \(.service))"' | nl -w2 -s') '
            read -rp "Pilih Domain yang Mau Dicabut [0=Batal]: " D_NUM; [ "$D_NUM" == "0" ] && return
            TARGET_DOM_ID=$(echo "$DOMAINS_JSON" | jq -r ".result[$((D_NUM-1))].id")
            TARGET_DOM_HOST=$(echo "$DOMAINS_JSON" | jq -r ".result[$((D_NUM-1))].hostname")

            DEL_DOM_RES=$(curl -s -X DELETE "${AUTH_HEADER[@]}" -H "Content-Type: application/json" "$BASE_URL/accounts/$ACCOUNT_ID/workers/domains/$TARGET_DOM_ID")
            IS_SUCCESS=$(echo "$DEL_DOM_RES" | jq -r '.success // false')
            if [ "$IS_SUCCESS" == "true" ] || ! echo "$DEL_DOM_RES" | grep -q "error"; then
                echo -e "${GREEN}✅ Domain '$TARGET_DOM_HOST' Berhasil Dicabut dari Worker!${NC}"
            else
                echo -e "${RED}❌ Gagal cabut domain:${NC}"
                echo "$DEL_DOM_RES" | jq -r '.errors[] | "Code: \(.code) - \(.message)"' 2>/dev/null || echo "$DEL_DOM_RES"
            fi
            ;;
    esac
    read -rp "Tekan Enter untuk kembali..."
}
