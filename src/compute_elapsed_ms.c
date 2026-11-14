/* ************************************************************************** */
/*                                                                            */
/*                                                        :::      ::::::::   */
/*   compute_elapsed_ms.c                               :+:      :+:    :+:   */
/*                                                    +:+ +:+         +:+     */
/*   By: ozmerte <ozmerte@student.42.fr>            +#+  +:+       +#+        */
/*                                                +#+#+#+#+#+   +#+           */
/*   Created: 2026/11/14 00:00:00 by ozmerte          #+#    #+#             */
/*   Updated: 2026/11/14 00:00:00 by ozmerte         ###   ########.fr       */
/*                                                                            */
/* ************************************************************************** */

#include "header.h"

double	compute_elapsed_ms(const struct timeval *start,
		const struct timeval *end)
{
	double	ms;

	ms = (double)(end->tv_sec - start->tv_sec) * 1000.0;
	ms += (double)(end->tv_usec - start->tv_usec) / 1000.0;
	return (ms);
}

void	timeval_add_ms(struct timeval *tv, long ms)
{
	long	usec;

	tv->tv_sec += (time_t)(ms / 1000L);
	usec = (long)tv->tv_usec + (ms % 1000L) * 1000L;
	tv->tv_sec += (time_t)(usec / 1000000L);
	tv->tv_usec = (suseconds_t)(usec % 1000000L);
}

int	timeval_remaining(const struct timeval *deadline, struct timeval *out)
{
	struct timeval	now;
	long			usec;

	gettimeofday(&now, NULL);
	usec = (long)(deadline->tv_sec - now.tv_sec) * 1000000L
		+ (long)(deadline->tv_usec - now.tv_usec);
	if (usec <= 0)
	{
		out->tv_sec = 0;
		out->tv_usec = 0;
		return (0);
	}
	out->tv_sec = (time_t)(usec / 1000000L);
	out->tv_usec = (suseconds_t)(usec % 1000000L);
	return (1);
}
