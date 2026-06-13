# new / new-term / new-cc Launch Commands Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** ghqリポジトリをfzfで選び、ターミナル(Ghostty)またはClaude Code(cmux)で開く3つのzsh関数 `new` / `new-term` / `new-cc` を `zsh-smart-cmd` プラグインに追加する。

**Architecture:** 既存の autoload パターン（1関数1ファイル、`init.zsh` でautoload）を踏襲。リポジトリ選択ロジックを共通ヘルパー `smart-cmd-pick-repo` に切り出し、`new-term` / `new-cc` から再利用。`new` はfzfでモードを選び両者へ委譲するディスパッチャ。GUI起動コマンド（`ghq`/`fzf`/`open`/`cmux`）をzsh関数でスタブ化し、引数・分岐・キャンセル時の挙動を自動テストする。実際のアプリ起動は手動で確認。

**Tech Stack:** zsh 5.9、ghq、fzf、Ghostty、cmux。テストは外部依存なしの素のzshスクリプト＋スタブ。

---

## ファイル構成

```
autoload/
  smart-cmd-pick-repo    # 共通: ghq list | fzf → 選択リポジトリのフルパスをecho
  new-term               # Ghosttyでターミナルを開く
  new-cc                 # cmuxでClaude Codeを起動
  new                    # fzfで terminal/claude-code を選択 → 委譲
test/
  helper.zsh             # アサーションヘルパー
  run.zsh                # テストランナー（各 test_*.zsh を別プロセスで実行）
  test_smart-cmd-pick-repo.zsh
  test_new-term.zsh
  test_new-cc.zsh
  test_new.zsh
init.zsh                 # autoload 行に4関数を追加（既存ファイルを修正）
doc/zsh_plugin.txt       # コマンド説明を追記（既存ファイルを修正）
```

各 `test_*.zsh` は別の `zsh` プロセスで実行するため、スタブ（`ghq`/`fzf`/`open`/`cmux` 等の関数定義）はファイル間で干渉しない。

---

## Task 1: テスト基盤（helper + runner）

**Files:**
- Create: `test/helper.zsh`
- Create: `test/run.zsh`

- [ ] **Step 1: アサーションヘルパーを作成**

Create `test/helper.zsh`:

```zsh
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
```

- [ ] **Step 2: テストランナーを作成**

Create `test/run.zsh`:

```zsh
#!/bin/zsh
# test/ 配下の test_*.zsh を各々別プロセスで実行し、結果を集計する。

local here=${0:A:h}
typeset -i fails=0

for t in "$here"/test_*.zsh; do
	print -- "== ${t:t} =="
	zsh "$t" || (( fails++ ))
done

if (( fails == 0 )); then
	print -- "ALL PASS"
else
	print -- "FAILED: $fails file(s)"
	exit 1
fi
```

- [ ] **Step 3: ランナーが動くことを確認**

Run: `zsh test/run.zsh`
Expected: テストファイルがまだ無いので `ALL PASS` と表示され、終了コード0。

- [ ] **Step 4: Commit**

```bash
git add test/helper.zsh test/run.zsh
git commit -m "test: add zsh test harness (helper + runner)"
```

---

## Task 2: smart-cmd-pick-repo（共通ヘルパー）

**Files:**
- Create: `autoload/smart-cmd-pick-repo`
- Test: `test/test_smart-cmd-pick-repo.zsh`

- [ ] **Step 1: 失敗するテストを書く**

Create `test/test_smart-cmd-pick-repo.zsh`:

```zsh
#!/bin/zsh
local here=${0:A:h}
source "$here/helper.zsh"
source "$here/../autoload/smart-cmd-pick-repo"

# --- 正常系: 選択されたリポジトリのフルパスを返す ---
ghq() {
	case $1 in
		list) print -l "github.com/foo/bar" "github.com/baz/qux" ;;
		root) print -- "/Users/test/ghq" ;;
	esac
}
fzf() { print -- "github.com/foo/bar" }

local result
result=$(smart-cmd-pick-repo)
assert_eq "/Users/test/ghq/github.com/foo/bar" "$result" "選択リポジトリのフルパスを返す"

# --- キャンセル系: fzfが非0なら非0で返す ---
fzf() { return 130 }
smart-cmd-pick-repo >/dev/null
assert_eq 1 $? "fzfキャンセル時は非0で返す"

test_summary
```

