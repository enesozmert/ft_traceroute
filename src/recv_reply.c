/* ************************************************************************** */
/*                                                                            */
/*                                                        :::      ::::::::   */
/*   recv_reply.c                                       :+:      :+:    :+:   */
/*                                                    +:+ +:+         +:+     */
/*   By: ozmerte <ozmerte@student.42.fr>            +#+  +:+       +#+        */
/*                                                +#+#+#+#+#+   +#+           */
/*   Created: 2026/11/14 00:00:00 by ozmerte          #+#    #+#             */
/*   Updated: 2026/11/14 00:00:00 by ozmerte         ###   ########.fr       */
/*                                                                            */
/* ************************************************************************** */

#include "header.h"

static void	fill_probe(t_traceroute *tr, int idx, const t_iphdr *ip,
		const t_icmphdr *icmp)
{
	struct in_addr	src;
	struct timeval	now;
	t_probe			*probe;

	gettimeofday(&now, NULL);
	probe = &tr->probes[idx];
	src.s_addr = ip->saddr;
	probe->rtt = compute_elapsed_ms(&probe->sent_at, &now);
	probe->from_addr = ip->saddr;
	inet_ntop(AF_INET, &src, probe->from_str, INET_ADDRSTRLEN);
	if (icmp->type == ICMP_T_DEST_UNREACH && icmp->code == ICMP_C_PORT_UNREACH)
	{
		probe->state = PROBE_FINAL;
		tr->reached = 1;
	}
	else
		probe->state = PROBE_TRANSIT;
}

static int	is_error_reply(uint8_t type)
{
	return (type == ICMP_T_TIME_EXCEEDED || type == ICMP_T_DEST_UNREACH);
}

int	recv_reply(t_traceroute *tr, int probe_idx, uint16_t port)
{
	unsigned char	buf[TR_RECV_BUFLEN];
	t_iphdr			ip;
	t_icmphdr		icmp;
	ssize_t			len;
	size_t			off;

	len = recvfrom(tr->recv_fd, buf, sizeof(buf), 0, NULL, NULL);
	if (len < (ssize_t) sizeof(t_iphdr))
		return (-1);
	memcpy(&ip, buf, sizeof(ip));
	off = (size_t)((ip.vhl & 0x0F) * 4);
	if ((size_t)len < off + sizeof(t_icmphdr))
		return (0);
	memcpy(&icmp, buf + off, sizeof(icmp));
	if (is_error_reply(icmp.type) == 0)
		return (0);
	if (match_probe(tr, buf, len, port) != 1)
		return (0);
	fill_probe(tr, probe_idx, &ip, &icmp);
	return (1);
}
