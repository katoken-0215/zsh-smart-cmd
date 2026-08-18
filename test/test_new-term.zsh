#!/bin/zsh
local here=${0:A:h}
source "$here/helper.zsh"
source "$here/../autoload/new-term"

# --- 正常系: smart-cmd-pick-repo が返したパスでGhosttyを開く ---
smart-cmd-pick-repo() { print -- "/path/to/repo" }
typeset -ga OPEN_ARGS
open() { OPEN_ARGS=("$@") }

new-term
assert_eq "-a Ghostty /path/to/repo" "${OPEN_ARGS[*]}" "Ghosttyを選択ディレクトリで開く"

# --- キャンセル系: pick-repo が非0なら open を呼ばない ---
OPEN_ARGS=()
smart-cmd-pick-repo() { return 1 }
new-term
assert_eq "" "${OPEN_ARGS[*]}" "キャンセル時は何もしない"

test_summary
