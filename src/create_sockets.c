/* ************************************************************************** */
/*                                                                            */
/*                                                        :::      ::::::::   */
/*   create_sockets.c                                   :+:      :+:    :+:   */
/*                                                    +:+ +:+         +:+     */
/*   By: ozmerte <ozmerte@student.42.fr>            +#+  +:+       +#+        */
/*                                                +#+#+#+#+#+   +#+           */
/*   Created: 2026/11/14 00:00:00 by ozmerte          #+#    #+#             */
/*   Updated: 2026/11/14 00:00:00 by ozmerte         ###   ########.fr       */
/*                                                                            */
/* ************************************************************************** */

#include "header.h"

int	create_sockets(t_traceroute *tr)
{
	tr->send_fd = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
	if (tr->send_fd < 0)
	{
		fprintf(stderr, "ft_traceroute: udp socket: %s\n", strerror(errno));
		return (1);
	}
	tr->recv_fd = socket(AF_INET, SOCK_RAW, IPPROTO_ICMP);
	if (tr->recv_fd < 0)
	{
		fprintf(stderr, "ft_traceroute: icmp socket: %s\n", strerror(errno));
		return (1);
	}
	return (0);
}
