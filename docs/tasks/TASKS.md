# Task — ft_traceroute Görev Listesi

> Subject: [`docs/main/en.subject.pdf`](../main/en.subject.pdf) (v5.0)
> Tasarım: [`docs/sdd/SDD.md`](../sdd/SDD.md)
>
> Çalışma yöntemi: **analiz → plan → SDD → red test → kod → kalite → teslim**.
> Hiçbir uygulama dosyası, kendisini kapsayan test başarısız olmadan yazılmadı.

---

## Durum Lejantı

- ☐ — Yapılacak
- 🔄 — Devam ediyor
- ✅ — Tamamlandı
- ⚠ — Eksik / iyileştirme gerekli
- ❌ — Bloke / sorun var

---

## Faz 0 — Analiz ve tasarım

- ✅ T-001 — ft_ping projesi analiz edildi, yeniden kullanılabilir parçalar çıkarıldı
- ✅ T-002 — ft_ping'in katman hataları tespit edildi (loop socket fonksiyonunun içinde, handler'da `printf`)
- ✅ T-003 — Subject PDF okundu, mandatory/bonus maddeleri kurala çevrildi
- ✅ T-004 — Probe protokolü subject'ten türetildi: UDP 33434+ (SDD §2)
- ✅ T-005 — `docs/sdd/SDD.md` yazıldı (kodlamadan önce)
- ✅ T-006 — Test matrisi tanımlandı (T-5xx CLI / T-6xx protokol / T-7xx format / T-8xx bonus)

## Faz 1 — Build & altyapı

- ✅ T-101 — `Makefile` oluşturuldu
- ✅ T-102 — `all` rule mevcut
- ✅ T-103 — `clean` rule mevcut
- ✅ T-104 — `fclean` rule mevcut
- ✅ T-105 — `re` rule mevcut
- ✅ T-106 — `-Wall -Wextra -Werror` set edildi
- ✅ T-107 — Header dependency tracking (`-MMD -MP`)
- ✅ T-108 — `-std=c11` açıkça belirtildi
- ✅ T-109 — `strict` target: `-Wpedantic -Wshadow -Wconversion -Wcast-align -Wstrict-prototypes`
- ✅ T-110 — Executable adı `ft_traceroute` (`output/ft_traceroute`)
- ✅ T-111 — Docker imajı: Ubuntu 22.04 + `traceroute` referans binary'si
- ✅ T-112 — `docker-compose.yml`: `cap_add NET_RAW` + `NET_ADMIN`

## Faz 2 — RED: test harness

- ✅ T-201 — `test/run_tests.sh` yazıldı (implementasyondan önce)
- ✅ T-202 — `make test` harness'a delege ediyor, FAIL'de non-zero dönüyor
- ✅ T-203 — Yetki yoksa ağ case'leri SKIP raporluyor (yanlış yeşil yok)

## Faz 3 — CLI kontratı (R-03, R-04)

- ✅ T-505 — `--help` exit 0
- ✅ T-506 — `--help` usage'ı stdout'a basıyor
- ✅ T-511 — Argümansız çalıştırma → usage + exit≠0
- ✅ T-511b — Argümansız çalıştırmada usage **stderr**'e gidiyor
- ✅ T-512 — Geçersiz opsiyon → exit≠0
- ✅ T-513 — İki hedef → exit≠0
- ✅ T-520 — Bilinmeyen host → exit≠0
- ✅ T-521 — Bilinmeyen host mesajı stderr'de

## Faz 4 — Ağ çekirdeği (R-05 … R-10)

- ✅ T-601 — UDP gönderim socket'i (`SOCK_DGRAM`)
- ✅ T-602 — Raw ICMP alım socket'i (`SOCK_RAW / IPPROTO_ICMP`)
- ✅ T-603 — `setsockopt(IP_TTL)` hop başına
- ✅ T-604 — Probe portu: `33434 + (ttl-1)*nprobes + probe`
- ✅ T-605 — `select(2)` ile bekleme, `O_NONBLOCK` kullanılmadı
- ✅ T-606 — ICMP type 11 → transit hop
- ✅ T-607 — ICMP type 3 code 3 → hedefe ulaşıldı, döngü durur
- ✅ T-608 — `match_probe`: iç IP + UDP başlığından port eşleştirme
- ✅ T-609 — Tüm `memcpy` öncesi uzunluk kontrolü
- ✅ T-610 — IHL `(vhl & 0x0F) * 4` ile hesaplanıyor, sabit 20 varsayılmıyor
- ✅ T-611 — RTT doğrulaması: `tc netem delay 50ms` altında 50.4–52.4 ms ölçüldü
             (gerçek traceroute: 50.3–50.5 ms, sapma < 2 ms, tolerans ±30 ms)

## Faz 5 — Çıktı formatı (R-23)

- ✅ T-701 — Banner: `traceroute to HOST (IP), 30 hops max, 60 byte packets`
- ✅ T-702 — Hop satırı: `%2d ` + ` <adres>` + `  %.3f ms`
- ✅ T-703 — Hop gösteriminde reverse DNS yok (bayraksız çalıştırmada `getnameinfo` çağrılmaz)
- ✅ T-704 — Rakam-normalize edilmiş layout gerçek `traceroute -n` ile **birebir aynı**

## Faz 6 — Kalite kapıları

