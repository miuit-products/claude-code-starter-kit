# テストガイド

このドキュメントは、本プロジェクトにおけるテストの書き方と規約を定義する。

## テストフレームワーク

- **Vitest**: テストランナー・アサーション
- **jsdom**: DOM環境のエミュレーション
- **@testing-library/react**: Reactコンポーネントテスト
- **Playwright**: E2Eテスト

## ディレクトリ構造

```
project/
├── lib/
│   └── __tests__/           # ユーティリティ関数のテスト
├── app/
│   └── api/
│       └── __tests__/       # APIルートのテスト
│           ├── test-helpers.ts  # 共通ヘルパー
│           └── *.test.ts
├── components/
│   └── __tests__/           # コンポーネントテスト
└── e2e/                     # E2Eテスト (Playwright)
```

## テストファイルの命名規則

- ユニットテスト: `{対象ファイル名}.test.ts`
- コンポーネントテスト: `{コンポーネント名}.test.tsx`
- E2Eテスト: `{機能名}.spec.ts`

---

## APIテストのテンプレート

### 基本構造

```typescript
import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { GET, POST } from '../{api-path}/route';
import { createMockRequest } from './test-helpers';

// 認証モック
vi.mock('@/lib/api-auth', () => ({
  requireAuth: vi.fn(() =>
    Promise.resolve({
      success: true,
      user: {
        sub: 'auth0|123456',
        email: 'admin@example.com',
        isAdmin: true,
      },
    })
  ),
  getAuditUserInfo: vi.fn(() => ({
    user_id: 'auth0|123456',
    user_email: 'admin@example.com',
    user_role: 'admin',
  })),
}));

// データ層モック
vi.mock('@/lib/supabase-data', () => ({
  getData: vi.fn(() => Promise.resolve(mockData)),
  createData: vi.fn((data) => Promise.resolve({ id: 'new-id', ...data })),
}));

// セキュリティモック
vi.mock('@/lib/security', async () => {
  const actual = await vi.importActual('@/lib/security');
  return {
    ...actual,
    checkRateLimit: vi.fn(() => ({ allowed: true })),
    recordAuditLog: vi.fn(),
  };
});

describe('GET /api/{endpoint}', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  describe('正常系', () => {
    it('データを正常に取得できる', async () => {
      const request = createMockRequest('/api/{endpoint}');
      const response = await GET(request as any);
      const body = await response.json();

      expect(response.status).toBe(200);
      expect(body.success).toBe(true);
      expect(body.data).toBeDefined();
    });
  });

  describe('認証・認可', () => {
    it('未認証の場合は401エラー', async () => {
      const { requireAuth } = await import('@/lib/api-auth');
      (requireAuth as any).mockResolvedValueOnce({
        success: false,
        response: new Response(JSON.stringify({ error: 'Unauthorized' }), {
          status: 401,
        }),
      });

      const request = createMockRequest('/api/{endpoint}');
      const response = await GET(request as any);

      expect(response.status).toBe(401);
    });
  });

  describe('セキュリティ', () => {
    it('レート制限超過時は429エラー', async () => {
      const { checkRateLimit } = await import('@/lib/security');
      (checkRateLimit as any).mockReturnValue({
        allowed: false,
        resetAt: new Date(Date.now() + 60000),
      });

      const request = createMockRequest('/api/{endpoint}');
      const response = await GET(request as any);

      expect(response.status).toBe(429);
    });
  });
});
```

---

## ユニットテストのテンプレート

### 関数テスト

```typescript
import { describe, it, expect } from 'vitest';
import { targetFunction } from '../target-file';

describe('targetFunction', () => {
  describe('正常系', () => {
    it('期待通りの結果を返す', () => {
      const result = targetFunction('input');
      expect(result).toBe('expected');
    });

    it('エッジケースを正しく処理する', () => {
      expect(targetFunction('')).toBe('');
      expect(targetFunction(null)).toBeNull();
    });
  });

  describe('異常系', () => {
    it('不正な入力でエラーをスローする', () => {
      expect(() => targetFunction(undefined)).toThrow();
    });
  });
});
```

---

## コンポーネントテストのテンプレート

```typescript
import { describe, it, expect, vi } from 'vitest';
import { render, screen, fireEvent } from '@testing-library/react';
import { ComponentName } from '../ComponentName';

describe('ComponentName', () => {
  it('正しくレンダリングされる', () => {
    render(<ComponentName />);
    expect(screen.getByRole('button')).toBeInTheDocument();
  });

  it('クリックイベントを処理する', async () => {
    const onClick = vi.fn();
    render(<ComponentName onClick={onClick} />);

    fireEvent.click(screen.getByRole('button'));
    expect(onClick).toHaveBeenCalledTimes(1);
  });
});
```

---

## モックのベストプラクティス

### 1. モジュール全体のモック

```typescript
vi.mock('@/lib/supabase-data', () => ({
  getApplicants: vi.fn(() => Promise.resolve([])),
}));
```

### 2. 部分的なモック（実際の実装を保持）

```typescript
vi.mock('@/lib/security', async () => {
  const actual = await vi.importActual('@/lib/security');
  return {
    ...actual,
    checkRateLimit: vi.fn(() => ({ allowed: true })),
  };
});
```

### 3. テストごとにモック実装を変更

```typescript
it('エラーケース', async () => {
  const { getData } = await import('@/lib/supabase-data');
  (getData as any).mockResolvedValueOnce(null);

  // テスト実行
});
```

### 4. beforeEachでモックをリセット

```typescript
beforeEach(async () => {
  vi.clearAllMocks();

  // モック実装をリセット
  const security = await import('@/lib/security');
  (security.checkRateLimit as any).mockReturnValue({ allowed: true });
});
```

---

## セキュリティテストチェックリスト

新しいAPIを実装する際は、以下のセキュリティテストを含めること：

- [ ] 未認証アクセスの拒否 (401)
- [ ] 権限不足アクセスの拒否 (403)
- [ ] レート制限の動作 (429)
- [ ] 入力値バリデーション (400)
- [ ] 存在しないリソースへのアクセス (404)

---

## テスト実行

```bash
# ウォッチモード（開発中）
npm run test

# 単発実行（CI/CD）
npm run test:run

# カバレッジレポート
npm run test:coverage

# 特定のファイルのみ
npm run test:run -- lib/__tests__/security.test.ts

# E2Eテスト
npm run test:e2e
```

---

## 新機能実装時のワークフロー

1. **テストファイルを作成**
   ```bash
   touch app/api/__tests__/{新機能}.test.ts
   ```

2. **テストケースを定義**（実装前にテストの骨組みを書く）
   ```typescript
   describe('新機能API', () => {
     it.todo('正常系のテスト');
     it.todo('バリデーションのテスト');
     it.todo('認証のテスト');
   });
   ```

3. **機能を実装**

4. **テストを実装**

5. **全テスト成功を確認**
   ```bash
   npm run test:run
   ```

6. **コミット**
