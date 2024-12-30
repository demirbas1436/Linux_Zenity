#!/bin/bash

log_file="log.csv"
depo_file="depo.csv"
kullanici_file="kullanici.csv"
backup_dir="backup"

# CSV dosyasının var olup olmadığını kontrol et, yoksa oluştur
if [ ! -f "$depo_file" ]; then
    echo "Ürün Numarası,Ürün Adı,Stok Miktarı,Birim Fiyatı,Kategori" > "$depo_file"
fi

if [ ! -f "$kullanici_file" ]; then
    echo "Kullanıcı Adı,Şifre,Adı,Soyadı,Rol" > "$kullanici_file"
fi

if [ ! -f "$log_file" ]; then
    touch "$log_file"
fi

if [ ! -f "$locked_accounts" ]; then
    touch "$locked_accounts"
fi

# Kullanıcı Giriş Kontrol Fonksiyonu
function check_user() {
    local username=$1
    local password=$2
    local date_time=$(date "+%Y-%m-%d %H:%M:%S")

    # Kilitli hesap kontrolü
    if grep -q "^$username$" "$locked_accounts"; then
        zenity --error --text="Hesabınız kilitlenmiştir. Lütfen yöneticiyle iletişime geçin."
        echo "$date_time, $username, HATA: Hesap kilitli" >> "$log_file"
        echo "Locked"
        return
    fi

    while IFS=',' read -r csv_username csv_password csv_firstname csv_lastname csv_role; do
        if [[ "$csv_username" == "$username" && "$csv_password" == "$password" ]]; then
            echo "$csv_role"
            return
        fi
    done < "$kullanici_file"

    # Hatalı giriş kaydı ekle ve deneme sayısını kontrol et
    echo "$date_time, $username, $password, Hatalı giriş" >> "$log_file"
    increment_failed_attempts "$username"
    echo "Invalid"
}

# Başarısız Giriş Denemelerini İzleme ve Hesap Kilitleme
function increment_failed_attempts() {
    local username=$1
    local max_attempts=3
    local attempts_file="failed_attempts.csv"

    if [ ! -f "$attempts_file" ]; then
        touch "$attempts_file"
    fi

    attempts=$(grep "^$username," "$attempts_file" | awk -F, '{print $2}')
    attempts=$((attempts + 1))

    grep -v "^$username," "$attempts_file" > temp && mv temp "$attempts_file"
    echo "$username,$attempts" >> "$attempts_file"

    if [ "$attempts" -ge "$max_attempts" ]; then
        echo "$username" >> "$locked_accounts"
        zenity --error --text="Hesabınız çok fazla hatalı giriş nedeniyle kilitlenmiştir."
    fi
}

# Hesap Kilidini Açma (Yönetici Yetkisiyle)
function unlock_account() {
    local username=$(zenity --entry --title="Hesap Kilidini Aç" --text="Kilitli hesabın kullanıcı adını girin:")

    if grep -q "^$username$" "$locked_accounts"; then
        grep -v "^$username$" "$locked_accounts" > temp && mv temp "$locked_accounts"
        zenity --info --text="Hesap başarıyla kilidi açıldı: $username"
    else
        zenity --error --text="Belirtilen kullanıcı kilitli değil."
    fi
}

# Şifre Sıfırlama (Yönetici Yetkisiyle)
function reset_password() {
    local username=$(zenity --entry --title="Şifre Sıfırla" --text="Şifresi sıfırlanacak kullanıcı adını girin:")

    if grep -q "^$username," "$kullanici_file"; then
        local new_password=$(zenity --entry --title="Şifre Sıfırla" --text="Yeni şifreyi girin:" --hide-text)
        local temp_file="temp_users.csv"

        while IFS=',' read -r csv_username csv_password csv_firstname csv_lastname csv_role; do
            if [[ "$csv_username" == "$username" ]]; then
                echo "$csv_username,$new_password,$csv_firstname,$csv_lastname,$csv_role" >> "$temp_file"
            else
                echo "$csv_username,$csv_password,$csv_firstname,$csv_lastname,$csv_role" >> "$temp_file"
            fi
        done < "$kullanici_file"

        mv "$temp_file" "$kullanici_file"
        zenity --info --text="Şifre başarıyla sıfırlandı."
    else
        zenity --error --text="Belirtilen kullanıcı bulunamadı."
    fi
}

