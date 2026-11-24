# === INPUT ===
declare -A KEY_TABLE=(
	# ARROWS
	[$'\e[A']=UP       [$'\eOA']=UP
	[$'\e[B']=DOWN     [$'\eOB']=DOWN
	[$'\e[C']=RIGHT    [$'\eOC']=RIGHT
	[$'\e[D']=LEFT     [$'\eOD']=LEFT

	# NAVIGATION
	[$'\e[2~']=INSERT  [$'\e[3~']=DELETE
	[$'\e[H']=HOME     [$'\e[1~']=HOME   [$'\e[7~']=HOME [$'\eOH']=HOME
	[$'\e[E']=CENTER   [$'\eOE']=CENTER  [$'\e[G']=CENTER
	[$'\e[F']=END      [$'\e[4~']=END    [$'\e[8~']=END  [$'\eOF']=END
	[$'\e[5~']=PAGEUP  [$'\e[6~']=PAGEDOWN
	[$'\e[Z']=SHIFT+TAB

	# F1-F4
	[$'\e[11~']=F1  [$'\e[[A']=F1  [$'\eOP']=F1  [$'\e[P']=F1
	[$'\e[12~']=F2  [$'\e[[B']=F2  [$'\eOQ']=F2  [$'\e[Q']=F2
	[$'\e[13~']=F3  [$'\e[[C']=F3  [$'\eOR']=F3  [$'\e[R']=F3
	[$'\e[14~']=F4  [$'\e[[D']=F4  [$'\eOS']=F4  [$'\e[S']=F4

	# F5-F12
	[$'\e[15~']=F5  [$'\e[[E']=F5
	[$'\e[17~']=F6
	[$'\e[18~']=F7
	[$'\e[19~']=F8
	[$'\e[20~']=F9
	[$'\e[21~']=F10
	[$'\e[23~']=F11
	[$'\e[24~']=F12

	# OTHER
	[$'\r']=ENTER       [$'\n']=ENTER
	[$'\x7f']=BACKSPACE [$'\x08']=BACKSPACE
	[$'\t']=TAB         [' ']=SPACE
	[$'\e']=ESC
)

KB_ESC_TIMEOUT=${KB_ESC_TIMEOUT:-0.05}
KB_SEQ_TIMEOUT=${KB_SEQ_TIMEOUT:-0.01}
KB_ABC="abcdefghijklmnopqrstuvwxyz"
KB_CTRL_EXTRA='\]^_'
KB_RE_MOD=$'^\e\[([0-9]*);([0-9]+)(.)$'

# read key into `local seq` from parent
kb_read_seq() {
	local char code

	IFS= read -rsn1 -d '' char || return 1
	seq=$char
	[[ $char == $'\e' ]] || return 0

	IFS= read -rsn1 -d '' -t "$KB_ESC_TIMEOUT" char || return 0
	seq+=$char
	[[ $char == '[' || $char == 'O' ]] || return 0

	while IFS= read -rsn1 -d '' -t "$KB_SEQ_TIMEOUT" char; do
		seq+=$char
		[[ $seq == $'\e[[' ]] && continue
		printf -v code '%d' "'$char"
		(( code >= 64 && code <= 126 )) && break
	done
	return 0
}

# SEQ -> NAME into `local name` from parent; return 1 if not SEQ
kb_name_mod() {
	local seq=$1 p mod fin base_seq base bits prefix=''

	[[ $seq =~ $KB_RE_MOD ]] || return 1
	p=${BASH_REMATCH[1]} mod=${BASH_REMATCH[2]} fin=${BASH_REMATCH[3]}

	case $fin in
		'~') base_seq=$'\e['"$p~" ;;
		Z)   base_seq=$'\e[Z' ;;
		*)   if [[ -z $p || $p == 1 ]]; then
				base_seq=$'\e['"$fin"
			else
				base_seq=$'\e['"$p$fin"
			fi ;;
	esac

	base=${KEY_TABLE["$base_seq"]-}
	bits=$(( mod - 1 ))
	if [[ $fin == Z ]]; then base=TAB; bits=$(( bits | 1 )); fi
	[[ -n $base ]] || { name=UNKNOWN; return 0; }

	(( bits & 4 )) && prefix+=CTRL+
	(( bits & 2 )) && prefix+=ALT+
	(( bits & 1 )) && prefix+=SHIFT+
	(( bits & 8 )) && prefix+=META+

	name=$prefix$base
}

