/* ************************************************************************** */
/*                                                                            */
/*                                                        :::      ::::::::   */
/*   wait_reply.c                                       :+:      :+:    :+:   */
/*                                                    +:+ +:+         +:+     */
/*   By: ozmerte <ozmerte@student.42.fr>            +#+  +:+       +#+        */
/*                                                +#+#+#+#+#+   +#+           */
/*   Created: 2026/11/14 00:00:00 by ozmerte          #+#    #+#             */
/*   Updated: 2026/11/14 00:00:00 by ozmerte         ###   ########.fr       */
/*                                                                            */
/* ************************************************************************** */

#include "header.h"

int	wait_reply(t_traceroute *tr, const struct timeval *deadline)
{
	fd_set			read_fds;
	struct timeval	tv;
	int				ready;

	if (timeval_remaining(deadline, &tv) == 0)
		return (0);
	FD_ZERO(&read_fds);
	FD_SET(tr->recv_fd, &read_fds);
	ready = select(tr->recv_fd + 1, &read_fds, NULL, NULL, &tv);
	if (ready < 0)
		return (-1);
	return (ready);
}
