# ft_traceroute

> Ecole 42 — Network Programming Project (Subject v5.0)
> `traceroute` komutunun **C** dilinde sıfırdan yeniden yazılması.

[![Norminette](https://img.shields.io/badge/norminette-22%2F22%20OK%20(0%20errors)-brightgreen)](docs/tasks/TASKS.md)
[![Tests](https://img.shields.io/badge/tests-29%2F29%20passing-brightgreen)](test/run_tests.sh)
[![Valgrind](https://img.shields.io/badge/valgrind-0%20errors%20%2F%200%20leaks-brightgreen)](docs/tasks/TASKS.md)
[![Strict](https://img.shields.io/badge/strict%20build-0%20warnings-brightgreen)](Makefile)

---

## İçindekiler

- [Genel Bakış](#genel-bakış)
- [Hızlı Başlangıç](#hızlı-başlangıç)
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
sudo setcap cap_net_raw+ep output/ft_traceroute   # bir kez
./output/ft_traceroute google.com
./output/ft_traceroute --help

# bonus flag'ler
./output/ft_traceroute -m 15 -q 1 google.com      # 15 hop, hop başına 1 probe
./output/ft_traceroute -p 40000 -w 2 8.8.8.8      # base port + bekleme süresi
./output/ft_traceroute --resolve 8.8.8.8          # hop'larda reverse DNS
```

Raw ICMP socket root veya `CAP_NET_RAW` ister; UDP gönderim socket'i istemez.

### Örnek çıktı

```
traceroute to 8.8.8.8 (8.8.8.8), 30 hops max, 60 byte packets
 1  172.23.0.1  0.545 ms  0.466 ms  0.429 ms
 2  * * *
```

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
29 passed, 0 failed, 0 skipped

T-5xx  CLI kontratı (--help, argümansız, geçersiz opsiyon, iki hedef, bilinmeyen host)
T-7xx  banner layout, hop satırı layout, reverse DNS yok,
       gerçek traceroute ile layout birebir aynı
T-8xx  bonus flag doğrulaması (aralık, eksik değer, sondaki çöp karakter, --help metni)
T-82x  bonus flag'lerin canlı trace üzerindeki etkisi
```

T-7xx ve T-82x case'leri root/`CAP_NET_RAW` ister; yetki yoksa SKIP raporlanır.

### Strict build

```
-Wall -Wextra -Werror -Wpedantic -Wshadow -Wconversion -Wcast-align
-Wstrict-prototypes   ->   0 warning
```

### Valgrind

```
7/7 path: 0 errors, 0 leaks
(--help, bilinmeyen host, argümansız, -m 0, -m değersiz, -q 99,
 canlı trace -m 2 --resolve + SIGINT)
```

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
├── test/run_tests.sh        # T-5xx / T-7xx test harness
│
├── docker/
│   ├── Dockerfile           # Ubuntu 22.04, builder/runtime/dev
│   └── docker-compose.yml   # cap_add NET_RAW + NET_ADMIN
│
├── opt/norm_autofix.py      # Norminette mekanik düzeltici
│
└── docs/
    ├── main/en.subject.pdf  # subject (resmi)
    ├── sdd/SDD.md           # tasarım dokümanı — kodlamadan önce yazıldı
    ├── rules/               # 8 kural seti (subject, norm, MISRA, docker, protokol…)
    ├── command/             # OS/build komut referansları
    ├── tasks/TASKS.md       # faz bazlı görev listesi
    └── report/              # durum raporu
```

---

## Dokümantasyon

| Konu | Dosya |
|------|-------|
| Subject (resmi PDF) | [`docs/main/en.subject.pdf`](docs/main/en.subject.pdf) |
| Tasarım dokümanı (SDD) | [`docs/sdd/SDD.md`](docs/sdd/SDD.md) |
| Subject kuralları | [`docs/rules/01-subject-rules.md`](docs/rules/01-subject-rules.md) |
| Ağ protokolü | [`docs/rules/08-network-protocol.md`](docs/rules/08-network-protocol.md) |
| Görev listesi | [`docs/tasks/TASKS.md`](docs/tasks/TASKS.md) |
| Komut referansı | [`docs/command/COMMAND.md`](docs/command/COMMAND.md) |
| Norminette | [`docs/rules/02-norminette.md`](docs/rules/02-norminette.md) |
| Docker | [`docs/rules/04-docker-standards.md`](docs/rules/04-docker-standards.md) |

---

## Sınırlar & Bilinen Sorunlar

- **IPv6 desteği yok** — subject yalnızca IPv4 zorunlu kılar.
- **Bonus:** `-m` `-q` `-p` `-w` ve `--resolve` eklendi (5/5). `-i` `-s` `-t`
  `-l` `-N` eklenmedi — subject en fazla 5 bonus sayıyor.
- **Docker bridge ağı** hop 1'den sonrasını NAT arkasında gizler; çok hop'lu
  gerçek bir yol için native Linux veya host network gerekir. Çıktı düzeni
  doğrulaması bundan etkilenmez (T-704 üretilen hop sayısı kadar karşılaştırır).
- **macOS native build** derlenir, ancak raw ICMP socket root ister ve BSD
  davranışı Debian değerlendirme ortamından sapabilir; Docker önerilir.
- **ICMP code anotasyonları** (`!H`, `!N`, `!X`) mandatory kapsamında değil.

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
