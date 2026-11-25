# vm/ — doğrulama VM'i

Subject, değerlendirmenin **Linux kernel ≥ 4.0** olan bir VM'de yapılacağını
söylüyor. Bu klasör o VM'i tek komutla, **arayüzsüz (headless)** kurar.

VM image'ının kendisi repoya konmadı: `disk.vdi` 1,3 GB ve GitHub'ın dosya
başına sınırı 100 MB. Onun yerine burada **tarif** var — resmi Debian cloud
image'ını indirip aynı makineyi üretir.

## Yeni bir makinede sıfırdan

Repo'da SSH anahtarı **yok** — script her makinede kendi anahtarını üretir.
Tek yapman gereken:

```bash
# 1. host araçları
#    macOS:          brew install --cask virtualbox && brew install qemu
#    Debian/Ubuntu:  sudo apt install virtualbox qemu-utils genisoimage
#    Fedora:         sudo dnf install VirtualBox qemu-img xorriso

# 2. VM'i kur ve başlat  (ilk sefer ~5-10 dk: ~400 MB image indirir,
#    cloud-init paketleri kurar)
sh vm/create-vm.sh

# 3. script en sonda bağlantı bilgisini basar:
#      ssh -i ~/vm/ft_traceroute/id_vm -p 2222 tester@127.0.0.1
#    ve kopyalayıp ~/.ssh/config'e yapıştırabileceğin bir blok

# 4. testleri VM'de koş
sh vm/run-tests.sh          # test suite
sh vm/run-tests.sh gates    # + norminette / strict / valgrind / diff-ref
```

Script tekrar çalıştırılabilir: VM kuruluysa yeniden kurmaz, kapalıysa
başlatır, çalışıyorsa sadece bağlantı bilgisini basar.

> **VM boş geliyor.** `create-vm.sh` yalnızca makineyi kurar; proje içeride
> değildir ve paylaşılan klasör yoktur. İçeri almak için `sh vm/run-tests.sh sync`.
> Dosyalar VM'de `~/ft_traceroute` altına gelir. Host'ta bir şey değiştirdikten
> sonra tekrar `sync` demen gerekir.

## Günlük kullanım

```bash
sh vm/create-vm.sh                        # başlat (veya bilgiyi yeniden bas)
ssh -i ~/vm/ft_traceroute/id_vm -p 2222 tester@127.0.0.1
VBoxManage controlvm ft-tr-vm poweroff    # durdur
sh vm/create-vm.sh destroy                # VM'i ve diskini sil
```

İlk koşudan hemen sonra `vm/run-tests.sh` paket eksikliğinden patlarsa
cloud-init hâlâ kuruyordur; bir kez bekle:

```bash
ssh -i ~/vm/ft_traceroute/id_vm -p 2222 tester@127.0.0.1 'sudo cloud-init status --wait'
```

## Nereye kuruluyor

Disk ~1,3 GB + image ~400 MB. Bir 42 makinesinde ev dizini kotası bunu
kaldırmaz, bu yüzden script **goinfre varsa oraya** kurar:

```
1. $HOME/goinfre/ft_traceroute-vm      <- 42 makinelerinde bu seçilir
2. /goinfre/$USER/ft_traceroute-vm
3. $HOME/sgoinfre/ft_traceroute-vm
4. /sgoinfre/$USER/ft_traceroute-vm
5. $HOME/vm/ft_traceroute              <- goinfre yoksa
```

Sondaki `-vm` kasıtlı: repoyu `goinfre/ft_traceroute` içine klonlarsan VM
dizini **repoyla aynı yere** düşerdi ve 1,3 GB'lık `disk.vdi` git ağacının
içinde kalırdı. Script bunu ayrıca kontrol ediyor: VM dizini repoya eşit ya da
repo içindeyse çalışmayı reddediyor.

Script başlarken hangisini seçtiğini basar ve 2,5 GB'tan az boş yer varsa uyarır.
Elle vermek için: `VM_DIR=/başka/yol sh vm/create-vm.sh`

> goinfre düzenli olarak temizlenir. VM silinirse `sh vm/create-vm.sh` tekrar
> kurar; repoda duran tek şey tarif olduğu için kayıp yok.

## &#8220;REMOTE HOST IDENTIFICATION HAS CHANGED&#8221; alırsan

```
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@    WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!     @
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
```

