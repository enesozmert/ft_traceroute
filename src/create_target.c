/* ************************************************************************** */
/*                                                                            */
/*                                                        :::      ::::::::   */
/*   create_target.c                                    :+:      :+:    :+:   */
/*                                                    +:+ +:+         +:+     */
/*   By: ozmerte <ozmerte@student.42.fr>            +#+  +:+       +#+        */
/*                                                +#+#+#+#+#+   +#+           */
/*   Created: 2026/11/14 00:00:00 by ozmerte          #+#    #+#             */
/*   Updated: 2026/11/14 00:00:00 by ozmerte         ###   ########.fr       */
/*                                                                            */
/* ************************************************************************** */

#include "header.h"

int	create_target(t_traceroute *tr)
{
	memset(&tr->target, 0, sizeof(tr->target));
	tr->target.sin_family = AF_INET;
	if (inet_pton(AF_INET, tr->dest_ip, &tr->target.sin_addr) != 1)
	{
		fprintf(stderr, "ft_traceroute: invalid address: %s\n", tr->dest_ip);
		return (1);
	}
	return (0);
}
