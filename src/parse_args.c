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

static int	is_option(const char *arg)
{
	return (arg[0] == '-' && arg[1] != '\0');
}

static int	reject(const char *reason, const char *arg)
{
	fprintf(stderr, "ft_traceroute: %s '%s'\n", reason, arg);
	print_usage(stderr);
	return (1);
}

int	parse_args(int argc, char *argv[], const char **dest)
{
	int	i;

	*dest = NULL;
	i = 1;
	while (i < argc)
	{
		if (strcmp(argv[i], "--help") == 0)
		{
			print_usage(stdout);
			return (0);
		}
		if (is_option(argv[i]))
			return (reject("invalid option", argv[i]));
		if (*dest != NULL)
			return (reject("extra operand", argv[i]));
		*dest = argv[i];
		i++;
	}
	if (*dest == NULL)
	{
		print_usage(stderr);
		return (1);
	}
	return (0);
}
