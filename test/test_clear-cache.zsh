#!/bin/zsh
local here=${0:A:h}
source "$here/helper.zsh"
source "$here/../autoload/clear-cache"

# clear-cache はサブシェルで動くため、呼び出し記録はファイルへ書く。
typeset original_path=$PATH
typeset original_home=$HOME
typeset test_home=$(mktemp -d)
typeset -g CALL_LOG="$test_home/calls.log"
typeset stderr_log="$test_home/stderr.log"

record_call() {
	print -r -- "$*" >> "$CALL_LOG"
}

# 最初は内部ヘルパーと同名の関数が存在しない状態で実行する。
mkdir -p "$test_home/Library/Caches/node-gyp"
: > "$CALL_LOG"
PATH=/nonexistent
HOME=$test_home

# --- 全ツール検出時は期待するコマンドを順番に実行する ---
pip() { record_call "pip $*" }
uvx() { record_call "uvx $*" }
uv() {
	if [[ "$*" == "cache clean --help" ]]; then
		return 0
	fi
	record_call "uv $*"
}
grep() { return 0 }
npm() { record_call "npm $*" }
pnpm() {
	if [[ "$*" == "cache --help" ]]; then
		return 0
	fi
	record_call "pnpm $*"
}
function pre-commit { record_call "pre-commit $*" }
prek() { record_call "prek $*" }
mise() { record_call "mise $*" }
brew() { record_call "brew $*" }
rm() { record_call "rm $*" }
docker() { record_call "docker $*" }

clear-cache 2> "$stderr_log"

expected_calls=$'pip cache purge\nuvx ruff clean\nuv cache clean --force\nnpm cache clean --force\npnpm store prune\npnpm cache delete *\npre-commit gc\nprek gc\nmise cache prune\nmise prune -y\nbrew cleanup -s\nrm -rf '"$test_home"$'/Library/Caches/node-gyp\ndocker system prune -f'
assert_eq "$expected_calls" "$(<"$CALL_LOG")" "全ツールへ安全化済みの引数を渡す"

expected_stderr=$'[clear-cache] Clearing pip cache...\n[clear-cache] Clearing ruff cache...\n[clear-cache] Clearing uv cache...\n[clear-cache] Clearing npm cache...\n[clear-cache] Clearing pnpm store...\n[clear-cache] Clearing pnpm metadata cache...\n[clear-cache] Clearing pre-commit cache...\n[clear-cache] Clearing prek cache...\n[clear-cache] Clearing mise cache...\n[clear-cache] Pruning unused mise tool versions...\n[clear-cache] Clearing Homebrew cache...\n[clear-cache] Clearing node-gyp cache...\n[clear-cache] Clearing Docker cache...'
assert_eq "$expected_stderr" "$(<"$stderr_log")" "進捗ログを stderr へ出力する"
assert_eq "0" "${+functions[check-command]}" "内部 check-command を残さない"
assert_eq "0" "${+functions[log]}" "内部 log を残さない"

unfunction pip uvx uv grep npm pnpm pre-commit prek mise brew rm docker
PATH=$original_path
command rm -rf "$test_home/Library"
PATH=/nonexistent

# --- uv が --force 非対応なら互換コマンドへフォールバックする ---
# 呼び出し元の同名関数が実行後も維持されることも確認する。
: > "$CALL_LOG"
check-command() { print -- "existing-check-command" }
log() { print -- "existing-log" }
uv() {
	if [[ "$*" == "cache clean --help" ]]; then
		return 0
	fi
	record_call "uv $*"
}
grep() { return 1 }
clear-cache 2> /dev/null
assert_eq "uv cache clean" "$(<"$CALL_LOG")" "古い uv では --force を付けない"
assert_eq "existing-check-command" "$(check-command)" "既存 check-command を保持する"
assert_eq "existing-log" "$(log)" "既存 log を保持する"
unfunction uv grep

# --- pnpm metadata cache 非対応なら store prune だけを実行する ---
: > "$CALL_LOG"
pnpm() {
	if [[ "$*" == "cache --help" ]]; then
		return 1
	fi
	record_call "pnpm $*"
}
clear-cache 2> /dev/null
assert_eq "pnpm store prune" "$(<"$CALL_LOG")" "古い pnpm では metadata 削除をスキップする"
unfunction pnpm

# --- ツールも node-gyp ディレクトリもなければ何もしない ---
: > "$CALL_LOG"
: > "$stderr_log"
clear-cache 2> "$stderr_log"
assert_eq "" "$(<"$CALL_LOG")" "未インストールのツールを実行しない"
assert_eq "" "$(<"$stderr_log")" "処理対象がなければログを出さない"

PATH=$original_path
HOME=$original_home
unfunction check-command log record_call
command rm -rf "$test_home"

test_summary
