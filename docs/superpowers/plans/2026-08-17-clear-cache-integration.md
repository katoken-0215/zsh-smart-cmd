# Clear Cache Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `zsh-clear-cache` の最新 `clear-cache` を、安全化・テスト・ドキュメントを含めて `zsh-smart-cmd` の autoload コマンドとして統合する。

**Architecture:** 移植元の `add-prek-mise-brew-cache` ブランチにある1ファイル実装を、統合先の「1コマンド = 1 autoload ファイル」規約へ移す。処理本体はサブシェルで実行して内部ヘルパーを呼び出し元へ漏らさず、Docker は名前付きボリュームを残す。既存の zsh テストハーネスで全外部操作をスタブ化し、実データを一切削除せずに引数・分岐・ログを検証する。

**Tech Stack:** zsh、zsh の `autoload -Uz` / `fpath`、既存のシェル製テストハーネス (`test/helper.zsh`, `test/run.zsh`)、Markdown

**Spec:** `docs/superpowers/specs/2026-08-17-clear-cache-integration-design.md`

## Global Constraints

- 移植元は `/Users/katoken-0215/work/zsh-clear-cache` の `add-prek-mise-brew-cache` ブランチ HEAD にある `autoload/clear-cache` とする。
- Git 履歴、移植元 README、`doc/`、`.DS_Store`、`.git/` は取り込まない。
- `clear-cache` は引数・オプション・確認プロンプト・dry-run を追加しない非対話コマンドとする。
- Docker は `docker system prune -f` を実行し、`--volumes` を絶対に渡さない。
- node-gyp は macOS の `$HOME/Library/Caches/node-gyp` だけを対象とする。
- `clear-cache` の処理本体はサブシェルで実行し、内部の `check-command` / `log` を呼び出し元へ残さない。
- 外部ツールの失敗集約、Linux 用 node-gyp パス、補完、man ページは追加しない。
- 自動テストでは実際の pip / uv / npm / pnpm / brew / Docker / `rm` などを実行しない。到達しうる外部コマンドは関数スタブまたは制御した `PATH` で隔離する。
- ユーザーの既存変更 `autoload/smart-history`、`docs/superpowers/specs/2026-06-13-cc-model-shortcuts-design.md`、未追跡 `.claude/` を編集・stage・commit・stash・reset・checkout しない。
- `git add -A`、`git add .`、パスを指定しない `git commit -a` を使わない。各コミットはこの計画に明記したパスだけを stage する。

---

## File Map

- Create: `autoload/clear-cache` — 公開関数 `clear-cache` と、サブシェル内だけで使うコマンド検出・ログ処理を持つ。
- Create: `test/test_clear-cache.zsh` — 全削除コマンドをスタブ化し、実行引数・互換分岐・stderr・名前空間隔離を検証する。
- Modify: `zsh-smart-cmd.plugin.zsh:8` — `clear-cache` を遅延 autoload 対象へ追加する。
- Modify: `README.md:3-20` — コマンド一覧、任意依存、削除対象、安全上の注意を記載する。
- Do not modify: `autoload/smart-history` — ユーザーの作業途中ファイル。
- Do not modify: `docs/superpowers/specs/2026-06-13-cc-model-shortcuts-design.md` — ユーザーの未コミット修正。
- Do not stage: `.claude/` — ユーザーの未追跡ファイル群。

---

### Task 1: `clear-cache` の振る舞いを TDD で実装する

**Files:**
- Create: `test/test_clear-cache.zsh`
- Create: `autoload/clear-cache`

**Interfaces:**
- Consumes: zsh の `command -v`、任意の外部ツール、`$HOME/Library/Caches/node-gyp`。
- Produces: 引数なしの zsh 関数 `clear-cache`; 進捗は stderr、各ツールの出力はそのまま通す。
- Isolation guarantee: 呼び出し前に存在した `check-command` / `log` 関数を変更せず、存在しなかった場合にも新規に残さない。

- [ ] **Step 1: 作業ツリーの保護対象を確認する**

Run:

```bash
git status --short
```

Expected: 少なくとも次が表示され、Task 1 の新規ファイルはまだない。

