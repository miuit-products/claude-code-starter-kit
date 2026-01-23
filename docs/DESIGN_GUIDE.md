# デザインガイド

## カラーパレット

### プライマリカラー（メインカラー）

プロジェクトに合わせてカスタマイズしてください。

| 用途 | Tailwind |
|------|----------|
| ブランドメイン | `amber-500` |
| ブランドメイン（濃） | `amber-600` |
| ブランドメイン（薄） | `amber-300` |

### セカンダリカラー

| 用途 | Tailwind |
|------|----------|
| ヘッダー/ナビ背景 | `gray-800` |
| サブテキスト | `gray-500` |
| ボーダー | `gray-200` |
| 背景 | `gray-50` |

### ステータスカラー

| ステータス | 背景 | テキスト |
|------------|------|----------|
| 進行中 | `gray-100` | `gray-700` |
| 成功/完了 | `green-100` | `green-700` |
| 終了/非アクティブ | `gray-100` | `gray-400` |

### 成功/エラー/警告

| 用途 | Tailwind |
|------|----------|
| 成功 | `emerald-500` |
| エラー | `red-500` |
| 警告 | `amber-500` |
| 情報 | `blue-500` |

---

## 色使いの原則

### 基本原則

1. **グレーをベースにする**
   - 進行中・処理中のステータスは全てグレー
   - 通常のデータ表示はグレー系
   - 色を使わないことで「通常状態」を表現

2. **色は結果・アクションにのみ使用**
   - 成功/完了した状態 → グリーン
   - エラー/危険な操作 → レッド
   - 重要な警告 → アンバー
   - それ以外は全てグレー

3. **色を使う場所を限定する**
   - ブランドカラー: ヘッダー、プライマリボタン、主要CTA
   - グリーン: 成功状態のみ
   - レッド: エラー表示、削除ボタンのみ

### ステータスバッジの色ルール

| 状態の種類 | 使用する色 | 例 |
|-----------|-----------|-----|
| 進行中 | グレー | 新規、処理中、調整中 |
| 成功/良い結果 | グリーン | 完了、成功 |
| 終了/非アクティブ | 薄いグレー | 停止中、無効 |
| エラー | レッド | エラー状態（稀にのみ使用） |

---

## タイポグラフィ

### フォントサイズ

| 用途 | Tailwind |
|------|----------|
| ページタイトル | `text-2xl` |
| セクションタイトル | `text-lg` |
| カードタイトル | `text-base` |
| 本文 | `text-sm` |
| キャプション | `text-xs` |
| 大きな数字（KPI） | `text-3xl` |

### フォントウェイト

| 用途 | Tailwind |
|------|----------|
| 見出し | `font-bold` |
| 強調テキスト | `font-semibold` |
| 本文 | `font-medium` |
| 通常 | `font-normal` |

---

## コンポーネントスタイル

### カード

```tsx
<div className="bg-white border border-gray-200 rounded-lg p-4 hover:bg-gray-50 transition-all">
  {/* content */}
</div>
```

### プライマリボタン

```tsx
<button className="bg-amber-500 hover:bg-amber-600 text-white px-4 py-2 rounded-lg font-medium transition-all">
  ボタン
</button>
```

### セカンダリボタン

```tsx
<button className="bg-white hover:bg-gray-50 border border-gray-200 text-gray-700 px-4 py-2 rounded-lg transition-all">
  ボタン
</button>
```

### ステータスバッジ

```tsx
<span className="inline-flex px-2.5 py-0.5 rounded-full text-xs font-medium bg-gray-100 text-gray-700">
  進行中
</span>
```

---

## レイアウト

### スペーシング

| 用途 | Tailwind |
|------|----------|
| セクション間 | `space-y-8` |
| カード間 | `gap-4` |
| カード内 | `p-4` |
| テーブルセル | `px-4 py-3` |

---

## アイコン

システムアイコンにはHeroicons（Outline）を推奨

```tsx
import { ArrowLeftIcon, MagnifyingGlassIcon, UserIcon } from '@heroicons/react/24/outline';
```

よく使うアイコン:
- 矢印: `ArrowLeftIcon`, `ArrowRightIcon`
- 検索: `MagnifyingGlassIcon`
- ユーザー: `UserIcon`
- メール: `EnvelopeIcon`
- 電話: `PhoneIcon`
- カレンダー: `CalendarIcon`
- チェック: `CheckIcon`
- クロス: `XMarkIcon`

---

## トランジション

```css
transition: all 150ms ease; /* transition-all */
```

ホバー、フォーカス時のスムーズな変化を実現

---

## アクセシビリティ

- コントラスト比は WCAG AA 基準（4.5:1以上）を満たすこと
- フォーカス時のアウトラインを表示
- リンクは下線またはカラーで区別
- 重要な情報は色だけでなくテキストでも表示
- 適切な `aria-label` を設定

---

## チェックリスト

新しいUIを作成する際は以下を確認:

- [ ] ステータスバッジは進行中→グレー、成功→グリーン、終了→薄いグレーになっているか
- [ ] カードの背景色は白またはグレーを基調としているか
- [ ] 数値やテキストの色に不要な装飾色を使っていないか
- [ ] 色を使っている箇所は本当に強調が必要か
- [ ] 同じ種類の情報に異なる色を使っていないか
- [ ] アクセシビリティは考慮されているか