- ✅ T-801 — Norminette: 22/22 OK, 0 error
- ✅ T-802 — Cppcheck: 0 bug (2 style: `variableScope`, norm nedeniyle deviation)
- ✅ T-803 — Strict build: 0 warning
- ✅ T-804 — Valgrind: 7 path, 0 error, 0 leak (SIGINT'li canlı trace dahil)
- ✅ T-805 — Yasak çağrı denetimi: `O_NONBLOCK` / `system` / `exec*` / `popen` → hiçbiri yok
             (`getnameinfo` yalnızca bonus `--resolve` yolunda; bayraksız çalışmada çağrılmaz, güvence T-703)
- ✅ T-806 — Signal handler async-signal-safe (yalnızca `volatile sig_atomic_t` set eder)
- ✅ T-807 — Tek exit noktası `main`; yardımcı fonksiyonlarda `exit()` yok

## Faz 7 — Dokümantasyon

- ✅ T-901 — `README.md` — dosya listesi kodla birebir uyumlu
- ✅ T-902 — `docs/rules/01-subject-rules.md` — subject maddeleri kurala çevrildi
- ✅ T-903 — `docs/rules/08-network-protocol.md` — UDP/ICMP protokol kuralları
- ✅ T-904 — `docs/sdd/SDD.md` — tasarım + AI şeffaflık notu (subject Chapter IV)
- ✅ T-905 — `docs/tasks/TASKS.md` — bu dosya

## Faz 8 — Teslim

- ✅ T-1001 — `git init` + ilk commit
- ✅ T-1002 — `make fclean && make` temiz checkout'ta çalışıyor
- ✅ T-1005 — Bonus commit'i, mandatory regresyonu yok (29/29 test)
- ✅ T-1006 — `make cmake-build` doğrulandı (CMake ile de derleniyor)
- ✅ T-1007 — `make asan` doğrulandı (AddressSanitizer altında canlı trace temiz)
- ✅ T-1008 — `make diff-ref` doğrulandı → `layout identical`
- ✅ T-1009 — Makefile'ın `all` içindeki otomatik `setcap`'i kaldırıldı:
             capability'li binary valgrind'i sessizce kırıyordu (VM raporu §4)
             (referans koşu `traceroute -n` ile yapılır; subject hop'ta DNS'i yasakladığı
             için karşılaştırılabilir referans numerik olandır)
- ✅ T-1003 — Linux VM'de doğrulandı: VirtualBox headless, Debian 13 arm64,
             kernel 6.12.116, 47/47 test — [`docs/report/vm-test-report.md`](../report/vm-test-report.md)
- ⚠ T-1004 — Çok hop'lu gerçek ağ: NAT (hem Docker hem VirtualBox) upstream ICMP
             Time Exceeded'ı yutuyor; referans `traceroute` de aynı çıktıyı veriyor.
             Bridged ağı olan makinede veya okul VM'inde kapatılacak.

---

## Faz 9 — Bonus (5/5)

> Subject: bonus **yalnızca** mandatory PERFECT ise değerlendirilir.
> Maksimum 5 bonus. `-V` bonus sayılmaz.

- ✅ B-01 — DNS management: `--resolve` ile opt-in reverse lookup
             (varsayılan numerik kalır — subject R-06 bunu zorunlu kılıyor)
- ✅ B-02 — `-m <hops>` max hops (1–255)
- ✅ B-03 — `-q <probes>` hop başına probe (1–10)
- ✅ B-04 — `-p <port>` base UDP port (1–65535)
- ✅ B-05 — `-w <seconds>` probe bekleme süresi (1–60)

### Bonus test kapsamı

- ✅ T-801…T-807 — aralık dışı, eksik değer, sondaki çöp karakter (`-m 5x`) reddediliyor
- ✅ T-808…T-812 — `--help` her bonus flag'i belgeliyor
- ✅ T-820 — `-m 1` trace'i tek hop'ta kesiyor
- ✅ T-821 — `-q 1` hop başına tek probe gönderiyor
- ✅ T-822 — `-p 40000` eşleştirmeyi bozmuyor
- ✅ T-823 — `-w 1` kabul ediliyor
- ✅ T-824 — `--resolve` kabul ediliyor, hop satırı bozulmuyor
- ✅ Pozitif DNS kanıtı: `--resolve 127.0.0.1` → `localhost (127.0.0.1)`

### Bonus tasarım kararı — neden `--resolve`, neden `-n` değil

Gerçek traceroute varsayılan olarak reverse DNS yapar ve `-n` ile kapatılır.
Subject R-06 ise hop gösteriminde DNS resolution'ı **yasaklıyor**. Bu yüzden
varsayılan davranış numerik bırakıldı ve DNS açıkça talep edilen bir bayrağın
arkasına kondu. Böylece bayraksız çalıştırma mandatory kurala tam uyuyor,
bonus ise ek bir yetenek olarak duruyor.

`checksum.c` (RFC 1071) ICMP probe modu için gerekiyordu; o mod bonusa
girmediği için ölü kod olarak bırakılmadı.

---

## Bilinen eksikler

| ID | Konu | Etki |
|----|------|------|
| ⚠ T-1004 | Docker bridge hop 1'den sonrasını NAT'lıyor | Çok hop'lu yol yalnızca native Linux'ta görülebilir; format doğrulaması etkilenmez |
| ⚠ — | ICMP code anotasyonları (`!H` `!N` `!X`) yok | Mandatory kapsamı dışında, bonus kotası dolu |
| ⚠ — | IPv6 yok | Subject IPv4 zorunlu kılıyor |