```text
 M autoload/smart-history
 M docs/superpowers/specs/2026-06-13-cc-model-shortcuts-design.md
?? .claude/
```

計画ファイルを未コミットで実行している場合は、次も表示されてよい。

```text
?? docs/superpowers/plans/2026-08-17-clear-cache-integration.md
```

保護対象の内容は確認だけに留め、変更しない。

- [ ] **Step 2: 破壊的操作を完全にスタブ化した失敗テストを書く**

Create `test/test_clear-cache.zsh`:

```zsh
#!/bin/zsh
local here=${0:A:h}
source "$here/helper.zsh"
source "$here/../autoload/clear-cache"

# clear-cache はサブシェルで動くため、呼び出し記録はファイルへ書く。
typeset original_path=$PATH
typeset original_home=$HOME
typeset test_home=$(mktemp -d)
typeset -g CALL_LOG="$test_home/calls.log"
typeset stderr_log="$test_home/stderr.log"

record_call() {
	print -r -- "$*" >> "$CALL_LOG"
}

# 最初は内部ヘルパーと同名の関数が存在しない状態で実行する。
mkdir -p "$test_home/Library/Caches/node-gyp"
: > "$CALL_LOG"
PATH=/nonexistent
HOME=$test_home

# --- 全ツール検出時は期待するコマンドを順番に実行する ---
pip() { record_call "pip $*" }
uvx() { record_call "uvx $*" }
uv() {
	if [[ "$*" == "cache clean --help" ]]; then
		return 0
	fi
	record_call "uv $*"
}
grep() { return 0 }
npm() { record_call "npm $*" }
pnpm() {
	if [[ "$*" == "cache --help" ]]; then
		return 0
	fi
	record_call "pnpm $*"
}
function pre-commit { record_call "pre-commit $*" }
prek() { record_call "prek $*" }
mise() { record_call "mise $*" }
brew() { record_call "brew $*" }
rm() { record_call "rm $*" }
docker() { record_call "docker $*" }

clear-cache 2> "$stderr_log"

expected_calls=$'pip cache purge\nuvx ruff clean\nuv cache clean --force\nnpm cache clean --force\npnpm store prune\npnpm cache delete *\npre-commit gc\nprek gc\nmise cache prune\nmise prune -y\nbrew cleanup -s\nrm -rf '"$test_home"$'/Library/Caches/node-gyp\ndocker system prune -f'
assert_eq "$expected_calls" "$(<"$CALL_LOG")" "全ツールへ安全化済みの引数を渡す"

expected_stderr=$'[clear-cache] Clearing pip cache...\n[clear-cache] Clearing ruff cache...\n[clear-cache] Clearing uv cache...\n[clear-cache] Clearing npm cache...\n[clear-cache] Clearing pnpm store...\n[clear-cache] Clearing pnpm metadata cache...\n[clear-cache] Clearing pre-commit cache...\n[clear-cache] Clearing prek cache...\n[clear-cache] Clearing mise cache...\n[clear-cache] Pruning unused mise tool versions...\n[clear-cache] Clearing Homebrew cache...\n[clear-cache] Clearing node-gyp cache...\n[clear-cache] Clearing Docker cache...'
assert_eq "$expected_stderr" "$(<"$stderr_log")" "進捗ログを stderr へ出力する"
assert_eq "0" "${+functions[check-command]}" "内部 check-command を残さない"
assert_eq "0" "${+functions[log]}" "内部 log を残さない"

unfunction pip uvx uv grep npm pnpm pre-commit prek mise brew rm docker
PATH=$original_path
command rm -rf "$test_home/Library"
PATH=/nonexistent

# --- uv が --force 非対応なら互換コマンドへフォールバックする ---
# 呼び出し元の同名関数が実行後も維持されることも確認する。
: > "$CALL_LOG"
check-command() { print -- "existing-check-command" }
log() { print -- "existing-log" }
uv() {
	if [[ "$*" == "cache clean --help" ]]; then
		return 0
	fi
	record_call "uv $*"
}
grep() { return 1 }
clear-cache 2> /dev/null
assert_eq "uv cache clean" "$(<"$CALL_LOG")" "古い uv では --force を付けない"
assert_eq "existing-check-command" "$(check-command)" "既存 check-command を保持する"
assert_eq "existing-log" "$(log)" "既存 log を保持する"
unfunction uv grep

# --- pnpm metadata cache 非対応なら store prune だけを実行する ---
: > "$CALL_LOG"
pnpm() {
	if [[ "$*" == "cache --help" ]]; then
		return 1
	fi
	record_call "pnpm $*"
}
clear-cache 2> /dev/null
assert_eq "pnpm store prune" "$(<"$CALL_LOG")" "古い pnpm では metadata 削除をスキップする"
unfunction pnpm

# --- ツールも node-gyp ディレクトリもなければ何もしない ---
: > "$CALL_LOG"
: > "$stderr_log"
clear-cache 2> "$stderr_log"
assert_eq "" "$(<"$CALL_LOG")" "未インストールのツールを実行しない"
assert_eq "" "$(<"$stderr_log")" "処理対象がなければログを出さない"

PATH=$original_path
HOME=$original_home
unfunction check-command log record_call
command rm -rf "$test_home"

test_summary
```