# Giriş Fonksiyonu
function login() {
    local role
    while true; do
        username=$(zenity --entry --title="Giriş" --text="Kullanıcı adı:")
        password=$(zenity --entry --title="Giriş" --text="Şifre:" --hide-text)

        role=$(check_user "$username" "$password")

        if [[ "$role" == "Locked" ]]; then
            return
        elif [[ "$role" != "Invalid" ]]; then
            zenity --info --text="Hoşgeldiniz, $username! Rolünüz: $role"
            break
        else
            zenity --error --text="Geçersiz kullanıcı adı veya şifre, tekrar deneyin."
        fi
    done
    echo $role
}


# Yönetici Menüsü
function show_admin_menu() {
    choice=$(zenity --list --title="Yönetici Menü" --column="İşlem" \
        "Ürün Ekle" "Ürün Listele" "Ürün Güncelle" "Ürün Sil" "Kullanıcı Yönetimi" \
        "Hesap Kilidi Aç" "Şifre Sıfırla" "Rapor Al" "Program Yönetimi" "Çıkış")

    case $choice in
        "Ürün Ekle") add_product ;;
        "Ürün Listele") list_products ;;
        "Ürün Güncelle") update_product ;;
        "Ürün Sil") delete_product ;;
        "Kullanıcı Yönetimi") user_management_menu ;;
        "Hesap Kilidi Aç") unlock_account ;;
        "Şifre Sıfırla") reset_password ;;
        "Rapor Al") generate_report ;;
        "Program Yönetimi") show_program_management ;;
        "Çıkış") 
            # Çıkış onayı için Zenity --question kullanılıyor
            if zenity --question --title="Çıkış Onayı" --text="Sistemi kapatmak istediğinizden emin misiniz?"; then
                exit 0
            else
                zenity --info --text="Çıkış işlemi iptal edildi."
            fi
            ;;
        
        *) zenity --error --text="Geçersiz seçim" ;;
    esac
}

# Kullanıcı Menüsü
function show_user_menu() {
    choice=$(zenity --list --title="Kullanıcı Menü" --column="İşlem" \
        "Ürün Listele" "Rapor Al" "Çıkış")

    case $choice in
        "Ürün Listele") list_products ;;
        "Rapor Al") generate_report ;;
        "Çıkış") exit ;;
        *) zenity --error --text="Geçersiz seçim" ;;
    esac
}

generate_report() {
    depo_file="depo.csv" # Depo dosyasının adını burada belirtin.

    report_type=$(zenity --list --title="Rapor Türü Seçin" --column="Seçenek" \
        "Stokta Azalan Ürünler" \
        "En Yüksek Stok Miktarına Sahip Ürünler" \
        "Toplam Ürün Değerini Hesapla")

    if [ -z "$report_type" ]; then
        return
    fi

    if [[ "$report_type" != "Toplam Ürün Değerini Hesapla" ]]; then
        threshold=$(zenity --entry --title="Eşik Değeri Girin" --text="Lütfen eşik değerini girin (örneğin: 5)" --entry-text="5")
        
        if [ -z "$threshold" ] || ! [[ "$threshold" =~ ^[0-9]+$ ]]; then
            zenity --error --text="Eşik değeri pozitif bir sayı olmalıdır."
            return
        fi
    fi

    case $report_type in
        "Stokta Azalan Ürünler")
            awk -F, -v threshold="$threshold" 'NR > 1 && $3 < threshold' "$depo_file" > low_stock.txt
            zenity --text-info --filename="low_stock.txt" --title="Stokta Azalan Ürünler"
            ;;
        "En Yüksek Stok Miktarına Sahip Ürünler")
            awk -F, -v threshold="$threshold" 'NR > 1 && $3 > threshold' "$depo_file" > high_stock.txt
            zenity --text-info --filename="high_stock.txt" --title="En Yüksek Stok Miktarına Sahip Ürünler"
            ;;
        "Toplam Ürün Değerini Hesapla")
            total_value=$(awk -F, 'NR > 1 { toplam += $3 * $4 } END { print toplam }' "$depo_file")
            zenity --info --text="Depodaki toplam ürünlerin toplam değeri: $total_value"
            ;;
        "Kritik Stok Seviyelerini Uyar")
            critical_threshold=$(zenity --entry --title="Eşik Değeri Girin" --text="Kritik stok eşik değerini girin:")
            
            if [ -z "$critical_threshold" ] || ! [[ "$critical_threshold" =~ ^[0-9]+$ ]]; then
                zenity --error --text="Eşik değeri pozitif bir sayı olmalıdır."
                return
            fi

            awk -F, -v threshold="$critical_threshold" 'NR > 1 && $3 < threshold' "$depo_file" > critical_stock.txt

            if [ -s critical_stock.txt ]; then
                mail -s "Kritik Stok Seviyesi Uyarısı" your_email@example.com < critical_stock.txt
                zenity --info --text="E-posta uyarısı gönderildi."
            else
                zenity --info --text="Kritik stok seviyesi altında ürün bulunamadı."
            fi
            ;;

        *)
            zenity --error --text="Geçersiz seçenek!"
            return
            ;;
    esac
}



