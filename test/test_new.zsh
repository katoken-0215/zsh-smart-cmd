#!/bin/zsh
local here=${0:A:h}
source "$here/helper.zsh"
source "$here/../autoload/new"

# new-term / new-cc をスタブ化して、どちらが呼ばれたか記録する
typeset -g CALLED=""
new-term() { CALLED="term" }
new-cc() { CALLED="cc" }

# --- terminal を選ぶと new-term に委譲 ---
fzf() { print -- "terminal (Ghostty)" }
new
assert_eq "term" "$CALLED" "terminal選択で new-term に委譲"

# --- claude-code を選ぶと new-cc に委譲 ---
CALLED=""
fzf() { print -- "claude-code (cmux)" }
new
assert_eq "cc" "$CALLED" "claude-code選択で new-cc に委譲"

# --- キャンセル時はどちらも呼ばない ---
CALLED=""
fzf() { return 130 }
new
assert_eq "" "$CALLED" "キャンセル時は委譲しない"

test_summary