- [ ] **Step 2: テストが失敗することを確認**

Run: `zsh test/test_smart-cmd-pick-repo.zsh`
Expected: FAIL。`smart-cmd-pick-repo` が未定義（source先のファイルが存在しない）でエラー終了、または関数未定義エラー。

- [ ] **Step 3: 最小実装を書く**

Create `autoload/smart-cmd-pick-repo`:

```zsh
#!/bin/zsh

# smart-cmd-pick-repo — ghqリポジトリをfzfで選び、選択されたフルパスをechoする。
# キャンセル/空選択のときは非0で返す（何もechoしない）。
function smart-cmd-pick-repo {
	local selected
	selected=$(ghq list | fzf) || return 1
	[[ -n $selected ]] || return 1
	print -r -- "$(ghq root)/$selected"
}
```

- [ ] **Step 4: テストが通ることを確認**

Run: `zsh test/test_smart-cmd-pick-repo.zsh`
Expected: 2件とも `ok:` と表示され、終了コード0。

- [ ] **Step 5: Commit**

```bash
git add autoload/smart-cmd-pick-repo test/test_smart-cmd-pick-repo.zsh
git commit -m "feat: add smart-cmd-pick-repo helper"
```

---

## Task 3: new-term（Ghostty版）

**Files:**
- Create: `autoload/new-term`
- Test: `test/test_new-term.zsh`

- [ ] **Step 1: 失敗するテストを書く**

Create `test/test_new-term.zsh`:

```zsh
#!/bin/zsh
local here=${0:A:h}
source "$here/helper.zsh"
source "$here/../autoload/new-term"

# --- 正常系: smart-cmd-pick-repo が返したパスでGhosttyを開く ---
smart-cmd-pick-repo() { print -- "/path/to/repo" }
typeset -ga OPEN_ARGS
open() { OPEN_ARGS=("$@") }

new-term
assert_eq "-a Ghostty /path/to/repo" "${OPEN_ARGS[*]}" "Ghosttyを選択ディレクトリで開く"

# --- キャンセル系: pick-repo が非0なら open を呼ばない ---
OPEN_ARGS=()
smart-cmd-pick-repo() { return 1 }
new-term
assert_eq "" "${OPEN_ARGS[*]}" "キャンセル時は何もしない"

test_summary
```

- [ ] **Step 2: テストが失敗することを確認**

Run: `zsh test/test_new-term.zsh`
Expected: FAIL。`new-term` が未定義。

- [ ] **Step 3: 最小実装を書く**

Create `autoload/new-term`:

```zsh
#!/bin/zsh

# new-term — ghqリポジトリをfzfで選び、そのディレクトリでGhosttyを開く。
function new-term {
	local dir
	dir=$(smart-cmd-pick-repo) || return
	open -a Ghostty "$dir"
}
```

- [ ] **Step 4: テストが通ることを確認**

Run: `zsh test/test_new-term.zsh`
Expected: 2件とも `ok:`、終了コード0。

- [ ] **Step 5: Commit**

```bash
git add autoload/new-term test/test_new-term.zsh
git commit -m "feat: add new-term command (Ghostty)"
```

---

## Task 4: new-cc（cmux + Claude Code版）

**Files:**
- Create: `autoload/new-cc`
- Test: `test/test_new-cc.zsh`

- [ ] **Step 1: 失敗するテストを書く**

Create `test/test_new-cc.zsh`:

