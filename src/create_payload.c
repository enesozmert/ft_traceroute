/* ************************************************************************** */
/*                                                                            */
/*                                                        :::      ::::::::   */
/*   create_payload.c                                   :+:      :+:    :+:   */
/*                                                    +:+ +:+         +:+     */
/*   By: ozmerte <ozmerte@student.42.fr>            +#+  +:+       +#+        */
/*                                                +#+#+#+#+#+   +#+           */
/*   Created: 2026/11/14 00:00:00 by ozmerte          #+#    #+#             */
/*   Updated: 2026/11/14 00:00:00 by ozmerte         ###   ########.fr       */
/*                                                                            */
/* ************************************************************************** */

#include "header.h"

int	create_payload(t_traceroute *tr)
{
	int	len;

	len = tr->opt.packet_len - (int) sizeof(t_iphdr) - (int) sizeof(t_udphdr);
	if (len < 0)
		len = 0;
	tr->payload_len = len;
	tr->payload = malloc((size_t)len + 1);
	if (tr->payload == NULL)
	{
		fprintf(stderr, "ft_traceroute: malloc: %s\n", strerror(errno));
		return (1);
	}
	memset(tr->payload, 0, (size_t)len + 1);
	return (0);
}
