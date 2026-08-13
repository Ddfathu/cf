# MENU_TITLE: 🌐 Kelola Zone Domain CF (Daftar / DNS Record / Status NS)
# MENU_ACTION: run_domain_module

add_dns_record_flow() {
    clear
    echo -e "${CYAN}====== TAMBAH DNS RECORD ======${NC}\n"

    ZONES_JSON=$(curl -s "${AUTH_HEADER[@]}" -H "Content-Type: application/json" "$BASE_URL/zones?account.id=$ACCOUNT_ID&per_page=50" || echo "")
    ZONE_COUNT=$(echo "$ZONES_JSON" | jq '.result | length' 2>/dev/null || echo "0")

    if [ "$ZONE_COUNT" -eq 0 ] || [ "$ZONE_COUNT" == "null" ]; then
        echo -e "${YELLOW}⚠️ Tidak ada domain terdaftar di akun ini.${NC}"
        return
    fi

    echo -e "${WHITE}📌 Pilih Domain Utama:${NC}"
    echo "$ZONES_JSON" | jq -r '.result[] | .name' | nl -w2 -s') '
    echo -e "  ${RED}[0] Batal${NC}"
    echo ""
    read -rp "Pilih Nomor Domain: " Z_NUM

    if [ "$Z_NUM" == "0" ] || ! [[ "$Z_NUM" =~ ^[0-9]+$ ]] || [ "$Z_NUM" -gt "$ZONE_COUNT" ]; then
        return
    fi

    SELECTED_DOMAIN=$(echo "$ZONES_JSON" | jq -r ".result[$((Z_NUM-1))].name")
    SELECTED_ZONE_ID=$(echo "$ZONES_JSON" | jq -r ".result[$((Z_NUM-1))].id")

    echo ""
    read -rp "📝 Masukkan Subdomain (ketik '@' atau '-' untuk root domain) [0=Batal]: " SUB_INPUT
    if [ "$SUB_INPUT" == "0" ] || [ -z "$SUB_INPUT" ]; then return; fi

    if [ "$SUB_INPUT" == "@" ] || [ "$SUB_INPUT" == "-" ]; then
        FULL_NAME="$SELECTED_DOMAIN"
    else
        FULL_NAME="${SUB_INPUT}.${SELECTED_DOMAIN}"
    fi

    echo -e "\n${WHITE}📌 Pilih Tipe DNS Record:${NC}"
    echo -e "  ${CYAN}[1]${NC} A (IPv4)"
    echo -e "  ${CYAN}[2]${NC} CNAME (Alias)"
    echo -e "  ${CYAN}[3]${NC} MX (Mail Exchange)"
    echo -e "  ${CYAN}[4]${NC} NS (Name Server)"
    echo -e "  ${CYAN}[5]${NC} TXT (Text Record)"
    echo -e "  ${CYAN}[6]${NC} AAAA (IPv6)"
    echo -e "  ${RED}[0]${NC} Batal"
    read -rp "Pilih Tipe [1-6/0]: " TYPE_CHOICE

    case "$TYPE_CHOICE" in
        1) REC_TYPE="A" ;;
        2) REC_TYPE="CNAME" ;;
        3) REC_TYPE="MX" ;;
        4) REC_TYPE="NS" ;;
        5) REC_TYPE="TXT" ;;
        6) REC_TYPE="AAAA" ;;
        *) return ;;
    esac

    echo ""
    read -rp "🎯 Masukkan Value / Isi Record ($REC_TYPE) [0=Batal]: " REC_CONTENT
    if [ "$REC_CONTENT" == "0" ] || [ -z "$REC_CONTENT" ]; then return; fi

    PROXIED=false
    PRIORITY=10

    if [ "$REC_TYPE" == "A" ] || [ "$REC_TYPE" == "CNAME" ] || [ "$REC_TYPE" == "AAAA" ]; then
        read -rp "⚡ Aktifkan Cloudflare Proxy (CDN/WAF)? [y/N]: " PROXY_CHOICE
        if [[ "$PROXY_CHOICE" =~ ^[Yy] ]]; then
            PROXIED=true
        fi
    elif [ "$REC_TYPE" == "MX" ]; then
        read -rp "🔢 Masukkan Priority MX [Default: 10]: " PRIO_INPUT
        if [[ "$PRIO_INPUT" =~ ^[0-9]+$ ]]; then
            PRIORITY=$PRIO_INPUT
        fi
    fi

    echo -e "\n${YELLOW}⏳ Menambahkan record $REC_TYPE $FULL_NAME -> $REC_CONTENT...${NC}"
    
    PAYLOAD=$(jq -n \
        --arg type "$REC_TYPE" \
        --arg name "$FULL_NAME" \
        --arg content "$REC_CONTENT" \
        --argjson proxied "$PROXIED" \
        --argjson priority "$PRIORITY" \
        '{type: $type, name: $name, content: $content, ttl: 1, proxied: $proxied, priority: $priority}')

    ADD_REC_RES=$(curl -s -X POST "${AUTH_HEADER[@]}" -H "Content-Type: application/json" -d "$PAYLOAD" "$BASE_URL/zones/$SELECTED_ZONE_ID/dns_records" || echo "")

    if [ "$(echo "$ADD_REC_RES" | jq -r '.success // false' 2>/dev/null)" == "true" ]; then
        echo -e "${GREEN}✅ DNS Record ($REC_TYPE) Berhasil Ditambahkan ke $FULL_NAME!${NC}"
    else
        echo -e "${RED}❌ Gagal menambahkan DNS Record:${NC}"
        echo "$ADD_REC_RES" | jq -r '.errors[] | "Code: \(.code) - \(.message)"' 2>/dev/null || echo "$ADD_REC_RES"
    fi
}

