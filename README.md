# zsh-smart-cmd

ghq + skim (`sk`) でリポジトリを選び、ターミナルや Claude Code を素早く起動する zsh コマンド集。

## コマンド

| コマンド | 説明 |
| --- | --- |
| `new` | 起動モード（terminal / claude-code）を選び、`new-term` / `new-cc` に委譲する。 |
| `new-term` | ghq リポジトリを選び、そのディレクトリで Ghostty を開く。 |
| `new-cc` | ghq リポジトリを選び、cmux の新規ワークスペースで Claude Code を起動する。 |
| `cc-haiku` / `cc-sonnet` / `cc-opus` | 指定モデルで Claude Code を起動する。 |
| `smart-cmd-pick-repo` | ghq リポジトリを選び、フルパスを出力する（他コマンドの内部利用）。 |

## 依存

- [ghq](https://github.com/x-motemen/ghq)
- [skim (`sk`)](https://github.com/skim-rs/skim)
- `new-term`: [Ghostty](https://ghostty.org/) / `new-cc`: cmux

## インストール

### sheldon

```toml
[plugins.zsh-smart-cmd]
github = "katoken-0215/zsh-smart-cmd"

[plugins.zsh-smart-cmd.hooks]
post = """
zle -N smart-history
bindkey "^R" smart-history
```

エントリポイントは `zsh-smart-cmd.plugin.zsh` なので、sheldon のデフォルトのマッチで自動的に読み込まれる。

> リポジトリ全体を再帰的に読み込む設定を使っている場合は、`test/` 配下が source されないよう `use = ["zsh-smart-cmd.plugin.zsh"]` を明示すること。

## テスト

```sh
zsh test/run.zsh
```
