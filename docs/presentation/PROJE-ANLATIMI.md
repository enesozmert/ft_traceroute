# ft_traceroute — Hap Bilgi / Anlatım Kartı

> Savunmada ve anlatımda kullanılacak tek sayfalık özet.
> Detay: [SDD](../sdd/SDD.md) · [Protokol](../rules/08-network-protocol.md) · [Subject kuralları](../rules/01-subject-rules.md)

---

## 1. Tek cümlede

Bir IP paketinin hedefe giderken geçtiği router'ları, TTL alanını kasıtlı
olarak düşük tutup dönen ICMP hata mesajlarının kaynak adresini okuyarak
hop hop ortaya çıkaran program.

---

## 2. Temel fikir — 3 satır

```
TTL = 1  ->  ilk router TTL'i 0'a düşürür  ->  ICMP Time Exceeded (type 11)   -> hop 1 bu router
TTL = 2  ->  ikinci router                 ->  ICMP Time Exceeded             -> hop 2
TTL = n  ->  hedef makine                  ->  ICMP Port Unreachable (3/3)    -> vardık, dur
```

Her ICMP hata mesajının **kaynak IP'si** o hop'un adresidir. Yol budur.

---

## 3. Neden UDP probe?

Subject protokolü **adlandırmıyor**. İki maddesinden türetildi:

1. *"The result will have the same indentation as the real traceroute"* +
   Chapter III'te `man traceroute` referansı. Linux `traceroute(8)` varsayılanı **UDP**.
2. Bonus listesinde `-p` (port) var, `-I` (ICMP modu) **yok**. Port kavramı
   yalnızca UDP probe'da anlamlıdır.

Port aralığı 33434–33534 IANA tarafından traceroute'a ayrılmıştır; hiçbir
servis dinlemediği için hedef **port unreachable** döner.

---

## 4. İki socket, neden

| Yön | Socket | Neden |
|-----|--------|-------|
| gönderim | `socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)` | TTL'i `setsockopt(IP_TTL)` ile ayarlanabilen sıradan UDP |
| alım | `socket(AF_INET, SOCK_RAW, IPPROTO_ICMP)` | ICMP hata mesajları normal socket'e **teslim edilmez** |

UDP socket'i yetki istemez, **raw ICMP socket'i root veya `CAP_NET_RAW` ister**.

---

## 5. En kritik kısım — probe eşleştirme

Raw ICMP socket, host'a gelen **tüm** ICMP trafiğini teslim eder. Aynı anda
çalışan bir `ping` de bu socket'e düşer. Gelen her paket bizim sanılamaz.

RFC 792: ICMP hata mesajı, hatayı tetikleyen datagramın **IP başlığını + ilk
8 baytını** taşımak zorundadır. UDP başlığı tam 8 bayt → orijinal hedef port
oradadır.

```
[ outer IP ][ ICMP 8B ][ inner IP ][ inner UDP 8B ]
                                         ^
                        dest port == 33434 + (ttl-1)*nprobes + probe
```

**Kural: iç UDP başlığındaki hedef port eşleşiyorsa paket bizimdir.**

Neden başka alan olmaz:
- outer IP source → hop'un adresi, probe kimliği değil
- ICMP id/sequence → UDP probe'da anlamsız (echo alanlarıdır)
- inner IP id → bazı router'lar değiştirir

Kanıt: [`test/fixtures/wire-udp-probes.txt`](../../test/fixtures/wire-udp-probes.txt)

---

## 6. Çıktı düzeni

```
traceroute to 8.8.8.8 (8.8.8.8), 30 hops max, 60 byte packets
 1  172.23.0.1  0.545 ms  0.466 ms  0.429 ms
 2  * * *
```

