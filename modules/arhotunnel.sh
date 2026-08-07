# MENU_TITLE: 🚀 Kelola Cloudflare Argo Tunnel & Ingress Routing
# MENU_ACTION: run_tunnel_module

run_tunnel_module() {
    echo -e "${BOLD}📌 MANAJEMEN CLOUDFLARE ARGO TUNNEL:${NC}"
    echo -e "  ${CYAN}[1]${NC} 🆕 Buat Tunnel Argo Baru"
    echo -e "  ${CYAN}[2]${NC} 🔀 Atur Routing Domain ke Port (+Auto CNAME DNS)"
    echo -e "  ${CYAN}[3]${NC} 📋 Cek Status Tunnel, Token & Daftar Routing"
    echo -e "  ${CYAN}[4]${NC} ✏️  Edit Port / Protocol Routing Ingress"
    echo -e "  ${CYAN}[5]${NC} 🔥 Hapus Routing Domain (+Auto Hapus CNAME DNS)"
    echo -e "  ${RED}[0]${NC} ↩️  Batal / Kembali"
    read -rp "Pilih [1/2/3/4/5/0]: " TUN_CHOICE

    case "$TUN_CHOICE" in
        1)
            read -rp "🚀 Nama Tunnel Baru [0=Batal]: " TUNNEL_NAME
            if [ "$TUNNEL_NAME" != "0" ] && [ -n "$TUNNEL_NAME" ]; then
                TUNNEL_SECRET=$(openssl rand -base64 32 2>/dev/null || date +%s%N | sha256sum | head -c 32 | base64)
                CREATE_RES=$(curl -s -X POST "${AUTH_HEADER[@]}" -H "Content-Type: application/json" -d "{\"name\":\"$TUNNEL_NAME\", \"tunnel_secret\":\"$TUNNEL_SECRET\", \"config_src\":\"cloudflare\"}" "$BASE_URL/accounts/$ACCOUNT_ID/cfd_tunnel")
                if [ "$(echo "$CREATE_RES" | jq -r '.success')" == "true" ]; then
                    TUNNEL_ID=$(echo "$CREATE_RES" | jq -r '.result.id')
                    TOKEN_RES=$(curl -s "${AUTH_HEADER[@]}" -H "Content-Type: application/json" "$BASE_URL/accounts/$ACCOUNT_ID/cfd_tunnel/$TUNNEL_ID/token")
                    echo -e "${GREEN}✅ Argo Tunnel '$TUNNEL_NAME' Berhasil Dibuat!${NC}"
                    echo -e "🔑 TOKEN: ${CYAN}$(echo "$TOKEN_RES" | jq -r '.result // empty')${NC}"
                else
                    echo -e "${RED}❌ Gagal buat tunnel:${NC}"
                    echo "$CREATE_RES" | jq -r '.errors[] | "Code: \(.code) - \(.message)"' 2>/dev/null || echo "$CREATE_RES"
                fi
            fi
            ;;
        2)
            TUNNELS_JSON=$(curl -s "${AUTH_HEADER[@]}" -H "Content-Type: application/json" "$BASE_URL/accounts/$ACCOUNT_ID/cfd_tunnel?is_deleted=false")
            echo "$TUNNELS_JSON" | jq -r '.result[] | "\(.name) (ID: \(.id))"' | nl -w2 -s') '
            read -rp "Pilih Tunnel Target [0=Batal]: " T_NUM; [ "$T_NUM" == "0" ] && return
            TUNNEL_ID=$(echo "$TUNNELS_JSON" | jq -r ".result[$((T_NUM-1))].id")

            ZONES_JSON=$(curl -s "${AUTH_HEADER[@]}" -H "Content-Type: application/json" "$BASE_URL/zones?account.id=$ACCOUNT_ID&per_page=50")
            echo "$ZONES_JSON" | jq -r '.result[] | .name' | nl -w2 -s') '
            read -rp "Pilih Domain Utama [0=Batal]: " Z_NUM; [ "$Z_NUM" == "0" ] && return
            SELECTED_DOMAIN=$(echo "$ZONES_JSON" | jq -r ".result[$((Z_NUM-1))].name")
            SELECTED_ZONE_ID=$(echo "$ZONES_JSON" | jq -r ".result[$((Z_NUM-1))].id")

            read -rp "Subdomain [Ketik '-' jika root, 0=Batal]: " SUB_INPUT; [ "$SUB_INPUT" == "0" ] && return
            [ "$SUB_INPUT" == "-" ] && FULL_HOSTNAME="$SELECTED_DOMAIN" || FULL_HOSTNAME="${SUB_INPUT}.${SELECTED_DOMAIN}"

            read -rp "Port Lokal Application (contoh: 8080 / 8880) [0=Batal]: " PORT_INPUT; [ "$PORT_INPUT" == "0" ] && return
            read -rp "Protokol [http/https/tcp/ssh] (Default: http): " SCHEME_INPUT
            SCHEME_INPUT=${SCHEME_INPUT:-http}
            TARGET_URL="${SCHEME_INPUT}://localhost:${PORT_INPUT}"

            CONFIG_URL="$BASE_URL/accounts/$ACCOUNT_ID/cfd_tunnel/$TUNNEL_ID/configurations"
            CURRENT_CONFIG=$(curl -s "${AUTH_HEADER[@]}" -H "Content-Type: application/json" "$CONFIG_URL")
            EXISTING_INGRESS=$(echo "$CURRENT_CONFIG" | jq '.result.config.ingress // []')

            FILTERED_INGRESS=$(echo "$EXISTING_INGRESS" | jq --arg host "$FULL_HOSTNAME" 'map(select(.hostname != $host and .service != "http_status:404"))')
            NEW_RULE=$(jq -n --arg host "$FULL_HOSTNAME" --arg service "$TARGET_URL" '{hostname: $host, service: $service}')
            CATCH_ALL_RULE=$(jq -n '{service: "http_status:404"}')
            UPDATED_INGRESS=$(echo "$FILTERED_INGRESS" | jq --argjson new "$NEW_RULE" --argjson catchall "$CATCH_ALL_RULE" '. + [$new, $catchall]')

            curl -s -X PUT "${AUTH_HEADER[@]}" -H "Content-Type: application/json" -d "{\"config\":{\"ingress\": $UPDATED_INGRESS}}" "$CONFIG_URL" > /dev/null

            CNAME_TARGET="${TUNNEL_ID}.cfargotunnel.com"
            DNS_CHECK=$(curl -s "${AUTH_HEADER[@]}" -H "Content-Type: application/json" "$BASE_URL/zones/$SELECTED_ZONE_ID/dns_records?name=$FULL_HOSTNAME&type=CNAME")
            EXISTING_DNS_ID=$(echo "$DNS_CHECK" | jq -r '.result[0].id // empty')

            if [ -n "$EXISTING_DNS_ID" ]; then
                curl -s -X PUT "${AUTH_HEADER[@]}" -H "Content-Type: application/json" -d "{\"type\":\"CNAME\",\"name\":\"$FULL_HOSTNAME\",\"content\":\"$CNAME_TARGET\",\"ttl\":1,\"proxied\":true}" "$BASE_URL/zones/$SELECTED_ZONE_ID/dns_records/$EXISTING_DNS_ID" > /dev/null
            else
                curl -s -X POST "${AUTH_HEADER[@]}" -H "Content-Type: application/json" -d "{\"type\":\"CNAME\",\"name\":\"$FULL_HOSTNAME\",\"content\":\"$CNAME_TARGET\",\"ttl\":1,\"proxied\":true}" "$BASE_URL/zones/$SELECTED_ZONE_ID/dns_records" > /dev/null
            fi
            echo -e "${GREEN}✅ Route & DNS CNAME https://$FULL_HOSTNAME Berhasil Dibuat ke $TARGET_URL!${NC}"
            ;;
        3)
            TUNNELS_JSON=$(curl -s "${AUTH_HEADER[@]}" -H "Content-Type: application/json" "$BASE_URL/accounts/$ACCOUNT_ID/cfd_tunnel?is_deleted=false")
            echo "$TUNNELS_JSON" | jq -r '.result[] | "\(.name) (ID: \(.id))"' | nl -w2 -s') '
            read -rp "Pilih Tunnel [0=Batal]: " T_NUM; [ "$T_NUM" == "0" ] && return
            TUNNEL_ITEM=$(echo "$TUNNELS_JSON" | jq -r ".result[$((T_NUM-1))]")
            TUNNEL_ID=$(echo "$TUNNEL_ITEM" | jq -r '.id')
            TUNNEL_NAME=$(echo "$TUNNEL_ITEM" | jq -r '.name')
            TUNNEL_STATUS_RAW=$(echo "$TUNNEL_ITEM" | jq -r '.status')

            [ "$TUNNEL_STATUS_RAW" == "healthy" ] && S_DISP="${GREEN}🟢 ONLINE${NC}" || S_DISP="${RED}🔴 OFFLINE ($TUNNEL_STATUS_RAW)${NC}"
            echo -e "\n📌 TUNNEL: $TUNNEL_NAME | Status: $S_DISP"

            CURRENT_CONFIG=$(curl -s "${AUTH_HEADER[@]}" -H "Content-Type: application/json" "$BASE_URL/accounts/$ACCOUNT_ID/cfd_tunnel/$TUNNEL_ID/configurations")
            echo -e "📋 ROUTING TERPASANG:"
            echo "$CURRENT_CONFIG" | jq -r '.result.config.ingress // [] | map(select(.service != "http_status:404")) | .[] | " 🌐 https://\(.hostname) -> \(.service)"'
            ;;
        4|5)
            TUNNELS_JSON=$(curl -s "${AUTH_HEADER[@]}" -H "Content-Type: application/json" "$BASE_URL/accounts/$ACCOUNT_ID/cfd_tunnel?is_deleted=false")
            echo "$TUNNELS_JSON" | jq -r '.result[] | "\(.name) (ID: \(.id))"' | nl -w2 -s') '
            read -rp "Pilih Tunnel [0=Batal]: " T_NUM; [ "$T_NUM" == "0" ] && return
            TUNNEL_ID=$(echo "$TUNNELS_JSON" | jq -r ".result[$((T_NUM-1))].id")

            CONFIG_URL="$BASE_URL/accounts/$ACCOUNT_ID/cfd_tunnel/$TUNNEL_ID/configurations"
            CURRENT_CONFIG=$(curl -s "${AUTH_HEADER[@]}" -H "Content-Type: application/json" "$CONFIG_URL")
            VALID_INGRESS=$(echo "$CURRENT_CONFIG" | jq '.result.config.ingress // [] | map(select(.service != "http_status:404"))')

            echo "$VALID_INGRESS" | jq -r '.[] | "\(.hostname) -> \(.service)"' | nl -w2 -s') '
            read -rp "Pilih Routing Domain [0=Batal]: " R_NUM; [ "$R_NUM" == "0" ] && return
            SELECTED_RULE=$(echo "$VALID_INGRESS" | jq -r ".[$((R_NUM-1))]")
            EDIT_HOSTNAME=$(echo "$SELECTED_RULE" | jq -r '.hostname')

            if [ "$TUN_CHOICE" == "4" ]; then
                read -rp "Port Lokal Baru [0=Batal]: " NEW_PORT; [ "$NEW_PORT" == "0" ] && return
                read -rp "Protokol Baru [http/https/tcp/ssh]: " NEW_SCHEME; NEW_SCHEME=${NEW_SCHEME:-http}
                NEW_SERVICE="${NEW_SCHEME}://localhost:${NEW_PORT}"

                ALL_INGRESS=$(echo "$CURRENT_CONFIG" | jq '.result.config.ingress // []')
                UPDATED_INGRESS=$(echo "$ALL_INGRESS" | jq --arg host "$EDIT_HOSTNAME" --arg new_svc "$NEW_SERVICE" 'map(if .hostname == $host then .service = $new_svc else . end)')
                curl -s -X PUT "${AUTH_HEADER[@]}" -H "Content-Type: application/json" -d "{\"config\":{\"ingress\": $UPDATED_INGRESS}}" "$CONFIG_URL" > /dev/null
                echo -e "${GREEN}✅ Routing https://$EDIT_HOSTNAME Diubah ke $NEW_SERVICE!${NC}"
            else
                ALL_INGRESS=$(echo "$CURRENT_CONFIG" | jq '.result.config.ingress // []')
                UPDATED_INGRESS=$(echo "$ALL_INGRESS" | jq --arg host "$EDIT_HOSTNAME" 'map(select(.hostname != $host))')
                curl -s -X PUT "${AUTH_HEADER[@]}" -H "Content-Type: application/json" -d "{\"config\":{\"ingress\": $UPDATED_INGRESS}}" "$CONFIG_URL" > /dev/null
                echo -e "${GREEN}✅ Routing https://$EDIT_HOSTNAME Berhasil Dihapus!${NC}"
            fi
            ;;
    esac
    read -rp "Tekan Enter untuk kembali..."
}