# KEY -> NAME into `local name` from parent
kb_name() {
	local seq=$1 c code
	name=UNKNOWN

	if [[ -z $seq ]]; then
		name=CTRL+SPACE
	elif [[ -n ${KEY_TABLE["$seq"]+x} ]]; then
		name=${KEY_TABLE["$seq"]}
	elif (( ${#seq} == 1 )); then
		printf -v code '%d' "'$seq"
		if   (( code >= 1  && code <= 26 )); then name="CTRL+${KB_ABC:code-1:1}"
		elif (( code >= 28 && code <= 31 )); then name="CTRL+${KB_CTRL_EXTRA:code-28:1}"
		else name=$seq; fi
	elif [[ $seq == $'\e'? ]]; then
		c=${seq:1:1}
		printf -v code '%d' "'$c"
		if   [[ -n ${KEY_TABLE["$c"]+x} ]]; then name="ALT+${KEY_TABLE["$c"]}"
		elif (( code >= 1 && code <= 26 )); then name="CTRL+ALT+${KB_ABC:code-1:1}"
		else name="ALT+$c"; fi
	else
		kb_name_mod "$seq"
	fi
}

keyboard_reader() {
	local seq name

	while kb_read_seq; do
		kb_name "$seq"
		printf 'KEY:%s\n' "$name"
	done
	printf 'OFF:KEYBOARD\n'
}
# === INPUT ===


# === TICKER ===
ticker() {
	local t us
	us=$(( 1000000 / FPS ))
	printf -v t '%d.%06d' $(( us / 1000000 )) $(( us % 1000000 ))
	
	local nofd
	exec {nofd}<> <(:)

	printf "TICK\n"
	while true; do
		IFS= read -r -t "$t" -u "$nofd"
		if (( $? <= 128 )); then
			printf "ERROR:TICKER\n"
			return 1
		fi

		printf "TICK\n"
	done
}
# === TICKER ===


# === ANSI ESCAPE CODES ===
ESC=$'\e'

CURSOR_HIDE="${ESC}[?25l"
CURSOR_SHOW="${ESC}[?25h"
CURSOR_SAVE="${ESC}[s"
CURSOR_RESTORE="${ESC}[u"

SCREEN_CLEAR="${ESC}[2J"
SCREEN_CLEAR_LINE="${ESC}[2K"
CURSOR_HOME="${ESC}[H"
ALT_SCREEN_ENTER="${ESC}[?1049h"
ALT_SCREEN_EXIT="${ESC}[?1049l"
WRAP_OFF="${ESC}[?7l"
WRAP_ON="${ESC}[?7h"

RESET="${ESC}[0m"
BOLD="${ESC}[1m"
DIM="${ESC}[2m"
ITALIC="${ESC}[3m"
UNDERLINE="${ESC}[4m"
REVERSE="${ESC}[7m"
STRIKETHROUGH="${ESC}[9m"

BLACK="${ESC}[30m"
RED="${ESC}[31m"
GREEN="${ESC}[32m"
YELLOW="${ESC}[33m"
BLUE="${ESC}[34m"
MAGENTA="${ESC}[35m"
CYAN="${ESC}[36m"
WHITE="${ESC}[37m"

BG_BLACK="${ESC}[40m"
BG_RED="${ESC}[41m"
BG_GREEN="${ESC}[42m"
BG_YELLOW="${ESC}[43m"
BG_BLUE="${ESC}[44m"
BG_MAGENTA="${ESC}[45m"
BG_CYAN="${ESC}[46m"
BG_WHITE="${ESC}[47m"
# === ANSI ESCAPE CODES ===


# === GLOBAL STATE ===
CURRENT_SCREEN=""
declare -A SCREENS=()
SCREEN_HISTORY=()
SHOULD_EXIT=false
DIRTY=true
# === GLOBAL STATE ===


# === BASIC FUNCTIONS ===
init_terminal() {
	shopt -s checkwinsize
	printf "%b%b" "${ALT_SCREEN_ENTER}" "${CURSOR_HIDE}"
	printf "%b" "${WRAP_OFF}"
	trap "cleanup; at_exit" EXIT
	trap 'exit 130' INT
	trap 'exit 143' TERM
	trap 'term_refresh' WINCH
	term_refresh
}

cleanup() {
	printf "%b%b" "${CURSOR_SHOW}" "${ALT_SCREEN_EXIT}"
	printf "%b" "${WRAP_ON}"
}

at_exit() {
	:
}

clear_screen() {
	printf "%b%b" "${SCREEN_CLEAR}" "${CURSOR_HOME}"
}

move_cursor() {
	printf "%b[%d;%dH" "${ESC}" "$1" "$2"
}

term_refresh() {
	(:;:)
	DIRTY=true
}
# === BASIC FUNCTIONS ===


# === NAVIGATION ===
push_screen() {
	SCREEN_HISTORY+=("$CURRENT_SCREEN")
	CURRENT_SCREEN="$1"
	DIRTY=true
}

pop_screen() {
	if (( ${#SCREEN_HISTORY[@]} > 0 )); then
		local last=$(( ${#SCREEN_HISTORY[@]} - 1 ))
		CURRENT_SCREEN="${SCREEN_HISTORY[$last]}"
		unset "SCREEN_HISTORY[$last]"
		DIRTY=true
	else
		SHOULD_EXIT=true
	fi
}

goto_screen() {
	CURRENT_SCREEN="$1"
	DIRTY=true
}
# === NAVIGATION ===

# === DRAWING ===
# _on_screen <row> <col>
_on_screen() {
	(( $1 >= 1 && $2 >= 1 && (LINES < 1 || $1 <= LINES) && (COLUMNS < 1 || $2 <= COLUMNS) ))
}

# fit_text <var> <text> <width>
fit_text() {
	if (( $3 <= 0 )); then printf -v "$1" ''; return 0; fi
	local _ft_s=${2:0:$3} _ft_pad
	printf -v _ft_pad '%*s' $(( $3 - ${#_ft_s} )) ''
	printf -v "$1" '%s%s' "$_ft_s" "$_ft_pad"
}

# repeat_char <var> <char> <count>
repeat_char() {
	if (( $3 <= 0 )); then printf -v "$1" ''; return 0; fi
	printf -v "$1" '%*s' "$3" ''
	printf -v "$1" '%s' "${!1// /"$2"}"
}

# draw_text <row> <col> <width> <text> [style]
draw_text() {
	_on_screen "$1" "$2" || return 0
	local s
	fit_text s "$4" "$3"
	printf '\e[%d;%dH%s%s%s' "$1" "$2" "${5-}" "$s" "$RESET"
}

# draw_centered <row> <text> [style]
draw_centered() {
	local w=${#2} col
	(( COLUMNS > 0 && w > COLUMNS )) && w=$COLUMNS
	col=$(( (COLUMNS - w) / 2 + 1 ))
	(( col < 1 )) && col=1
	draw_text "$1" "$col" "$w" "$2" "${3-}"
}

# draw_fill <row> <col> <w> <h> [style]: залить прямоугольник пробелами
draw_fill() {
	local row=$1 col=$2 w=$3 h=$4 pad out='' i
	(( w > 0 && h > 0 )) || return 0
	printf -v pad '%*s' "$w" ''
	for (( i=0; i<h; i++ )); do
		_on_screen $(( row + i )) "$col" || continue
		out+=$'\e'"[$(( row + i ));${col}H${pad}"
	done
	printf '%s%s%s' "${5-}" "$out" "$RESET"
}

declare -A BOX_CHARS=(
	[ASCII]='++++-|'
	[SINGLE]='┌┐└┘─│'
	[DOUBLE]='╔╗╚╝═║'
	[ROUND]='╭╮╰╯─│'
)
BOX_STYLE=SINGLE

# draw_hline <row> <col> <width> [char] [style]
draw_hline() {
	_on_screen "$1" "$2" || return 0
	local line set=${BOX_CHARS[$BOX_STYLE]:-${BOX_CHARS[SINGLE]}}
	repeat_char line "${4:-${set:4:1}}" "$3"
	printf '\e[%d;%dH%s%s%s' "$1" "$2" "${5-}" "$line" "$RESET"
}

# draw_box <row> <col> <w> <h> [title] [style] [border: ASCII|SINGLE|DOUBLE|ROUND]
draw_box() {
	local row=$1 col=$2 w=$3 h=$4 title=${5-} style=${6-}
	(( w >= 2 && h >= 2 )) || return 0

	local set=${BOX_CHARS[${7:-$BOX_STYLE}]:-${BOX_CHARS[SINGLE]}}
	local tl=${set:0:1} tr=${set:1:1} bl=${set:2:1} br=${set:3:1}
	local hz=${set:4:1} vt=${set:5:1}
	local inner=$(( w - 2 )) right=$(( col + w - 1 )) bottom=$(( row + h - 1 ))
	local e=$'\e' bar out='' i

	if _on_screen "$row" "$col"; then
		if [[ -n $title ]] && (( inner >= 4 )); then
			title=${title:0:inner-3}
			repeat_char bar "$hz" $(( inner - ${#title} - 3 ))
			out+="${e}[${row};${col}H${tl}${hz} ${title} ${bar}${tr}"
		else
			repeat_char bar "$hz" "$inner"
			out+="${e}[${row};${col}H${tl}${bar}${tr}"
		fi
	fi

	for (( i=1; i<h-1; i++ )); do
		_on_screen $(( row + i )) "$col" || continue
		out+="${e}[$(( row + i ));${col}H${vt}${e}[$(( row + i ));${right}H${vt}"
	done

	if _on_screen "$bottom" "$col"; then
		repeat_char bar "$hz" "$inner"
		out+="${e}[${bottom};${col}H${bl}${bar}${br}"
	fi

	printf '%s%s%s' "$style" "$out" "$RESET"
}

drawing_begin() { printf '\e[?2026h'; }
drawing_end()   { printf '\e[?2026l'; }
# === DRAWING ===
