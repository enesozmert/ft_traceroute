/* ************************************************************************** */
/*                                                                            */
/*                                                        :::      ::::::::   */
/*   trace_init.c                                       :+:      :+:    :+:   */
/*                                                    +:+ +:+         +:+     */
/*   By: ozmerte <ozmerte@student.42.fr>            +#+  +:+       +#+        */
/*                                                +#+#+#+#+#+   +#+           */
/*   Created: 2026/11/14 00:00:00 by ozmerte          #+#    #+#             */
/*   Updated: 2026/11/14 00:00:00 by ozmerte         ###   ########.fr       */
/*                                                                            */
/* ************************************************************************** */

#include "header.h"

static void	set_defaults(t_traceroute *tr)
{
	memset(tr, 0, sizeof(*tr));
	tr->send_fd = -1;
	tr->recv_fd = -1;
	tr->opt.max_hops = TR_MAX_HOPS;
	tr->opt.nprobes = TR_NPROBES;
	tr->opt.base_port = TR_BASE_PORT;
	tr->opt.packet_len = TR_PACKET_LEN;
	tr->opt.probe_timeout = TR_PROBE_TIMEOUT;
}

int	trace_init(t_traceroute *tr, const char *dest)
{
	set_defaults(tr);
	tr->dest_arg = dest;
	tr->ident = (uint16_t)(getpid() & 0xFFFF);
	if (resolve_hostname(dest, tr->dest_ip, sizeof(tr->dest_ip)) != 0)
		return (1);
	if (create_target(tr) != 0)
		return (1);
	if (create_payload(tr) != 0)
		return (1);
	if (create_sockets(tr) != 0)
		return (1);
	return (0);
}
