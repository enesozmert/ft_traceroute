# VM Test Raporu — ft_traceroute

> Tarih: 2026-11-14
> Amaç: T-1003 — değerlendirme ortamına denk bir Linux VM'de doğrulama
> Subject şartı: *"You will have to be in a VM with a Linux core >= 4.0"*

---

## 1. Ortam

| Alan | Değer |
|------|-------|
| Hypervisor | VirtualBox 7.2.16 (headless, arayüz yok) |
| Host | macOS 26.5.1, Apple Silicon (arm64) |
| Guest | Debian 13 (trixie) cloud image, arm64 |
| Kernel | `6.12.116+deb13-arm64` — subject şartı ≥ 4.0 ✅ |
| CPU / RAM | 4 vCPU / 4096 MB |
| Ağ | NAT + port forward `127.0.0.1:2222 -> 22` |
| Provisioning | cloud-init (NoCloud seed ISO), SSH anahtarıyla |
| Erişim | `ssh -i ~/vm/ft_traceroute/id_vm -p 2222 tester@127.0.0.1` |

VM tamamen headless kuruldu; hiçbir adımda GUI kullanılmadı. Disk, Debian
cloud image'ının `qemu-img` ile VDI'ya çevrilmiş hâlidir, kullanıcı ve paketler
cloud-init ile sağlanmıştır.

---

## 2. Test suite — 47/47

```
==> 47 passed, 0 failed, 0 skipped
```

Hiçbir case SKIP değil: VM'de root olduğumuz için raw ICMP socket gerektiren
T-7xx ve T-82x case'leri de koştu.

| Grup | Kapsam | Sonuç |
|------|--------|-------|
| T-1xx | Executable adı, Makefile kuralları, `fclean`/`re` davranışı | ✅ 7/7 |
| T-2xx | `O_NONBLOCK` / `fcntl` / `system` / `exec*` / `popen` yok, libC-only link | ✅ 4/4 |
| T-5xx | CLI kontratı, IPv4 ve FQDN girişi, hata yolları | ✅ 10/10 |
| T-7xx | Banner, hop satırı, reverse DNS yok, layout, hop numaraları, durma, SIGINT, ±30 ms | ✅ 9/9 |
| T-8xx | Bonus flag doğrulaması ve `--help` metni | ✅ 12/12 |
| T-82x | Bonus flag'lerin canlı trace etkisi | ✅ 5/5 |

---

## 3. Kalite kapıları (VM içinde)

| Kapı | Sonuç |
|------|-------|
| Norminette | 22/22 dosya OK, **0 error** |
| Strict build (`-Wpedantic -Wshadow -Wconversion -Wcast-align -Wstrict-prototypes`) | `rc=0`, **0 warning** |
| Cppcheck | 2 style bulgusu (`variableScope`, norm nedeniyle belgelenmiş deviation), 0 bug |
| Valgrind | 6 yol, hepsinde `ERROR SUMMARY: 0 errors`, leak yok |
| `make diff-ref` | `layout identical` |

Valgrind koşulan yollar: `--help`, bilinmeyen host, argümansız, `-m 0`,
`-q 99`, ve SIGINT ile kesilen canlı `-m 2 --resolve` trace'i.

---

## 4. Koşu sırasında bulunan ve düzeltilen sorun

**Makefile `all` kuralı binary'ye sessizce `setcap cap_net_raw+ep` uyguluyordu.**

Belirti: VM'de `make valgrind` çalışmıyordu —

```
valgrind: Can't execute setuid/setgid/setcap executable: ./output/ft_traceroute
valgrind: ./output/ft_traceroute: Permission denied
```

Valgrind, capability taşıyan bir dosyayı güvenlik gereği çalıştırmayı reddeder.
Docker container'ında root olarak çalıştığımız ve `setcap` orada da uygulandığı
hâlde sorun görünmemişti, çünkü testleri hep root olarak koşmuştuk; VM'de normal
kullanıcıyla koşunca ortaya çıktı.

Düzeltme:

- `all` kuralından otomatik `setcap` kaldırıldı. Yetki artık yalnızca açıkça
  `make setcap` denince veriliyor — build'in sessiz bir yan etkisi olmaktan
  çıktı.
- `valgrind` hedefi, önceki bir `make setcap`'in bıraktığı capability'yi
  çalıştırmadan önce `setcap -r` ile temizliyor.

İkincil etki: `sudo make` çalıştırıldığında `output/` dizini root'a geçtiği için
sonraki `make fclean` `Permission denied` veriyordu. Otomatik setcap kalkınca
build'i root olarak çalıştırma gerekçesi de ortadan kalktı.

---

## 5. VM'de kapanamayan madde — T-1004

Çok hop'lu gerçek yol **bu makinede doğrulanamıyor**, ve bu bizim kodumuzla
ilgili değil:

```
$ sudo traceroute -n -m 10 8.8.8.8      # gerçek traceroute, VM içinde
traceroute to 8.8.8.8 (8.8.8.8), 10 hops max, 60 byte packets
 1  10.0.2.2  0.077 ms  0.064 ms  0.060 ms
 2  * * *
 ...
10  * * *
```

Referans `traceroute` de hop 1'den sonrasını göremiyor. Sebep VirtualBox NAT
katmanının upstream router'lardan gelen ICMP Time Exceeded mesajlarını guest'e
iletmemesi. Aynı davranış Docker Desktop'ın NAT'ında da görülüyor.

Denenen ve çalışmayan alternatif: VirtualBox bridged adapter. Host arayüzü Wi-Fi
(`en0`) olduğu için vmnet reddediyor:

```
vmnet_start_interface returned 1001 (VERR_INVALID_PARAMETER)
Failed to attach the network LUN (VERR_INVALID_PARAMETER)
```

**Sonuç:** T-1004 kablolu/bridged ağı olan bir makinede veya okul VM'inde
kapatılmalı. Referans araç bizimle aynı çıktıyı verdiği için davranış paritesi
zaten gösterilmiş durumda; eksik olan ortam, implementasyon değil.

Kapatma komutu (bridged ağı olan bir Linux'ta):

```bash
make && make test && make test-net NET_HOST=8.8.8.8
```

---

## 6. Özet

| Madde | Durum |
|-------|-------|
| T-1003 — Linux kernel ≥ 4.0 VM'de doğrulama | ✅ kapandı (kernel 6.12, 47/47 test) |
| T-1004 — çok hop'lu gerçek ağ | ⚠ ortam engeli; NAT ICMP'yi yutuyor, referans araç da aynı |
| Koşu sırasında bulunan hata | ✅ düzeltildi (Makefile otomatik setcap) |
