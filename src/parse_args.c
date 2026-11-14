/* ************************************************************************** */
/*                                                                            */
/*                                                        :::      ::::::::   */
/*   parse_args.c                                       :+:      :+:    :+:   */
/*                                                    +:+ +:+         +:+     */
/*   By: ozmerte <ozmerte@student.42.fr>            +#+  +:+       +#+        */
/*                                                +#+#+#+#+#+   +#+           */
/*   Created: 2026/11/14 00:00:00 by ozmerte          #+#    #+#             */
/*   Updated: 2026/11/14 00:00:00 by ozmerte         ###   ########.fr       */
/*                                                                            */
/* ************************************************************************** */

#include "header.h"

static int	usage_error(void)
{
	print_usage(stderr);
	return (1);
}

static int	take_dest(const char **dest, const char *arg)
{
	if (*dest != NULL)
	{
		fprintf(stderr, "ft_traceroute: extra operand '%s'\n", arg);
		print_usage(stderr);
		return (1);
	}
	*dest = arg;
	return (0);
}

int	parse_args(int argc, char *argv[], const char **dest, t_options *opt)
{
	int	i;
	int	used;

	*dest = NULL;
	i = 1;
	while (i < argc)
	{
		if (strcmp(argv[i], "--help") == 0)
		{
			print_usage(stdout);
			return (0);
		}
		used = parse_option(argc, argv, i, opt);
		if (used < 0)
			return (1);
		if (used == 0 && take_dest(dest, argv[i]) != 0)
			return (1);
		if (used == 0)
			used = 1;
		i += used;
	}
	if (*dest == NULL)
		return (usage_error());
	return (0);
}
