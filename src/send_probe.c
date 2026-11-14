/* ************************************************************************** */
/*                                                                            */
/*                                                        :::      ::::::::   */
/*   send_probe.c                                       :+:      :+:    :+:   */
/*                                                    +:+ +:+         +:+     */
/*   By: ozmerte <ozmerte@student.42.fr>            +#+  +:+       +#+        */
/*                                                +#+#+#+#+#+   +#+           */
/*   Created: 2026/11/14 00:00:00 by ozmerte          #+#    #+#             */
/*   Updated: 2026/11/14 00:00:00 by ozmerte         ###   ########.fr       */
/*                                                                            */
/* ************************************************************************** */

#include "header.h"

uint16_t	probe_port(const t_traceroute *tr, int ttl, int probe_idx)
{
	int	offset;

	offset = (ttl - 1) * tr->opt.nprobes + probe_idx;
	return ((uint16_t)(tr->opt.base_port + offset));
}

static void	reset_probe(t_probe *probe)
{
	probe->state = PROBE_TIMEOUT;
	probe->rtt = 0.0;
	probe->from_addr = 0;
	probe->from_str[0] = '\0';
	probe->host_str[0] = '\0';
	gettimeofday(&probe->sent_at, NULL);
}

int	send_probe(t_traceroute *tr, int ttl, int probe_idx)
{
	struct sockaddr_in	dst;
	ssize_t				sent;

	if (setsockopt(tr->send_fd, IPPROTO_IP, IP_TTL, &ttl, sizeof(ttl)) < 0)
	{
		fprintf(stderr, "ft_traceroute: setsockopt IP_TTL: %s\n",
			strerror(errno));
		return (1);
	}
	dst = tr->target;
	dst.sin_port = htons(probe_port(tr, ttl, probe_idx));
	reset_probe(&tr->probes[probe_idx]);
	sent = sendto(tr->send_fd, tr->payload, (size_t)tr->payload_len, 0,
			(const struct sockaddr *)&dst, sizeof(dst));
	if (sent < 0)
		return (1);
	return (0);
}