# Ürün Ekleme (Ürün Numarası Otomatik Artırmalı ve Eşsiz)
function add_product() {
    # Mevcut en yüksek ürün numarasını bul
    if [[ -s "$depo_file" ]]; then
        max_product_id=$(awk -F, 'NR > 1 {if ($1 > max) max = $1} END {print max}' "$depo_file")
    else
        max_product_id=0
    fi

    # Yeni ürün numarası oluştur
    new_product_id=$((max_product_id + 1))

    while true; do
        # Zenity --forms ile ürün bilgilerini al
        product_info=$(zenity --forms --title="Ürün Ekle" \
            --text="Ürün bilgilerini giriniz:" \
            --add-entry="Ürün Adı" \
            --add-entry="Stok Miktarı" \
            --add-entry="Birim Fiyatı" \
            --add-entry="Kategori")

        # Kullanıcı işlemi iptal ettiyse çıkış yap
        if [[ -z "$product_info" ]]; then
            zenity --error --text="Ürün ekleme işlemi iptal edildi."
            return
        fi

        # Alınan bilgileri ayrıştır
        IFS="|" read -r product_name stock_quantity unit_price category <<< "$product_info"

         # Ürün adı ve kategori içinde boşluk olup olmadığını kontrol et
        if [[ "$product_name" =~ \  || "$category" =~ \  ]]; then
            zenity --error --text="Ürün adı ve kategori boşluk içermemelidir. Lütfen geçerli bir ürün adı ve kategori giriniz."
            continue
        fi

        # Ürün adı kontrolü
        if grep -q -F ",$product_name," "$depo_file"; then
            local date_time=$(date "+%Y-%m-%d %H:%M:%S")
            echo "$date_time, $product_name, HATA: Bu ürün adıyla başka bir kayıt bulunmaktadır. Lütfen farklı bir ad giriniz." >> "$log_file"
            zenity --error --text="Bu ürün adıyla başka bir kayıt bulunmaktadır. Lütfen farklı bir ad giriniz."
        else
            break
        fi
    done

    # Zenity ile ilerleme çubuğu göster
    (
    for i in {1..100}; do
        echo $((i))
        sleep 0.02
    done
    ) | zenity --progress --title="Ürün Ekleme" --text="Ürün ekleniyor..." --percentage=0 --auto-close

    # Veriyi dosyaya ekle
    echo "$new_product_id,$product_name,$stock_quantity,$unit_price,$category" >> "$depo_file"
    zenity --info --text="Ürün başarıyla eklendi. Ürün Numarası: $new_product_id"
}




# Ürün Listeleme
function list_products() {
    zenity --text-info --filename="$depo_file" --title="Ürün Listesi"
}

