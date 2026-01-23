---
name: lint-and-test
description: ESLint + Vitestユニットテストを順次実行
---

# lint-and-test

ESLint でコード品質チェック後、Vitest でユニット/API/コンポーネントテストを実行します。

## 実行コマンド

```bash
npm run lint && npm run test:run
```

## 手順

1. ESLint でコード品質チェック
2. Vitest でテスト実行

## 失敗時の対応

### Lint エラーの場合

自動修正を試行:

```bash
npm run lint -- --fix
```

### テスト失敗の場合

1. エラーメッセージを確認
2. 該当テストファイルを特定
3. 実装またはテストを修正

## 期待される結果

- Lint: エラー 0 件
- Test: 全テスト PASS
