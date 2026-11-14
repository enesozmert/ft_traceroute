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
