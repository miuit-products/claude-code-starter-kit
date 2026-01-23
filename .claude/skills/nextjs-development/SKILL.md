---
name: Next.js 16開発
description: Next.js 16 App Router、TypeScript、Tailwind CSSを使用した開発
level: 1
---

# Next.js 16開発スキル

このスキルは、Next.js 16のApp Routerパターンを使用した開発に特化しています。

## Level 1: 概要（常に読み込み）

### 技術スタック
- Next.js 16 (App Router)
- React 19
- TypeScript 5
- Tailwind CSS 4

### 主要コマンド
```bash
npm run dev      # 開発サーバー
npm run build    # ビルド
npx tsc --noEmit # 型チェック
npm run lint     # Lint
```

### Server vs Client Components
| 用途 | コンポーネント種別 |
|------|-------------------|
| データフェッチ | Server Component |
| 静的UI | Server Component |
| インタラクティブUI | Client Component ('use client') |
| 状態管理 | Client Component |

---

## Level 2: プロジェクト構造（必要時に参照）

```
app/
├── page.tsx           # トップページ
├── layout.tsx         # ルートレイアウト
├── globals.css        # グローバルスタイル
└── {feature}/         # 機能別ページ
    ├── page.tsx       # 機能のメインページ
    └── [id]/          # 動的ルート
        └── page.tsx

components/
├── ui/                # 汎用UIコンポーネント
└── {feature}/         # 機能別コンポーネント
```

### ルーティングパターン
- 動的ルート: `[id]/page.tsx`
- レイアウト: `layout.tsx`
- ローディング: `loading.tsx`
- エラー: `error.tsx`

### スタイリング
- Tailwind CSSユーティリティクラスを使用
- レスポンシブ: `sm:`, `md:`, `lg:`, `xl:` プレフィックス

---

## Level 3: 詳細リソース（深掘り時のみ）

詳細な情報は以下のドキュメントを参照:

| リソース | 内容 |
|---------|------|
| `docs/DESIGN_GUIDE.md` | デザインガイドライン |
| `types/database.ts` | 型定義 |
| `CLAUDE.md` | プロジェクトルール |

### 注意事項
- 'use client'は必要な場合のみ使用
- サーバーコンポーネントでは非同期データフェッチが可能
- 環境変数はNEXT_PUBLIC_プレフィックスで公開
