#!/bin/zsh

fpath=(
"${${(%):-%N}:A:h}"/autoload(N-/)
$fpath
)

autoload -Uz cc-haiku cc-sonnet cc-opus
