/* ************************************************************************** */
/*                                                                            */
/*                                                        :::      ::::::::   */
/*   print_usage.c                                      :+:      :+:    :+:   */
/*                                                    +:+ +:+         +:+     */
/*   By: ozmerte <ozmerte@student.42.fr>            +#+  +:+       +#+        */
/*                                                +#+#+#+#+#+   +#+           */
/*   Created: 2026/11/14 00:00:00 by ozmerte          #+#    #+#             */
/*   Updated: 2026/11/14 00:00:00 by ozmerte         ###   ########.fr       */
/*                                                                            */
/* ************************************************************************** */

#include "header.h"

void	print_usage(FILE *stream)
{
	fprintf(stream, "Usage: ft_traceroute [OPTION]... <host>\n");
	fprintf(stream, "\n");
	fprintf(stream, "Print the route packets take to a network host.\n");
	fprintf(stream, "\n");
	fprintf(stream, "  --help        display this help and exit\n");
	fprintf(stream, "  -m <hops>     maximum number of hops (default %d)\n",
		TR_MAX_HOPS);
	fprintf(stream, "  -q <probes>   probes per hop (default %d, max %d)\n",
		TR_NPROBES, TR_MAX_PROBES);
	fprintf(stream, "  -p <port>     base UDP port (default %d)\n",
		TR_BASE_PORT);
	fprintf(stream, "  -w <seconds>  reply wait per probe (default %d)\n",
		TR_PROBE_TIMEOUT);
	fprintf(stream, "  --resolve     resolve hop addresses to hostnames\n");
	fprintf(stream, "\n");
	fprintf(stream, "Exactly one destination is required: an IPv4 address");
	fprintf(stream, " or a hostname.\n");
}