```zsh
#!/bin/zsh
local here=${0:A:h}
source "$here/helper.zsh"
source "$here/../autoload/new-cc"

# --- 正常系: cmux new-workspace を正しい引数で呼ぶ ---
smart-cmd-pick-repo() { print -- "/path/to/repo" }
typeset -ga CMUX_ARGS
cmux() { CMUX_ARGS=("$@") }

new-cc
assert_eq "new-workspace --cwd /path/to/repo --command claude --focus true" \
	"${CMUX_ARGS[*]}" "cmux new-workspace でclaudeを起動する"

# --- キャンセル系: pick-repo が非0なら cmux を呼ばない ---
CMUX_ARGS=()
smart-cmd-pick-repo() { return 1 }
new-cc
assert_eq "" "${CMUX_ARGS[*]}" "キャンセル時は何もしない"

test_summary
```

- [ ] **Step 2: テストが失敗することを確認**

Run: `zsh test/test_new-cc.zsh`
Expected: FAIL。`new-cc` が未定義。

- [ ] **Step 3: 最小実装を書く**

Create `autoload/new-cc`:

```zsh
#!/bin/zsh

# new-cc — ghqリポジトリをfzfで選び、cmuxの新規ワークスペースでClaude Codeを起動する。
function new-cc {
	local dir
	dir=$(smart-cmd-pick-repo) || return
	cmux new-workspace --cwd "$dir" --command "claude" --focus true
}
```

- [ ] **Step 4: テストが通ることを確認**

Run: `zsh test/test_new-cc.zsh`
Expected: 2件とも `ok:`、終了コード0。

- [ ] **Step 5: Commit**

```bash
git add autoload/new-cc test/test_new-cc.zsh
git commit -m "feat: add new-cc command (cmux + Claude Code)"
```

---

## Task 5: new（ディスパッチャ）

**Files:**
- Create: `autoload/new`
- Test: `test/test_new.zsh`

- [ ] **Step 1: 失敗するテストを書く**

Create `test/test_new.zsh`:

```zsh
#!/bin/zsh
local here=${0:A:h}
source "$here/helper.zsh"
source "$here/../autoload/new"

# new-term / new-cc をスタブ化して、どちらが呼ばれたか記録する
typeset -g CALLED=""
new-term() { CALLED="term" }
new-cc() { CALLED="cc" }

# --- terminal を選ぶと new-term に委譲 ---
fzf() { print -- "terminal (Ghostty)" }
new
assert_eq "term" "$CALLED" "terminal選択で new-term に委譲"

# --- claude-code を選ぶと new-cc に委譲 ---
CALLED=""
fzf() { print -- "claude-code (cmux)" }
new
assert_eq "cc" "$CALLED" "claude-code選択で new-cc に委譲"

# --- キャンセル時はどちらも呼ばない ---
CALLED=""
fzf() { return 130 }
new
assert_eq "" "$CALLED" "キャンセル時は委譲しない"

test_summary
```

- [ ] **Step 2: テストが失敗することを確認**

Run: `zsh test/test_new.zsh`
Expected: FAIL。`new` が未定義。

- [ ] **Step 3: 最小実装を書く**

Create `autoload/new`:

```zsh
#!/bin/zsh

# new — fzfで起動モードを選び、new-term / new-cc に委譲する。
#   terminal (Ghostty)    → new-term
#   claude-code (cmux)    → new-cc
function new {
	local choice
	choice=$(print -l "terminal (Ghostty)" "claude-code (cmux)" | fzf) || return
	case $choice in
		terminal*)    new-term ;;
		claude-code*) new-cc ;;
	esac
}
```

- [ ] **Step 4: テストが通ることを確認**

Run: `zsh test/test_new.zsh`
Expected: 3件とも `ok:`、終了コード0。

- [ ] **Step 5: 全テストを通して確認**

Run: `zsh test/run.zsh`
Expected: 全ファイルが通り、最後に `ALL PASS`、終了コード0。

- [ ] **Step 6: Commit**

```bash
git add autoload/new test/test_new.zsh
git commit -m "feat: add new command (fzf mode dispatcher)"
```

---

## Task 6: init.zsh への登録