このテストは PATH を空にした後、検出させるツールだけを zsh 関数で定義する。`rm` と Docker もスタブ化されるため、実データは削除されない。

- [ ] **Step 3: 新規テストが RED になることを確認する**

Run:

```bash
zsh test/test_clear-cache.zsh
```

Expected: FAIL。`autoload/clear-cache` がまだ存在しないため、`source` の `no such file or directory` と `clear-cache: command not found` が表示され、テストは非0で終了する。

- [ ] **Step 4: テストを通す最小実装を書く**

Create `autoload/clear-cache`:

```zsh
#!/bin/zsh

function clear-cache {
	(
		# サブシェル内だけで使うため、呼び出し元の関数を汚染しない。
		function check-command() {
			command -v "$1" >/dev/null 2>&1
		}

		function log() {
			echo '[clear-cache]' "$1" >&2
		}

		# pip
		if check-command pip; then
			log "Clearing pip cache..."
			pip cache purge
		fi
		# ruff
		if check-command uvx; then
			log "Clearing ruff cache..."
			uvx ruff clean
		fi
		# uv
		if check-command uv; then
			log "Clearing uv cache..."
			# --force は新しい uv だけがサポートする。
			if uv cache clean --help 2>/dev/null | grep -q -- '--force'; then
				uv cache clean --force
			else
				uv cache clean
			fi
		fi
		# npm
		if check-command npm; then
			log "Clearing npm cache..."
			npm cache clean --force
		fi
		# pnpm
		if check-command pnpm; then
			log "Clearing pnpm store..."
			pnpm store prune
			# metadata cache は新しい pnpm だけがサポートする。
			if pnpm cache --help >/dev/null 2>&1; then
				log "Clearing pnpm metadata cache..."
				pnpm cache delete '*'
			fi
		fi
		# pre-commit
		if check-command pre-commit; then
			log "Clearing pre-commit cache..."
			pre-commit gc
		fi
		# prek
		if check-command prek; then
			log "Clearing prek cache..."
			prek gc
		fi
		# mise
		if check-command mise; then
			log "Clearing mise cache..."
			mise cache prune
			log "Pruning unused mise tool versions..."
			mise prune -y
		fi
		# Homebrew
		if check-command brew; then
			log "Clearing Homebrew cache..."
			brew cleanup -s
		fi
		# node-gyp の専用コマンドはないため、macOS のキャッシュを直接削除する。
		if [[ -d "$HOME/Library/Caches/node-gyp" ]]; then
			log "Clearing node-gyp cache..."
			rm -rf "$HOME/Library/Caches/node-gyp"
		fi
		# 名前付きボリュームは削除しない。
		if check-command docker; then
			log "Clearing Docker cache..."
			docker system prune -f
		fi
	)
}
```

- [ ] **Step 5: 対象テストが GREEN になることを確認する**

Run:

```bash
zsh test/test_clear-cache.zsh
```

