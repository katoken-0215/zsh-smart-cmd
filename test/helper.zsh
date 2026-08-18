#!/bin/zsh
# 最小限のアサーションヘルパー。各 test_*.zsh から source する。

typeset -gi TEST_FAILURES=0

# assert_eq <expected> <actual> <message>
assert_eq() {
	local expected=$1 actual=$2 msg=$3
	if [[ $expected == $actual ]]; then
		print -- "  ok: $msg"
	else
		print -- "  FAIL: $msg | expected:[$expected] actual:[$actual]"
		(( TEST_FAILURES++ ))
	fi
}

# 全アサーション後に呼ぶ。失敗があれば非0で終了。
test_summary() {
	(( TEST_FAILURES == 0 )) || exit 1
}
