# ft_traceroute

> Ecole 42 — Network Programming Project (Subject v5.0)
> `traceroute` komutunun **C** dilinde sıfırdan yeniden yazılması.

[![Norminette](https://img.shields.io/badge/norminette-22%2F22%20OK%20(0%20errors)-brightgreen)](docs/tasks/TASKS.md)
[![Tests](https://img.shields.io/badge/tests-50%2F50%20passing-brightgreen)](test/run_tests.sh)
[![Valgrind](https://img.shields.io/badge/valgrind-0%20errors%20%2F%200%20leaks-brightgreen)](docs/tasks/TASKS.md)
[![Strict](https://img.shields.io/badge/strict%20build-0%20warnings-brightgreen)](Makefile)

---

## İçindekiler

- [Genel Bakış](#genel-bakış)
- [Hızlı Başlangıç](#hızlı-başlangıç)
- [Makefile Hedefleri](#makefile-hedefleri)
- [Doğrulama VM'i](#doğrulama-vmi)
- [Nasıl Çalışır](#nasıl-çalışır)
- [Quality Gates](#quality-gates)
- [Proje Yapısı](#proje-yapısı)
- [Dokümantasyon](#dokümantasyon)
- [Sınırlar & Bilinen Sorunlar](#sınırlar--bilinen-sorunlar)
- [AI Kullanımı](#ai-kullanımı)

---

## Genel Bakış

ft_traceroute, bir IP paketinin hedefe giderken izlediği yolu hop hop ortaya
çıkarır. Subject (Ecole 42 v5.0) tarafından zorunlu kılınan:

- Executable adı `ft_traceroute`, build `make` ile
- Yönetilen **tek** opsiyon: `--help`
- Tek parametre: IPv4 adresi veya hostname
- FQDN desteği — ancak **hop gösteriminde DNS resolution yok**
- Hop başına ±30 ms sapma toleransı
- Socket'ler `O_NONBLOCK` moduna **alınmaz** (bekleme `select(2)` ile)
- Sadece libC
- Gerçek `traceroute` komutunu çağırmak **yasak**
- Çıktı girintisi gerçek `traceroute` ile **birebir aynı**

Bonus olarak `-m` `-q` `-p` `-w` flag'leri ve opt-in reverse DNS (`--resolve`)
eklenmiştir — mandatory davranış bayraksız çalıştırmada değişmez.

Subject dosyası: [`docs/main/en.subject.pdf`](docs/main/en.subject.pdf)

---

## Hızlı Başlangıç

### Docker (önerilen — host bağımsız, Linux davranışı garanti)

```bash
docker compose -f docker/docker-compose.yml up -d --build
docker exec -it ft_traceroute_container bash
# container içinde:
make
./output/ft_traceroute 8.8.8.8
```

### Native Linux

```bash
make
sudo setcap cap_net_raw+ep output/ft_traceroute   # bir kez; ya da sudo ile çalıştır
./output/ft_traceroute google.com
./output/ft_traceroute --help

# bonus flag'ler
./output/ft_traceroute -m 15 -q 1 google.com      # 15 hop, hop başına 1 probe
./output/ft_traceroute -p 40000 -w 2 8.8.8.8      # base port + bekleme süresi
./output/ft_traceroute --resolve 8.8.8.8          # hop'larda reverse DNS
```

Raw ICMP socket root veya `CAP_NET_RAW` ister; UDP gönderim socket'i istemez.

> **Not:** `make` yetkiyi **otomatik vermez**. Bu bilinçli: capability taşıyan bir
> dosyayı valgrind çalıştırmayı reddeder (`Can't execute setuid/setgid/setcap
> executable`), yani otomatik `setcap` kalite kapılarından birini sessizce
> kapatıyordu. Yetki yalnızca `make setcap` ile veriliyor; `make valgrind` de
> çalışmadan önce kalmış capability'yi `setcap -r` ile temizliyor.

### Örnek çıktı

```
traceroute to 8.8.8.8 (8.8.8.8), 30 hops max, 60 byte packets
 1  172.23.0.1  0.545 ms  0.466 ms  0.429 ms
 2  * * *
```

---

## Makefile Hedefleri

### Subject zorunlu

| Hedef | İş |
|-------|-----|
| `make` / `make all` | `output/ft_traceroute` üretir |
| `make clean` | `.o` ve `.d` dosyalarını siler |
| `make fclean` | `clean` + executable ve `output/` siler |
| `make re` | `fclean` + `all` |

### Çalıştırma

| Hedef | İş |
|-------|-----|
| `make run ARGS="8.8.8.8" SUDO=1` | binary'yi argümanlarla çalıştırır |
| `make setcap` | `CAP_NET_RAW` verir (sudo ister) — build bunu otomatik yapmaz |

### Kalite

| Hedef | İş |
|-------|-----|
| `make norm` | Ecole 42 norminette |
| `make cppcheck` | cppcheck statik analiz → `cppcheck.txt` |
| `make misra` | MISRA C:2012 addon → `misra.txt` |
| `make strict` | `-Wpedantic -Wshadow -Wconversion -Wcast-align -Wstrict-prototypes` ile yeniden derler |
| `make asan` | AddressSanitizer build |

### Test

| Hedef | İş |
|-------|-----|
| `make test` | 50 case'lik suite; yetki yoksa ağ case'leri SKIP |
| `make test-net NET_HOST=8.8.8.8` | canlı trace testi (root/`CAP_NET_RAW` ister) |
| `make test-net-docker` | aynısını container içinde koşar |
| `make valgrind` | leak/hata taraması; önce capability'yi temizler |
| `make diff-ref DIFF_HOST=8.8.8.8` | gerçek `traceroute -n` ile layout diff'i |

### Diğer

| Hedef | İş |
|-------|-----|
| `make cmake-build` | CMake ile `build/` altında derler |
| `make cmake-clean` | `build/` siler |
| `make help` | tüm hedefleri listeler |

Ortam değişkenleri: `NET_HOST`, `NET_TIMEOUT`, `DIFF_HOST`, `VALGRIND_HOST`,
`CONTAINER`, `ARGS`, `SUDO`.

---

## Doğrulama VM'i

Subject değerlendirmenin **Linux kernel ≥ 4.0** olan bir VM'de yapılacağını
söylüyor. `vm/` klasörü o VM'i tek komutla, **arayüzsüz (headless)** kurar.

### Yeni bir makinede sıfırdan

```bash
# 1. host araçları
#    macOS:          brew install --cask virtualbox && brew install qemu
#    Debian/Ubuntu:  sudo apt install virtualbox qemu-utils genisoimage
#    Fedora:         sudo dnf install VirtualBox qemu-img xorriso

# 2. VM'i kur ve başlat (ilk sefer ~5-10 dk: ~400 MB Debian image indirir,
#    VDI'ya çevirir, cloud-init paketleri kurar)
sh vm/create-vm.sh

# 3. script en sonda bağlantı bilgisini basar:
#      ssh -i ~/vm/ft_traceroute/id_vm -p 2222 tester@127.0.0.1
#    altında ~/.ssh/config'e yapıştırılacak hazır blok da var

# 4. testleri VM'de koş
sh vm/run-tests.sh          # test suite        -> 50/50 bekleniyor
sh vm/run-tests.sh gates    # + norminette / strict / valgrind / diff-ref
```

**SSH anahtarı repoda yok** — olmamalı da. Script her makinede kendi
`id_vm` anahtarını üretir.

**Nereye kuruluyor:** disk ~1,3 GB + image ~400 MB. 42 makinelerinde ev dizini
kotası bunu kaldırmadığı için script **goinfre varsa oraya** kurar
(`$HOME/goinfre` → `/goinfre/$USER` → `$HOME/sgoinfre` → `/sgoinfre/$USER`,
yoksa `$HOME/vm`). Başlarken hangisini seçtiğini basar, yer azsa uyarır.
Elle vermek için `VM_DIR=/başka/yol sh vm/create-vm.sh`.

**TLS hatası** (`curl: (60) ... unable to get local issuer certificate`) 42
makinelerinde sık görülür: host'ta kullanılabilir CA bundle yoktur. Script
sırayla dener — bulunan CA bundle ile `curl`, curl'ün varsayılanları, `wget`,
son olarak **düz HTTP + mirror'ın `SHA512SUMS`'ına karşı doğrulama**. Hiçbir
adımda TLS doğrulaması kapatılmıyor. Hepsi başarısız olursa
`sudo apt install ca-certificates && sudo update-ca-certificates`, ya da
`CURL_CA_BUNDLE=/path/to/bundle.crt sh vm/create-vm.sh`. Script doğrulamayı
kendi kendine kapatmaz.

Script tekrar çalıştırılabilir: VM kuruluysa yeniden kurmaz, kapalıysa başlatır,
çalışıyorsa sadece bağlantı bilgisini basar.

### Günlük kullanım

```bash
sh vm/create-vm.sh                        # başlat / bilgiyi yeniden bas
ssh -i ~/vm/ft_traceroute/id_vm -p 2222 tester@127.0.0.1
VBoxManage controlvm ft-tr-vm poweroff    # durdur
sh vm/create-vm.sh destroy                # VM'i ve diskini sil
```

İlk koşudan hemen sonra `vm/run-tests.sh` paket eksikliğinden patlarsa
cloud-init hâlâ kuruyordur; bir kez bekle:

```bash
ssh -i ~/vm/ft_traceroute/id_vm -p 2222 tester@127.0.0.1 'sudo cloud-init status --wait'
```

### Ayarlar

```bash
SSH_PORT=2345 MEMORY=8192 CPUS=8 DISK_MB=20480 sh vm/create-vm.sh
ARCH=amd64 sh vm/create-vm.sh          # mimariyi zorla (varsayılan: host'unki)
VM_NAME=ft-tr-2 sh vm/create-vm.sh     # ikinci bir VM
VM_DIR=/goinfre/$USER/tr sh vm/create-vm.sh   # kurulum yerini elle ver
CURL_CA_BUNDLE=/path/to/bundle.crt sh vm/create-vm.sh   # TLS sorunu varsa
BRIDGE="enp0s31f6" sh vm/create-vm.sh  # bridged ağ — çok hop'lu trace için
```

### Ne kuruluyor

| Alan | Değer |
|------|-------|
| Guest | Debian 13 (trixie) cloud image, host mimarisine göre arm64 / amd64 |
| Kernel | 6.12.x — subject şartı ≥ 4.0 |
| CPU / RAM / Disk | 4 vCPU / 4096 MB / 12 GB (env ile değişir) |
| Ağ | NAT + `127.0.0.1:2222 -> 22` (veya `BRIDGE=` ile bridged) |
| Kullanıcı | `tester`, passwordless sudo, SSH anahtarıyla |
| Araçlar | gcc, make, traceroute, tcpdump, valgrind, cppcheck, norminette |

**VM image'ı repoda değil:** `disk.vdi` 1,3 GB ve GitHub dosya başına 100 MB
sınırı koyuyor. Repoda **tarif** var — resmi Debian image'ından aynı makineyi
üretir, repo 6 MB kalır.

Koşu raporu: [`docs/report/vm-test-report.md`](docs/report/vm-test-report.md)

---

## Nasıl Çalışır

```
TTL = 1  -> ilk router TTL'i düşürür -> ICMP Time Exceeded (type 11)
TTL = 2  -> ikinci router            -> ICMP Time Exceeded
...
TTL = n  -> hedef makine             -> ICMP Port Unreachable (type 3, code 3) -> dur
```

| Yön | Socket | Not |
|-----|--------|-----|
| gönderim | `SOCK_DGRAM` / UDP, port `33434 + n` | TTL `setsockopt(IP_TTL)` ile hop başına artar |
| alım | `SOCK_RAW` / `IPPROTO_ICMP` | ICMP hataları normal socket'e teslim edilmez |

**Probe eşleştirme:** raw ICMP socket host'a gelen *tüm* ICMP trafiğini
teslim eder. ICMP hata gövdesindeki **iç IP + UDP başlığının hedef portu**
tek güvenilir anahtardır. Detay: [`docs/rules/08-network-protocol.md`](docs/rules/08-network-protocol.md)

Protokol seçiminin subject'ten nasıl türetildiği: [`docs/sdd/SDD.md`](docs/sdd/SDD.md) §2.

---

## Quality Gates

### Norminette (Ecole 42)

```
22/22 dosya OK
0 Error
2 Notice (GLOBAL_VAR_DETECTED — g_interrupted, signal handler için zorunlu)
```

### Test suite (`make test`)

```
50 passed, 0 failed, 0 skipped        # root ile (Docker veya VM)
32 passed, 0 failed, 18 skipped       # yetkisiz host'ta — ağ case'leri atlanır
```

| Grup | Kapsam | Adet |
|------|--------|------|
| T-1xx | Executable adı, Makefile kuralları, `fclean`/`re` gerçekten çalışıyor mu | 7 |
| T-2xx | `O_NONBLOCK` / `fcntl` / `system` / `exec*` / `popen` yok, libC-only link | 4 |
| T-5xx | CLI kontratı, IPv4 ve FQDN girişi, hata yolları ve exit kodları | 10 |
| T-6xx | **Wire üzerinde protokol** (`tcpdump`): UDP 33434+ adımlama, 32 bayt payload, port unreachable | 3 |
| T-7xx | Banner, hop satırı, reverse DNS yok, layout, hop numaraları, durma, SIGINT, ±30 ms | 9 |
| T-8xx | Bonus flag doğrulaması ve `--help` metni | 12 |
| T-82x | Bonus flag'lerin canlı trace üzerindeki etkisi | 5 |

T-6xx / T-7xx / T-82x root veya `CAP_NET_RAW` ister (T-6xx ayrıca `tcpdump`);
yetki yoksa **SKIP** raporlanır — sessizce PASS olmaz.

Testlerin karşılaştırdığı referans kayıtlar [`test/fixtures/`](test/fixtures/)
altında: gerçek `traceroute` çıktısı, `tcpdump` ile yakalanmış UDP probe'ları ve
ICMP port unreachable yanıtı.

### Strict build

```
-Wall -Wextra -Werror -Wpedantic -Wshadow -Wconversion -Wcast-align
-Wstrict-prototypes   ->   0 warning
```

### Valgrind

```
0 errors, 0 leaks — her yolda
(--help, bilinmeyen host, argümansız, -m 0, değersiz -m, -q 99,
 ve SIGINT ile kesilen canlı -m 2 --resolve trace'i)
```

`make valgrind` çalışmadan önce binary'deki capability'yi temizler; aksi hâlde
valgrind dosyayı çalıştırmayı reddeder.

### Cppcheck

```
2 finding (style: variableScope) — norm blok içi değişken tanımını
yasakladığı için belgelenmiş deviation. 0 bug / 0 leak / 0 nullPointer.
```

### Yasak çağrı denetimi

```
grep -r O_NONBLOCK src/ hdr/              -> boş  (R-08)
grep -rE 'system\(|execv|popen' src/      -> boş  (R-10)
```

`getnameinfo` yalnızca bonus `--resolve` yolunda çağrılır; bayraksız
çalıştırmada hiç çalışmaz. Davranışsal güvence testi T-703'tür.

---

## Proje Yapısı

```
ft_traceroute/
├── Makefile                 # Subject zorunlu build sistemi
├── CMakeLists.txt           # Alternatif build (IDE)
├── README.md
│
├── src/                     # 22 .c dosyası — dosya başına bir public fonksiyon
│   ├── main.c               # argv -> init -> loop -> cleanup, tek exit noktası
│   ├── options_init.c       # mandatory varsayılanları
│   ├── parse_args.c         # --help, tek hedef, hata yolları
│   ├── parse_option.c       # bonus flag tablosu + aralık doğrulama
│   ├── print_usage.c
│   ├── resolve_hostname.c   # getaddrinfo, AF_INET
│   ├── trace_init.c         # t_traceroute yaşam döngüsü girişi
│   ├── trace_cleanup.c      # socket kapat + payload free
│   ├── create_sockets.c     # UDP send + raw ICMP recv
│   ├── create_payload.c     # 32 baytlık UDP payload
│   ├── create_target.c      # sockaddr_in
│   ├── trace_loop.c         # TTL 1..30, hop başına 3 probe
│   ├── send_probe.c         # IP_TTL + sendto + probe_port()
│   ├── wait_reply.c         # select(2), O_NONBLOCK yok
│   ├── recv_reply.c         # recvfrom + ICMP sınıflandırma
│   ├── match_probe.c        # iç IP+UDP başlığından port eşleştirme
│   ├── resolve_hops.c       # bonus: opt-in reverse DNS
│   ├── print_banner.c
│   ├── print_hop.c          # traceroute(8) satır düzeni
│   ├── compute_elapsed_ms.c # timeval yardımcıları
│   └── interrupt_handler.c  # sadece g_interrupted set eder
│
├── hdr/header.h             # merkezi header: wire struct'lar + prototipler
│
├── test/
│   ├── run_tests.sh         # T-1xx … T-82x test harness (50 case)
│   └── fixtures/            # referans çıktılar + tcpdump kayıtları
│
├── vm/                      # doğrulama VM'i (headless VirtualBox)
│   ├── create-vm.sh         # Debian 13 cloud image'dan VM kurar ve başlatır
│   ├── run-tests.sh         # projeyi VM'e senkronlar, suite'i root ile koşar
│   ├── common.sh            # goinfre tespiti + CA bundle çözümü
│   └── README.md
│
├── docker/
│   ├── Dockerfile           # Ubuntu 22.04, builder/runtime/dev
│   └── docker-compose.yml   # cap_add NET_RAW + NET_ADMIN
│
├── opt/norm_autofix.py      # Norminette mekanik düzeltici
│
└── docs/
    ├── main/en.subject.pdf              # subject (resmi)
    ├── sdd/SDD.md                       # tasarım dokümanı — kodlamadan önce yazıldı
    ├── rules/                           # 8 kural seti (subject, norm, MISRA, docker, protokol…)
    ├── command/                         # OS/build komut referansları
    ├── tasks/TASKS.md                   # faz bazlı görev listesi
    ├── report/report.md                 # durum raporu + savunma Q&A
    ├── report/vm-test-report.md         # VM koşu raporu
    └── presentation/
        ├── ft_traceroute-overview.pdf   # 3 sayfa A4 yatay teknik özet
        ├── ft_traceroute-surec.pdf      # 9 sayfa süreç anlatımı, sade dil
        └── PROJE-ANLATIMI.md            # savunma için hap bilgi kartı
```

---

## Dokümantasyon

| Konu | Dosya |
|------|-------|
| Subject (resmi PDF) | [`docs/main/en.subject.pdf`](docs/main/en.subject.pdf) |
| **Anlatım kartı (savunma)** | [`docs/presentation/PROJE-ANLATIMI.md`](docs/presentation/PROJE-ANLATIMI.md) |
| **Genel bakış PDF'i (3 sayfa)** | [`docs/presentation/ft_traceroute-overview.pdf`](docs/presentation/ft_traceroute-overview.pdf) |
| **Süreç anlatımı PDF'i (9 sayfa, sade dil)** | [`docs/presentation/ft_traceroute-surec.pdf`](docs/presentation/ft_traceroute-surec.pdf) |
| Tasarım dokümanı (SDD) | [`docs/sdd/SDD.md`](docs/sdd/SDD.md) |
| Subject kuralları | [`docs/rules/01-subject-rules.md`](docs/rules/01-subject-rules.md) |
| Ağ protokolü | [`docs/rules/08-network-protocol.md`](docs/rules/08-network-protocol.md) |
| Görev listesi | [`docs/tasks/TASKS.md`](docs/tasks/TASKS.md) |
| Durum raporu + savunma Q&A | [`docs/report/report.md`](docs/report/report.md) |
| VM koşu raporu | [`docs/report/vm-test-report.md`](docs/report/vm-test-report.md) |
| Doğrulama VM'i | [`vm/README.md`](vm/README.md) |
| Test referans kayıtları | [`test/fixtures/`](test/fixtures/) |
| Komut referansı | [`docs/command/COMMAND.md`](docs/command/COMMAND.md) |
| Norminette | [`docs/rules/02-norminette.md`](docs/rules/02-norminette.md) |
| Docker | [`docs/rules/04-docker-standards.md`](docs/rules/04-docker-standards.md) |

---

## Sınırlar & Bilinen Sorunlar

### Kapsam dışı bırakılanlar

- **IPv6 yok** — subject yalnızca IPv4 zorunlu kılıyor.
- **Bonus 5/5 dolu:** `-m` `-q` `-p` `-w` ve `--resolve`. `-i` `-s` `-t` `-l`
  `-N` eklenmedi — subject en fazla 5 bonus sayıyor.
- **ICMP code anotasyonları** (`!H` `!N` `!X`) mandatory kapsamında değil ve
  bonus kotası dolu olduğu için eklenmedi.

### Çok hop'lu gerçek yol — açık tek madde (T-1004)

NAT'lı ortamlarda **gerçek `traceroute` de** hop 1'den sonrasını göremiyor: NAT
katmanı upstream router'ların ICMP Time Exceeded mesajlarını iletmiyor. Hem
Docker Desktop hem VirtualBox NAT'ında aynı. Yani davranış paritesi gösterilmiş
durumda; eksik olan ortam, kod değil.

Kapatmak için VM'in gerçek bir LAN adresi olması gerekir:

```bash
BRIDGE="enp0s31f6" sh vm/create-vm.sh   # arayüz adı: ip link / VBoxManage list bridgedifs
sh vm/run-tests.sh
# veya doğrudan: make test-net NET_HOST=8.8.8.8
```

macOS'ta Wi-Fi üzerinden bridge çalışmıyor — vmnet
`vmnet_start_interface returned 1001` ile reddediyor. Kablolu arayüz gerekiyor.

Çıktı düzeni doğrulaması bundan etkilenmiyor: T-704 loopback üzerinde birebir
diff alıyor, T-709 uzak trace'in her satırını referans gramerine göre denetliyor.

### Ortam notları

- **macOS native build** derleniyor, ancak raw ICMP socket root istiyor ve BSD
  davranışı Debian değerlendirme ortamından sapabilir — Docker veya `vm/` önerilir.
- **`make` yetki vermiyor:** raw socket için `make setcap` veya `sudo` gerekiyor
  (gerekçe [Hızlı Başlangıç](#hızlı-başlangıç) bölümünde).
- **Yetkisiz host'ta** `make test` 18 case'i SKIP olarak raporluyor; bu bir hata
  değil, yanlış yeşil vermemek için.

---

## AI Kullanımı

Subject Chapter IV şeffaflık ister. Bu projede mimari tasarım, test matrisi ve
kod üretimi bir AI asistanı ile birlikte yapılmıştır; her tasarım kararı
[`docs/sdd/SDD.md`](docs/sdd/SDD.md) içinde gerekçesiyle belgelenmiştir ve
savunmada öğrenci tarafından açıklanır. AI'ın ilk önerileri gözden geçirilip
düzeltilmiştir — probe eşleştirme anahtarı (SDD §2) ve katman ayrımı (SDD §3.1)
bu düzeltmelerin örnekleridir.

---

**Yazar:** ozmerte (Ecole 42 — student)
**Subject:** Ecole 42 — `ft_traceroute` v5.0
**Bağımlılıklar:** yalnızca `libc`

  ft_traceroute git:(main) ✗ ssh -i /home/eozmert/goinfre/ft_traceroute/id_vm -p 2222 tester@127.0.0.1
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@    WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!     @
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
IT IS POSSIBLE THAT SOMEONE IS DOING SOMETHING NASTY!
Someone could be eavesdropping on you right now (man-in-the-middle attack)!
It is also possible that a host key has just been changed.
The fingerprint for the ED25519 key sent by the remote host is
SHA256:dzxvHL8rnxYfNT29hL4HV+eohcR2P+9SzGEEJDZ10B4.
Please contact your system administrator.
Add correct host key in /home/eozmert/.ssh/known_hosts to get rid of this message.
Offending ECDSA key in /home/eozmert/.ssh/known_hosts:5
  remove with:
  ssh-keygen -f "/home/eozmert/.ssh/known_hosts" -R "[127.0.0.1]:2222"
Host key for [127.0.0.1]:2222 has changed and you have requested strict checking.
Host key verification failed.
