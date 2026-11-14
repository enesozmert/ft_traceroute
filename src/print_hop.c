/* ************************************************************************** */
/*                                                                            */
/*                                                        :::      ::::::::   */
/*   print_hop.c                                        :+:      :+:    :+:   */
/*                                                    +:+ +:+         +:+     */
/*   By: ozmerte <ozmerte@student.42.fr>            +#+  +:+       +#+        */
/*                                                +#+#+#+#+#+   +#+           */
/*   Created: 2026/11/14 00:00:00 by ozmerte          #+#    #+#             */
/*   Updated: 2026/11/14 00:00:00 by ozmerte         ###   ########.fr       */
/*                                                                            */
/* ************************************************************************** */

#include "header.h"

/*
** Layout taken from traceroute(8): "%2d " for the hop, " <addr>" the first
** time an address appears inside the hop, "  %.3f ms" per reply and " *"
** per lost probe. The hop display never resolves an address back to a
** hostname -- the subject forbids DNS resolution in the jump display.
*/

static void	print_probe(const t_probe *probe, const char *last)
{
	if (probe->state == PROBE_TIMEOUT)
	{
		printf(" *");
		return ;
	}
	if (last == NULL || strcmp(last, probe->from_str) != 0)
		printf(" %s", probe->from_str);
	printf("  %.3f ms", probe->rtt);
}

void	print_hop(const t_traceroute *tr, int ttl)
{
	const char	*last;
	int			i;

	printf("%2d ", ttl);
	last = NULL;
	i = 0;
	while (i < tr->opt.nprobes)
	{
		print_probe(&tr->probes[i], last);
		if (tr->probes[i].state != PROBE_TIMEOUT)
			last = tr->probes[i].from_str;
		i++;
	}
	printf("\n");
	fflush(stdout);
}
