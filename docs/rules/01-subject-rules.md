# 01 — Subject Rules (Ecole 42, ft_traceroute v5.0)

> Kaynak: [`docs/main/en.subject.pdf`](../main/en.subject.pdf)
> Bu dosya subject'in **zorunlu** maddelerini denetlenebilir kurallara çevirir.

---

## Mandatory (Chapter V)

| ID | Kural | Durum kaynağı |
|----|-------|---------------|
| R-01 | Executable adı `ft_traceroute` | `Makefile` → `output/ft_traceroute` |
| R-02 | C dilinde yazılacak, Makefile teslim edilecek | `Makefile` |
| R-03 | Makefile normal kuralları içerecek (`all` `clean` `fclean` `re`) | `Makefile` |
| R-04 | Yönetilecek **tek** opsiyon: `--help` | `src/parse_args.c` |
| R-05 | Tek IPv4 parametresi (adres **veya** hostname) | `src/parse_args.c`, `src/resolve_hostname.c` |
| R-06 | FQDN yönetilecek, **hop gösteriminde DNS resolution yapılmayacak** | `src/print_hop.c` |
| R-07 | Hop başına ±30 ms sapma tolere edilir | `src/compute_elapsed_ms.c` |
| R-08 | Socket'ler `O_NONBLOCK` moduna **alınmayacak** | `src/create_sockets.c`, `src/wait_reply.c` |
| R-09 | Sadece libC kullanılacak (kendi libft + printf serbest) | `Makefile` link satırı |
| R-10 | Gerçek `traceroute` **çağrılmayacak** | kaynakta `system/exec*/popen` yok |

### R-04 detayı

`--help` dışında hiçbir flag kabul edilmez. `-` ile başlayan her argüman hata
sayılır; bu, bonus flag'lerin mandatory part'a sızmasını da engeller.

### R-06 detayı

Subject: *"You have to manage the FQDN without running the DNS resolution in
the jump display."* Yani:

- **Başlangıçta** forward resolution yapılır (hostname → IPv4), banner'da
  `hostname (IP)` yazılır.
- **Hop satırlarında** `getnameinfo` / reverse DNS **çağrılmaz**; adres ham
  IPv4 olarak basılır. Davranış `traceroute -n` ile aynıdır.

### R-08 detayı

Bekleme `select(2)` ile yapılır, socket blocking kalır. `fcntl(..., O_NONBLOCK)`
çağrısı kaynakta hiç geçmez — denetlenebilir kural: `grep -r O_NONBLOCK src/`
boş dönmeli.

---

## Submission (Chapter VII)

| ID | Kural | Durum kaynağı |
|----|-------|---------------|
| R-20 | Git repository'ye teslim | repo kökü |
| R-21 | Hatalar makul şekilde yönetilecek; segfault / beklenmedik çıkış yok | `docs/rules/06-error-handling.md` |
| R-22 | Değerlendirme Linux kernel >= 4.0 VM üzerinde | `docker/Dockerfile` (Ubuntu 22.04) |
| R-23 | Çıktı girintisi gerçek traceroute ile **aynı** | `make diff-ref`, test T-704 |

---

## Bonus (Chapter VI) — kilitli

Subject: bonus **yalnızca** mandatory part PERFECT ise değerlendirilir.
Mandatory'de tek bir eksik varsa bonus hiç değerlendirilmez.

| ID | Bonus | Durum |
|----|-------|-------|
| B-01 | DNS management (reverse lookup) | planlandı |
| B-02 | `-i` flag | planlandı |
| B-03 | `-m` flag (max hops) | planlandı |
| B-04 | `-q` flag (probe sayısı) | planlandı |
| B-05 | `-p` flag (base port) | planlandı |

Maksimum 5 bonus. `-V` bonus olarak sayılmaz (subject açık şekilde belirtiyor).

---

## AI kullanımı (Chapter IV)

Subject AI kullanımını yasaklamıyor, **şeffaflık** ve **sahiplik** istiyor:

- Teknik kararların sorumluluğu öğrencide.
- AI ile üretilen kısımlar açıkça belirtilecek.
- Savunmada her tasarım kararı öğrenci tarafından açıklanabilmeli.

Bu projede AI kullanımı [`docs/sdd/SDD.md`](../sdd/SDD.md) §8'de belgelenmiştir.
