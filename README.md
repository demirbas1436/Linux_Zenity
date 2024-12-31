# Proje Adı: Depo ve Kullanıcı Yönetimi Sistemi

Bu proje, bir şirketin depo ve kullanıcı yönetimini kolaylaştırmak için tasarlanmış bir Bash scriptidir. Zenity kullanılarak grafiksel arayüz sunar ve ürün yönetimi, kullanıcı yönetimi, şifre sıfırlama ve hata kayıtları gibi birçok fonksiyonu destekler.

## Özellikler

- **Kullanıcı Doğrulama:** Kullanıcı adı ve şire ile giriş.
- **Hesap Kilitleme:** Çok fazla başarısız giriş durumunda hesap kilitlenir.
- **Kullanıcı Yönetimi:** Yeni kullanıcı ekleme, güncelleme ve silme.
- **Depo Yönetimi:** Ürün ekleme, listeleme, güncelleme ve silme.
- **Raporlama:** Stok durumu ve toplam değer raporları.
- **Dosya Yönetimi:** Dosya yedekleme, hata kayıtlarını görüntüleme ve dosya izinlerini düzenleme.

## Gereksinimler

Bu scriptin çalışabilmesi için aşağıdaki yazılımların kurulu olması gerekir:

- **Bash:** Çoğu Linux ve macOS sistemlerinde yüklü gelir.
- **Zenity:** Grafiksel arayüz için kullanılır.

Zenity kurulumu için Ubuntu tabanlı bir sistemde:
```bash
sudo apt-get install zenity
```

## Kurulum

1. Bu projeyi klonlayın veya dosyayı indirin:
   ```bash
   git clone <https://github.com/demirbas1436/Linux_Zenity/blob/main/deneme2.sh>
   cd <proje-dizini>
   ```

2. Scriptin çalışabilirliğini kontrol edin:
   ```bash
   chmod +x deneme2.sh
   ```

3. Gerekli dizin ve dosyaların var olduğundan emin olun. Aksi takdirde script ılgili dosyaları otomatik olarak oluşturur.

## Kullanım

Scripti çalıştırmak için:
```bash
./deneme2.sh
```

### Kullanıcı Rolleri

- **Yönetici:** Depo yönetimi, kullanıcı yönetimi ve program yönetimi gibi tüm fonksiyonlara erişim.
- **Kullanıcı:** Yalnızca ürün listeleme ve rapor alma işlemleri.

### Fonksiyonlar ve Koddan Örnekler

#### Kullanıcı Doğrulama (check_user)
Bu fonksiyon, kullanıcının girdiği ad ve şifreyi kontrol eder. Hesap kilitliyse veya bilgiler yanlışsa ilgili kayıtları log dosyasına ekler.

**Koddan Kesit:**
```bash
function check_user() {
    local username=$1
    local password=$2
    local date_time=$(date "+%Y-%m-%d %H:%M:%S")

    if grep -q "^$username$" "$locked_accounts"; then
        zenity --error --text="Hesabınız kilitlenmiştir. Lütfen yöneticiyle iletişime geçin."
        echo "$date_time, $username, HATA: Hesap kilitli" >> "$log_file"
        return
    fi

    echo "$date_time, $username, $password, Hatalı giriş" >> "$log_file"
    increment_failed_attempts "$username"
}
```

#### Depo Yönetimi: Ürün Ekleme (add_product)
Bu fonksiyon, kullanıcıdan ürün bilgilerini alır ve depo dosyasına kaydeder. Ürün bilgileri eşsiz olmalıdır.

**Koddan Kesit:**
```bash
function add_product() {
    local max_product_id=$(awk -F, 'NR > 1 {if ($1 > max) max = $1} END {print max}' "$depo_file")
    local new_product_id=$((max_product_id + 1))

    product_info=$(zenity --forms --title="Ürün Ekle" \
        --add-entry="Ürün Adı" \
        --add-entry="Stok Miktarı" \
        --add-entry="Birim Fiyatı" \
        --add-entry="Kategori")

    IFS="|" read -r product_name stock_quantity unit_price category <<< "$product_info"

    echo "$new_product_id,$product_name,$stock_quantity,$unit_price,$category" >> "$depo_file"
    zenity --info --text="Ürün başarıyla eklendi. Ürün Numarası: $new_product_id"
}
```

#### Raporlama (generate_report)
Raporlama fonksiyonu, stok durumu ve toplam depo değeri gibi çıktılar oluşturur. Kritik stok seviyelerinde uyarı verir.

**Koddan Kesit:**
```bash
function generate_report() {
    report_type=$(zenity --list --title="Rapor Türü Seçin" --column="Seçenek" \
        "Stokta Azalan Ürünler" \
        "En Yüksek Stok Miktarına Sahip Ürünler" \
        "Toplam Ürün Değerini Hesapla")

    case $report_type in
        "Stokta Azalan Ürünler")
            awk -F, 'NR > 1 && $3 < 10' "$depo_file" > low_stock.txt
            zenity --text-info --filename="low_stock.txt" --title="Stokta Azalan Ürünler"
            ;;
        "Toplam Ürün Değerini Hesapla")
            total_value=$(awk -F, 'NR > 1 { toplam += $3 * $4 } END { print toplam }' "$depo_file")
            zenity --info --text="Depodaki toplam ürünlerin toplam değeri: $total_value"
            ;;
    esac
}
```

## Tanıtım Videosu
Projenin kullanımıyla ilgili detaylı bir tanıtım videosunu [https://www.youtube.com/watch?v=NfVmpycYMQc](#).

## Ekstra Kaynaklar
Zenity hakkında daha fazla bilgi edinmek için bu [Medium yazısını](#) inceleyebilirsiniz.

## Dosya Yapısı

- `deneme2.sh`: Ana script dosyası.
- `depo.csv`: Ürün bilgileri.
- `kullanici.csv`: Kullanıcı bilgileri.
- `log.csv`: Hata ve etkinlik kayıtları.
- `backup/`: Yedekleme dosyalarının tutulduğu dizin.

## Katkı

Katkı sağlamak için lütfen bir **pull request** oluşturun veya herhangi bir sorunu **issue** olarak bildiriniz.
