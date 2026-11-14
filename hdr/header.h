/* ************************************************************************** */
/*                                                                            */
/*                                                        :::      ::::::::   */
/*   header.h                                           :+:      :+:    :+:   */
/*                                                    +:+ +:+         +:+     */
/*   By: ozmerte <ozmerte@student.42.fr>            +#+  +:+       +#+        */
/*                                                +#+#+#+#+#+   +#+           */
/*   Created: 2026/11/14 00:00:00 by ozmerte          #+#    #+#             */
/*   Updated: 2026/11/14 00:00:00 by ozmerte         ###   ########.fr       */
/*                                                                            */
/* ************************************************************************** */

#ifndef HEADER_H
# define HEADER_H

# ifndef _DEFAULT_SOURCE
#  define _DEFAULT_SOURCE
# endif
# ifndef _GNU_SOURCE
#  define _GNU_SOURCE
# endif
# ifndef _DARWIN_C_SOURCE
#  define _DARWIN_C_SOURCE
# endif

# include <stdio.h>
# include <stdlib.h>
# include <string.h>
# include <unistd.h>
# include <signal.h>
# include <errno.h>
# include <stdint.h>
# include <netdb.h>
# include <sys/types.h>
# include <sys/socket.h>
# include <sys/time.h>
# include <sys/select.h>
# include <netinet/in.h>
# include <arpa/inet.h>

/*
** ---------------------------------------------------------------------------
** Subject defaults — mirror the real traceroute(8) so the output layout and
** the probing behaviour match the reference implementation.
** ---------------------------------------------------------------------------
*/

/* Hop count ceiling (traceroute: -m, default 30). */
# define TR_MAX_HOPS 30
/* Probes sent per hop (traceroute: -q, default 3). */
# define TR_NPROBES 3
/* First UDP destination port (traceroute: -p, default 33434). */
# define TR_BASE_PORT 33434
/* Total wire size announced in the banner: IP(20) + UDP(8) + payload(32). */
# define TR_PACKET_LEN 60
/* Seconds to wait for a single probe reply (traceroute: -w, default 5). */
# define TR_PROBE_TIMEOUT 5
/* Receive buffer for the raw ICMP socket. */
# define TR_RECV_BUFLEN 1024

/*
** ---------------------------------------------------------------------------
** Wire-format structs. Declared locally instead of using <netinet/ip.h> and
** <netinet/ip_icmp.h> so the layout is identical on Linux (iphdr/icmphdr) and
** BSD/macOS (struct ip / struct icmp). Layout follows RFC 791 (IP),
** RFC 792 (ICMP) and RFC 768 (UDP) exactly as they appear on the wire.
** ---------------------------------------------------------------------------
*/

# ifndef IPPROTO_ICMP
#  define IPPROTO_ICMP 1
# endif

/* ICMP types we care about. */
# define ICMP_T_DEST_UNREACH 3
# define ICMP_T_TIME_EXCEEDED 11
/* ICMP code: port unreachable -> the destination itself answered. */
# define ICMP_C_PORT_UNREACH 3

typedef struct s_iphdr
{
	uint8_t		vhl;
	uint8_t		tos;
	uint16_t	tot_len;
	uint16_t	id;
	uint16_t	frag_off;
	uint8_t		ttl;
	uint8_t		protocol;
	uint16_t	check;
	uint32_t	saddr;
	uint32_t	daddr;
}	t_iphdr;

typedef struct s_icmphdr
{
	uint8_t		type;
	uint8_t		code;
	uint16_t	checksum;
	uint16_t	id;
	uint16_t	sequence;
}	t_icmphdr;

typedef struct s_udphdr
{
	uint16_t	source;
	uint16_t	dest;
	uint16_t	len;
	uint16_t	check;
}	t_udphdr;

/*
** ---------------------------------------------------------------------------
** Runtime state
** ---------------------------------------------------------------------------
*/

/* What a single probe ended up being. */
typedef enum e_probe_state
{
	PROBE_TIMEOUT = 0,
	PROBE_TRANSIT = 1,
	PROBE_FINAL = 2
}	t_probe_state;

typedef struct s_probe
{
	t_probe_state	state;
	struct timeval	sent_at;
	double			rtt;
	uint32_t		from_addr;
	char			from_str[INET_ADDRSTRLEN];
}	t_probe;

typedef struct s_options
{
	int			max_hops;
	int			nprobes;
	uint16_t	base_port;
	int			packet_len;
	int			probe_timeout;
}	t_options;

typedef struct s_traceroute
{
	int					send_fd;
	int					recv_fd;
	const char			*dest_arg;
	char				dest_ip[INET_ADDRSTRLEN];
	struct sockaddr_in	target;
	t_options			opt;
	t_probe				probes[TR_NPROBES];
	unsigned char		*payload;
	int					payload_len;
	uint16_t			ident;
	int					reached;
}	t_traceroute;

/* Set from the SIGINT handler only; read by the probing loop. */
extern volatile sig_atomic_t	g_interrupted;

/*
** ---------------------------------------------------------------------------
** Prototypes — one public function per source file (norm).
** ---------------------------------------------------------------------------
*/

int				parse_args(int argc, char *argv[], const char **dest);
void			print_usage(FILE *stream);

int				resolve_hostname(const char *hostname, char *ip_str,
					size_t ip_str_len);

int				trace_init(t_traceroute *tr, const char *dest);
void			trace_cleanup(t_traceroute *tr);
int				create_sockets(t_traceroute *tr);
int				create_payload(t_traceroute *tr);
int				create_target(t_traceroute *tr);

int				trace_loop(t_traceroute *tr);
int				send_probe(t_traceroute *tr, int ttl, int probe_idx);
uint16_t		probe_port(const t_traceroute *tr, int ttl, int probe_idx);
int				wait_reply(t_traceroute *tr, const struct timeval *deadline);
int				recv_reply(t_traceroute *tr, int probe_idx, uint16_t port);
int				match_probe(const t_traceroute *tr, const unsigned char *buf,
					ssize_t len, uint16_t port);

void			print_banner(const t_traceroute *tr);
void			print_hop(const t_traceroute *tr, int ttl);

double			compute_elapsed_ms(const struct timeval *start,
					const struct timeval *end);
void			timeval_add_ms(struct timeval *tv, long ms);
int				timeval_remaining(const struct timeval *deadline,
					struct timeval *out);

void			interrupt_handler(int sig);

#endif
