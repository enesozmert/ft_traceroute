# =============================================================================
# ft_traceroute — Makefile (Ecole 42, Subject v5.0)
# Subject mandatory rules: all / clean / fclean / re
# Extra targets: run / norm / cppcheck / misra / test / valgrind / asan / cmake
# =============================================================================

# ---------------------------------------------------------------------------
# Compiler & flags
# ---------------------------------------------------------------------------
CC      = gcc
STD     = -std=c11
CFLAGS  = -Wall -Wextra -Werror $(STD) -g -Ihdr
DEPFLAGS = -MMD -MP

ASAN_FLAGS   = -fsanitize=address -fno-omit-frame-pointer
STRICT_FLAGS = -Wpedantic -Wshadow -Wconversion -Wcast-align -Wstrict-prototypes

# ---------------------------------------------------------------------------
# Directories
# ---------------------------------------------------------------------------
SRCDIR  = src
OBJDIR  = obj
HDRDIR  = hdr
OUTDIR  = output
TESTDIR = test

NET_HOST    ?= 8.8.8.8
NET_TIMEOUT ?= 40s
CONTAINER   ?= ft_traceroute_container

# ---------------------------------------------------------------------------
# Project name & files
# ---------------------------------------------------------------------------
NAME = $(OUTDIR)/ft_traceroute
SRCS = $(wildcard $(SRCDIR)/*.c)
OBJS = $(patsubst $(SRCDIR)/%.c, $(OBJDIR)/%.o, $(SRCS))
DEPS = $(OBJS:.o=.d)

# ---------------------------------------------------------------------------
# Subject mandatory rules
# ---------------------------------------------------------------------------
all: $(NAME)

$(NAME): $(OBJS)
	@mkdir -p $(OUTDIR)
	$(CC) $(CFLAGS) -o $(NAME) $(OBJS) -lm
	@# Try to apply CAP_NET_RAW automatically (non-fatal if unavailable)
	@if command -v setcap >/dev/null 2>&1; then \
		setcap cap_net_raw+ep $(NAME) >/dev/null 2>&1 || true; \
	fi

$(OBJDIR)/%.o: $(SRCDIR)/%.c | $(OBJDIR)
	$(CC) $(CFLAGS) $(DEPFLAGS) -c $< -o $@

$(OBJDIR):
	@mkdir -p $(OBJDIR)

clean:
	rm -f $(OBJS) $(DEPS)

fclean: clean
	rm -f $(NAME)
	rm -rf $(OUTDIR)

re: fclean all

# Header dependency tracking (auto-generated *.d files)
-include $(DEPS)

# ---------------------------------------------------------------------------
# Run target — supports ARGS="..." and SUDO=1
# ---------------------------------------------------------------------------
ARGS ?=
SUDO ?= 0

run: $(NAME)
	@if [ "$(SUDO)" = "1" ]; then \
		echo "Running $(NAME) with sudo $(ARGS)"; \
		sudo $(NAME) $(ARGS); \
	else \
		echo "Running $(NAME) $(ARGS)"; \
		$(NAME) $(ARGS); \
	fi

# Apply CAP_NET_RAW so binary runs without sudo
setcap: $(NAME)
	sudo setcap cap_net_raw+ep $(NAME)

# ---------------------------------------------------------------------------
# Quality — Norminette (Ecole 42)
# ---------------------------------------------------------------------------
NORM_PATHS = $(SRCDIR) $(HDRDIR)

norm:
	@command -v norminette >/dev/null 2>&1 || { \
		echo "norminette not found. Install: pip install norminette"; exit 1; }
	@echo "==> Running norminette on $(NORM_PATHS)"
	@norminette $(NORM_PATHS) || (echo "norminette failed"; exit 1)

# ---------------------------------------------------------------------------
# Quality — Cppcheck (general static analysis)
# ---------------------------------------------------------------------------
CPPCHECK_OUT = cppcheck.txt

cppcheck:
	@command -v cppcheck >/dev/null 2>&1 || { \
		echo "cppcheck not found. Install: apt-get install cppcheck"; exit 1; }
	@echo "==> Running cppcheck (general)"
	cppcheck --enable=all --inconclusive --std=c11 --force \
		--suppress=missingIncludeSystem \
		-I $(HDRDIR) \
		--quiet $(SRCDIR) 2> $(CPPCHECK_OUT) || true
	@echo "Output: $(CPPCHECK_OUT)"
	@cat $(CPPCHECK_OUT)

# ---------------------------------------------------------------------------
# Quality — MISRA C:2012 (cppcheck addon)
# ---------------------------------------------------------------------------
MISRA_OUT = misra.txt
MISRA_ADDON ?= /usr/share/cppcheck/addons/misra.py

misra:
	@command -v cppcheck >/dev/null 2>&1 || { echo "cppcheck not found"; exit 1; }
	@command -v python3 >/dev/null 2>&1 || { echo "python3 not found"; exit 1; }
	@echo "==> Generating cppcheck dumps"
	cppcheck --dump --std=c11 -I $(HDRDIR) $(SRCDIR)/*.c >/dev/null 2>&1
	@echo "==> Running MISRA C:2012 addon"
	@if [ -f "$(MISRA_ADDON)" ]; then \
		python3 $(MISRA_ADDON) $(SRCDIR)/*.dump > $(MISRA_OUT) 2>&1 || true; \
	else \
		cppcheck --addon=misra --std=c11 -I $(HDRDIR) $(SRCDIR) 2> $(MISRA_OUT) || true; \
	fi
	@echo "Output: $(MISRA_OUT)"
	@cat $(MISRA_OUT)

# ---------------------------------------------------------------------------
# Quality — Strict build (extra warnings)
# ---------------------------------------------------------------------------
strict:
	$(MAKE) re CFLAGS="$(CFLAGS) $(STRICT_FLAGS)"

# ---------------------------------------------------------------------------
# Tests — CLI / exit-code smoke tests (no network needed)
# ---------------------------------------------------------------------------
test: $(NAME)
	@sh $(TESTDIR)/run_tests.sh $(NAME)

# ---------------------------------------------------------------------------
# Network test — needs root or CAP_NET_RAW (ICMP raw recv socket)
# ---------------------------------------------------------------------------
test-net: $(NAME)
	@echo "==> ft_traceroute network test ($(NET_HOST))"
	@if [ "$$(id -u)" -ne 0 ] && ! (command -v getcap >/dev/null 2>&1 && getcap $(NAME) | grep -q cap_net_raw); then \
		echo "  CAP_NET_RAW not set, trying to apply..."; \
		if command -v sudo >/dev/null 2>&1 && sudo -n true >/dev/null 2>&1; then \
			sudo -n setcap cap_net_raw+ep $(NAME) >/dev/null 2>&1 || true; \
		fi; \
	fi
	@if [ "$$(id -u)" -ne 0 ] && ! (command -v getcap >/dev/null 2>&1 && getcap $(NAME) | grep -q cap_net_raw); then \
		echo "  FAIL: root/CAP_NET_RAW required (run in container as root, or once: sudo setcap cap_net_raw+ep $(NAME))"; \
		exit 1; \
	fi
	@timeout -s INT $(NET_TIMEOUT) $(NAME) $(NET_HOST) >/tmp/ft_traceroute_net_test.log 2>&1 || true
	@if grep -Eq "^traceroute to " /tmp/ft_traceroute_net_test.log \
		&& grep -Eq "^[ ]*[0-9]+[ ]+(\*|[0-9]{1,3}\.)" /tmp/ft_traceroute_net_test.log; then \
		echo "  OK"; \
	else \
		echo "  FAIL (output: /tmp/ft_traceroute_net_test.log)"; \
		tail -n 20 /tmp/ft_traceroute_net_test.log || true; \
		exit 1; \
	fi

test-net-docker:
	@echo "==> ft_traceroute network test in container ($(CONTAINER))"
	@docker ps --format '{{.Names}}' | grep -qx "$(CONTAINER)" || { \
		echo "  Container not running. Start first: docker compose -f docker/docker-compose.yml up -d"; \
		exit 1; \
	}
	@docker exec -i $(CONTAINER) bash -lc "cd /usr/src/ft_traceroute && make --no-print-directory test-net NET_HOST='$(NET_HOST)' NET_TIMEOUT='$(NET_TIMEOUT)'"

# ---------------------------------------------------------------------------
# Valgrind — memory leak / invalid access
# ---------------------------------------------------------------------------
VALGRIND_HOST ?= 127.0.0.1
VALGRIND_TIMEOUT ?= 40s
VALGRIND_FLAGS = --leak-check=full --show-leak-kinds=all --track-origins=yes \
                 --error-exitcode=1

valgrind: $(NAME)
	@command -v valgrind >/dev/null 2>&1 || { echo "valgrind not found"; exit 1; }
	@echo "==> valgrind: argument-error paths (no privileges needed)"
	valgrind $(VALGRIND_FLAGS) $(NAME) --help
	valgrind $(VALGRIND_FLAGS) $(NAME) nonexistent.invalid.tld || true
	@echo "==> valgrind: live trace ($(VALGRIND_HOST))"
	timeout -s INT $(VALGRIND_TIMEOUT) valgrind $(VALGRIND_FLAGS) $(NAME) $(VALGRIND_HOST)

# ---------------------------------------------------------------------------
# AddressSanitizer build
# ---------------------------------------------------------------------------
asan:
	$(MAKE) re CFLAGS="$(CFLAGS) $(ASAN_FLAGS)"

# ---------------------------------------------------------------------------
# CMake delegation (out-of-source build under build/)
# ---------------------------------------------------------------------------
CMAKE_BUILD_DIR = build

cmake-build:
	@command -v cmake >/dev/null 2>&1 || { echo "cmake not found"; exit 1; }
	cmake -S . -B $(CMAKE_BUILD_DIR) -DCMAKE_BUILD_TYPE=Debug
	cmake --build $(CMAKE_BUILD_DIR) -j

cmake-clean:
	rm -rf $(CMAKE_BUILD_DIR)

# ---------------------------------------------------------------------------
# Reference (GNU inetutils / LBL traceroute) diff helper
# ---------------------------------------------------------------------------
DIFF_HOST ?= 8.8.8.8

diff-ref: $(NAME)
	@command -v traceroute >/dev/null 2>&1 || { echo "system traceroute not found"; exit 1; }
	@echo "==> Comparing ft_traceroute vs system traceroute ($(DIFF_HOST))"
	@traceroute $(DIFF_HOST) > /tmp/ref-traceroute.txt 2>&1 || true
	@$(NAME) $(DIFF_HOST) > /tmp/our-traceroute.txt 2>&1 || true
	@echo "--- line-by-line diff (RTT values will differ, layout must not) ---"
	-@diff -u /tmp/ref-traceroute.txt /tmp/our-traceroute.txt || true
	@echo "--- layout-only diff (digits normalised to N) ---"
	-@sed -E 's/[0-9]+/N/g' /tmp/ref-traceroute.txt > /tmp/ref-layout.txt; \
	  sed -E 's/[0-9]+/N/g' /tmp/our-traceroute.txt > /tmp/our-layout.txt; \
	  diff -u /tmp/ref-layout.txt /tmp/our-layout.txt && echo "  layout identical" || true

# ---------------------------------------------------------------------------
# Help
# ---------------------------------------------------------------------------
help:
	@echo "ft_traceroute Makefile — available targets:"
	@echo ""
	@echo "  Subject mandatory:"
	@echo "    all          Build $(NAME)"
	@echo "    clean        Remove object/dependency files"
	@echo "    fclean       clean + remove executable"
	@echo "    re           fclean + all"
	@echo ""
	@echo "  Run:"
	@echo "    run          Run binary (ARGS=\"...\" SUDO=1)"
	@echo "    setcap       Apply CAP_NET_RAW to binary"
	@echo ""
	@echo "  Quality:"
	@echo "    norm         Run Ecole 42 norminette"
	@echo "    cppcheck     Run cppcheck static analysis"
	@echo "    misra        Run MISRA C:2012 addon"
	@echo "    strict       Rebuild with -Wpedantic -Wshadow -Wconversion"
	@echo ""
	@echo "  Test:"
	@echo "    test              Smoke tests (CLI/exit-code)"
	@echo "    test-net          Network test (auto CAP_NET_RAW prepare)"
	@echo "    test-net-docker   Network test inside container"
	@echo "    valgrind          Run under valgrind (VALGRIND_HOST=...)"
	@echo "    asan              Rebuild with AddressSanitizer"
	@echo "    diff-ref          Diff against system traceroute (DIFF_HOST=...)"
	@echo ""
	@echo "  CMake:"
	@echo "    cmake-build  Configure + build via CMake"
	@echo "    cmake-clean  Remove build/ directory"

# ---------------------------------------------------------------------------
# Phony targets
# ---------------------------------------------------------------------------
.PHONY: all clean fclean re run setcap \
        norm cppcheck misra strict \
        test test-net test-net-docker valgrind asan \
        cmake-build cmake-clean \
        diff-ref help
