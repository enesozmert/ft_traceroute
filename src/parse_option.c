/* ************************************************************************** */
/*                                                                            */
/*                                                        :::      ::::::::   */
/*   parse_option.c                                     :+:      :+:    :+:   */
/*                                                    +:+ +:+         +:+     */
/*   By: ozmerte <ozmerte@student.42.fr>            +#+  +:+       +#+        */
/*                                                +#+#+#+#+#+   +#+           */
/*   Created: 2026/11/14 00:00:00 by ozmerte          #+#    #+#             */
/*   Updated: 2026/11/14 00:00:00 by ozmerte         ###   ########.fr       */
/*                                                                            */
/* ************************************************************************** */

#include "header.h"

static int	option_error(const char *reason, const char *arg)
{
	fprintf(stderr, "ft_traceroute: %s '%s'\n", reason, arg);
	print_usage(stderr);
	return (-1);
}

/*
** Whole-string conversion: a trailing character makes the value invalid,
** so "-m 5x" is rejected instead of silently becoming 5.
*/

static int	parse_value(const char *text, int min, int max, int *out)
{
	char	*end;
	long	value;

	if (text[0] == '\0')
		return (1);
	errno = 0;
	value = strtol(text, &end, 10);
	if (*end != '\0' || errno != 0)
		return (1);
	if (value < (long)min || value > (long)max)
		return (1);
	*out = (int)value;
	return (0);
}

static int	*opt_target(const char *name, t_options *opt, int *min, int *max)
{
	*min = 1;
	if (strcmp(name, "-m") == 0)
	{
		*max = 255;
		return (&opt->max_hops);
	}
	if (strcmp(name, "-q") == 0)
	{
		*max = TR_MAX_PROBES;
		return (&opt->nprobes);
	}
	if (strcmp(name, "-p") == 0)
	{
		*max = 65535;
		return (&opt->base_port);
	}
	if (strcmp(name, "-w") == 0)
	{
		*max = 60;
		return (&opt->probe_timeout);
	}
	return (NULL);
}

int	parse_option(int argc, char *argv[], int i, t_options *opt)
{
	int	*target;
	int	min;
	int	max;

	if (strcmp(argv[i], "--resolve") == 0)
	{
		opt->resolve_dns = 1;
		return (1);
	}
	target = opt_target(argv[i], opt, &min, &max);
	if (target == NULL)
	{
		if (argv[i][0] == '-' && argv[i][1] != '\0')
			return (option_error("invalid option", argv[i]));
		return (0);
	}
	if (i + 1 >= argc)
		return (option_error("option requires a value", argv[i]));
	if (parse_value(argv[i + 1], min, max, target) != 0)
		return (option_error("invalid value for", argv[i]));
	return (2);
}
