#!/bin/zsh
# test/ 配下の test_*.zsh を各々別プロセスで実行し、結果を集計する。

local here=${0:A:h}
typeset -i fails=0

for t in "$here"/test_*.zsh(N); do
	print -- "== ${t:t} =="
	zsh "$t" || (( fails++ ))
done

if (( fails == 0 )); then
	print -- "ALL PASS"
else
	print -- "FAILED: $fails file(s)"
	exit 1
fi
