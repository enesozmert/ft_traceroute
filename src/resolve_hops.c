/* ************************************************************************** */
/*                                                                            */
/*                                                        :::      ::::::::   */
/*   resolve_hops.c                                     :+:      :+:    :+:   */
/*                                                    +:+ +:+         +:+     */
/*   By: ozmerte <ozmerte@student.42.fr>            +#+  +:+       +#+        */
/*                                                +#+#+#+#+#+   +#+           */
/*   Created: 2026/11/14 00:00:00 by ozmerte          #+#    #+#             */
/*   Updated: 2026/11/14 00:00:00 by ozmerte         ###   ########.fr       */
/*                                                                            */
/* ************************************************************************** */

#include "header.h"

/*
** Bonus only, and opt-in only. The subject forbids DNS resolution in the
** jump display, so this runs exactly when --resolve was passed; with no
** flag the hop lines stay numeric and the mandatory behaviour is untouched.
** A lookup that fails leaves host_str empty, and print_hop falls back to
** the raw address.
*/

void	resolve_hops(t_traceroute *tr)
{
	struct sockaddr_in	sa;
	t_probe				*probe;
	int					i;

	if (tr->opt.resolve_dns == 0)
		return ;
	i = 0;
	while (i < tr->opt.nprobes)
	{
		probe = &tr->probes[i];
		if (probe->state != PROBE_TIMEOUT && probe->host_str[0] == '\0')
		{
			memset(&sa, 0, sizeof(sa));
			sa.sin_family = AF_INET;
			sa.sin_addr.s_addr = probe->from_addr;
			if (getnameinfo((const struct sockaddr *)&sa, sizeof(sa),
					probe->host_str, NI_MAXHOST, NULL, 0, NI_NAMEREQD) != 0)
				probe->host_str[0] = '\0';
		}
		i++;
	}
}
