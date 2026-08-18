#!/bin/zsh
local here=${0:A:h}
source "$here/helper.zsh"
source "$here/../autoload/smart-cmd-pick-repo"

# --- 正常系: 選択されたリポジトリのフルパスを返す ---
ghq() {
	case $1 in
		list) print -l "github.com/foo/bar" "github.com/baz/qux" ;;
		root) print -- "/Users/test/ghq" ;;
	esac
}
sk() { print -- "github.com/foo/bar" }

local result
result=$(smart-cmd-pick-repo)
assert_eq "/Users/test/ghq/github.com/foo/bar" "$result" "選択リポジトリのフルパスを返す"

# --- キャンセル系: skが非0なら非0で返す ---
sk() { return 130 }
smart-cmd-pick-repo >/dev/null
assert_eq 1 $? "skキャンセル時は非0で返す"

# --- 異常系: ghq root が失敗したら非0で返す（壊れたパスをechoしない） ---
ghq() { [[ $1 == root ]] && return 1; print -l "github.com/foo/bar" }
sk() { print -- "github.com/foo/bar" }
local broken
broken=$(smart-cmd-pick-repo)
assert_eq 1 $? "ghq root失敗時は非0で返す"
assert_eq "" "$broken" "ghq root失敗時は何もechoしない"

test_summary
