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


# === SCREENS ===
SCREENS["main_menu"]="screen_main_menu"
screen_main_menu() {
	local key=$1
	
	case "$key" in
		KEY:q) SHOULD_EXIT=true ;;
	esac

	if $DIRTY; then
		drawing_begin
		
		clear_screen
		draw_box 1 1 $COLUMNS $LINES "main menu" "" "ROUND"
		
		drawing_end
		DIRTY=false
	fi
}

FPS=30
main() {
	init_terminal
	init_coproc

	CURRENT_SCREEN="main_menu"
	while ! $SHOULD_EXIT ; do
		IFS= read -r -u 3 line
		case "$line" in
			TICK)    ${SCREENS["$CURRENT_SCREEN"]} "" ;;
			KEY:*)   ${SCREENS["$CURRENT_SCREEN"]} "$line" ;;
			OFF:*|ERROR:*)   SHOULD_EXIT=true ;;
		esac
	done;
}

main
