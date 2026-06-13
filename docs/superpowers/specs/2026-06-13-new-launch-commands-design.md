# 設計: リポジトリ起動コマンド `new` / `new-term` / `new-cc`

## 背景

ユーザーは以下のエイリアスを使っている:

```zsh
alias new='open -a Ghostty $(ghq root)/$((ghq list) | fzf)'
```

ghqで管理するリポジトリをfzfで選び、そのディレクトリでGhosttyを開く。これを `zsh-smart-cmd` プラグインへ移植する。あわせて次の2点を解消する:

1. アプリがGhostty固定 → cmuxも使い分けたい
2. 素のターミナルを開きたい場合と、ターミナルでClaude Codeを開きたい場合がある

## 決定事項

- **モードがアプリを決める**:
  - ターミナル → Ghostty (`open -a Ghostty <path>`)
  - Claude Code → cmux (`cmux claude-teams`、teams有効でClaude Codeを起動)
- コマンドは3つ。`new` はモードを選ぶディスパッチャ。

## コマンド仕様

| コマンド | 動作 |
|---------|------|
| `new-term` | リポジトリをfzf選択 → そのディレクトリでGhosttyを開く |
| `new-cc` | リポジトリをfzf選択 → cmuxでClaude Code(teams)を起動 |
| `new` | `terminal (Ghostty)` / `claude-code (cmux)` をfzf選択 → `new-term` / `new-cc` に委譲 |

`new` の流れは **モード選択 → リポジトリ選択** の順。実処理は `new-term` / `new-cc` を再利用する。

## ファイル構成

既存の autoload パターン（1関数1ファイル、kebab-case、`init.zsh` でautoload）を踏襲する。

```
autoload/
  new                    # fzfで terminal/claude-code を選択 → 委譲
  new-term               # Ghostty版（旧 new エイリアス相当）
  new-cc                 # cmux + Claude Code版
  smart-cmd-pick-repo    # 共通ヘルパー: ghq list | fzf → フルパスをecho
```

`init.zsh` の autoload 行に `new new-term new-cc smart-cmd-pick-repo` を追加する。

## 実装イメージ

```zsh
# smart-cmd-pick-repo — 選択されたリポジトリのフルパスをecho。キャンセル/空なら非0で返す。
function smart-cmd-pick-repo {
	local selected
	selected=$(ghq list | fzf) || return 1
	[[ -n $selected ]] || return 1
	print -r -- "$(ghq root)/$selected"
}

# new-term — Ghosttyでターミナルを開く
function new-term {
	local dir
	dir=$(smart-cmd-pick-repo) || return
	open -a Ghostty "$dir"
}

# new-cc — cmuxでClaude Codeを起動
function new-cc {
	local dir
	dir=$(smart-cmd-pick-repo) || return
	(cd "$dir" && cmux claude-teams)
}

# new — モードをfzf選択して委譲
function new {
	local choice
	choice=$(print -l "terminal (Ghostty)" "claude-code (cmux)" | fzf) || return
	case $choice in
		terminal*)    new-term ;;
		claude-code*) new-cc ;;
	esac
}
```

## 共通ヘルパーの責務分離

- `smart-cmd-pick-repo`: 「ghqリポジトリ選択 → フルパス」のみを担う。何を起動するかは知らない。標準出力にパスを書き、キャンセル時は非0で返す。
- `new-term` / `new-cc`: パスを受け取り、それぞれのアプリを起動する。
- `new`: モード選択して委譲するだけ。アプリ起動の詳細は知らない。

## エッジケース / エラー処理

- **fzfをESCでキャンセル（モード選択・リポジトリ選択どちら）** → 何もせず抜ける。ルートディレクトリを開くなどしない（`|| return` で防ぐ）。
- **ghq / fzf / cmux / Ghostty 未インストール** → 各コマンドのエラーがそのまま表示される。プラグイン側で特別なチェックはしない（YAGNI）。

## 要検証ポイント（実装時に実機で確認）

`(cd "$dir" && cmux claude-teams)` で **cmuxが当該ディレクトリのワークスペースを開いた上でClaude Codeを起動するか** を確認する。

`cmux claude-teams` は引数をclaudeへ転送し、作業ディレクトリはcwd依存になる見込み。もしcwdがワークスペースに反映されない場合は、`cmux "$dir"`（ワークスペースを開く）→ claude起動 の2段構成に切り替える。GUI起動のため自動テストではなく手動で確認する。

## テスト方針

GUIアプリ起動が絡むため、ロジック部分（リポジトリ選択・モード分岐・キャンセル時の挙動）は起動コマンドをモック/スタブして検証し、実際の `open` / `cmux` 起動は手動確認とする。詳細は実装計画で定める。
