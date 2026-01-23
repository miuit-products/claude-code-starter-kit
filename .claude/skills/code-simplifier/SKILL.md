---
name: code-simplifier
description: 最近変更されたコードを簡略化・リファクタリング
---

# Code Simplifier

コードの明確性・一貫性・保守性を向上させるリファクタリングスキル。

## 使い方

```
/code-simplifier
```

## 実行内容

1. git diffで最近変更されたファイルを特定
2. 変更箇所のコードを分析
3. 以下の観点でリファクタリング:
   - 不要な複雑さ・ネストの削減
   - 冗長コード・抽象化の除去
   - 変数・関数名の改善
   - プロジェクト標準(CLAUDE.md)への準拠

## 重要ルール

- **機能は一切変更しない** - 動作・出力は完全に維持
- ネストした三項演算子は禁止（switch/if-elseを使用）
- 短さより可読性を優先
- 過度な抽象化は避ける

## 手順

実行時は以下の手順で進める:

1. `git diff --name-only HEAD~1` で変更ファイルを取得
2. 各ファイルを読み込み、変更箇所を特定
3. CLAUDE.mdのルールに従ってリファクタリング案を作成
4. ユーザーに確認後、Editツールで適用

## リファクタリング例

### Before
```typescript
const result = data ? (data.items ? data.items.filter(x => x.active ? x.active === true : false) : []) : [];
```

### After
```typescript
if (!data?.items) {
  return [];
}

return data.items.filter(item => item.active === true);
```

## チェックリスト

- [ ] 変更前後で動作が同一である
- [ ] 可読性が向上している
- [ ] プロジェクト標準に準拠している
- [ ] テストが成功する
