/* ************************************************************************** */
/*                                                                            */
/*                                                        :::      ::::::::   */
/*   resolve_hostname.c                                 :+:      :+:    :+:   */
/*                                                    +:+ +:+         +:+     */
/*   By: ozmerte <ozmerte@student.42.fr>            +#+  +:+       +#+        */
/*                                                +#+#+#+#+#+   +#+           */
/*   Created: 2026/11/14 00:00:00 by ozmerte          #+#    #+#             */
/*   Updated: 2026/11/14 00:00:00 by ozmerte         ###   ########.fr       */
/*                                                                            */
/* ************************************************************************** */

#include "header.h"

int	resolve_hostname(const char *hostname, char *ip_str, size_t ip_str_len)
{
	struct addrinfo		hints;
	struct addrinfo		*res;
	struct sockaddr_in	*addr;
	int					status;

	memset(&hints, 0, sizeof(hints));
	hints.ai_family = AF_INET;
	hints.ai_socktype = SOCK_DGRAM;
	status = getaddrinfo(hostname, NULL, &hints, &res);
	if (status != 0)
	{
		fprintf(stderr, "ft_traceroute: unknown host %s\n", hostname);
		return (1);
	}
	addr = (struct sockaddr_in *)(void *)res->ai_addr;
	if (inet_ntop(AF_INET, &addr->sin_addr, ip_str,
			(socklen_t)ip_str_len) == NULL)
	{
		fprintf(stderr, "ft_traceroute: inet_ntop: %s\n", strerror(errno));
		freeaddrinfo(res);
		return (1);
	}
	freeaddrinfo(res);
	return (0);
}
