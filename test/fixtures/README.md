# test/fixtures — kaydedilmiş referans çıktılar

Bu klasör, testlerin karşılaştırdığı davranışın **kaynağını** tutar. Testler
canlı koşuyor; buradaki dosyalar savunmada "neye göre doğru diyorsun?"
sorusunun cevabıdır ve bir regresyonda neyin değiştiğini gösterir.

| Dosya | Ne |
|-------|-----|
| `reference-traceroute.txt` | Debian `traceroute(8)` çıktısı — layout kaynağı |
| `wire-udp-probes.txt` | `tcpdump` ile yakalanan UDP probe'ları ve ICMP yanıtları |
| `wire-port-unreachable.txt` | Hedefin verdiği ICMP port unreachable |

Ortam: Docker, Ubuntu 22.04, container `ft_traceroute_container`, 2026-11-14.
