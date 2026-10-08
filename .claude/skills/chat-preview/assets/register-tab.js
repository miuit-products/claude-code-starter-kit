#!/usr/bin/env node
'use strict';
// chat-preview hub にコンテキスト（worktree/プロジェクト）単位のプレビューを登録する。
// 呼び出し側（skill）は生HTMLフラグメントをファイルに書き、これを node で実行するだけでよい。
// エスケープや index.js の再構築はすべてここで決定的に行う（LLMの手作業テキスト編集で
// 他worktreeのタブを壊さないようにするため）。
const fs = require('fs');
const path = require('path');
const os = require('os');

function arg(name, required = true) {
  const idx = process.argv.indexOf('--' + name);
  if (idx === -1 || idx === process.argv.length - 1) {
    if (required) {
      console.error(`missing --${name}`);
      process.exit(1);
    }
    return undefined;
  }
  return process.argv[idx + 1];
}

const key = arg('key');
const title = arg('title');
const cwd = arg('cwd');
const htmlFile = arg('html-file');

if (!/^[a-z0-9-]+$/.test(key)) {
  console.error('invalid --key (must match [a-z0-9-]+):', key);
  process.exit(1);
}

const base = process.env.CHAT_PREVIEW_BASE || path.join(os.homedir(), '.claude', 'chat-preview');
const dataDir = path.join(base, 'data');
fs.mkdirSync(dataDir, { recursive: true });

// タブが無期限に溜まり続けるとハブの読み込み・応答が遅くなる
// （実測: 30タブ・3.8MB、うち1件2.9MBの単体タブがあり、ブラウザが固まったように見える不具合の原因だった）。
// 直近 MIN_KEEP 件は年齢を問わず必ず残し、それ以外は AGE_LIMIT_MS 超過で捨て、
// 総数は HARD_CAP を超えないようにする。
const AGE_LIMIT_MS = 14 * 24 * 60 * 60 * 1000;
const MIN_KEEP = 8;
const HARD_CAP = 40;
const WARN_BYTES = 300 * 1024;

const html = fs.readFileSync(htmlFile, 'utf8');
const htmlBytes = Buffer.byteLength(html, 'utf8');
const b64 = Buffer.from(html, 'utf8').toString('base64');
const updatedAt = new Date().toISOString();

const meta = { key, title, cwd, updatedAt };
const metaLine = '// META: ' + JSON.stringify(meta);
const body =
  metaLine +
  '\n' +
  `window.__cp_register(${JSON.stringify(key)}, ${JSON.stringify(b64)});\n`;

fs.writeFileSync(path.join(dataDir, `${key}.js`), body, 'utf8');

// data/*.js の META ヘッダーだけを集めて index.js を毎回まるごと再生成する。
// （既存タブの中身には一切触れないので、他worktreeのタブを壊すリスクがない）
// ファイル全体を読むと巨大タブ1件で全体が遅くなるため、先頭だけ読む。
function readFirstLine(filePath) {
  const fd = fs.openSync(filePath, 'r');
  try {
    const buf = Buffer.alloc(4096);
    const bytesRead = fs.readSync(fd, buf, 0, buf.length, 0);
    return buf.toString('utf8', 0, bytesRead).split('\n', 1)[0];
  } finally {
    fs.closeSync(fd);
  }
}

const metas = [];
for (const f of fs.readdirSync(dataDir)) {
  if (f === 'index.js' || !f.endsWith('.js')) continue;
  let first;
  try {
    first = readFirstLine(path.join(dataDir, f));
  } catch {
    continue;
  }
  const m = first.match(/^\/\/ META: (.+)$/);
  if (!m) continue;
  try {
    metas.push(JSON.parse(m[1]));
  } catch {
    // 壊れたファイルはindexから除外するだけ（他タブには影響しない）
  }
}
metas.sort((a, b) => (b.updatedAt || '').localeCompare(a.updatedAt || ''));

const now = Date.now();
const kept = [];
const evicted = [];
metas.forEach((m, idx) => {
  const age = now - new Date(m.updatedAt).getTime();
  const overCap = idx >= HARD_CAP;
  const tooOld = idx >= MIN_KEEP && Number.isFinite(age) && age > AGE_LIMIT_MS;
  if (overCap || tooOld) evicted.push(m);
  else kept.push(m);
});
for (const m of evicted) {
  try {
    fs.unlinkSync(path.join(dataDir, `${m.key}.js`));
  } catch {
    // 既に無ければ無視
  }
}

fs.writeFileSync(
  path.join(dataDir, 'index.js'),
  'window.__CP_INDEX__ = ' + JSON.stringify(kept, null, 2) + ';\n',
  'utf8',
);

// hub.html の殻（コンテンツを含まない静的シェル）は毎回最新のテンプレで上書きしておく。
const hubTemplate = path.join(__dirname, 'hub-template.html');
fs.copyFileSync(hubTemplate, path.join(base, 'hub.html'));

const hubPath = path.join(base, 'hub.html');
const result = {
  ok: true,
  key,
  updatedAt,
  hub: hubPath,
  url: `file://${hubPath}#${key}`,
  tabCount: kept.length,
  evictedCount: evicted.length,
};
if (htmlBytes > WARN_BYTES) {
  result.warning = `このタブの本文が ${Math.round(htmlBytes / 1024)}KB あります。大きすぎるとハブの表示が重くなるため、分割・要約を検討してください。`;
}
console.log(JSON.stringify(result));
