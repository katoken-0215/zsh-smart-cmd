#!/bin/zsh
local here=${0:A:h}
source "$here/helper.zsh"
source "$here/../autoload/new-cc"

# --- 正常系: cmux new-workspace を正しい引数で呼ぶ ---
smart-cmd-pick-repo() { print -- "/path/to/repo" }
typeset -ga CMUX_ARGS
cmux() { CMUX_ARGS=("$@") }

new-cc
assert_eq "new-workspace --cwd /path/to/repo --command claude --focus true" \
	"${CMUX_ARGS[*]}" "cmux new-workspace でclaudeを起動する"

# --- キャンセル系: pick-repo が非0なら cmux を呼ばない ---
CMUX_ARGS=()
smart-cmd-pick-repo() { return 1 }
new-cc
assert_eq "" "${CMUX_ARGS[*]}" "キャンセル時は何もしない"

test_summary
