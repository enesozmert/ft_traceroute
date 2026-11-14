/* ************************************************************************** */
/*                                                                            */
/*                                                        :::      ::::::::   */
/*   trace_cleanup.c                                    :+:      :+:    :+:   */
/*                                                    +:+ +:+         +:+     */
/*   By: ozmerte <ozmerte@student.42.fr>            +#+  +:+       +#+        */
/*                                                +#+#+#+#+#+   +#+           */
/*   Created: 2026/11/14 00:00:00 by ozmerte          #+#    #+#             */
/*   Updated: 2026/11/14 00:00:00 by ozmerte         ###   ########.fr       */
/*                                                                            */
/* ************************************************************************** */

#include "header.h"

void	trace_cleanup(t_traceroute *tr)
{
	if (tr == NULL)
		return ;
	if (tr->send_fd >= 0)
		close(tr->send_fd);
	if (tr->recv_fd >= 0)
		close(tr->recv_fd);
	tr->send_fd = -1;
	tr->recv_fd = -1;
	free(tr->payload);
	tr->payload = NULL;
}
