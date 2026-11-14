/* ************************************************************************** */
/*                                                                            */
/*                                                        :::      ::::::::   */
/*   options_init.c                                     :+:      :+:    :+:   */
/*                                                    +:+ +:+         +:+     */
/*   By: ozmerte <ozmerte@student.42.fr>            +#+  +:+       +#+        */
/*                                                +#+#+#+#+#+   +#+           */
/*   Created: 2026/11/14 00:00:00 by ozmerte          #+#    #+#             */
/*   Updated: 2026/11/14 00:00:00 by ozmerte         ###   ########.fr       */
/*                                                                            */
/* ************************************************************************** */

#include "header.h"

/*
** Mandatory defaults. The bonus flags only ever move these values; with no
** flag at all the program behaves exactly as the mandatory part requires.
*/

void	options_init(t_options *opt)
{
	opt->max_hops = TR_MAX_HOPS;
	opt->nprobes = TR_NPROBES;
	opt->base_port = TR_BASE_PORT;
	opt->packet_len = TR_PACKET_LEN;
	opt->probe_timeout = TR_PROBE_TIMEOUT;
	opt->resolve_dns = 0;
}
