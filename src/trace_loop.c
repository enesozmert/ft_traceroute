/* ************************************************************************** */
/*                                                                            */
/*                                                        :::      ::::::::   */
/*   trace_loop.c                                       :+:      :+:    :+:   */
/*                                                    +:+ +:+         +:+     */
/*   By: ozmerte <ozmerte@student.42.fr>            +#+  +:+       +#+        */
/*                                                +#+#+#+#+#+   +#+           */
/*   Created: 2026/11/14 00:00:00 by ozmerte          #+#    #+#             */
/*   Updated: 2026/11/14 00:00:00 by ozmerte         ###   ########.fr       */
/*                                                                            */
/* ************************************************************************** */

#include "header.h"

static int	run_probe(t_traceroute *tr, int ttl, int idx)
{
	struct timeval	deadline;
	int				ready;

	if (send_probe(tr, ttl, idx) != 0)
		return (0);
	gettimeofday(&deadline, NULL);
	timeval_add_ms(&deadline, (long)tr->opt.probe_timeout * 1000L);
	while (g_interrupted == 0)
	{
		ready = wait_reply(tr, &deadline);
		if (ready <= 0)
			return (0);
		if (recv_reply(tr, idx, probe_port(tr, ttl, idx)) == 1)
			return (1);
	}
	return (0);
}

static void	run_hop(t_traceroute *tr, int ttl)
{
	int	i;

	i = 0;
	while (i < tr->opt.nprobes && g_interrupted == 0)
	{
		run_probe(tr, ttl, i);
		i++;
	}
	resolve_hops(tr);
	print_hop(tr, ttl);
}

int	trace_loop(t_traceroute *tr)
{
	int	ttl;

	ttl = 1;
	while (ttl <= tr->opt.max_hops && g_interrupted == 0)
	{
		run_hop(tr, ttl);
		if (tr->reached != 0)
			break ;
		ttl++;
	}
	return (0);
}
