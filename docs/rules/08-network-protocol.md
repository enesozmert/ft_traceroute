# 08 — Network Protocol Rules (IPv4 / UDP / ICMP)

> RFC 791 (IP), RFC 768 (UDP), RFC 792 (ICMP), RFC 1812 (router requirements)
> Reference implementation: `traceroute(8)`, LBL / Dmitry Butskoy

---

## 1. Probe mekanizması

Traceroute, hedefe giden yolu TTL alanını sömürerek çıkarır.

```
TTL = 1  -> ilk router TTL'i 0'a düşürür  -> ICMP Time Exceeded gönderir
TTL = 2  -> ikinci router                 -> ICMP Time Exceeded
...
TTL = n  -> hedef makine                  -> ICMP Port Unreachable
```

Her ICMP hata mesajının kaynak IP'si o hop'un adresidir. Yol bu şekilde
hop hop ortaya çıkar.

### 1.1 Socket çifti

| Yön | Socket | Neden |
|-----|--------|-------|
| gönderim | `socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)` | TTL'i `IP_TTL` ile ayarlanabilen sıradan UDP datagram |
| alım | `socket(AF_INET, SOCK_RAW, IPPROTO_ICMP)` | ICMP hata mesajları normal socket'e teslim edilmez |

UDP socket'i root yetkisi istemez; **raw ICMP socket'i ister** (root veya
`CAP_NET_RAW`). Bu yüzden program root olmadan çalıştırıldığında hata
`icmp socket: Operation not permitted` olur.

### 1.2 Port seçimi

```
port(ttl, probe) = 33434 + (ttl - 1) * nprobes + probe
```

33434–33534 aralığı IANA tarafından "traceroute" için ayrılmıştır ve
hiçbir servis dinlemediği için hedef makine **Port Unreachable** döner.
Port aynı zamanda probe'u geri eşleştirmenin anahtarıdır (bkz. §3).

---

## 2. ICMP yanıt sınıflandırması

| Type | Code | Anlam | Döngü davranışı |
|------|------|-------|------------------|
| 11 | 0 | Time Exceeded in Transit — ara router | hop kaydedilir, devam |
| 11 | 1 | Fragment reassembly time exceeded | hop kaydedilir, devam |
| 3 | 3 | Port Unreachable — **hedef yanıt verdi** | hop kaydedilir, **dur** |
| 3 | 0 | Net Unreachable | hop kaydedilir, devam (`!N`) |
| 3 | 1 | Host Unreachable | hop kaydedilir, devam (`!H`) |
| 3 | 13 | Communication administratively prohibited | hop kaydedilir, devam (`!X`) |
| — | — | yanıt yok (timeout) | `*` basılır |

Mandatory part type 11 ve type 3 code 3 ayrımını yapar; diğer code'ların
`!N` / `!H` / `!X` anotasyonu bonus kapsamındadır.

---

## 3. Probe eşleştirme — kritik kural

Raw ICMP socket **host'a gelen tüm ICMP trafiğini** teslim eder. Aynı anda
çalışan bir `ping`, başka bir traceroute veya rastgele bir ağ hatası da bu
socket'e düşer. Gelen her datagram bizim probe'umuz sanılamaz.

RFC 792, ICMP hata mesajının gövdesine **hatayı tetikleyen datagramın IP
başlığını + ilk 8 baytını** koymayı zorunlu kılar. UDP başlığı tam 8 bayt
olduğundan, orijinal UDP başlığı bütünüyle oradadır.

```
 0                    20                  28                  48        56
 +--------------------+-------------------+-------------------+---------+
 |   outer IP header  |    ICMP header    |   inner IP header | inner   |
 |   (router'ın IP'si)|  type/code/cksum  |  (bizim paketimiz)| UDP hdr |
 +--------------------+-------------------+-------------------+---------+
                                                                   ^
                                                         dest port == probe portu
```

Eşleştirme kuralı: **inner UDP başlığındaki hedef port, beklenen probe'un
portuna eşitse paket bizimdir.** Başka hiçbir alan güvenilir değildir:

- outer IP source → hop'un adresi, probe kimliği değil
- ICMP id/sequence → UDP probe'da anlamsız (bunlar echo alanlarıdır)
- inner IP id → bazı router'lar değiştirir

Uzunluk kontrolü her adımda yapılır; kısa veya bozuk paket sessizce atılır.

---

## 4. Başlık düzeni taşınabilirliği

Linux `struct iphdr` / `struct icmphdr`, BSD ve macOS `struct ip` /
`struct icmp` tanımlar; alan adları ve bitfield sırası farklıdır. Bu yüzden
projede kendi POSIX-portable struct'larımız kullanılır:

```c
t_iphdr   vhl, tos, tot_len, id, frag_off, ttl, protocol, check, saddr, daddr
t_icmphdr type, code, checksum, id, sequence
t_udphdr  source, dest, len, check
```

Alanlar tel üzerindeki (wire) düzenle birebir aynıdır. Okuma `memcpy` ile
yapılır — `unsigned char*` tamponunu doğrudan struct pointer'a cast etmek
hizalama (alignment) açısından tanımsız davranıştır ve `-Wcast-align`
altında uyarı üretir.

### 4.1 Byte order

| Alan | Dönüşüm |
|------|---------|
| `sin_port` | `htons()` ile yazılır |
| inner UDP `dest` | `ntohs()` ile okunur |
| `saddr` / `daddr` | network byte order'da kalır, `inet_ntop` öyle bekler |
| `vhl` / `ttl` / `type` / `code` | tek bayt, dönüşüm gerekmez |

IHL hesabı: `(vhl & 0x0F) * 4`. Sabit 20 varsayılmaz — IP seçenekleri olan
paketlerde başlık daha uzundur.

---

## 5. Zamanlama

- `gettimeofday` probe gönderilmeden hemen önce ve yanıt alındıktan hemen
  sonra çağrılır.
- RTT milisaniye cinsinden `%.3f` basılır.
- Probe timeout'u 5 saniyedir (`traceroute -w` varsayılanı).
- Subject ±30 ms sapmaya izin verir; bu, `select` uyanma gecikmesi ve
  kernel zamanlaması için fazlasıyla yeterlidir.

---

## 6. Denetim listesi

- [ ] `grep -r O_NONBLOCK src/` boş dönüyor (R-08)
- [ ] `grep -rE 'system\(|execv|popen' src/` boş dönüyor (R-10)
- [ ] `grep -r getnameinfo src/` boş dönüyor (R-06)
- [ ] IHL her zaman `(vhl & 0x0F) * 4` ile hesaplanıyor
- [ ] Her `memcpy` öncesi uzunluk kontrolü var
- [ ] UDP checksum kernel'e bırakılmış (raw IP göndermiyoruz)
