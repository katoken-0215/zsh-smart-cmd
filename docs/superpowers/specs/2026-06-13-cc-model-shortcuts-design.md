# cc-* モデル切り替えショートカット 設計

## 目的

`claude --model <name>` を毎回打たずに済むよう、各モデル系統を呼び出す
ショートカットコマンドを `zsh-smart-cmd` プラグインに追加する。
`sheldon` でこのプラグインをインポートすると利用可能になる。

## 追加するコマンド

| コマンド     | 実行内容                       |
|--------------|--------------------------------|
| `cc-haiku`   | `claude --model haiku "$@"`    |
| `cc-sonnet`  | `claude --model sonnet "$@"`   |
| `cc-opus`    | `claude --model opus "$@"`     |

- モデル指定はショートエイリアス(`haiku` / `sonnet` / `opus`)を使い、
  各系統の最新版に自動追従する。
- 追加引数は `"$@"` でパススルー(例: `cc-opus "プロンプト"`)。

## 実装方式

既存リポジトリの構成(fpath + `autoload`)を踏襲する。`zsh-history` の
`fzf-history` と同じく、1コマンド = 1 autoload ファイルとする。今後
エイリアス以外のコマンドも同じ方式で追加していく。

### ファイル構成

```
autoload/
  cc-haiku
  cc-sonnet
  cc-opus
init.zsh
```

各 autoload ファイルの中身(例: `autoload/cc-opus`):

```zsh
#!/bin/zsh

function cc-opus {
	claude --model opus "$@"
}
```

`init.zsh`:

```zsh
#!/bin/zsh

fpath=(
"${${(%):-%N}:A:h}"/autoload(N-/)
$fpath
)

autoload -Uz cc-haiku cc-sonnet cc-opus
```

## 既存スケルトンの整理

- `autoload/zsh_plugin`・`bin/zsh_plugin`(中身が空のプレースホルダ)を削除。
- 書きかけの `tmp.zsh` を削除。
- `doc/` は今回は変更しない。

## 動作確認

- `source init.zsh` 後に `which cc-opus` で関数が定義されること。
- `cc-opus --help` などでフラグが `claude` に渡ること。