# Ürün Güncelleme Fonksiyonu
function update_product() {
    local product_name=$(zenity --entry --title="Ürün Güncelle" --text="Güncellenecek ürün adını girin:")

    # Aranan ürünlerin listesini bul
    local matching_products=$(awk -F, -v name="$product_name" 'NR>1 && $2 == name {print $1 "," $2 "," $3 "," $4 "," $5}' "$depo_file")

    if [[ -z "$matching_products" ]]; then
        zenity --error --text="Belirtilen adla bir ürün bulunamadı."
        return
    fi

    # Kullanıcıya mevcut ürünlerin kategorilerini seçtir
    local selected_product=$(echo "$matching_products" | zenity --list --title="Mevcut Ürünler" \
        --column="Ürün Numarası" --column="Ürün Adı" --column="Stok Miktarı" --column="Birim Fiyatı" --column="Kategori" \
        --text="Güncellenecek ürünü seçin:")

    if [[ -z "$selected_product" ]]; then
        zenity --error --text="Herhangi bir ürün seçilmedi."
        return
    fi

    # Seçilen ürünün bilgilerini ayrıştır
    local product_id=$(echo "$selected_product" | awk -F, '{print $1}')
    local product_category=$(echo "$selected_product" | awk -F, '{print $5}')

    # Kullanıcıdan yeni bilgileri al
    local new_name=$(zenity --entry --title="Yeni Ürün Adı" --text="Yeni ürün adını girin:" --entry-text="$product_name")
    local new_stock=$(zenity --entry --title="Yeni Stok Miktarı" --text="Yeni stok miktarını girin:")
    local new_price=$(zenity --entry --title="Yeni Birim Fiyatı" --text="Yeni birim fiyatını girin:")
    local new_category=$(zenity --entry --title="Yeni Kategori" --text="Yeni kategoriyi girin:" --entry-text="$product_category")

    if [[ -z "$new_name" || -z "$new_stock" || -z "$new_price" || -z "$new_category" ]]; then
        zenity --error --text="Eksik bilgi girdiniz. Lütfen tekrar deneyin."
        return
    fi

    # Güncelleme işlemi
    local temp_file="temp_depo.csv"
    echo "Ürün Numarası,Ürün Adı,Stok Miktarı,Birim Fiyatı,Kategori" > "$temp_file"
    awk -F, -v id="$product_id" -v name="$new_name" -v stock="$new_stock" -v price="$new_price" -v category="$new_category" \
        'NR==1 {print $0} NR>1 {if ($1 == id) print $1 "," name "," stock "," price "," category; else print $0}' "$depo_file" >> "$temp_file"

    mv "$temp_file" "$depo_file"
    zenity --info --text="Ürün başarıyla güncellendi."
}


# Ürün Silme
function delete_product() {
    # Silmek istenen ürünün adını al
    product_name=$(zenity --entry --title="Ürün Sil" --text="Silmek istediğiniz ürünün adını girin:")

    # Ürünü bulalım
    found=0
    temp_file="temp.csv"
    matched_line=""
    while IFS=',' read -r id name stock price category; do
        if [[ "$name" == "$product_name" ]]; then
            found=1
            matched_line="$id,$name,$stock,$price,$category"
            break
        fi
    done < "$depo_file"

    # Ürün bulunamadıysa hata mesajı göster
    if [ "$found" -eq 0 ]; then
        zenity --error --text="Ürün bulunamadı!"
        return
    fi

    # Bulunan ürünü göster ve silme onayı al
    if ! zenity --question --title="Ürün Sil" --text="Bu ürünü silmek istediğinizden emin misiniz?\n\nBulunan Ürün:\n$matched_line"; then
        zenity --info --text="Ürün silme işlemi iptal edildi."
        return
    fi

    # Silme işlemi için ilerleme çubuğu göster
    (
    for i in {1..100}; do
        echo $((i))
        sleep 0.02
    done
    ) | zenity --progress --title="Ürün Siliniyor" --text="Ürün siliniyor..." --percentage=0 --auto-close

    # Ürünü sil ve veritabanını güncelle
    while IFS=',' read -r id name stock price category; do
        if [[ "$name" != "$product_name" ]]; then
            echo "$id,$name,$stock,$price,$category" >> "$temp_file"
        fi
    done < "$depo_file"

    mv "$temp_file" "$depo_file"
    zenity --info --text="Ürün başarıyla silindi."
}


# Kullanıcı Yönetimi Menüsü
function user_management_menu() {
    choice=$(zenity --list --title="Kullanıcı Yönetimi" --column="İşlem" \
        "Yeni Kullanıcı Ekle" "Kullanıcıları Listele" "Kullanıcı Güncelle" "Kullanıcı Silme" "Çıkış")

    case $choice in
        "Yeni Kullanıcı Ekle") add_user ;;
        "Kullanıcıları Listele") list_users ;;
        "Kullanıcı Güncelle") update_user ;;
        "Kullanıcı Silme") delete_user ;;
        "Çıkış") return ;;
        *) zenity --error --text="Geçersiz seçim" ;;
    esac
}