Saldırı değil. `127.0.0.1:2222` adresini daha önce **başka bir VM** kullanmış;
onun host anahtarı `~/.ssh/known_hosts` içinde sabitlenmiş kalmış. Her yeni VM
kendi anahtarını üretir, ssh de değişikliği görünce bağlantıyı reddeder.

```bash
ssh-keygen -R "[127.0.0.1]:2222"     # eski kaydı sil, sonra tekrar bağlan
```

`create-vm.sh` bunu artık **kendisi yapıyor**: VM'i başlatmadan önce o porta ait
eski kaydı siliyor, `destroy` da silerken temizliyor. Script'in verdiği bağlantı
komutu da `known_hosts`'a hiç yazmıyor.

Şifre yok, gerekmiyor de &#8212; giriş SSH anahtarıyla. `tester` kullanıcısının
parolası kilitli değil ama ayarlanmamıştır; `sudo` parolasız.

## TLS hatası alırsan

42 makinelerinde sık görülür:

```
curl: (60) SSL certificate ... unable to get local issuer certificate
```

Image'da sorun yok — host'ta kullanılabilir bir CA bundle yok. Script sırayla
dener:

1. Bulunan CA bundle ile `curl` (`CURL_CA_BUNDLE`, `SSL_CERT_FILE`, bilinen
   trust store yolları, Python `certifi`)
2. `curl`'ün kendi varsayılanları
3. `wget` — ayrı CA yapılandırması taşır, curl'ün patladığı yerde çoğu zaman çalışır
4. **Düz HTTP + SHA512 doğrulaması** — mirror'ın yanında yayınladığı
   `SHA512SUMS` ile indirilen dosya denetlenir

4. adım, TLS'i hiç kullanamayan makineler için kaçış yolu. TLS'ten zayıf
(image'ı değiştirebilen checksum'ı da değiştirebilir) ama bozuk/yarım indirmeyi
yakalar — `curl -k`'nın yapmadığı şey. Script **hiçbir adımda doğrulamayı
kapatmıyor**.

Hepsi başarısız olursa:

```bash
# 1. trust store'u kur
sudo apt install ca-certificates && sudo update-ca-certificates

# 2. ya da elindeki bundle'ı göster
CURL_CA_BUNDLE=/path/to/ca-bundle.crt sh vm/create-vm.sh

# 3. ya da image'ı elle indirip VM_DIR'e koy, script indirmeyi atlar
```

Script **doğrulamayı kendi kendine kapatmaz**; `-k` ile indirmek yerine ne
yapılacağını söyler.

## Ayarlar

Hepsi ortam değişkeniyle değişir:

```bash
SSH_PORT=2345 MEMORY=8192 CPUS=8 DISK_MB=20480 sh vm/create-vm.sh
ARCH=amd64 sh vm/create-vm.sh          # mimariyi zorla
VM_NAME=ft-tr-2 sh vm/create-vm.sh     # ikinci bir VM
```

## Ne kuruluyor

| Alan | Değer |
|------|-------|
| Guest | Debian 13 (trixie) cloud image, host mimarisine göre arm64 veya amd64 |
| Kernel | 6.12.x — subject şartı ≥ 4.0 |
| CPU / RAM / Disk | 4 vCPU / 4096 MB / 12 GB (env ile değiştirilebilir) |
| Ağ | NAT + `127.0.0.1:2222 -> 22` port forward |
| Kullanıcı | `tester`, passwordless sudo, SSH anahtarıyla |
| Araçlar | gcc, make, traceroute, tcpdump, valgrind, cppcheck, norminette |

Firmware EFI, disk virtio, provisioning cloud-init (NoCloud seed ISO).

## Çok hop'lu test için

NAT'lı ağda **gerçek `traceroute` de** hop 1'den sonrasını göremez: NAT katmanı
upstream router'ların ICMP Time Exceeded mesajlarını guest'e iletmez. Çok hop'lu
yolu görmek için VM'in gerçek bir LAN adresi olması gerekir:

```bash
BRIDGE="en0: Ethernet" sh vm/create-vm.sh     # kablolu arayüz adı
```

macOS'ta Wi-Fi arayüzü üzerinden bridge çalışmaz; vmnet
`vmnet_start_interface returned 1001` ile reddeder.

Detaylı koşu raporu: [`../docs/report/vm-test-report.md`](../docs/report/vm-test-report.md)
