---
name: Supabase連携
description: Supabaseを使用したデータベース操作、認証、ストレージ管理
---

# Supabase連携スキル

このスキルは、Supabaseとの連携に特化しています。

## 設定

環境変数:
- `NEXT_PUBLIC_SUPABASE_URL`: SupabaseプロジェクトURL
- `NEXT_PUBLIC_SUPABASE_ANON_KEY`: 匿名キー
- `SUPABASE_SERVICE_ROLE_KEY`: サービスロールキー（サーバーサイドのみ）

## Supabaseクライアント

```typescript
import { createClient } from '@supabase/supabase-js';
import type { Database } from '@/types/database';

// クライアントサイド用
const supabase = createClient<Database>(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
);

// サーバーサイド用（Admin権限）
const supabaseAdmin = createClient<Database>(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY!
);
```

## CRUD操作

### 取得（SELECT）

```typescript
// 全件取得
const { data, error } = await supabase
  .from('table_name')
  .select('*');

// 条件付き取得
const { data, error } = await supabase
  .from('table_name')
  .select('*')
  .eq('status', 'active')
  .order('created_at', { ascending: false });

// 単一レコード取得
const { data, error } = await supabase
  .from('table_name')
  .select('*')
  .eq('id', id)
  .single();

// リレーション込みで取得
const { data, error } = await supabase
  .from('table_name')
  .select(`
    *,
    related_table (
      id,
      name
    )
  `);
```

### 挿入（INSERT）

```typescript
const { data, error } = await supabase
  .from('table_name')
  .insert({
    name: 'テスト',
    email: 'test@example.com',
  })
  .select()
  .single();
```

### 更新（UPDATE）

```typescript
const { data, error } = await supabase
  .from('table_name')
  .update({
    status: 'completed',
    updated_at: new Date().toISOString(),
  })
  .eq('id', id)
  .select()
  .single();
```

### 削除（DELETE）

```typescript
const { error } = await supabase
  .from('table_name')
  .delete()
  .eq('id', id);
```

## ストレージ

```typescript
// ファイルアップロード
const { data, error } = await supabase.storage
  .from('bucket_name')
  .upload(`${folder}/${filename}`, file);

// 公開URL取得
const { data } = supabase.storage
  .from('bucket_name')
  .getPublicUrl(`${folder}/${filename}`);

// ファイル削除
const { error } = await supabase.storage
  .from('bucket_name')
  .remove([`${folder}/${filename}`]);
```

## RLS (Row Level Security)

```sql
-- RLSを有効化
ALTER TABLE table_name ENABLE ROW LEVEL SECURITY;

-- ポリシー作成
CREATE POLICY policy_name ON table_name
  FOR ALL TO authenticated
  USING (
    -- 条件
    auth.uid() = user_id
  );
```

## Repository パターン

```typescript
// infrastructure/repositories/supabase/example-repository.ts
import { supabase } from '@/lib/supabase';
import type { Example } from '@/types/database';

export const exampleRepository = {
  async findById(id: string): Promise<Example | null> {
    const { data, error } = await supabase
      .from('examples')
      .select('*')
      .eq('id', id)
      .single();

    if (error) throw error;
    return data;
  },

  async findAll(): Promise<Example[]> {
    const { data, error } = await supabase
      .from('examples')
      .select('*')
      .order('created_at', { ascending: false });

    if (error) throw error;
    return data || [];
  },

  async create(input: Omit<Example, 'id' | 'created_at' | 'updated_at'>): Promise<Example> {
    const { data, error } = await supabase
      .from('examples')
      .insert(input)
      .select()
      .single();

    if (error) throw error;
    return data;
  },

  async update(id: string, input: Partial<Example>): Promise<Example> {
    const { data, error } = await supabase
      .from('examples')
      .update({ ...input, updated_at: new Date().toISOString() })
      .eq('id', id)
      .select()
      .single();

    if (error) throw error;
    return data;
  },

  async delete(id: string): Promise<void> {
    const { error } = await supabase
      .from('examples')
      .delete()
      .eq('id', id);

    if (error) throw error;
  },
};
```

## エラーハンドリング

```typescript
const { data, error } = await supabase
  .from('table_name')
  .select('*');

if (error) {
  console.error('Supabase error:', error.message);
  throw new Error(`Database error: ${error.message}`);
}
```

## 型定義との整合性

`types/database.ts`の型定義とSupabaseスキーマを常に同期させること。

```typescript
// types/database.ts
export interface Example {
  id: string;
  name: string;
  status: 'active' | 'inactive';
  created_at: string;
  updated_at: string;
}
```
