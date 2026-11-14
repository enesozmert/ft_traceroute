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
	fprintf(stream, "Usage: ft_traceroute [--help] <host>\n");
	fprintf(stream, "\n");
	fprintf(stream, "Print the route packets take to a network host.\n");
	fprintf(stream, "\n");
	fprintf(stream, "  --help    display this help and exit\n");
	fprintf(stream, "\n");
	fprintf(stream, "Exactly one destination is required: an IPv4 address");
	fprintf(stream, " or a hostname.\n");
}
