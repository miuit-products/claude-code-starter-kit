# Claude Code Template

Next.js + Supabase プロジェクト用の Claude Code 設定テンプレートです。

## 概要

このテンプレートは、Claude Code を使用した開発を効率化するための設定一式を提供します。

### 含まれるもの

- **7つのエージェント定義**
  - CTO/統括指揮官: タスク分解・委任・統合
  - FEコーダー: React/Next.js/Tailwind CSS実装
  - BEコーダー: API/Supabase実装
  - DBコーダー: スキーマ/マイグレーション
  - テストコーダー: テスト作成
  - コードレビューアー: 品質チェック
  - バグ修正エージェント: バグ調査・修正

- **3つのスキル**
  - nextjs-development: Next.js開発パターン
  - supabase: Supabase連携ガイド
  - code-simplifier: コードリファクタリング

- **6つのコマンド**
  - /design-fe: FE設計ガイドライン
  - /design-be: BE設計ガイドライン
  - /db-schema: DBスキーマ設計
  - /test-guide: テスト作成ガイド
  - /lint-and-test: Lint + テスト実行
  - /commit-push-pr: コミット→PR支援

## セットアップ

### 1. テンプレートからリポジトリを作成

GitHub で「Use this template」をクリックして新しいリポジトリを作成します。

### 2. クローン

```bash
git clone https://github.com/YOUR_USERNAME/your-new-project.git
cd your-new-project
```

### 3. プレースホルダーを置換

```bash
# macOS
sed -i '' 's/{{PROJECT_NAME}}/My Project/g' CLAUDE.md .claude/settings.json
sed -i '' 's/{{PROJECT_DESCRIPTION}}/My project description/g' .claude/settings.json

# Linux
sed -i 's/{{PROJECT_NAME}}/My Project/g' CLAUDE.md .claude/settings.json
sed -i 's/{{PROJECT_DESCRIPTION}}/My project description/g' .claude/settings.json
```

### 4. 初期コミット

```bash
git add -A && git commit -m "chore: initialize project from template"
```

## カスタマイズ

### プロジェクト固有のエージェントを追加

1. `.claude/agents/` に新しいエージェント定義ファイルを作成

```bash
cp .claude/agents/coder-fe.md .claude/agents/my-custom-agent.md
```

2. `.claude/settings.json` の `subagents.available` に追加

```json
{
  "name": "my-custom-agent",
  "path": ".claude/agents/my-custom-agent.md",
  "description": "カスタムエージェントの説明"
}
```

### プロジェクト固有のスキルを追加

1. `.claude/skills/` に新しいスキルディレクトリを作成

```bash
mkdir .claude/skills/my-skill
touch .claude/skills/my-skill/SKILL.md
```

2. `.claude/settings.json` の `skills.available` に追加

```json
{
  "name": "my-skill",
  "path": ".claude/skills/my-skill/SKILL.md",
  "description": "カスタムスキルの説明"
}
```

### プロジェクト固有のコマンドを追加

`.claude/commands/` に新しいコマンドファイルを作成

```bash
touch .claude/commands/my-command.md
```

## ディレクトリ構造

```
.claude/
├── settings.json           # メイン設定
├── settings.local.json     # ローカル設定（Git追跡対象外推奨）
├── agents/
│   ├── cto.md              # CTO/統括指揮官
│   ├── coder-fe.md         # FEコーダー
│   ├── coder-be.md         # BEコーダー
│   ├── coder-db.md         # DBコーダー
│   ├── coder-test.md       # テストコーダー
│   ├── code-reviewer.md    # コードレビューアー
│   └── bug-fixer.md        # バグ修正エージェント
├── skills/
│   ├── nextjs-development/ # Next.js開発スキル
│   ├── supabase/           # Supabase連携スキル
│   └── code-simplifier/    # コード最適化スキル
└── commands/
    ├── design-fe.md        # FE設計ガイド
    ├── design-be.md        # BE設計ガイド
    ├── db-schema.md        # DBスキーマ設計
    ├── test-guide.md       # テスト作成ガイド
    ├── lint-and-test.md    # Lint + テスト実行
    └── commit-push-pr.md   # コミット→PR

docs/
├── DESIGN_GUIDE.md         # デザインガイド（テンプレート）
└── TESTING_GUIDE.md        # テストガイド（テンプレート）

CLAUDE.md                   # プロジェクトルール（テンプレート）
```

## 技術スタック（想定）

- Next.js 16 (App Router)
- TypeScript
- Tailwind CSS v4
- Supabase (Database + Auth)
- Vitest（ユニット / API / コンポーネントテスト）
- Playwright（E2Eテスト）

## 使い方

### エージェントの使用

```typescript
// CTOに委任
Task(subagent_type: "cto", prompt: "この機能を実装してください", description: "機能実装")

// FEコーダーに直接委任
Task(subagent_type: "coder-fe", prompt: "ボタンコンポーネントを作成", description: "FE実装")
```

### スキルの使用

```
/code-simplifier  # 最近変更されたコードをリファクタリング
```

### コマンドの使用

```
/design-fe        # FE設計ガイドラインを表示
/lint-and-test    # Lint + テスト実行
/commit-push-pr   # コミットからPR作成まで支援
```

## ライセンス

MIT
