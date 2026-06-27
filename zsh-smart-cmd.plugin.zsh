#!/bin/zsh

fpath=(
"${${(%):-%N}:A:h}"/autoload(N-/)
$fpath
)

autoload -Uz cc-haiku cc-sonnet cc-opus new new-term new-cc smart-cmd-pick-repo
autoload +X smart-history
