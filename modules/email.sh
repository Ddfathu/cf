# MENU_TITLE: ✉️ Kelola Cloudflare Email Routing & Catch-All
# MENU_ACTION: run_email_routing_module

# 1. CEK & TAMBAH DNS MX RECORD OTOMATIS
check_and_fix_mx_records() {
    local zone_id="$1"
    local domain_name="$2"

    echo -e "${YELLOW}🔍 Memeriksa DNS Record untuk Email Routing di '$domain_name'...${NC}"
    
    DNS_RECS=$(curl -s "${AUTH_HEADER[@]}" -H "Content-Type: application/json" "$BASE_URL/zones/$zone_id/dns_records?type=MX")
    MX_COUNT=$(echo "$DNS_RECS" | jq '.result | length')

    if [ "$MX_COUNT" -gt 0 ]; then
        echo -e "${GREEN}✅ DNS MX Record sudah terpasang di domain '$domain_name'.${NC}"
    else
        echo -e "${YELLOW}⚠️ DNS MX Record belum ada di Cloudflare! Memasang MX Record otomatis...${NC}"
        
        # Cloudflare Email Routing MX Records
        curl -s -X POST "${AUTH_HEADER[@]}" -H "Content-Type: application/json" -d "{\"type\":\"MX\",\"name\":\"$domain_name\",\"content\":\"isaac.mx.cloudflare.net\",\"priority\":92,\"ttl\":1}" "$BASE_URL/zones/$zone_id/dns_records" > /dev/null
        curl -s -X POST "${AUTH_HEADER[@]}" -H "Content-Type: application/json" -d "{\"type\":\"MX\",\"name\":\"$domain_name\",\"content\":\"linda.mx.cloudflare.net\",\"priority\":62,\"ttl\":1}" "$BASE_URL/zones/$domain_name/dns_records" > /dev/null || curl -s -X POST "${AUTH_HEADER[@]}" -H "Content-Type: application/json" -d "{\"type\":\"MX\",\"name\":\"$domain_name\",\"content\":\"linda.mx.cloudflare.net\",\"priority\":62,\"ttl\":1}" "$BASE_URL/zones/$zone_id/dns_records" > /dev/null
        curl -s -X POST "${AUTH_HEADER[@]}" -H "Content-Type: application/json" -d "{\"type\":\"MX\",\"name\":\"$domain_name\",\"content\":\"amir.mx.cloudflare.net\",\"priority\":19,\"ttl\":1}" "$BASE_URL/zones/$zone_id/dns_records" > /dev/null

        # SPF Record
        curl -s -X POST "${AUTH_HEADER[@]}" -H "Content-Type: application/json" -d "{\"type\":\"TXT\",\"name\":\"$domain_name\",\"content\":\"v=spf1 include:_spf.mx.cloudflare.net ~all\",\"ttl\":1}" "$BASE_URL/zones/$zone_id/dns_records" > /dev/null

        echo -e "${GREEN}✅ MX Record & SPF Record berhasil ditambahkan 100%!${NC}"
    fi
}

