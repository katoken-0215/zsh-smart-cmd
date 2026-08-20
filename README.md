# zsh-smart-cmd

リポジトリの選択・起動や開発ツールのキャッシュ削除を素早く実行する zsh コマンド集。

## コマンド

| コマンド | 説明 |
| --- | --- |
| `new` | 起動モード（terminal / claude-code）を選び、`new-term` / `new-cc` に委譲する。 |
| `new-term` | ghq リポジトリを選び、そのディレクトリで Ghostty を開く。 |
| `new-cc` | ghq リポジトリを選び、cmux の新規ワークスペースで Claude Code を起動する。 |
| `cc-haiku` / `cc-sonnet` / `cc-opus` | 指定モデルで Claude Code を起動する。 |
| `clear-cache` | インストール済みの開発ツールを検出し、キャッシュや未使用リソースを一括削除する。 |
| `smart-cmd-pick-repo` | ghq リポジトリを選び、フルパスを出力する（他コマンドの内部利用）。 |

## 依存

- `new` / `new-term` / `new-cc`: [ghq](https://github.com/x-motemen/ghq)、[skim (`sk`)](https://github.com/skim-rs/skim)
- `new-term`: [Ghostty](https://ghostty.org/)
- `new-cc`: cmux
- `clear-cache`: 必須の外部ツールなし。pip、uvx (ruff)、uv、npm、pnpm、pre-commit、prek、mise、Homebrew、Docker、Rancher Desktop (`rdctl`) のうち、インストール済みのものだけを処理する。

### `clear-cache` の注意事項

`clear-cache` は pip / ruff / uv / npm / pnpm / pre-commit / prek / mise / Homebrew / node-gyp / Docker のキャッシュまたは未使用リソースを対象とする。

Docker デーモンや Rancher Desktop の VM が停止しているときは、疎通確認で検出してスキップし、他のツールの処理は続行する。

`rdctl` が見つかる場合は、Docker のキャッシュ削除に続けて `rdctl shell sudo fstrim -v /mnt/data` を実行する。Rancher Desktop の VM ディスクはスパースファイルで自動収縮しないため、VM 内で消しただけではホストの空き容量が増えない。fstrim で解放済み領域をホストへ返して初めてディスクが空く。

> [!WARNING]
> `clear-cache` は確認プロンプトを表示せず、検出した対象を直ちに削除する。Docker では `docker system prune -f` と `docker builder prune -af` を実行するため、ビルドキャッシュは全て失われ次回ビルドが遅くなる。名前付きボリュームは削除しない。

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
