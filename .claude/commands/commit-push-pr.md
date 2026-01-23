---
name: commit-push-pr
description: 変更内容を確認し、コミット、プッシュ、PR作成までを支援
---

# commit-push-pr

変更のコミットから PR 作成までのワークフローを支援します。

## 実行手順

### Step 1: 変更状態の確認

```bash
git status
git diff --stat
```

### Step 2: 差分の詳細確認

```bash
git diff
```

### Step 3: 変更のステージング

```bash
git add <ファイルパス>
# または全ファイル
git add .
```

### Step 4: コミット

コミットメッセージ形式:

```
<type>: <簡潔な説明>

<詳細な説明（任意）>

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
```

**type の種類:**

| type | 説明 |
|------|------|
| feat | 新機能 |
| fix | バグ修正 |
| docs | ドキュメント |
| style | フォーマット |
| refactor | リファクタリング |
| test | テスト追加/修正 |
| chore | ビルド/ツール |

### Step 5: プッシュ

```bash
git push -u origin <branch-name>
```

### Step 6: PR作成

```bash
gh pr create --title "<タイトル>" --body "$(cat <<'EOF'
## Summary
- <変更点1>
- <変更点2>

## Test plan
- [ ] ユニットテスト実行
- [ ] E2Eテスト実行
- [ ] 手動確認

Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

## コミット前チェックリスト

- [ ] `npm run test:run` でテストが通ること
- [ ] `npm run lint` でエラーがないこと
- [ ] 機密情報を含むファイルがコミットに含まれていないこと
- [ ] `.env` ファイルがコミットに含まれていないこと
