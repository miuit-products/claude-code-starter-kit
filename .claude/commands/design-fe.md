---
name: design-fe
description: FE設計ガイドライン - UI/コンポーネント設計の方針策定
---

# FE設計ガイドライン

UI/コンポーネント設計の方針を策定するためのガイドです。

## 必読ドキュメント

1. `docs/DESIGN_GUIDE.md` - デザインガイド
2. `CLAUDE.md` - プロジェクトルール

## 設計手順

### 1. 要件確認

- 実装対象の機能・画面を特定
- ユーザーストーリーを明確化

### 2. 既存パターン調査

- 類似機能の既存実装を確認
- 再利用可能なコンポーネントを特定

### 3. コンポーネント設計

| 判断基準 | コンポーネント種別 |
|---------|-------------------|
| データフェッチ | Server Component |
| 静的UI | Server Component |
| useState/useEffect使用 | Client Component ('use client') |
| onClick等イベント | Client Component |

### 4. 状態管理方針

- ローカル状態: `useState` で管理
- サーバー状態: API連携

## 出力フォーマット

```markdown
## 設計方針: [機能名]

### コンポーネント構成
- ComponentA: [役割]
- ComponentB: [役割]

### Server/Client 判断
- Server Component: [理由]
- Client Component: [理由]

### 状態管理
- ローカル状態: [管理対象]
- API連携: [必要なエンドポイント]

### レビューチェックリスト
- [ ] DESIGN_GUIDE.md に準拠
- [ ] アクセシビリティ考慮（aria-label等）
- [ ] レスポンシブ対応
```

## デザインルール（必須）

- DESIGN_GUIDE.md のカラー規約に準拠
- Tailwind CSS を使用
- アクセシビリティを考慮
