#!/bin/zsh

fpath=(
"${${(%):-%N}:A:h}"/autoload(N-/)
$fpath
)

autoload -Uz cl cl-haiku cl-sonnet cl-opus cl-opus-high cl-opus-xhigh cl-opus-max new new-term new-cc smart-cmd-pick-repo clear-cache
autoload +X smart-history