# Yeni Kullanıcı Ekle
function add_user() {
    username=$(zenity --entry --title="Yeni Kullanıcı Ekle" --text="Kullanıcı adı:")
    password=$(zenity --entry --title="Yeni Kullanıcı Ekle" --text="Şifre:")
    firstname=$(zenity --entry --title="Yeni Kullanıcı Ekle" --text="Adı:")
    lastname=$(zenity --entry --title="Yeni Kullanıcı Ekle" --text="Soyadı:")
    role=$(zenity --entry --title="Yeni Kullanıcı Ekle" --text="Rol (Yönetici/Kullanıcı):")

    # Kullanıcıyı dosyaya ekle
    echo "$username,$password,$firstname,$lastname,$role" >> "$kullanici_file"
    zenity --info --text="Kullanıcı başarıyla eklendi."
}

# Kullanıcı Listeleme
function list_users() {
    zenity --text-info --filename="$kullanici_file" --title="Kullanıcı Listesi"
}


# Kullanıcı Güncelle
function update_user() {
    username=$(zenity --entry --title="Kullanıcı Güncelle" --text="Güncellemek istediğiniz kullanıcı adı:")
    
    # Kullanıcıyı bul ve düzenle
    if grep -q "^$username," "$kullanici_file"; then
        new_password=$(zenity --entry --title="Kullanıcı Güncelle" --text="Yeni Şifre:")
        new_firstname=$(zenity --entry --title="Kullanıcı Güncelle" --text="Yeni Adı:")
        new_lastname=$(zenity --entry --title="Kullanıcı Güncelle" --text="Yeni Soyadı:")
        new_role=$(zenity --entry --title="Kullanıcı Güncelle" --text="Yeni Rol (Yönetici/Kullanıcı):")
        
        # Eski kaydı sil ve yeni bilgileri ekle
        sed -i "/^$username,/d" "$kullanici_file"
        echo "$username,$new_password,$new_firstname,$new_lastname,$new_role" >> "$kullanici_file"
        zenity --info --text="Kullanıcı başarıyla güncellendi."
    else
        zenity --error --text="Kullanıcı bulunamadı."
    fi
}




# Kullanıcı Silme
function delete_user() {
    username=$(zenity --entry --title="Kullanıcı Silme" --text="Silmek istediğiniz kullanıcı adı:")

    if [ -z "$username" ]; then
        zenity --error --text="Kullanıcı adı boş bırakılamaz."
        return
    fi

    # Kullanıcı var mı kontrolü
    if grep -q "^$username," "$kullanici_file"; then
        # Onay iste
        zenity --question --title="Onay" --text="Kullanıcıyı silmek istediğinizden emin misiniz?"
        if [ $? -eq 0 ]; then
            (
                echo "50" ; sleep 2 # İlk aşama
                sed -i "/^$username,/d" "$kullanici_file"
                echo "100" ; sleep 1 # İşlem tamamlandı
            ) | zenity --progress --title="Kullanıcı Silme" --text="Kullanıcı siliniyor..." --percentage=0 --auto-close

            if [ $? -eq 0 ]; then
                zenity --info --text="Kullanıcı başarıyla silindi."
            else
                zenity --error --text="İşlem iptal edildi."
            fi
        else
            zenity --info --text="Kullanıcı silme işlemi iptal edildi."
        fi
    else
        zenity --error --text="Kullanıcı bulunamadı."
    fi
}




# Program Yönetimi Menüsü
function show_program_management() {
    choice=$(zenity --list --title="Program Yönetimi" --column="İşlem" \
        "Yedekleme" "Hata Kayıtları" "Disk Alanı Göster" "Dosya İzinlerini Yönet" "Çıkış")

    case $choice in
        "Yedekleme") backup_program ;;
        "Hata Kayıtları") show_error_logs ;;
        "Disk Alanı Göster") show_disk_usage ;;
        "Dosya İzinlerini Yönet") select_directory_for_permissions ;;
        "Çıkış") return ;;
        *) zenity --error --text="Geçersiz seçim" ;;
    esac
}
# Yedekleme Fonksiyonu
function backup_program() {
    timestamp=$(date "+%Y%m%d_%H%M%S")
    backup_file="$backup_dir/backup_$timestamp.tar.gz"
    mkdir -p "$backup_dir"
    tar -czf "$backup_file" "$depo_file" "$kullanici_file" "$log_file"
    zenity --info --text="Yedekleme başarıyla tamamlandı: $backup_file"
}

