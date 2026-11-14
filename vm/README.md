# vm/ — doğrulama VM'i

Subject, değerlendirmenin **Linux kernel ≥ 4.0** olan bir VM'de yapılacağını
söylüyor. Bu klasör o VM'i tek komutla, **arayüzsüz (headless)** kurar.

VM image'ının kendisi repoya konmadı: `disk.vdi` 1,3 GB ve GitHub'ın dosya
başına sınırı 100 MB. Onun yerine burada **tarif** var — resmi Debian cloud
image'ını indirip aynı makineyi üretir.

## Kullanım

```bash
sh vm/create-vm.sh          # VM'i kur ve başlat (ilk sefer ~5 dk, image indirir)
sh vm/run-tests.sh          # projeyi senkronla, VM'de test suite'i koş
sh vm/run-tests.sh gates    # ek olarak norminette / strict / valgrind / diff-ref
sh vm/create-vm.sh destroy  # VM'i ve diskini sil
ssh -i ~/vm/ft_traceroute/id_vm -p 2222 tester@127.0.0.1
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
