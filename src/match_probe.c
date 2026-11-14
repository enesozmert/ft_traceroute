/* ************************************************************************** */
/*                                                                            */
/*                                                        :::      ::::::::   */
/*   match_probe.c                                      :+:      :+:    :+:   */
/*                                                    +:+ +:+         +:+     */
/*   By: ozmerte <ozmerte@student.42.fr>            +#+  +:+       +#+        */
/*                                                +#+#+#+#+#+   +#+           */
/*   Created: 2026/11/14 00:00:00 by ozmerte          #+#    #+#             */
/*   Updated: 2026/11/14 00:00:00 by ozmerte         ###   ########.fr       */
/*                                                                            */
/* ************************************************************************** */

#include "header.h"

/*
** An ICMP error carries the IP header of the offending datagram plus its
** first 8 bytes, i.e. the whole UDP header. The destination port in that
** embedded UDP header is the only reliable key back to one of our probes,
** because a raw ICMP socket receives every ICMP packet on the host.
*/

int	match_probe(const t_traceroute *tr, const unsigned char *buf,
		ssize_t len, uint16_t port)
{
	t_iphdr		outer;
	t_iphdr		inner;
	t_udphdr	udp;
	size_t		off;

	(void)tr;
	memcpy(&outer, buf, sizeof(outer));
	off = (size_t)((outer.vhl & 0x0F) * 4) + sizeof(t_icmphdr);
	if ((size_t)len < off + sizeof(inner))
		return (0);
	memcpy(&inner, buf + off, sizeof(inner));
	if (inner.protocol != IPPROTO_UDP)
		return (0);
	off += (size_t)((inner.vhl & 0x0F) * 4);
	if ((size_t)len < off + sizeof(udp))
		return (0);
	memcpy(&udp, buf + off, sizeof(udp));
	if (ntohs(udp.dest) != port)
		return (0);
	return (1);
}
