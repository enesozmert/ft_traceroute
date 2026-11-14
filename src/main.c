/* ************************************************************************** */
/*                                                                            */
/*                                                        :::      ::::::::   */
/*   main.c                                             :+:      :+:    :+:   */
/*                                                    +:+ +:+         +:+     */
/*   By: ozmerte <ozmerte@student.42.fr>            +#+  +:+       +#+        */
/*                                                +#+#+#+#+#+   +#+           */
/*   Created: 2026/11/14 00:00:00 by ozmerte          #+#    #+#             */
/*   Updated: 2026/11/14 00:00:00 by ozmerte         ###   ########.fr       */
/*                                                                            */
/* ************************************************************************** */

#include "header.h"

volatile sig_atomic_t	g_interrupted = 0;

int	main(int argc, char *argv[])
{
	t_traceroute	tr;
	t_options		opt;
	const char		*dest;
	int				status;

	dest = NULL;
	options_init(&opt);
	if (parse_args(argc, argv, &dest, &opt) != 0)
		return (1);
	if (dest == NULL)
		return (0);
	if (trace_init(&tr, dest, &opt) != 0)
	{
		trace_cleanup(&tr);
		return (1);
	}
	signal(SIGINT, interrupt_handler);
	print_banner(&tr);
	status = trace_loop(&tr);
	trace_cleanup(&tr);
	if (status != 0)
		return (1);
	return (0);
}