Expected: 10件の `ok:` が表示され、終了ステータス0。実際のキャッシュ削除コマンドは一つも実行されない。

- [ ] **Step 6: 新規ファイルの構文を検査する**

Run:

```bash
zsh -n autoload/clear-cache test/test_clear-cache.zsh
```

Expected: 出力なし、終了ステータス0。

- [ ] **Step 7: Task 1 のファイルだけをコミットする**

```bash
git add autoload/clear-cache test/test_clear-cache.zsh
git diff --cached --name-only
git commit -m "feat: add clear-cache command" -m "Co-Authored-By: Claude <noreply@anthropic.com>"
```

Expected staged paths before commit:

```text
autoload/clear-cache
test/test_clear-cache.zsh
```

---

### Task 2: プラグインから `clear-cache` を autoload する

**Files:**
- Modify: `zsh-smart-cmd.plugin.zsh:8`
- Test: clean zsh (`zsh -f`) からのロード確認

**Interfaces:**
- Consumes: Task 1 の `autoload/clear-cache`。
- Produces: `zsh-smart-cmd.plugin.zsh` を source したシェルで autoload 登録された `clear-cache` 関数。

- [ ] **Step 1: 未登録状態が RED になることを確認する**

Run:

```bash
zsh -f -c 'source ./zsh-smart-cmd.plugin.zsh; (( $+functions[clear-cache] ))'
```

Expected: 出力なし、終了ステータス1。ファイルは存在するが plugin の `autoload -Uz` にまだ登録されていない。

- [ ] **Step 2: `clear-cache` を autoload 対象へ追加する**

Modify `zsh-smart-cmd.plugin.zsh:8`:

```zsh
autoload -Uz cc-haiku cc-sonnet cc-opus new new-term new-cc smart-cmd-pick-repo smart-history clear-cache
```

既存の `smart-history` や他の登録順は変更せず、末尾への追加だけにする。

- [ ] **Step 3: clean zsh で登録状態が GREEN になることを確認する**

Run:

```bash
zsh -f -c 'source ./zsh-smart-cmd.plugin.zsh; (( $+functions[clear-cache] )) && whence -w clear-cache'
```

Expected:

```text
clear-cache: function
```

終了ステータス0。ここでは `clear-cache` 自体を実行しない。

- [ ] **Step 4: 全テストを実行する**

Run:

```bash
zsh test/run.zsh
```

Expected: 各 `test_*.zsh` が成功し、最後に `ALL PASS`。

- [ ] **Step 5: plugin の1ファイルだけをコミットする**

```bash
git add zsh-smart-cmd.plugin.zsh
git diff --cached --name-only
git commit -m "feat: autoload clear-cache command" -m "Co-Authored-By: Claude <noreply@anthropic.com>"
```

Expected staged path before commit:

```text
zsh-smart-cmd.plugin.zsh
```

---

### Task 3: `clear-cache` の用途と安全性を README に記載する

**Files:**
- Modify: `README.md:3-20`

**Interfaces:**
- Consumes: Task 1 の公開仕様と Task 2 のインストール時ロード方式。
- Produces: 利用者が削除対象・任意依存・無確認実行・Docker ボリューム保護を判断できる文書。

- [ ] **Step 1: README の概要・コマンド表・依存・警告を更新する**

Modify `README.md` の冒頭説明を次に置き換える。

```markdown
リポジトリの選択・起動や開発ツールのキャッシュ削除を素早く実行する zsh コマンド集。
```

コマンド表の `cc-haiku` / `cc-sonnet` / `cc-opus` 行の次に追加する。

```markdown
| `clear-cache` | インストール済みの開発ツールを検出し、キャッシュや未使用リソースを一括削除する。 |
```

`## 依存` の内容を次にする。