**Files:**
- Modify: `init.zsh`

- [ ] **Step 1: autoload 行に4関数を追加**

`init.zsh` の最終行を以下に置き換える（現在は `autoload -Uz cc-haiku cc-sonnet cc-opus`）:

```zsh
autoload -Uz cc-haiku cc-sonnet cc-opus new new-term new-cc smart-cmd-pick-repo
```

- [ ] **Step 2: source して関数が定義されることを確認**

Run:
```bash
zsh -c 'source init.zsh; for f in new new-term new-cc smart-cmd-pick-repo; do whence -w $f; done'
```
Expected: 4関数すべてが `function`（autoload）として認識される。各行 `new: function` のように表示される。

- [ ] **Step 3: Commit**

```bash
git add init.zsh
git commit -m "feat: register new/new-term/new-cc/smart-cmd-pick-repo in init.zsh"
```

---

## Task 7: ドキュメント追記と手動検証

**Files:**
- Modify: `doc/zsh_plugin.txt`

- [ ] **Step 1: コマンド説明を追記**

`doc/zsh_plugin.txt`（現在 `# vim: ft=asciidoc` の1行のみ）に以下を追記する:

```asciidoc
# vim: ft=asciidoc

== Repository launch commands

ghq + fzf でリポジトリを選び、ターミナルまたは Claude Code で開く。

new-term::
    ghq リポジトリを fzf で選び、そのディレクトリで Ghostty を開く。

new-cc::
    ghq リポジトリを fzf で選び、cmux の新規ワークスペースで Claude Code を起動する。

new::
    fzf で `terminal (Ghostty)` / `claude-code (cmux)` を選び、new-term / new-cc に委譲する。
```

- [ ] **Step 2: Commit**

```bash
git add doc/zsh_plugin.txt
git commit -m "docs: document new/new-term/new-cc commands"
```

- [ ] **Step 3: 手動検証（実機・GUI）**

新しいzshセッションで `source init.zsh` してから、以下を実機確認する（自動テスト不可）:

1. `new-term` → fzfが出る → リポジトリを選ぶ → そのディレクトリでGhosttyが開く。ESCキャンセルで何も起きない。
2. `new-cc` → fzfが出る → リポジトリを選ぶ → cmuxのワークスペースがそのディレクトリで開き、Claude Codeが起動する。
   - **要確認**: cmux外のターミナルから `cmux new-workspace --cwd <path> --command "claude" --focus true` が期待通り動くか。`new-workspace` はcmux内からの呼び出し（`$CMUX_WORKSPACE_ID`/`$CMUX_SURFACE_ID`）を前提にしている可能性がある。
   - **動かない場合のフォールバック**: `new-cc` を `cmux "$dir"` でワークスペースを開く方式に変更し、claude起動の手段を別途調整する。その場合は本タスクで `autoload/new-cc` と `test/test_new-cc.zsh` を更新し、再コミットする。
3. `new` → fzfでモード選択 → 選んだモードに応じて上記1/2が起きる。

- [ ] **Step 4: 検証結果を記録**

手動検証の結果（特にnew-ccのcmux挙動）を確認し、フォールバックが必要だった場合は実装を修正して `zsh test/run.zsh` が `ALL PASS` のままであることを確認する。

---

## Self-Review

- **Spec coverage**: 仕様書の3コマンド（new/new-term/new-cc）+ 共通ヘルパー + init.zsh登録 + エッジケース（fzfキャンセル）+ 要検証ポイント（cmux外からのnew-workspace）をすべてタスク化済み。
- **Placeholder scan**: 全ステップに実コードと期待出力を記載。TBD/TODOなし。Task7のフォールバックは「条件付き手順」であり未確定のプレースホルダではない。
- **Type consistency**: 関数名 `smart-cmd-pick-repo` / `new-term` / `new-cc` / `new` を全タスク・テストで一貫使用。cmux引数 `new-workspace --cwd <path> --command claude --focus true` を実装・テストで一致させている。
