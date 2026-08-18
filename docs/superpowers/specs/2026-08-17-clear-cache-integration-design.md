# 設計: `clear-cache` の統合

## 背景

隣接リポジトリ `zsh-clear-cache` が提供する `clear-cache` コマンドを、`zsh-smart-cmd` のコマンド群へ統合する。

移植元の実装は `add-prek-mise-brew-cache` ブランチの `autoload/clear-cache` 1ファイルで完結している。移植元の README は実装に追従しておらず、`prek`、`node-gyp`、Docker など一部の対象が記載されていない。また、移植元は zplug の lazy autoload を前提とする一方、統合先は `zsh-smart-cmd.plugin.zsh` で `fpath` と `autoload -Uz` を設定する。

統合先には次の未コミット変更があるため、今回の作業では触れない。

- `autoload/smart-history`
- `docs/superpowers/specs/2026-06-13-cc-model-shortcuts-design.md`
- 未追跡の `.claude/`

## 決定事項

- Git 履歴やリポジトリ構造はマージせず、最新の `autoload/clear-cache` の内容を統合先の規約に合わせて直接移植する。
- 移植元の `doc/`、README、`.DS_Store`、`.git/` は持ち込まない。
- `docker system prune` から `--volumes` を外し、名前付きボリュームを削除しない。
- 実行前の確認プロンプトは追加せず、移植元と同じ非対話コマンドとする。
- `clear-cache` の処理本体をサブシェルで実行し、内部ヘルパーをグローバル関数として残さない。
- 統合先の既存テスト規約に従い、破壊的コマンドをすべてスタブ化した自動テストを追加する。
- 既存の未コミット変更は stash、reset、checkout、編集、コミットの対象にしない。

## 公開仕様

### コマンド

```zsh
clear-cache
```

引数とオプションは設けない。引数が渡されても移植元と同様に使用しない。

インストール済みのツールだけを検出し、次の処理を順番に実行する。

| 対象 | 実行内容 |
| --- | --- |
| pip | `pip cache purge` |
| ruff | `uvx ruff clean` |
| uv | 対応していれば `uv cache clean --force`、未対応なら `uv cache clean` |
| npm | `npm cache clean --force` |
| pnpm | `pnpm store prune`、対応していれば `pnpm cache delete '*'` |
| pre-commit | `pre-commit gc` |
| prek | `prek gc` |
| mise | `mise cache prune`、`mise prune -y` |
| Homebrew | `brew cleanup -s` |
| node-gyp | `$HOME/Library/Caches/node-gyp` が存在すれば削除 |
| Docker | `docker system prune -f` |

各処理の前に `[clear-cache] ...` 形式の進捗を stderr へ出力する。各ツール本体の stdout / stderr はそのまま利用者へ渡す。

### 安全性

`clear-cache` は確認なしでキャッシュや未使用リソースを削除する破壊的コマンドである。README にその旨を明記する。

Docker は `--volumes` を付けず、名前付きボリュームを削除対象に含めない。node-gyp は移植元と同じく macOS の `$HOME/Library/Caches/node-gyp` だけを対象とし、ディレクトリの存在を確認してから引用済み固定パスを `rm -rf` する。

## 構成

### 新規ファイル

```text
autoload/clear-cache
test/test_clear-cache.zsh
docs/superpowers/specs/2026-08-17-clear-cache-integration-design.md
```

### 変更ファイル

```text
zsh-smart-cmd.plugin.zsh
README.md
```

`zsh-smart-cmd.plugin.zsh` の既存 `autoload -Uz` 行に `clear-cache` を追加する。1コマンド = 1 autoload ファイル、kebab-case、ファイル名 = 関数名という既存規約を維持する。

## 内部設計

移植元の `clear-cache` は関数内で `check-command` と `log` を定義している。しかし、zsh のネストした関数定義は呼び出し元のグローバル関数テーブルに残るため、一度 `clear-cache` を実行すると汎用名の `check-command` と `log` が外部へ露出する。

統合版では `clear-cache` の処理本体をサブシェルで実行し、その中だけで内部ヘルパーを定義する。サブシェル終了時に関数定義が自動的に破棄されるため、正常終了・途中失敗のどちらでも他のプラグインや利用者定義の `log` などを上書きしたままにしない。ヘルパーの責務は次の2つだけとする。

- コマンドの存在を `command -v` で判定する。
- `[clear-cache]` 接頭辞付きログを stderr へ出力する。

外部ツールは任意依存であり、存在しないツールの処理は黙ってスキップする。uv と pnpm のバージョン差は移植元の capability check を維持する。

## エラー処理

移植元と同じく、各ツールの失敗を集約せず、後続ツールの処理を継続する。関数の終了ステータスを新たな公開契約にはしない。エラー集約や要約表示は今回のスコープ外とする。

内部ヘルパーはサブシェルの終了と同時に破棄する。コマンドの存在判定や capability check の失敗は対象処理のスキップまたは互換コマンドへのフォールバックとして扱う。

## README

README の冒頭説明を、リポジトリ起動だけでなく日常的な zsh コマンド群を含む表現へ調整する。コマンド表に `clear-cache` を追加し、次を記載する。

- 削除対象の11カテゴリ
- インストール済みのツールだけを処理すること
- 確認なしで削除する破壊的コマンドであること
- Docker の名前付きボリュームは削除しないこと

移植元の zplug 用インストール手順は持ち込まず、既存の sheldon 手順を維持する。

## テスト方針

`test/test_clear-cache.zsh` を既存の `test/helper.zsh` と `test/run.zsh` に乗せる。実際のキャッシュや Docker リソースを削除しないよう、テストで到達しうる外部コマンドはすべて zsh 関数または制御した PATH でスタブ化する。

最低限、次を検証する。

1. 検出された各ツールへ期待する引数が渡る。
2. 検出されないツールは実行されない。
3. uv が `--force` 対応時には `uv cache clean --force`、未対応時には `uv cache clean` となる。
4. pnpm metadata cache 対応時だけ `pnpm cache delete '*'` が実行される。
5. Docker は `docker system prune -f` を実行し、`--volumes` を渡さない。
6. node-gyp のディレクトリが存在するときだけ削除処理へ進む。
7. 進捗ログが stderr に出力される。
8. 実行後に内部ヘルパー関数が残らない。
9. `zsh -n` による構文検査と `zsh test/run.zsh` の全テストが成功する。

テストは TDD で追加し、まず期待する統合仕様に対して失敗することを確認してから実装する。

## スコープ外

- 移植元の Git 履歴を subtree や unrelated-history merge で取り込むこと
- 確認プロンプト、dry-run、個別ツール選択オプションの追加
- 各ツールの失敗ステータスを集約すること
- Linux 向け node-gyp キャッシュパスの追加
- `clear-cache` 専用の補完や man ページの作成
- 既存の `smart-history` その他の未コミット変更の修正