# Hata Kayıtları
function show_error_logs() {
    zenity --text-info --filename="$log_file" --title="Hata Kayıtları"
}

# Disk Alanını Gösterme
function show_disk_usage() {
    disk_usage=$(du -sh "$0" "$depo_file" "$kullanici_file" "$log_file" 2>/dev/null)
    zenity --info --text="Belirtilen dosyaların toplam disk kullanımı:\n\n$disk_usage"
}






# Dosya izinlerini sorgulama fonksiyonu
function check_file_permissions() {
    local directory=$1

    # Dizin altındaki tüm dosyaları bul
    files=$(find "$directory" -type f)

    # Dosya yoksa bilgi ver
    if [[ -z "$files" ]]; then
        zenity --info --text="Seçilen dizinde dosya bulunamadı."
        return
    fi

    # Dosya izinlerini kontrol et
    permission_info=""
    for file in $files; do
        # Mevcut dosya izinlerini kontrol et
        current_permissions=$(stat -c "%A" "$file")
        # Dosya izinlerini birleştir
        permission_info="$permission_info\n$file: $current_permissions"
    done

    # İzin bilgilerini göster
    zenity --info --title="Dosya İzinleri" --text="$permission_info"
}

# Dosya izinlerini değiştirme fonksiyonu
function change_file_permissions() {
    local directory=$1

    # Kullanıcıdan dosya izinlerini değiştirmek için onay al
    if zenity --question --title="Dosya İzinlerini Değiştir" --text="Seçilen dosyaların izinlerini değiştirmek ister misiniz?"; then
        # Kullanıcıdan yeni izin bilgisi al
        new_permissions=$(zenity --entry --title="Yeni İzinler" --text="Yeni dosya izinlerini (örneğin, 755) giriniz:")

        if [[ -z "$new_permissions" ]]; then
            zenity --error --text="Geçersiz izin girişi!"
            return
        fi

        # Dosya izinlerini güncelle
        for file in $(find "$directory" -type f); do
            chmod "$new_permissions" "$file"
        done

        zenity --info --text="Dosya izinleri başarıyla değiştirildi."
    else
        zenity --info --text="Dosya izinleri değiştirilmeyecek."
    fi
}

# Dosya izinlerini otomatik olarak ayarlama fonksiyonu
function auto_set_permissions() {
    local directory=$1

    # Dizin altındaki dosyaların izinlerini kontrol et ve ayarla
    for file in $(find "$directory" -type f); do
        # Dosyaya özel izinler
        if [[ "$file" =~ \.sh$ ]]; then
            chmod 755 "$file"
        else
            chmod 644 "$file"
        fi
    done

    zenity --info --text="Dosya izinleri başarıyla ayarlandı."
}

# Dosya izinlerini sorgulamak için dizin seçme fonksiyonu
function select_directory_for_permissions() {
    # Kullanıcıdan dizin seçmesi istenir
    local directory=$(zenity --file-selection --directory --title="Dizin Seç")

    if [[ -z "$directory" ]]; then
        zenity --error --text="Bir dizin seçmelisiniz."
        return
    fi

    # Dosya izinlerini kontrol et
    check_file_permissions "$directory"

    # Dosya izinlerini değiştirme veya otomatik ayarlama seçeneği sunuluyor
    action=$(zenity --list --title="İşlem Seçin" --column="İşlem" \
        "Dosya İzinlerini Değiştir" "Otomatik Olarak İzin Ayarla" "Çıkış")

    case $action in
        "Dosya İzinlerini Değiştir")
            change_file_permissions "$directory"
            ;;
        "Otomatik Olarak İzin Ayarla")
            auto_set_permissions "$directory"
            ;;
        "Çıkış")
            zenity --info --text="İşlem iptal edildi."
            ;;
        *)
            zenity --error --text="Geçersiz işlem seçildi."
            ;;
    esac
}






# Ana giriş
role=$(login)

if [[ "$role" == "Yönetici" ]]; then
    while true; do
        show_admin_menu
    done
elif [[ "$role" == "Kullanici" ]]; then
    while true; do
        show_user_menu
    done
else
    zenity --error --text="Giriş başarısız. Program sonlandırılıyor."
    exit 1
fi

