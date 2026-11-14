# ft_traceroute — Durum Raporu

> Tarih: 2026-11-14
> Subject: Ecole 42 `ft_traceroute` v5.0
> Commit: `933c2e0` mandatory, `4373ce9` bonus (Faz 9)

---

## Özet

Mandatory part tamamlandı ve doğrulandı; çıktı düzeni gerçek `traceroute(8)`
ile birebir aynı. Ardından 5/5 bonus eklendi ve mandatory davranışta
regresyon olmadığı testle gösterildi.

| Alan | Durum |
|------|-------|
| Subject mandatory (R-01 … R-10) | ✅ tamam |
| Test suite | ✅ 29/29 |
| Norminette | ✅ 22/22 OK, 0 error |
| Strict build | ✅ 0 warning |
| Valgrind | ✅ 0 error, 0 leak (7 path) |
| Cppcheck | ✅ 0 bug (2 belgelenmiş style deviation) |
| Bonus | ✅ 5/5 (`-m` `-q` `-p` `-w` `--resolve`) |

---

## Doğrulama kanıtları

### Çıktı düzeni (T-704)

Rakamlar `N`'e normalize edilerek gerçek `traceroute -n` çıktısıyla
karşılaştırıldı — fark yok:

```
traceroute to N.N.N.N (N.N.N.N), N hops max, N byte packets
 N  N.N.N.N  N.N ms  N.N ms  N.N ms
 N  * * *
```

### RTT doğruluğu (T-611)

`tc qdisc add dev eth0 root netem delay 50ms` altında:

| Kaynak | Probe 1 | Probe 2 | Probe 3 |
|--------|---------|---------|---------|
| gerçek `traceroute` | 50.512 ms | 50.416 ms | 50.319 ms |
| `ft_traceroute` | 52.366 ms | 50.417 ms | 52.406 ms |

Maksimum sapma < 2 ms. Subject toleransı ±30 ms.

### Yasak çağrı denetimi

```
grep -r O_NONBLOCK src/ hdr/            -> boş
grep -rE 'system\(|execv|popen' src/    -> boş
```

`getnameinfo` yalnızca `src/resolve_hops.c` içinde ve yalnızca `--resolve`
verildiğinde çağrılır; mandatory yolda erişilmez. Güvence testi T-703.

### Bonus — mandatory regresyonu yok

Bayraksız çalıştırma varsayılanları değişmedi; T-701…T-704 bonus commit'inden
sonra da geçiyor. Reverse DNS yalnızca `--resolve` ile devreye giriyor:

```
$ ft_traceroute 127.0.0.1
 1  127.0.0.1  0.811 ms  0.005 ms  0.004 ms

$ ft_traceroute --resolve 127.0.0.1
 1  localhost (127.0.0.1)  0.010 ms  0.004 ms  0.004 ms
```

### Bellek güvenliği

7 yol valgrind altında koşuldu — `--help`, bilinmeyen host, argümansız,
`-m 0`, değersiz `-m`, `-q 99` ve SIGINT ile kesilen `-m 2 --resolve` canlı
trace. Hepsinde `ERROR SUMMARY: 0 errors`, leak yok.

---

## Savunmada sorulması muhtemel sorular

**S: Neden UDP probe, ICMP echo değil?**
Subject protokolü adlandırmıyor ama iki maddesi UDP'yi işaret ediyor:
çıktının gerçek traceroute ile aynı girintide olması isteniyor (Linux
traceroute varsayılanı UDP'dir) ve bonus listesinde `-p` (port) var ama
`-I` (ICMP modu) hiç geçmiyor. Port kavramı yalnızca UDP probe'da anlamlıdır.

**S: Gelen ICMP paketinin senin probe'un olduğunu nasıl anlıyorsun?**
Raw ICMP socket host'a gelen tüm ICMP trafiğini teslim eder. RFC 792, hata
mesajının gövdesine hatayı tetikleyen datagramın IP başlığını + ilk 8 baytını
koymayı zorunlu kılar; UDP başlığı tam 8 bayt olduğu için orijinal hedef port
oradadır. Eşleştirme o porta göre yapılır. Outer IP source hop'un adresidir,
probe kimliği değildir; ICMP id/sequence alanları UDP probe'da anlamsızdır.

**S: `O_NONBLOCK` yasağını nasıl karşıladın?**
Socket'ler blocking kalıyor. Bekleme `select(2)` ile yapılıyor ve kalan süre
her turda deadline'dan hesaplanıyor. `fcntl` kaynakta hiç geçmiyor.

**S: Hop satırında neden hostname yok?**
Subject: *"manage the FQDN without running the DNS resolution in the jump
display."* Forward resolution yalnızca başlangıçta, banner için yapılıyor.
Hop satırları ham IPv4 basıyor — davranış `traceroute -n` ile aynı.

**S: `(vhl & 0x0F) * 4` neden, neden sabit 20 değil?**
IP başlığı seçenekler (options) içerdiğinde 20 bayttan uzundur. IHL alanı
32-bit kelime sayısını verir, 4 ile çarpılır. Sabit 20 varsaymak seçenekli
paketlerde iç başlığı yanlış offset'ten okumaya yol açar.

**S: Bonus reverse DNS subject'in R-06 yasağını ihlal etmiyor mu?**
Hayır. Varsayılan numerik. `resolve_hops` bayrak yoksa ilk satırda dönüyor,
yani `getnameinfo` mandatory yolda hiç çağrılmıyor. Gerçek traceroute'un
tersine (`-n` ile kapatılır) burada DNS açıkça istenmek zorunda.

**S: `-q 99` verirsem probe dizisini taşırır mıyım?**
Hayır. `-q`'nun üst sınırı `TR_MAX_PROBES` ve dizi tam o boyutta. Aralık
dışı değer parse aşamasında reddediliyor, socket bile açılmıyor — T-804.

**S: Signal handler'da neden istatistik basmıyorsun?**
`printf` ve `exit` async-signal-safe değildir; handler içinde çağrılmaları
tanımsız davranıştır. Handler yalnızca `volatile sig_atomic_t` bayrağı set
eder, döngü normal yoldan döner ve kaynaklar tek seferde serbest bırakılır.

---

## Bilinen eksikler

| Konu | Etki | Plan |
|------|------|------|
| Docker bridge hop 1'den sonrasını NAT'lıyor | Çok hop'lu gerçek yol container'da görülemiyor; format doğrulaması etkilenmiyor | Native Linux VM'de son doğrulama (T-1003, T-1004) |
| ICMP code anotasyonları (`!H` `!N` `!X`) yok | Mandatory kapsamı dışında | Bonus kotası dolu, eklenmedi |
| `-i` `-s` `-t` `-l` `-N` yok | Subject en fazla 5 bonus sayıyor, kota dolu | — |
| IPv6 yok | Subject IPv4 zorunlu kılıyor | Kapsam dışı |

---

## Sonraki adımlar

1. Değerlendirme VM'inde (Linux kernel ≥ 4.0) `make && make test` doğrulaması
2. Çok hop'lu gerçek ağda canlı trace karşılaştırması
3. Bonus tamamlandı (5/5); ek flag subject kotasını aşacağı için eklenmedi
