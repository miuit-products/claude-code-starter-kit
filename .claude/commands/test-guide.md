---
name: test-guide
description: テスト作成ガイド - ユニット/API/コンポーネント/E2Eテスト
---

# テスト作成ガイド

テスト作成のためのガイドです。

## テストの種類と配置

| 種類 | 配置場所 | 対象 | フレームワーク |
|------|----------|------|---------------|
| ユニットテスト | `lib/__tests__/` | ユーティリティ関数 | Vitest |
| APIテスト | `app/api/__tests__/` | APIルート | Vitest |
| コンポーネントテスト | `components/__tests__/` | Reactコンポーネント | Vitest + Testing Library |
| E2Eテスト | `e2e/` | ユーザーフロー | Playwright |

## APIテストテンプレート

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

// セキュリティモック
vi.mock('@/lib/security', async () => {
  const actual = await vi.importActual('@/lib/security');
  return {
    ...actual,
    checkRateLimit: vi.fn(() => ({ allowed: true })),
    recordAuditLog: vi.fn(),
  };
});

describe('API名', () => {
  beforeEach(() => { vi.clearAllMocks(); });
  afterEach(() => { vi.restoreAllMocks(); });

  describe('正常系', () => {
    it('有効なデータで成功する', async () => {
      const request = createMockRequest('/api/endpoint');
      const response = await GET(request as any);
      expect(response.status).toBe(200);
    });
  });

  describe('バリデーション', () => {
    it('必須項目が欠けている場合は400エラー');
  });

  describe('認証・認可', () => {
    it('未認証の場合は401エラー');
  });

  describe('セキュリティ', () => {
    it('レート制限超過時は429エラー');
  });
});
```

## 必須テストケース

### API実装時
- [ ] 正常系（有効データでの成功）
- [ ] バリデーション（必須項目の検証）
- [ ] 認証・認可（未認証時401、権限不足時403）
- [ ] セキュリティ（レート制限）

### ユーティリティ関数
- [ ] 正常系（期待通りの動作）
- [ ] エッジケース（空入力、null等）
- [ ] 異常系（不正入力でのエラー）

## 実行コマンド

```bash
npm run test:run              # 全テスト実行
npm run test:run -- path/to/test.ts  # 特定ファイル
npm run test:e2e              # E2Eテスト
npm run test:coverage         # カバレッジ
```

## ヘルパー

`app/api/__tests__/test-helpers.ts` を使用