# 2. MANAJEMEN DESTINATION ADDRESS (EMAIL PENERIMA)
manage_destination_addresses() {
    echo -e "\n${BOLD}📌 MANAJEMEN EMAIL PENERIMA (DESTINATION ADDRESS):${NC}"
    echo -e "  ${CYAN}[1]${NC} 📋 Tampilkan Email Terverifikasi / Pending"
    echo -e "  ${CYAN}[2]${NC} ✉️  Daftarkan Email Penerima Baru (Kirim Verifikasi)"
    echo -e "  ${CYAN}[3]${NC} 🔑 Verifikasi Email Penerima (Masukkan Kode OTP)"
    echo -e "  ${RED}[0]${NC} ↩️  Batal / Kembali"
    read -rp "Pilih [1/2/3/0]: " DEST_CHOICE

    case "$DEST_CHOICE" in
        1)
            echo -e "${YELLOW}📜 Mengambil daftar email penerima...${NC}"
            DEST_RES=$(curl -s "${AUTH_HEADER[@]}" -H "Content-Type: application/json" "$BASE_URL/accounts/$ACCOUNT_ID/email/routing/addresses")
            DEST_COUNT=$(echo "$DEST_RES" | jq '.result | length')

            if [ -z "$DEST_COUNT" ] || [ "$DEST_COUNT" -eq 0 ]; then
                echo -e "${RED}❌ Belum ada email penerima yang terdaftar.${NC}"
            else
                echo -e "\n📋 DAFTAR EMAIL PENERIMA:"
                echo -e "${CYAN}----------------------------------------------------------------${NC}"
                for (( idx=0; idx<DEST_COUNT; idx++ )); do
                    EM_ADDR=$(echo "$DEST_RES" | jq -r ".result[$idx].email")
                    EM_VER=$(echo "$DEST_RES" | jq -r ".result[$idx].verified")
                    
                    if [ "$EM_VER" != "null" ] && [ -n "$EM_VER" ]; then
                        VER_STATUS="${GREEN}🟢 TERVERIFIKASI${NC}"
                    else
                        VER_STATUS="${YELLOW}🟡 PENDING (Butuh Kode Verifikasi)${NC}"
                    fi
                    echo -e "✉️  Email  : ${CYAN}$EM_ADDR${NC}"
                    echo -e "📌 Status : $VER_STATUS"
                    echo -e "${CYAN}----------------------------------------------------------------${NC}"
                done
            fi
            ;;
        2)
            read -rp "✉️  Masukkan Email Penerima Baru (contoh: emailku@gmail.com) [0=Batal]: " NEW_DEST_EMAIL
            if [ "$NEW_DEST_EMAIL" != "0" ] && [ -n "$NEW_DEST_EMAIL" ]; then
                echo -e "${YELLOW}⏳ Mengirim email verifikasi ke '$NEW_DEST_EMAIL'...${NC}"
                ADD_DEST_RES=$(curl -s -X POST "${AUTH_HEADER[@]}" -H "Content-Type: application/json" -d "{\"email\":\"$NEW_DEST_EMAIL\"}" "$BASE_URL/accounts/$ACCOUNT_ID/email/routing/addresses")

                if [ "$(echo "$ADD_DEST_RES" | jq -r '.success')" == "true" ]; then
                    echo -e "${GREEN}✅ Berhasil mendaftarkan '$NEW_DEST_EMAIL'! Silakan cek inbox/spam email tersebut.${NC}"
                else
                    echo -e "${RED}❌ Gagal mendaftarkan email:${NC}"
                    echo "$ADD_DEST_RES" | jq -r '.errors[] | "Code: \(.code) - \(.message)"' 2>/dev/null || echo "$ADD_DEST_RES"
                fi
            fi
            ;;
        3)
            echo -e "${YELLOW}📜 Mengambil daftar email pending...${NC}"
            DEST_RES=$(curl -s "${AUTH_HEADER[@]}" -H "Content-Type: application/json" "$BASE_URL/accounts/$ACCOUNT_ID/email/routing/addresses")
            PENDING_DESTS=$(echo "$DEST_RES" | jq '.result // [] | map(select(.verified == null))')
            PEND_COUNT=$(echo "$PENDING_DESTS" | jq 'length')

            if [ -z "$PEND_COUNT" ] || [ "$PEND_COUNT" -eq 0 ]; then
                echo -e "${YELLOW}⚠️ Tidak ada email penerima yang berstatus PENDING.${NC}"
            else
                echo -e "\n${BOLD}Pilih Email yang Mau Diverifikasi:${NC}"
                echo "$PENDING_DESTS" | jq -r '.[] | .email' | nl -w2 -s') '
                read -rp "Nomor Email [0=Batal]: " PEND_NUM
                
                if [ "$PEND_NUM" != "0" ] && [ -n "$PEND_NUM" ]; then
                    TARGET_PEND_ITEM=$(echo "$PENDING_DESTS" | jq -r ".[$((PEND_NUM-1))]")
                    TARGET_PEND_ID=$(echo "$TARGET_PEND_ITEM" | jq -r '.id')
                    TARGET_PEND_EMAIL=$(echo "$TARGET_PEND_ITEM" | jq -r '.email')

                    read -rp "🔑 Masukkan Kode Verifikasi / Token dari Email '$TARGET_PEND_EMAIL' [0=Batal]: " VER_CODE
                    if [ "$VER_CODE" != "0" ] && [ -n "$VER_CODE" ]; then
                        echo -e "${YELLOW}⏳ Memverifikasi kode...${NC}"
                        VER_RES=$(curl -s -X POST "${AUTH_HEADER[@]}" -H "Content-Type: application/json" -d "{\"token\":\"$VER_CODE\"}" "$BASE_URL/accounts/$ACCOUNT_ID/email/routing/addresses/$TARGET_PEND_ID/verify")

                        if [ "$(echo "$VER_RES" | jq -r '.success')" == "true" ]; then
                            echo -e "${GREEN}🎉 CONGRATS! Email '$TARGET_PEND_EMAIL' BERHASIL TERVERIFIKASI 100%!${NC}"
                        else
                            echo -e "${RED}❌ Gagal verifikasi (Kode salah / kadaluwarsa):${NC}"
                            echo "$VER_RES" | jq -r '.errors[] | "Code: \(.code) - \(.message)"' 2>/dev/null || echo "$VER_RES"
                        fi
                    fi
                fi
            fi
            ;;
    esac
}

