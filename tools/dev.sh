#!/usr/bin/env bash
# The dev loop on macOS and Linux. The Windows equivalents are build.ps1 and
# coop_test.ps1.
#
#   tools/dev.sh import                  rebuild the import cache (after a pull
#                                        that adds a class_name, asset or .uid)
#   tools/dev.sh test                    headless unit tests
#   tools/dev.sh scenario starter        one scripted in-world check
#   tools/dev.sh scenario guns --seed=1  ... with extra arguments passed through
#   tools/dev.sh look shore shot.png     a screenshot of one view
#   tools/dev.sh check                   import, then tests, then the starter scenario
#
# Set GODOT to use a specific build.
set -euo pipefail

project="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Both developers must be on the same Godot patch version — a mismatch shows up
# as assets reimporting differently on the two machines. Version-suffixed
# installs are preferred over a bare Godot.app, which could be any build.
GODOT_VERSION="${GODOT_VERSION:-4.7.2}"

godot="${GODOT:-}"
if [[ -z "$godot" ]]; then
	for candidate in \
		"/Applications/Godot_v$GODOT_VERSION.app/Contents/MacOS/Godot" \
		"$(command -v "godot$GODOT_VERSION" || true)" \
		/Applications/Godot.app/Contents/MacOS/Godot \
		"$(command -v godot4 || true)" \
		"$(command -v godot || true)"
	do
		if [[ -n "$candidate" && -x "$candidate" ]]; then godot="$candidate"; break; fi
	done
fi
if [[ -z "$godot" ]]; then
	echo "Godot not found. Set GODOT=/path/to/Godot" >&2
	exit 1
fi

# Warn rather than refuse: an intentional version test is fine, a silent mismatch
# is not.
found_version="$("$godot" --version 2>/dev/null | tail -1)"
if [[ "$found_version" != "$GODOT_VERSION."* ]]; then
	echo "warning: using Godot $found_version, but this project targets $GODOT_VERSION" >&2
	echo "         ($godot)" >&2
fi

# Test runs get their own profile and a port in Josh's range (Troy uses 24600+),
# so they can never touch a real save or collide with the other developer.
profile="${RIPTIDE_TEST_PROFILE:-test_a}"
port="${RIPTIDE_TEST_PORT:-24710}"

# A scripted run must never steal focus or make noise on the developer's machine.
run_scenario() {
	local scenario="$1"; shift
	"$godot" --path "$project" --no-focus --audio-driver Dummy -- \
		--host "--profile=$profile" "--port=$port" "--scenario=$scenario" "$@"
}

command="${1:-check}"
[[ $# -gt 0 ]] && shift

case "$command" in
import)
	"$godot" --headless --path "$project" --import
	;;
test)
	"$godot" --headless --path "$project" --script res://tests/run_tests.gd
	;;
scenario)
	[[ $# -gt 0 ]] || { echo "usage: tools/dev.sh scenario <name> [args...]" >&2; exit 2; }
	run_scenario "$@"
	;;
look)
	[[ $# -ge 2 ]] || { echo "usage: tools/dev.sh look <face> <output.png> [args...]" >&2; exit 2; }
	face="$1"; shot="$2"; shift 2
	# The screenshot path has to be absolute for Godot to find it.
	[[ "$shot" = /* ]] || shot="$PWD/$shot"
	run_scenario look "--face=$face" "--shot=$shot" --dev "$@"
	echo "wrote $shot"
	;;
check)
	"$godot" --headless --path "$project" --import
	"$godot" --headless --path "$project" --script res://tests/run_tests.gd
	run_scenario starter --seed=4242
	;;
run)
	"$godot" --path "$project" -- --dev "$@"
	;;
*)
	sed -n '2,15p' "${BASH_SOURCE[0]}" >&2
	exit 2
	;;
esac