```markdown
## 依存

- `new` / `new-term` / `new-cc`: [ghq](https://github.com/x-motemen/ghq)、[skim (`sk`)](https://github.com/skim-rs/skim)
- `new-term`: [Ghostty](https://ghostty.org/)
- `new-cc`: cmux
- `clear-cache`: 必須の外部ツールなし。pip、uvx (ruff)、uv、npm、pnpm、pre-commit、prek、mise、Homebrew、Docker のうち、インストール済みのものだけを処理する。

### `clear-cache` の注意事項

`clear-cache` は pip / ruff / uv / npm / pnpm / pre-commit / prek / mise / Homebrew / node-gyp / Docker のキャッシュまたは未使用リソースを対象とする。

> [!WARNING]
> `clear-cache` は確認プロンプトを表示せず、検出した対象を直ちに削除する。Docker では `docker system prune -f` を実行するが、名前付きボリュームは削除しない。
```

既存の sheldon インストール手順とテスト手順は変更しない。

- [ ] **Step 2: README が実装の安全契約を明記していることを確認する**

Run:

```bash
rg -n 'clear-cache|docker system prune -f|名前付きボリューム|確認プロンプト' README.md
```

Expected: コマンド表、任意依存、対象一覧、警告から複数行がヒットする。`--volumes` はヒットしてはならない。

Run:

```bash
if rg -n -- '--volumes' README.md; then exit 1; fi
```

Expected: 出力なし、終了ステータス0。

- [ ] **Step 3: 全テストと構文検査を再実行する**

Run:

```bash
zsh -n zsh-smart-cmd.plugin.zsh autoload/clear-cache test/test_clear-cache.zsh
zsh test/run.zsh
```

Expected: 構文検査は出力なしで成功し、テストは最後に `ALL PASS`。

- [ ] **Step 4: README だけをコミットする**

```bash
git add README.md
git diff --cached --name-only
git commit -m "docs: document clear-cache command" -m "Co-Authored-By: Claude <noreply@anthropic.com>"
```

Expected staged path before commit:

```text
README.md
```

---

### Task 4: 統合結果を最終検証する

**Files:**
- Verify only: `autoload/clear-cache`
- Verify only: `test/test_clear-cache.zsh`
- Verify only: `zsh-smart-cmd.plugin.zsh`
- Verify only: `README.md`
- Protect: `autoload/smart-history`
- Protect: `docs/superpowers/specs/2026-06-13-cc-model-shortcuts-design.md`
- Protect: `.claude/`

**Interfaces:**
- Consumes: Tasks 1–3 のコミット済み成果物。
- Produces: 実データを削除しない検証証跡と、保護対象だけが未コミットで残る作業ツリー。

- [ ] **Step 1: 対象ファイルの構文と全テストを検証する**

Run:

```bash
zsh -n zsh-smart-cmd.plugin.zsh autoload/clear-cache test/test_clear-cache.zsh
zsh test/run.zsh
```

Expected: 構文検査は出力なし、全テストの最後は `ALL PASS`。

- [ ] **Step 2: clean zsh で autoload 登録だけを検証する**

Run:

```bash
zsh -f -c 'source ./zsh-smart-cmd.plugin.zsh; (( $+functions[clear-cache] )) && whence -w clear-cache'
```

Expected:

```text
clear-cache: function
```

実データ保護のため、実環境では `clear-cache` を呼び出さない。

- [ ] **Step 3: 統合差分に空白エラーがないことを検証する**

Run:

```bash
git diff --check 6692248..HEAD -- autoload/clear-cache test/test_clear-cache.zsh zsh-smart-cmd.plugin.zsh README.md
```

Expected: 出力なし、終了ステータス0。`6692248` は承認済み設計書のコミットであり、それ以降の統合差分だけを検査する。

- [ ] **Step 4: 保護対象がそのまま残り、統合対象がコミット済みであることを確認する**

Run:

```bash
git status --short
git log --oneline -5
```

Expected: `autoload/clear-cache`、`test/test_clear-cache.zsh`、`zsh-smart-cmd.plugin.zsh`、`README.md` は status に出ない。次の保護対象は作業開始時と同じく残る。

```text
 M autoload/smart-history
 M docs/superpowers/specs/2026-06-13-cc-model-shortcuts-design.md
?? .claude/
```

Expected recent commits: README、autoload 登録、コア実装、実装計画、設計書の順で確認できる。追加のコミットは作成しない。