list_dns_records_flow() {
    clear
    echo -e "${CYAN}====== TAMPILKAN SEMUA DNS RECORD ======${NC}\n"

    ZONES_JSON=$(curl -s "${AUTH_HEADER[@]}" -H "Content-Type: application/json" "$BASE_URL/zones?account.id=$ACCOUNT_ID&per_page=50" || echo "")
    ZONE_COUNT=$(echo "$ZONES_JSON" | jq '.result | length' 2>/dev/null || echo "0")

    if [ "$ZONE_COUNT" -eq 0 ] || [ "$ZONE_COUNT" == "null" ]; then
        echo -e "${YELLOW}⚠️ Tidak ada domain terdaftar di akun ini.${NC}"
        return
    fi

    echo -e "${WHITE}📌 Pilih Domain yang Ingin Dilihat Record-nya:${NC}"
    echo "$ZONES_JSON" | jq -r '.result[] | .name' | nl -w2 -s') '
    echo -e "  ${RED}[0] Batal${NC}"
    echo ""
    read -rp "Pilih Nomor Domain: " Z_NUM

    if [ "$Z_NUM" == "0" ] || ! [[ "$Z_NUM" =~ ^[0-9]+$ ]] || [ "$Z_NUM" -gt "$ZONE_COUNT" ]; then
        return
    fi

    SELECTED_DOMAIN=$(echo "$ZONES_JSON" | jq -r ".result[$((Z_NUM-1))].name")
    SELECTED_ZONE_ID=$(echo "$ZONES_JSON" | jq -r ".result[$((Z_NUM-1))].id")

    echo -e "\n${YELLOW}⏳ Mengambil data DNS Record untuk domain $SELECTED_DOMAIN...${NC}"
    RECORDS_JSON=$(curl -s "${AUTH_HEADER[@]}" -H "Content-Type: application/json" "$BASE_URL/zones/$SELECTED_ZONE_ID/dns_records?per_page=100" || echo "")
    REC_COUNT=$(echo "$RECORDS_JSON" | jq '.result | length' 2>/dev/null || echo "0")

    if [ "$REC_COUNT" -eq 0 ] || [ "$REC_COUNT" == "null" ]; then
        echo -e "${YELLOW}⚠️ Belum ada DNS Record di domain $SELECTED_DOMAIN.${NC}"
    else
        echo -e "\n📋 DAFTAR DNS RECORD ($SELECTED_DOMAIN):"
        echo -e "${CYAN}----------------------------------------------------------------------------------${NC}"
        printf "%-8s %-30s %-30s %-8s\n" "TIPE" "NAME" "VALUE / CONTENT" "PROXY"
        echo -e "${CYAN}----------------------------------------------------------------------------------${NC}"

        for (( i=0; i<REC_COUNT; i++ )); do
            R_TYPE=$(echo "$RECORDS_JSON" | jq -r ".result[$i].type // \"-\"")
            R_NAME=$(echo "$RECORDS_JSON" | jq -r ".result[$i].name // \"-\"")
            R_CONTENT=$(echo "$RECORDS_JSON" | jq -r ".result[$i].content // \"-\"")
            R_PROXY=$(echo "$RECORDS_JSON" | jq -r ".result[$i].proxied // false")

            [ "$R_PROXY" == "true" ] && PROXY_STATUS="${GREEN}ON${NC}" || PROXY_STATUS="${RED}OFF${NC}"
            
            if [ ${#R_CONTENT} -gt 28 ]; then
                R_CONTENT="${R_CONTENT:0:25}..."
            fi

            printf "%-8s %-30s %-30s " "$R_TYPE" "$R_NAME" "$R_CONTENT"
            echo -e "$PROXY_STATUS"
        done
        echo -e "${CYAN}----------------------------------------------------------------------------------${NC}"
    fi
}

edit_dns_record_flow() {
    clear
    echo -e "${CYAN}====== EDIT DNS RECORD ======${NC}\n"

    ZONES_JSON=$(curl -s "${AUTH_HEADER[@]}" -H "Content-Type: application/json" "$BASE_URL/zones?account.id=$ACCOUNT_ID&per_page=50" || echo "")
    ZONE_COUNT=$(echo "$ZONES_JSON" | jq '.result | length' 2>/dev/null || echo "0")

    if [ "$ZONE_COUNT" -eq 0 ] || [ "$ZONE_COUNT" == "null" ]; then
        echo -e "${YELLOW}⚠️ Tidak ada domain terdaftar di akun ini.${NC}"
        return
    fi

    echo -e "${WHITE}📌 Pilih Domain Utama:${NC}"
    echo "$ZONES_JSON" | jq -r '.result[] | .name' | nl -w2 -s') '
    echo -e "  ${RED}[0] Batal${NC}"
    echo ""
    read -rp "Pilih Nomor Domain: " Z_NUM

    if [ "$Z_NUM" == "0" ] || ! [[ "$Z_NUM" =~ ^[0-9]+$ ]] || [ "$Z_NUM" -gt "$ZONE_COUNT" ]; then return; fi

    SELECTED_DOMAIN=$(echo "$ZONES_JSON" | jq -r ".result[$((Z_NUM-1))].name")
    SELECTED_ZONE_ID=$(echo "$ZONES_JSON" | jq -r ".result[$((Z_NUM-1))].id")

    RECORDS_JSON=$(curl -s "${AUTH_HEADER[@]}" -H "Content-Type: application/json" "$BASE_URL/zones/$SELECTED_ZONE_ID/dns_records?per_page=100" || echo "")
    REC_COUNT=$(echo "$RECORDS_JSON" | jq '.result | length' 2>/dev/null || echo "0")

    if [ "$REC_COUNT" -eq 0 ] || [ "$REC_COUNT" == "null" ]; then
        echo -e "${YELLOW}⚠️ Belum ada DNS Record di domain $SELECTED_DOMAIN.${NC}"
        return
    fi

    echo -e "\n📌 Pilih DNS Record yang Ingin Di-edit:"
    echo "$RECORDS_JSON" | jq -r '.result[] | "[\(.type)] \(.name) -> \(.content)"' | nl -w2 -s') '
    echo -e "  ${RED}[0] Batal${NC}"
    echo ""
    read -rp "Pilih Nomor Record: " R_NUM

    if [ "$R_NUM" == "0" ] || ! [[ "$R_NUM" =~ ^[0-9]+$ ]] || [ "$R_NUM" -gt "$REC_COUNT" ]; then return; fi

    REC_ID=$(echo "$RECORDS_JSON" | jq -r ".result[$((R_NUM-1))].id")
    CURR_TYPE=$(echo "$RECORDS_JSON" | jq -r ".result[$((R_NUM-1))].type")
    CURR_NAME=$(echo "$RECORDS_JSON" | jq -r ".result[$((R_NUM-1))].name")
    CURR_CONTENT=$(echo "$RECORDS_JSON" | jq -r ".result[$((R_NUM-1))].content")
    CURR_PROXY=$(echo "$RECORDS_JSON" | jq -r ".result[$((R_NUM-1))].proxied")

    echo -e "\n${WHITE}✏️ Edit Content untuk $CURR_NAME ($CURR_TYPE)${NC}"
    echo -e "Value lama: ${YELLOW}$CURR_CONTENT${NC}"
    read -rp "Value baru [Tekan Enter jika tidak diubah]: " NEW_CONTENT
    [ -z "$NEW_CONTENT" ] && NEW_CONTENT="$CURR_CONTENT"

    NEW_PROXY="$CURR_PROXY"
    if [ "$CURR_TYPE" == "A" ] || [ "$CURR_TYPE" == "CNAME" ] || [ "$CURR_TYPE" == "AAAA" ]; then
        read -rp "⚡ Cloudflare Proxy Active? [y/n/Enter=Sama]: " PROXY_CHOICE
        if [[ "$PROXY_CHOICE" =~ ^[Yy] ]]; then NEW_PROXY=true; fi
        if [[ "$PROXY_CHOICE" =~ ^[Nn] ]]; then NEW_PROXY=false; fi
    fi

    echo -e "\n${YELLOW}⏳ Mengubah DNS Record...${NC}"
    PAYLOAD=$(jq -n \
        --arg type "$CURR_TYPE" \
        --arg name "$CURR_NAME" \
        --arg content "$NEW_CONTENT" \
        --argjson proxied "$NEW_PROXY" \
        '{type: $type, name: $name, content: $content, ttl: 1, proxied: $proxied}')

    EDIT_RES=$(curl -s -X PUT "${AUTH_HEADER[@]}" -H "Content-Type: application/json" -d "$PAYLOAD" "$BASE_URL/zones/$SELECTED_ZONE_ID/dns_records/$REC_ID" || echo "")

    if [ "$(echo "$EDIT_RES" | jq -r '.success // false' 2>/dev/null)" == "true" ]; then
        echo -e "${GREEN}✅ DNS Record $CURR_NAME Berhasil Diperbarui!${NC}"
    else
        echo -e "${RED}❌ Gagal mengubah DNS Record:${NC}"
        echo "$EDIT_RES" | jq -r '.errors[] | "Code: \(.code) - \(.message)"' 2>/dev/null || echo "$EDIT_RES"
    fi
}

delete_dns_record_flow() {
    clear
    echo -e "${CYAN}====== HAPUS DNS RECORD ======${NC}\n"

    ZONES_JSON=$(curl -s "${AUTH_HEADER[@]}" -H "Content-Type: application/json" "$BASE_URL/zones?account.id=$ACCOUNT_ID&per_page=50" || echo "")
    ZONE_COUNT=$(echo "$ZONES_JSON" | jq '.result | length' 2>/dev/null || echo "0")

    if [ "$ZONE_COUNT" -eq 0 ] || [ "$ZONE_COUNT" == "null" ]; then
        echo -e "${YELLOW}⚠️ Tidak ada domain terdaftar di akun ini.${NC}"
        return
    fi

    echo -e "${WHITE}📌 Pilih Domain Utama:${NC}"
    echo "$ZONES_JSON" | jq -r '.result[] | .name' | nl -w2 -s') '
    echo -e "  ${RED}[0] Batal${NC}"
    echo ""
    read -rp "Pilih Nomor Domain: " Z_NUM

    if [ "$Z_NUM" == "0" ] || ! [[ "$Z_NUM" =~ ^[0-9]+$ ]] || [ "$Z_NUM" -gt "$ZONE_COUNT" ]; then return; fi

    SELECTED_DOMAIN=$(echo "$ZONES_JSON" | jq -r ".result[$((Z_NUM-1))].name")
    SELECTED_ZONE_ID=$(echo "$ZONES_JSON" | jq -r ".result[$((Z_NUM-1))].id")

    RECORDS_JSON=$(curl -s "${AUTH_HEADER[@]}" -H "Content-Type: application/json" "$BASE_URL/zones/$SELECTED_ZONE_ID/dns_records?per_page=100" || echo "")
    REC_COUNT=$(echo "$RECORDS_JSON" | jq '.result | length' 2>/dev/null || echo "0")

    if [ "$REC_COUNT" -eq 0 ] || [ "$REC_COUNT" == "null" ]; then
        echo -e "${YELLOW}⚠️ Belum ada DNS Record di domain $SELECTED_DOMAIN.${NC}"
        return
    fi

    echo -e "\n📌 Pilih DNS Record yang Ingin Dihapus:"
    echo "$RECORDS_JSON" | jq -r '.result[] | "[\(.type)] \(.name) -> \(.content)"' | nl -w2 -s') '
    echo -e "  ${RED}[0] Batal${NC}"
    echo ""
    read -rp "Pilih Nomor Record yang Mau Dihapus: " R_NUM

    if [ "$R_NUM" == "0" ] || ! [[ "$R_NUM" =~ ^[0-9]+$ ]] || [ "$R_NUM" -gt "$REC_COUNT" ]; then return; fi

    REC_ID=$(echo "$RECORDS_JSON" | jq -r ".result[$((R_NUM-1))].id")
    TARGET_NAME=$(echo "$RECORDS_JSON" | jq -r ".result[$((R_NUM-1))].name")

    read -rp "⚠️ Yakin ingin menghapus record '$TARGET_NAME'? [y/N]: " CONFIRM_DEL
    if [[ "$CONFIRM_DEL" =~ ^[Yy] ]]; then
        DEL_RES=$(curl -s -X DELETE "${AUTH_HEADER[@]}" -H "Content-Type: application/json" "$BASE_URL/zones/$SELECTED_ZONE_ID/dns_records/$REC_ID" || echo "")
        if [ "$(echo "$DEL_RES" | jq -r '.success // false' 2>/dev/null)" == "true" ]; then
            echo -e "${GREEN}🗑️ DNS Record '$TARGET_NAME' Berhasil Dihapus!${NC}"
        else
            echo -e "${RED}❌ Gagal menghapus record:${NC}"
            echo "$DEL_RES" | jq -r '.errors[] | "Code: \(.code) - \(.message)"' 2>/dev/null || echo "$DEL_RES"
        fi
    fi
}

run_domain_module() {
    while true; do
        clear
        echo -e "${CYAN}================================================================${NC}"
        echo -e "${BOLD}📌 MANAJEMEN ZONE DOMAIN CLOUDFLARE:${NC}"
        echo -e "${CYAN}----------------------------------------------------------------${NC}"
        echo -e "  ${CYAN}[1]${NC} 🆕 Daftarkan Domain Baru ke Cloudflare (Zone)"
        echo -e "  ${CYAN}[2]${NC} 🔍 Cek Status Keaktifan & NS Domain CF"
        echo -e "  ${CYAN}[3]${NC} ➕ Tambah DNS Record (A, CNAME, MX, NS, TXT, AAAA)"
        echo -e "  ${CYAN}[4]${NC} 📋 Tampilkan Semua DNS Record Domain"
        echo -e "  ${CYAN}[5]${NC} ✏️  Edit DNS Record"
        echo -e "  ${RED}[6]${NC} 🗑️  Hapus DNS Record"
        echo -e "  ${RED}[0]${NC} ↩️  Kembali ke Menu Utama"
        echo -e "${CYAN}----------------------------------------------------------------${NC}"
        read -rp "Pilih [1/2/3/4/5/6/0]: " DOM_CHOICE

        case "$DOM_CHOICE" in
            1)
                read -rp "🌐 Masukkan Nama Domain Baru [0=Batal]: " NEW_DOMAIN
                if [ "$NEW_DOMAIN" != "0" ] && [ -n "$NEW_DOMAIN" ]; then
                    NEW_DOMAIN=$(echo "$NEW_DOMAIN" | sed 's/https:\/\///g; s/http:\/\///g; s/\///g' | tr '[:upper:]' '[:lower:]')
                    ADD_ZONE_RES=$(curl -s -X POST "${AUTH_HEADER[@]}" -H "Content-Type: application/json" -d "{\"account\":{\"id\":\"$ACCOUNT_ID\"},\"name\":\"$NEW_DOMAIN\",\"jump_start\":true}" "$BASE_URL/zones" || echo "")
                    if [ "$(echo "$ADD_ZONE_RES" | jq -r '.success // false' 2>/dev/null)" == "true" ]; then
                        NS1=$(echo "$ADD_ZONE_RES" | jq -r '.result.name_servers[0]')
                        NS2=$(echo "$ADD_ZONE_RES" | jq -r '.result.name_servers[1]')
                        echo -e "${GREEN}✅ Domain '$NEW_DOMAIN' Berhasil Didaftarkan!${NC}"
                        echo -e "📢 WAJIB PASANG NS DI REGISTRAR:\n 1. $NS1\n 2. $NS2"
                    else
                        echo -e "${RED}❌ Gagal daftarkan domain:${NC}"
                        echo "$ADD_ZONE_RES" | jq -r '.errors[] | "Code: \(.code) - \(.message)"' 2>/dev/null || echo "$ADD_ZONE_RES"
                    fi
                fi
                read -rp "Tekan Enter untuk kembali ke Sub-Menu..."
                ;;
            2)
                ZONES_JSON=$(curl -s "${AUTH_HEADER[@]}" -H "Content-Type: application/json" "$BASE_URL/zones?account.id=$ACCOUNT_ID&per_page=50" || echo "")
                ZONE_COUNT=$(echo "$ZONES_JSON" | jq '.result | length' 2>/dev/null || echo "0")
                
                if [ "$ZONE_COUNT" -eq 0 ] || [ "$ZONE_COUNT" == "null" ]; then
                    echo -e "${YELLOW}⚠️ Tidak ada domain terdaftar di akun ini.${NC}"
                else
                    echo -e "\n📋 STATUS KEAKTIFAN DOMAIN AKUN INI:"
                    for (( idx=0; idx<ZONE_COUNT; idx++ )); do
                        DNAME=$(echo "$ZONES_JSON" | jq -r ".result[$idx].name")
                        DSTATUS=$(echo "$ZONES_JSON" | jq -r ".result[$idx].status")
                        DNS1=$(echo "$ZONES_JSON" | jq -r ".result[$idx].name_servers[0]")
                        DNS2=$(echo "$ZONES_JSON" | jq -r ".result[$idx].name_servers[1]")
                        [ "$DSTATUS" == "active" ] && S_LABEL="${GREEN}🟢 ACTIVE${NC}" || S_LABEL="${YELLOW}🟡 PENDING / UNVERIFIED${NC}"
                        echo -e "🌐 Domain: ${CYAN}$DNAME${NC} | Status: $S_LABEL | NS: $DNS1, $DNS2"
                    done
                fi
                read -rp "Tekan Enter untuk kembali ke Sub-Menu..."
                ;;
            3)
                add_dns_record_flow
                read -rp "Tekan Enter untuk kembali ke Sub-Menu..."
                ;;
            4)
                list_dns_records_flow
                read -rp "Tekan Enter untuk kembali ke Sub-Menu..."
                ;;
            5)
                edit_dns_record_flow
                read -rp "Tekan Enter untuk kembali ke Sub-Menu..."
                ;;
            6)
                delete_dns_record_flow
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