Kurallar (`traceroute(8)`'den alındı):
- hop numarası `"%2d "`
- cevap veren probe: `" <adres>"` (yalnızca önceki probe'dan farklıysa) + `"  %.3f ms"`
- kayıp probe: `" *"`
- 60 bayt = 20 (IP) + 8 (UDP) + 32 (payload)

Doğrulama: rakamlar `N`'e normalize edilip gerçek `traceroute -n` ile diff
alınır → **fark yok** (T-704, `make diff-ref`).

---

## 7. Subject'in zor maddeleri ve cevapları

| Madde | Nasıl karşılandı |
|-------|------------------|
| Tek opsiyon `--help` | `parse_args` yalnızca `--help`; tanınmayan her `-` argümanı hata |
| Hop gösteriminde **DNS yok** | Forward resolution sadece başlangıçta (banner); hop satırları ham IPv4. Davranış `traceroute -n` ile aynı |
| `O_NONBLOCK` **yasak** | Socket'ler blocking; bekleme `select(2)` + deadline. `fcntl` kaynakta geçmiyor (T-201/T-203) |
| Sadece libC | Harici bağımlılık yok (T-204) |
| Gerçek traceroute çağrılamaz | `system` / `exec*` / `popen` kaynakta yok (T-202) |
| ±30 ms tolerans | `netem delay 50ms` altında ölçüm: bizim 50.4–52.4 ms, referans 50.3–50.5 ms → sapma < 2 ms (T-708) |
| Beklenmedik çıkış yok | Tek `exit` noktası `main`; SIGINT fatal sinyalle bitmiyor (T-707); valgrind 0 leak |

---

## 8. Tasarım kararları — savunulacak 3 nokta

**1. setup / run / teardown ayrı.**
`trace_init → trace_loop → trace_cleanup`, hepsi normal yoldan döner. (ft_ping'de
döngü socket açan fonksiyonun içindeydi ve `free` hiç çalışmıyordu — o hata
tekrarlanmadı.)

**2. Signal handler async-signal-safe.**
Handler sadece `volatile sig_atomic_t g_interrupted = 1` yazar. `printf`/`exit`
handler içinde tanımsız davranıştır. Döngü bayrağı probe'lar arasında kontrol
eder, normal dönüş yapar, kaynaklar tek seferde serbest kalır.

**3. Wire struct'lar kendi tanımımız, okuma `memcpy` ile.**
Linux `struct iphdr` ile BSD `struct ip` alan adları ve bitfield sırasında
ayrışır. RFC 791/792/768 düzenini birebir izleyen kendi struct'larımız iki
platformda da doğru. `unsigned char*` tamponu doğrudan struct pointer'a cast
etmek hizalama açısından tanımsız davranıştır — `memcpy` kullanıldı,
`-Wcast-align` temiz.

---

## 9. Bonus (5/5)

| Flag | İş | Aralık |
|------|-----|--------|
| `-m` | max hop | 1–255 |
| `-q` | hop başına probe | 1–10 (dizi boyutu = üst sınır, taşma imkânsız) |
| `-p` | base UDP port | 1–65535 |
| `-w` | probe bekleme | 1–60 s |
| `--resolve` | hop'larda reverse DNS | opt-in |

**`--resolve` neden ters çevrildi:** gerçek traceroute varsayılan çözer, `-n`
ile kapatılır. Subject hop gösteriminde DNS'i yasakladığı için burada varsayılan
numerik; DNS açıkça istenmek zorunda. `resolve_hops` bayrak yoksa ilk satırda
döner → `getnameinfo` mandatory yolda hiç çağrılmaz.

```
$ ft_traceroute 127.0.0.1
 1  127.0.0.1  0.811 ms  0.005 ms  0.004 ms

$ ft_traceroute --resolve 127.0.0.1
 1  localhost (127.0.0.1)  0.010 ms  0.004 ms  0.004 ms
```

---

## 10. Kalite kanıtları

| Kapı | Sonuç |
|------|-------|
| Test suite | 50/50 pass, 0 fail, 0 skip (root'la) |
| Norminette | 22/22 OK, **0 error** |
| Strict build | `-Wpedantic -Wshadow -Wconversion -Wcast-align -Wstrict-prototypes` → **0 warning** |
| Valgrind | 6 yol, `ERROR SUMMARY: 0 errors`, leak yok |
| Cppcheck | 2 style (`variableScope`, norm deviation), 0 bug |
| `make diff-ref` | `layout identical` |
| Linux VM | Debian 13, kernel 6.12.116 (subject ≥ 4.0), 50/50 |

---

## 11. Dosya haritası — nereye bakılacak

| Soru | Dosya |
|------|-------|
| Argümanlar nasıl işleniyor? | `src/parse_args.c`, `src/parse_option.c` |
| Socket'ler nerede açılıyor? | `src/create_sockets.c` |
| TTL döngüsü? | `src/trace_loop.c` |
| Probe eşleştirme? | `src/match_probe.c` |
| Çıktı düzeni? | `src/print_hop.c`, `src/print_banner.c` |
| Reverse DNS (bonus)? | `src/resolve_hops.c` |
| Veri modeli, wire struct'lar? | `hdr/header.h` |
| Testler? | `test/run_tests.sh` |
| Wire kanıtı? | `test/fixtures/` |

---

## 12. Bilinen sınırlar (dürüst liste)

- **IPv6 yok** — subject IPv4 zorunlu kılıyor.
- **ICMP code anotasyonları** (`!H` `!N` `!X`) yok — mandatory kapsamı dışında,
  bonus kotası (5) dolu.
- **Çok hop'lu gerçek yol** NAT'lı ortamlarda görülemiyor: hem Docker hem
  VirtualBox NAT'ı upstream ICMP Time Exceeded'ı yutuyor. Referans `traceroute`
  de aynı ortamda hop 1'den sonrasını göremiyor, yani davranış paritesi var;
  eksik olan ortam, kod değil. Bridged/kablolu ağda `make test-net` ile kapanır.