# 3. PENGATURAN CATCH-ALL EMAIL ROUTING
configure_catch_all() {
    echo -e "${YELLOW}🌐 Mengambil daftar Zone Domain...${NC}"
    ZONES_JSON=$(curl -s "${AUTH_HEADER[@]}" -H "Content-Type: application/json" "$BASE_URL/zones?account.id=$ACCOUNT_ID&per_page=50")
    ZONE_COUNT=$(echo "$ZONES_JSON" | jq '.result | length')

    if [ -z "$ZONE_COUNT" ] || [ "$ZONE_COUNT" -eq 0 ]; then
        echo -e "${RED}❌ Tidak ada domain utama ditemukan.${NC}"
        return
    fi

    echo -e "\n${BOLD}Pilih Domain Utama Target Catch-All:${NC}"
    echo "$ZONES_JSON" | jq -r '.result[] | .name' | nl -w2 -s') '
    read -rp "Nomor Domain [0=Batal]: " ZONE_NUM; [ "$ZONE_NUM" == "0" ] && return
    
    SELECTED_DOMAIN=$(echo "$ZONES_JSON" | jq -r ".result[$((ZONE_NUM-1))].name")
    SELECTED_ZONE_ID=$(echo "$ZONES_JSON" | jq -r ".result[$((ZONE_NUM-1))].id")

    # Cek & pasang MX Record
    check_and_fix_mx_records "$SELECTED_ZONE_ID" "$SELECTED_DOMAIN"

    # Aktifkan fitur Email Routing di Domain tersebut
    echo -e "${YELLOW}⏳ Memastikan fitur Email Routing aktif di '$SELECTED_DOMAIN'...${NC}"
    curl -s -X POST "${AUTH_HEADER[@]}" -H "Content-Type: application/json" -d '{"enabled":true}' "$BASE_URL/zones/$SELECTED_ZONE_ID/email/routing" > /dev/null

    echo -e "\n${BOLD}📌 PILIH TARGET ROUTING CATCH-ALL (*@$SELECTED_DOMAIN):${NC}"
    echo -e "  ${CYAN}[1]${NC} 🚀 Teruskan ke Service Worker"
    echo -e "  ${CYAN}[2]${NC} ✉️  Forward ke Email Penerima (Destination Address)"
    echo -e "  ${RED}[0]${NC} ↩️  Batal / Kembali"
    read -rp "Pilih [1/2/0]: " CATCH_CHOICE

    case "$CATCH_CHOICE" in
        1)
            WORKERS_JSON=$(curl -s "${AUTH_HEADER[@]}" -H "Content-Type: application/json" "$BASE_URL/accounts/$ACCOUNT_ID/workers/services?per_page=100")
            echo "$WORKERS_JSON" | jq -r '.result[] | .id' | nl -w2 -s') '
            read -rp "Pilih Worker Target [0=Batal]: " W_NUM; [ "$W_NUM" == "0" ] && return
            TARGET_WORKER_NAME=$(echo "$WORKERS_JSON" | jq -r ".result[$((W_NUM-1))].id")

            echo -e "${YELLOW}⚙️ Mengkonfigurasi Catch-All ke Worker '$TARGET_WORKER_NAME'...${NC}"
            CATCH_BODY=$(jq -n --arg worker "$TARGET_WORKER_NAME" '{"name":"Catch-All Worker","enabled":true,"actions":[{"type":"worker","value":[$worker]}],"matchers":[{"type":"all"}]}')
            
            SET_CATCH_RES=$(curl -s -X PUT "${AUTH_HEADER[@]}" -H "Content-Type: application/json" -d "$CATCH_BODY" "$BASE_URL/zones/$SELECTED_ZONE_ID/email/routing/rules/catch_all")

            if [ "$(echo "$SET_CATCH_RES" | jq -r '.success')" == "true" ]; then
                echo -e "${GREEN}🎉 BERHASIL! Semua email masuk (*@$SELECTED_DOMAIN) akan diteruskan ke Worker '$TARGET_WORKER_NAME'!${NC}"
            else
                echo -e "${RED}❌ Gagal mengatur Catch-All Worker:${NC}"
                echo "$SET_CATCH_RES" | jq -r '.errors[] | "Code: \(.code) - \(.message)"' 2>/dev/null || echo "$SET_CATCH_RES"
            fi
            ;;
        2)
            DEST_RES=$(curl -s "${AUTH_HEADER[@]}" -H "Content-Type: application/json" "$BASE_URL/accounts/$ACCOUNT_ID/email/routing/addresses")
            VERIFIED_DESTS=$(echo "$DEST_RES" | jq '.result // [] | map(select(.verified != null))')
            VER_COUNT=$(echo "$VERIFIED_DESTS" | jq 'length')

            if [ -z "$VER_COUNT" ] || [ "$VER_COUNT" -eq 0 ]; then
                echo -e "${RED}❌ Belum ada email penerima yang TERVERIFIKASI!${NC}"
                echo -e "${YELLOW}💡 Daftarkan & verifikasi email penerima dulu di Sub-Menu [1].${NC}"
                return
            fi

            echo -e "\n${BOLD}Pilih Email Penerima Terverifikasi Target Forward:${NC}"
            echo "$VERIFIED_DESTS" | jq -r '.[] | .email' | nl -w2 -s') '
            read -rp "Nomor Email Target [0=Batal]: " V_NUM; [ "$V_NUM" == "0" ] && return
            TARGET_FWD_EMAIL=$(echo "$VERIFIED_DESTS" | jq -r ".[$((V_NUM-1))].email")

            echo -e "${YELLOW}⚙️ Mengkonfigurasi Catch-All Forwarding ke '$TARGET_FWD_EMAIL'...${NC}"
            CATCH_BODY=$(jq -n --arg email "$TARGET_FWD_EMAIL" '{"name":"Catch-All Forward","enabled":true,"actions":[{"type":"forward","value":[$email]}],"matchers":[{"type":"all"}]}')
            
            SET_CATCH_RES=$(curl -s -X PUT "${AUTH_HEADER[@]}" -H "Content-Type: application/json" -d "$CATCH_BODY" "$BASE_URL/zones/$SELECTED_ZONE_ID/email/routing/rules/catch_all")

            if [ "$(echo "$SET_CATCH_RES" | jq -r '.success')" == "true" ]; then
                echo -e "${GREEN}🎉 BERHASIL! Semua email masuk (*@$SELECTED_DOMAIN) akan di-forward ke '$TARGET_FWD_EMAIL'!${NC}"
            else
                echo -e "${RED}❌ Gagal mengatur Catch-All Forwarding:${NC}"
                echo "$SET_CATCH_RES" | jq -r '.errors[] | "Code: \(.code) - \(.message)"' 2>/dev/null || echo "$SET_CATCH_RES"
            fi
            ;;
    esac
}

# MAIN ENTRY POINT KELOLA EMAIL ROUTING
run_email_routing_module() {
    echo -e "${BOLD}📌 MANAJEMEN CLOUDFLARE EMAIL ROUTING:${NC}"
    echo -e "  ${CYAN}[1]${NC} ✉️  Kelola Email Penerima Destination (Daftar / Cek / Verifikasi)"
    echo -e "  ${CYAN}[2]${NC} 🔄 Pengaturan Catch-All Email (*@domain -> Worker / Forwarding)"
    echo -e "  ${RED}[0]${NC} ↩️  Batal / Kembali"
    read -rp "Pilih [1/2/0]: " MAIN_EMAIL_CHOICE

    case "$MAIN_EMAIL_CHOICE" in
        1) manage_destination_addresses ;;
        2) configure_catch_all ;;
    esac
    read -rp "Tekan Enter untuk kembali..."
}
