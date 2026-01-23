---
name: db-schema
description: DBスキーマ設計ガイド - テーブル設計・マイグレーション作成
---

# DBスキーマ設計ガイド

データベーススキーマ設計とマイグレーション作成のためのガイドです。

## 主要ファイル

| ファイル | 内容 |
|---------|------|
| `types/database.ts` | TypeScript型定義 |
| `supabase/migrations/` | マイグレーションSQL |

## 設計原則

1. 正規化を適切に行う
2. インデックスを適切に設定
3. 外部キー制約を定義
4. NULL許容を最小限に
5. 型定義とスキーマの整合性を維持

## 実装手順

### 1. 型定義の更新

`types/database.ts` にTypeScript型を追加:

```typescript
export interface NewTable {
  id: string;
  created_at: string;
  updated_at: string;
  // ... フィールド
}
```

### 2. マイグレーション作成

`supabase/migrations/YYYYMMDD_XXX_description.sql`:

```sql
-- =============================================================================
-- Migration: [機能名]
-- Description: [説明]
-- =============================================================================

CREATE TABLE IF NOT EXISTS new_table (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- フィールド
  name TEXT NOT NULL,

  -- タイムスタンプ
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- インデックス
CREATE INDEX IF NOT EXISTS idx_new_table_name ON new_table(name);

-- 更新日時自動更新トリガー
CREATE OR REPLACE FUNCTION update_new_table_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_new_table_updated_at
  BEFORE UPDATE ON new_table
  FOR EACH ROW
  EXECUTE FUNCTION update_new_table_updated_at();

-- RLSポリシー
ALTER TABLE new_table ENABLE ROW LEVEL SECURITY;
```

### 3. Repository作成

`infrastructure/repositories/supabase/` にRepositoryを作成

## チェックリスト

- [ ] types/database.ts の型定義を更新
- [ ] マイグレーションSQLを作成
- [ ] インデックスを設定
- [ ] RLSポリシーを設定
- [ ] Repositoryを作成
