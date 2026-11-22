#!/usr/bin/env bash

. ./ui.sh

init_coproc() {
	coproc COPRO {
		trap "exit" TERM INT
		ticker & tp=$!
		trap 'kill "$tp" 2>/dev/null' EXIT
		keyboard_reader </dev/tty;
	}
	exec 3<&"${COPRO[0]}"
}

at_exit() {
	[[ -n "$COPRO_PID" ]] && kill "$COPRO_PID" 2>/dev/null
	exec 3<&-
}

FPS=1
main() {
	init_terminal
	init_coproc

	while ! $SHOULD_EXIT ; do
		IFS= read -r -u 3 line
		case "$line" in
			TICK)    printf "got tick\n" ;;
			KEY:*)   printf "%s\n" "$line" ;;
			ERROR:*) printf "%s\n" "$line"; exit 1 ;;
			OFF:*)   printf "%s\n" "$line"; exit 1 ;;
		esac
	done;
}

main
