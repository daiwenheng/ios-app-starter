'use strict';
/* 阅书:本地书房。数据全部存在这台设备的浏览器里(IndexedDB + localStorage)。 */

// ───────── 小工具 ─────────
const $ = (id) => document.getElementById(id);
const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const uid = () => (crypto.randomUUID ? crypto.randomUUID() : Date.now().toString(36) + Math.random().toString(36).slice(2));
const clamp = (v, [lo, hi]) => Math.min(Math.max(v, lo), hi);

let toastTimer;
function toast(msg) {
  const el = $('toast');
  el.textContent = msg;
  el.classList.add('show');
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => el.classList.remove('show'), 2000);
}

const ICON_PATHS = {
  chevL: 'M15 18l-6-6 6-6', list: 'M8 6h13M8 12h13M8 18h13M3 6h.01M3 12h.01M3 18h.01',
  prev: 'M11 17l-5-5 5-5M18 17l-5-5 5-5', next: 'M13 17l5-5-5-5M6 17l5-5-5-5',
  more: 'M5 12h.01M12 12h.01M19 12h.01', search: 'M11 4a7 7 0 100 14 7 7 0 000-14zM21 21l-4.3-4.3',
  plus: 'M12 5v14M5 12h14', up: 'M12 19V5M5 12l7-7 7 7', down: 'M12 5v14M19 12l-7 7-7-7',
  pencil: 'M17 3l4 4L8 20H4v-4L17 3z', x: 'M18 6L6 18M6 6l12 12', check: 'M20 6L9 17l-5-5',
  bookmark: 'M6 3h12v18l-6-4-6 4V3z', note: 'M12 20h9M16.5 3.5a2.1 2.1 0 013 3L7 19l-4 1 1-4L16.5 3.5z',
  upload: 'M12 16V4M7 9l5-5 5 5M5 20h14', box: 'M3 4h18v4H3zM5 8v12h14V8M10 12h4',
  book: 'M4 19.5V5.5A2.5 2.5 0 016.5 3H20v14H6.5A2.5 2.5 0 004 19.5zM6.5 17H20v4H6.5A2.5 2.5 0 014 19.5',
  arrow: 'M5 12h14M13 6l6 6-6 6',
};
const ic = (name, extra = '') => name === 'aa'
  ? '<span class="i aa" style="font-weight:700;font-size:.78em;letter-spacing:-.02em">Aa</span>'
  : `<svg class="i" viewBox="0 0 24 24" aria-hidden="true" ${extra}><path d="${ICON_PATHS[name]}"/></svg>`;
const chk = (on) => on
  ? '<svg class="i" viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="12" r="10" fill="currentColor" stroke="none"/><path d="M7.5 12.5l3 3 6-6.5" stroke="#fff" stroke-width="2.4"/></svg>'
  : '<svg class="i" viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="12" r="9.5" stroke-width="1.6"/></svg>';

function hueIndex(id) {
  let h = 0;
  for (const ch of String(id)) h = (h * 31 + ch.charCodeAt(0)) >>> 0;
  return h % 8;
}
function glyphOf(title) {
  const ch = [...String(title)].find((c) => !/[\s《》「」“”"']/.test(c));
  return ch || '书';
}
function coverHTML(book) {
  if (book.cover) return `<div class="cover"><img src="${book.cover}" alt="${esc(book.title)}"></div>`;
  return `<div class="cover h${hueIndex(book.id)}" role="img" aria-label="${esc(book.title)}">
    <div class="glyph">${esc(glyphOf(book.title))}</div><div class="ct">${esc(book.title)}</div><div class="au">${esc(book.author)}</div></div>`;
}

// ───────── 存储 ─────────
const DB_NAME = 'yueshu-db', STORE = 'books';
let dbPromise;
function openDB() {
  dbPromise ||= new Promise((resolve, reject) => {
    const req = indexedDB.open(DB_NAME, 1);
    req.onupgradeneeded = () => req.result.createObjectStore(STORE, { keyPath: 'id' });
    req.onsuccess = () => resolve(req.result);
    req.onerror = () => reject(req.error);
  });
  return dbPromise;
}
async function tx(mode, fn) {
  const db = await openDB();
  return new Promise((resolve, reject) => {
    const t = db.transaction(STORE, mode);
    const out = fn(t.objectStore(STORE));
    t.oncomplete = () => resolve(out && out.result !== undefined ? out.result : undefined);
    t.onerror = () => reject(t.error);
  });
}
const dbAll = () => tx('readonly', (s) => s.getAll());
const dbPut = (book) => tx('readwrite', (s) => s.put(book));
const dbDelete = (id) => tx('readwrite', (s) => s.delete(id));
const dbClear = () => tx('readwrite', (s) => s.clear());

let library = [];
const progressKey = 'yueshu.progress.v1';
let progress = {};
try { progress = JSON.parse(localStorage.getItem(progressKey) || '{}') || {}; } catch { progress = {}; }
function saveProgressMap() { try { localStorage.setItem(progressKey, JSON.stringify(progress)); } catch { /* 存储满了就算了 */ } }
function setProgress(id, patch) {
  progress[id] = { c: 0, b: 0, t: 0, ...(progress[id] || {}), ...patch };
  saveProgressMap();
}

// ───────── 阅读设置 ─────────
const RANGES = { fontSize: [13, 28], lineHeight: [1.2, 2.6], letterSpacing: [-1, 3], paraGap: [0.2, 2.5], padX: [0, 40], padY: [0, 60] };
const TEXT_COLORS = ['#333333', '#000000', '#1F3A5F', '#2E4F3C', '#5C3A21'];
const DIALOGUE_COLORS = ['#5B8C6F', '#3D7EAA', '#7B5EA7', '#A67B5B', '#C05A5A'];
const DEFAULTS = { fontSize: 17, bold: false, lineHeight: 1.8, letterSpacing: 0, paraGap: 1, padX: 8, padY: 25,
  textColor: '#333333', dialogue: true, dialogueColor: '#5B8C6F', theme: 'system' };
const settingsKey = 'yueshu.settings.v2';
let settings = { ...DEFAULTS };
try { Object.assign(settings, JSON.parse(localStorage.getItem(settingsKey) || '{}')); } catch { /* 用默认值 */ }
function normalizeSettings() {
  for (const k of Object.keys(RANGES)) {
    const n = Number(settings[k]);
    settings[k] = clamp(Number.isFinite(n) ? n : DEFAULTS[k], RANGES[k]);
  }
  if (!['system', 'paper', 'eye', 'night'].includes(settings.theme)) settings.theme = 'system';
}
normalizeSettings();
const darkQuery = matchMedia('(prefers-color-scheme: dark)');

function applySettings() {
  normalizeSettings();
  try { localStorage.setItem(settingsKey, JSON.stringify(settings)); } catch { /* 忽略 */ }
  const r = $('reader');
  const theme = settings.theme === 'system' ? (darkQuery.matches ? 'night' : 'paper') : settings.theme;
  r.dataset.rt = theme === 'eye' ? 'eye' : theme === 'night' ? 'night' : 'paper';
  const st = r.style;
  st.setProperty('--fs', settings.fontSize + 'px');
  st.setProperty('--fw', settings.bold ? '700' : '400');
  st.setProperty('--lh', settings.lineHeight);
  st.setProperty('--ls', settings.letterSpacing + 'px');
  st.setProperty('--pg', settings.paraGap + 'em');
  st.setProperty('--px', settings.padX + 'px');
  st.setProperty('--py', settings.padY + 'px');
  // 夜间和护眼主题用主题自带的字色
  if (theme === 'paper') st.setProperty('--tc', settings.textColor); else st.removeProperty('--tc');
  st.setProperty('--dc', settings.dialogueColor);
}
darkQuery.addEventListener?.('change', applySettings);

// ───────── txt 导入 ─────────
function decodeText(buf) {
  const u8 = new Uint8Array(buf);
  if (u8[0] === 0xEF && u8[1] === 0xBB && u8[2] === 0xBF) return new TextDecoder('utf-8').decode(u8.subarray(3));
  if (u8[0] === 0xFF && u8[1] === 0xFE) return new TextDecoder('utf-16le').decode(u8.subarray(2));
  if (u8[0] === 0xFE && u8[1] === 0xFF) return new TextDecoder('utf-16be').decode(u8.subarray(2));
  try { return new TextDecoder('utf-8', { fatal: true }).decode(u8); } catch { /* 不是 UTF-8 */ }
  try { return new TextDecoder('gb18030').decode(u8); } catch { return null; }
}
const HEADING = /^(第\s*[0-9零〇一二三四五六七八九十百千万两]+\s*[章节回卷集部篇]|chapter\s*[0-9IVXivx]+|序章|楔子|引子|尾声|后记|番外)/i;
function splitChapters(text) {
  const lines = text.replace(/\r\n?/g, '\n').split('\n').map((l) => l.trim()).filter(Boolean);
  const chapters = [];
  let title = null, buf = [];
  const flush = () => {
    if (buf.length) chapters.push({ id: uid(), title: title || '序章', content: buf.join('\n') });
    buf = [];
  };
  for (const line of lines) {
    if (line.length <= 40 && HEADING.test(line)) { flush(); title = line; } else buf.push(line);
  }
  flush();
  if (chapters.length > 1 || (chapters.length === 1 && chapters[0].title !== '序章')) return chapters;
  // 没有识别到章节标题:按字数切成若干部分
  const all = lines;
  if (!all.length) return [];
  const parts = [];
  let cur = [], size = 0;
  for (const line of all) {
    cur.push(line); size += line.length;
    if (size >= 3000) { parts.push(cur); cur = []; size = 0; }
  }
  if (cur.length) parts.push(cur);
  if (parts.length === 1) return [{ id: uid(), title: '正文', content: parts[0].join('\n') }];
  return parts.map((p, i) => ({ id: uid(), title: `第 ${i + 1} 部分`, content: p.join('\n') }));
}
async function bookFromFile(file) {
  const text = decodeText(await file.arrayBuffer());
  if (text === null) throw new Error('无法识别文件编码');
  const chapters = splitChapters(text);
  if (!chapters.length) throw new Error('文件里没有可阅读的文字');
  const name = file.name.replace(/\.[^.]+$/, '') || '未命名';
  return { id: uid(), title: name, author: '导入作品', desc: '', cover: null, chapters,
    createTime: Date.now(), bookmarks: [], notes: [] };
}

// ───────── 封面图片 ─────────
function resizeCover(file) {
  return new Promise((resolve, reject) => {
    const url = URL.createObjectURL(file);
    const img = new Image();
    img.onload = () => {
      const scale = Math.min(1, 800 / Math.max(img.width, img.height));
      const c = document.createElement('canvas');
      c.width = Math.max(1, Math.round(img.width * scale));
      c.height = Math.max(1, Math.round(img.height * scale));
      const g = c.getContext('2d');
      g.fillStyle = '#fff'; g.fillRect(0, 0, c.width, c.height);
      g.drawImage(img, 0, 0, c.width, c.height);
      URL.revokeObjectURL(url);
      resolve(c.toDataURL('image/jpeg', 0.82));
    };
    img.onerror = () => { URL.revokeObjectURL(url); reject(new Error('不是有效的图片')); };
    img.src = url;
  });
}

// ───────── 弹层 ─────────
const sheetRoot = $('sheetRoot');
function openSheet(html, { tall = false, onClose } = {}) {
  const scrim = document.createElement('div');
  scrim.className = 'scrim';
  scrim.innerHTML = `<div class="sheet${tall ? ' tall' : ''}" role="dialog" aria-modal="true"><div class="grab"></div>${html}</div>`;
  const close = () => { scrim.remove(); onClose?.(); };
  scrim.addEventListener('click', (e) => { if (e.target === scrim) close(); });
  sheetRoot.appendChild(scrim);
  return { el: scrim.firstElementChild, close };
}
function dialog(html) {
  const scrim = document.createElement('div');
  scrim.className = 'scrim center';
  scrim.style.zIndex = 60;
  scrim.innerHTML = `<div class="dialog" role="alertdialog" aria-modal="true">${html}</div>`;
  sheetRoot.appendChild(scrim);
  return { el: scrim.firstElementChild, close: () => scrim.remove() };
}
function confirmDialog(title, message, okText, onOk, danger = true) {
  const d = dialog(`<h3>${esc(title)}</h3><p>${esc(message)}</p>
    <div class="row"><button class="btn plain" data-x="no">取消</button>
    <button class="btn ${danger ? 'danger' : 'solid'}" data-x="ok">${esc(okText)}</button></div>`);
  d.el.addEventListener('click', (e) => {
    const x = e.target.closest('[data-x]')?.dataset.x;
    if (!x) return;
    d.close();
    if (x === 'ok') onOk();
  });
}
function promptDialog(title, value, onOk, { multiline = false, placeholder = '' } = {}) {
  const d = dialog(`<h3>${esc(title)}</h3>
    ${multiline ? `<textarea class="field" placeholder="${esc(placeholder)}">${esc(value)}</textarea>`
      : `<input class="field" value="${esc(value)}" placeholder="${esc(placeholder)}">`}
    <div class="row"><button class="btn plain" data-x="no">取消</button><button class="btn solid" data-x="ok">确定</button></div>`);
  const input = d.el.querySelector('.field');
  setTimeout(() => input.focus(), 50);
  d.el.addEventListener('click', (e) => {
    const x = e.target.closest('[data-x]')?.dataset.x;
    if (!x) return;
    if (x === 'ok') { if (onOk(input.value) === false) return; }
    d.close();
  });
}

// ───────── 书架 ─────────
let manage = false, query = '';
const bookById = (id) => library.find((b) => b.id === id);
function sortedLibrary() {
  const q = query.trim().toLowerCase();
  const list = q ? library.filter((b) => b.title.toLowerCase().includes(q) || b.author.toLowerCase().includes(q)) : [...library];
  return list.sort((a, b) => {
    const ta = progress[a.id]?.t || 0, tb = progress[b.id]?.t || 0;
    return ta !== tb ? tb - ta : (b.createTime || 0) - (a.createTime || 0);
  });
}
function percentOf(book) {
  const p = progress[book.id];
  if (!p || !p.t) return null;
  const c = Math.min(p.c || 0, book.chapters.length - 1);
  return Math.round(((c + 1) / book.chapters.length) * 100);
}
function renderLibrary() {
  const list = sortedLibrary();
  const recent = [...library].filter((b) => progress[b.id]?.t).sort((a, b) => progress[b.id].t - progress[a.id].t)[0];
  let banner = '';
  if (!query && recent) {
    const c = Math.min(progress[recent.id].c || 0, recent.chapters.length - 1);
    banner = `<button class="resume" data-open="${recent.id}">${coverHTML(recent)}
      <div class="rt"><small>接着读</small><strong>${esc(recent.title)}</strong><span class="ch">${esc(recent.chapters[c].title)}</span>
      <div class="bar"><i style="width:${percentOf(recent) || 0}%"></i></div></div><span class="btn solid go">继续</span></button>`;
  }
  let body;
  if (!library.length) body = `<div class="empty"><div class="ei">${ic('book')}</div><b>书架是空的</b><span>点“传 TXT”导入一本小说,<br>或者点“写书”从空白开始。</span></div>`;
  else if (!list.length) body = `<div class="empty"><div class="ei">${ic('search')}</div><b>没有找到</b><span>换个书名或作者再搜一次。</span></div>`;
  else {
    body = `<div class="grid">${list.map((b) => {
      const pct = percentOf(b);
      return `<div class="cell"><div class="cell-cover" data-open="${b.id}">${coverHTML(b)}
        ${manage ? `<div class="badges"><button class="badge" data-edit="${b.id}" aria-label="编辑">${ic('pencil')}</button><button class="badge del" data-del="${b.id}" aria-label="删除">${ic('x')}</button></div>` : ''}</div>
        <h3>${esc(b.title)}</h3><p>${esc(b.author)}</p>${pct !== null ? `<p class="pct">已读 ${pct}%</p>` : ''}</div>`;
    }).join('')}</div>`;
  }
  $('library').innerHTML = `
    <div class="lib-head"><div><h1 class="lib-title">书架</h1><div class="lib-count">${library.length} 本书</div></div>
      <button class="btn ${manage ? 'on' : 'plain'}" id="btnManage">${manage ? '完成' : '管理'}</button></div>
    <div class="lib-actions">
      <button class="btn solid" id="btnImport">${ic('upload')} 传 TXT</button>
      <button class="btn" id="btnWrite">${ic('pencil')} 写书</button>
      <button class="btn" id="btnBackup">${ic('box')} 备份</button>
    </div>
    <label class="search">${ic('search')}<input id="searchInput" type="search" placeholder="搜索书名或作者" value="${esc(query)}"></label>
    ${banner}${body}`;
}
$('library').addEventListener('click', (e) => {
  const t = e.target;
  const edit = t.closest('[data-edit]'), del = t.closest('[data-del]'), open = t.closest('[data-open]');
  if (edit) return openBookForm({ editing: bookById(edit.dataset.edit) });
  if (del) {
    const b = bookById(del.dataset.del);
    return confirmDialog('删除这本书?', `《${b.title}》和它的书签、笔记都会被删除,不能恢复。`, '删除', async () => {
      await dbDelete(b.id); delete progress[b.id]; saveProgressMap();
      library = library.filter((x) => x.id !== b.id); renderLibrary(); toast('已删除');
    });
  }
  if (open) { if (!manage) openBook(open.dataset.open); return; }
  if (t.closest('#btnImport')) return $('txtInput').click();
  if (t.closest('#btnWrite')) return openBookForm({ draft: { chapters: [{ id: uid(), title: '第一章', content: '' }] } });
  if (t.closest('#btnBackup')) return openBackup();
  if (t.closest('#btnManage')) { manage = !manage; renderLibrary(); }
});
$('library').addEventListener('input', (e) => {
  if (e.target.id === 'searchInput') {
    query = e.target.value;
    const pos = e.target.selectionStart;
    renderLibrary();
    const el = $('searchInput'); el.focus(); el.setSelectionRange(pos, pos);
  }
});
$('txtInput').addEventListener('change', async (e) => {
  const files = [...e.target.files];
  e.target.value = '';
  if (!files.length) return;
  const books = [], failures = [];
  toast('正在导入…');
  for (const f of files) {
    try { books.push(await bookFromFile(f)); } catch (err) { failures.push(`${f.name}:${err.message}`); }
  }
  if (books.length === 1 && !failures.length) return openBookForm({ draft: books[0] });
  for (const b of books) { await dbPut(b); library.push(b); }
  renderLibrary();
  toast(failures.length ? `导入失败 ${failures[0]}${failures.length > 1 ? ` 等 ${failures.length} 个文件` : ''}` : `已导入 ${books.length} 本书`);
});

// ───────── 书籍表单 ─────────
function openBookForm({ editing = null, draft = null }) {
  const data = editing
    ? { title: editing.title, author: editing.author, desc: editing.desc || '', cover: editing.cover }
    : { title: draft.title || '', author: draft.author || '', desc: draft.desc || '', cover: draft.cover || null };
  const previewId = editing ? editing.id : (draft?.id || uid());
  const s = openSheet(`
    <div class="sheet-head"><button data-x="cancel">取消</button><h2>${editing ? '编辑书籍信息' : '新书信息'}</h2><button data-x="save">保存</button></div>
    <div class="sheet-body">
      <div class="form-cover"><div id="fcPreview"></div>
        <div class="col"><button class="btn" data-x="pick">选择封面图片</button><button class="btn" data-x="reset" id="fcReset">恢复默认封面</button></div></div>
      <label class="lab"><span>书名</span><input class="field" id="fTitle" value="${esc(data.title)}" placeholder="必填"></label>
      <label class="lab"><span>作者</span><input class="field" id="fAuthor" value="${esc(data.author)}" placeholder="不填就是“佚名”"></label>
      <label class="lab"><span>简介</span><textarea class="field" id="fDesc" placeholder="不填就是“暂无简介”">${esc(data.desc)}</textarea></label>
      <input type="file" accept="image/*" id="fCover" hidden>
    </div>`, { tall: true });
  const el = s.el;
  const refresh = () => {
    const title = el.querySelector('#fTitle').value.trim(), author = el.querySelector('#fAuthor').value.trim() || '佚名';
    el.querySelector('#fcPreview').innerHTML = coverHTML({ id: previewId, title: title || '书', author, cover: data.cover });
    el.querySelector('#fcReset').hidden = !data.cover;
  };
  refresh();
  el.addEventListener('input', refresh);
  el.querySelector('#fCover').addEventListener('change', async (e) => {
    const f = e.target.files[0]; e.target.value = '';
    if (!f) return;
    if (f.size > 5 * 1024 * 1024) return toast('图片不能超过 5MB');
    try { data.cover = await resizeCover(f); refresh(); } catch (err) { toast(err.message); }
  });
  el.addEventListener('click', async (e) => {
    const x = e.target.closest('[data-x]')?.dataset.x;
    if (x === 'cancel') s.close();
    else if (x === 'pick') el.querySelector('#fCover').click();
    else if (x === 'reset') { data.cover = null; refresh(); }
    else if (x === 'save') {
      const title = el.querySelector('#fTitle').value.trim();
      if (!title) return toast('请填写书名');
      const author = el.querySelector('#fAuthor').value.trim() || '佚名';
      const desc = el.querySelector('#fDesc').value.trim() || '暂无简介';
      if (editing) {
        Object.assign(editing, { title, author, desc, cover: data.cover });
        await dbPut(editing); toast('已保存');
      } else {
        const book = { id: previewId, title, author, desc, cover: data.cover, chapters: draft.chapters,
          createTime: Date.now(), bookmarks: [], notes: [] };
        await dbPut(book); library.push(book); toast('已加入书架');
      }
      s.close(); renderLibrary();
    }
  });
}

// ───────── 阅读页 ─────────
let cur = null;           // 当前书
let ci = 0;               // 当前章节序号
let editing = false;
let barsHidden = false;
const scroller = () => $('scroller');
const paragraphsOf = (content) => String(content || '').split(/\r?\n/).map((l) => l.replace(/^[\s　]+|[\s　]+$/g, '')).filter(Boolean);
const excerptOf = (t) => { const s = String(t).trim(); return s.length > 40 ? s.slice(0, 40) + '…' : s; };
function dialogueHTML(text) {
  const safe = esc(text);
  return settings.dialogue ? safe.replace(/(“[^”]+”|「[^」]+」)/g, '<span class="dlg">$1</span>') : safe;
}

function openBook(id, chapterIndex, block) {
  const book = bookById(id);
  if (!book) return;
  cur = book;
  const p = progress[id] || {};
  ci = Math.min(Math.max(chapterIndex ?? p.c ?? 0, 0), book.chapters.length - 1);
  const startBlock = block ?? (chapterIndex === undefined ? (p.b || 0) : 0);
  setProgress(id, { c: ci, t: Date.now() });
  $('library').hidden = true;
  const r = $('reader');
  r.hidden = false;
  r.innerHTML = `
    <div id="scroller"><article id="article"></article></div>
    <textarea id="editor" hidden spellcheck="false"></textarea>
    <header class="rbar top" id="topBar">
      <button class="ic" data-r="back" aria-label="返回书架">${ic('chevL')}</button>
      <div class="ttlbox"><b id="rbTitle"></b><small id="rbIdx"></small></div>
      <button class="tx" data-r="edit" id="editBtn">编辑</button>
      <button class="ic" data-r="more" aria-label="更多">${ic('more', 'style="stroke-width:3.4"')}</button>
    </header>
    <nav class="rbar bottom" id="botBar">
      <button data-r="prev" id="bPrev">${ic('prev')}上一章</button>
      <button data-r="catalog">${ic('list')}目录</button>
      <button data-r="settings">${ic('aa')}设置</button>
      <button data-r="next" id="bNext">${ic('next')}下一章</button>
    </nav>`;
  barsHidden = false; editing = false;
  applySettings();
  renderChapter(startBlock);
}
function renderChapter(startBlock = 0) {
  const ch = cur.chapters[ci];
  const paras = paragraphsOf(ch.content);
  const bm = new Set(cur.bookmarks.filter((b) => b.chapterID === ch.id).map((b) => b.blockIndex));
  const nt = new Set(cur.notes.filter((n) => n.chapterID === ch.id).map((n) => n.blockIndex));
  $('article').innerHTML = `<h2 class="ttl" data-b="0">${esc(ch.title)}</h2>` +
    paras.map((p, i) => `<p data-b="${i + 1}" class="${bm.has(i + 1) ? 'bm ' : ''}${nt.has(i + 1) ? 'nt' : ''}">${dialogueHTML(p)}</p>`).join('') +
    `<div class="rfoot"><button class="btn" data-r="prev" ${ci === 0 ? 'disabled' : ''}>上一章</button>
     <button class="btn" data-r="next" ${ci === cur.chapters.length - 1 ? 'disabled' : ''}>下一章</button></div>`;
  $('rbTitle').textContent = cur.title;
  $('rbIdx').textContent = `第 ${ci + 1} / ${cur.chapters.length} 章`;
  $('bPrev').disabled = ci === 0;
  $('bNext').disabled = ci === cur.chapters.length - 1;
  const sc = scroller();
  sc.scrollTop = 0;
  if (startBlock > 0) {
    const el = $('article').querySelector(`[data-b="${Math.min(startBlock, paras.length)}"]`);
    if (el) sc.scrollTop = Math.max(el.offsetTop - 70, 0);
  }
  setProgress(cur.id, { c: ci, b: startBlock, t: Date.now() });
}
function currentBlock() {
  const sc = scroller();
  const top = sc.scrollTop + 70;
  let found = 0;
  for (const el of $('article').querySelectorAll('[data-b]')) {
    if (el.offsetTop <= top) found = Number(el.dataset.b); else break;
  }
  return found;
}
let scrollTimer;
function onScroll() {
  clearTimeout(scrollTimer);
  scrollTimer = setTimeout(() => {
    if (!cur || editing || $('reader').hidden) return;
    setProgress(cur.id, { c: ci, b: currentBlock(), t: Date.now() });
  }, 250);
}
function setBars(hidden) {
  barsHidden = hidden;
  $('topBar')?.classList.toggle('hide', hidden);
  $('botBar')?.classList.toggle('hide', hidden);
  $('readerMenu')?.remove();
}
function commitEdit(announce) {
  if (!editing) return;
  const text = $('editor').value;
  cur.chapters[ci].content = paragraphsOf(text).join('\n');
  editing = false;
  $('editor').hidden = true; scroller().hidden = false;
  $('editBtn').textContent = '编辑';
  dbPut(cur);
  const keep = progress[cur.id]?.b || 0;
  renderChapter(keep);
  if (announce) toast('内容已保存');
}
function goChapter(index, block = 0) {
  commitEdit();
  index = Math.min(Math.max(index, 0), cur.chapters.length - 1);
  ci = index;
  renderChapter(block);
}
function closeReader() {
  commitEdit();
  if (cur) setProgress(cur.id, { c: ci, b: editing ? 0 : currentBlock(), t: Date.now() });
  cur = null;
  $('reader').hidden = true; $('reader').innerHTML = '';
  $('library').hidden = false;
  renderLibrary();
}
function showMoreMenu() {
  if ($('readerMenu')) return $('readerMenu').remove();
  const m = document.createElement('div');
  m.className = 'menu'; m.id = 'readerMenu';
  m.innerHTML = `<button data-r="addbm">在这里加书签${ic('bookmark')}</button><button data-r="addnote">在这里写笔记${ic('note')}</button>`;
  $('reader').appendChild(m);
}
function blockInfo(b) {
  const paras = paragraphsOf(cur.chapters[ci].content);
  const block = Math.min(Math.max(b, 0), paras.length);
  return { block, excerpt: block === 0 ? excerptOf(cur.chapters[ci].title) : excerptOf(paras[block - 1]) };
}
async function addBookmark() {
  const { block, excerpt } = blockInfo(currentBlock());
  const chapterID = cur.chapters[ci].id;
  if (cur.bookmarks.some((b) => b.chapterID === chapterID && b.blockIndex === block)) return toast('这里已经有书签了');
  cur.bookmarks.push({ id: uid(), chapterID, blockIndex: block, excerpt, createdAt: Date.now() });
  await dbPut(cur); renderChapter(block); toast('已加书签');
}
function addNote() {
  const { block, excerpt } = blockInfo(currentBlock());
  const s = openSheet(`
    <div class="sheet-head"><button data-x="cancel">取消</button><h2>写笔记</h2><button data-x="save">保存</button></div>
    <div class="sheet-body">${excerpt ? `<div class="quote">${esc(excerpt)}</div>` : ''}
    <textarea class="field" id="noteText" style="min-height:140px" placeholder="写下你的想法"></textarea></div>`);
  setTimeout(() => s.el.querySelector('#noteText').focus(), 60);
  s.el.addEventListener('click', async (e) => {
    const x = e.target.closest('[data-x]')?.dataset.x;
    if (x === 'cancel') s.close();
    if (x === 'save') {
      const text = s.el.querySelector('#noteText').value.trim();
      if (!text) return toast('笔记内容不能为空');
      cur.notes.push({ id: uid(), chapterID: cur.chapters[ci].id, blockIndex: block, quote: excerpt, text, createdAt: Date.now() });
      await dbPut(cur); s.close(); renderChapter(block); toast('笔记已保存');
    }
  });
}

$('reader').addEventListener('scroll', onScroll, true);
$('reader').addEventListener('click', (e) => {
  const r = e.target.closest('[data-r]')?.dataset.r;
  if (!r) {
    if ($('readerMenu')) return $('readerMenu').remove();
    if (!editing && e.target.closest('#scroller') && !getSelection()?.toString()) setBars(!barsHidden);
    return;
  }
  $('readerMenu')?.remove();
  switch (r) {
    case 'back': closeReader(); break;
    case 'edit':
      if (editing) commitEdit(true);
      else {
        $('editor').value = paragraphsOf(cur.chapters[ci].content).join('\n\n');
        editing = true; $('editor').hidden = false; scroller().hidden = true;
        $('editBtn').textContent = '保存'; setBars(false); toast('已开启编辑');
      }
      break;
    case 'more': if (!editing) showMoreMenu(); break;
    case 'prev': ci > 0 ? goChapter(ci - 1) : toast('已经是第一章了'); break;
    case 'next': ci < cur.chapters.length - 1 ? goChapter(ci + 1) : toast('已经是最后一章了'); break;
    case 'catalog': commitEdit(); openCatalog(); break;
    case 'settings': openSettings(); break;
    case 'addbm': addBookmark(); break;
    case 'addnote': addNote(); break;
  }
});

// ───────── 目录 / 书签 / 笔记 ─────────
function openCatalog() {
  let tab = 'chapters', catEdit = false, asc = true, q = '';
  const s = openSheet('', { tall: true });
  const root = s.el;
  const jump = (c, b) => { s.close(); goChapter(c, b); };
  const draw = () => {
    const book = cur;
    const head = `<div class="sheet-head"><button data-x="close">关闭</button><h2>目录</h2>
      <button data-x="edit" style="visibility:${tab === 'chapters' ? 'visible' : 'hidden'}">${catEdit ? '完成' : '编辑'}</button></div>
      <div class="cat-head">${coverHTML(book)}<div><b>${esc(book.title)}</b><span class="muted" style="font-size:13px">${esc(book.author)} · 共 ${book.chapters.length} 章</span></div></div>
      <div class="tabs seg">${[['chapters', '章节'], ['bookmarks', '书签'], ['notes', '笔记']].map(([k, n]) => `<button data-tab="${k}" class="${tab === k ? 'on' : ''}">${n}</button>`).join('')}</div>`;
    let body = '';
    if (tab === 'chapters') {
      let idx = book.chapters.map((_, i) => i);
      if (!asc) idx.reverse();
      if (q.trim()) idx = idx.filter((i) => book.chapters[i].title.toLowerCase().includes(q.trim().toLowerCase()));
      body = `<div class="tools"><input class="field" id="catQ" type="search" placeholder="搜索章节" value="${esc(q)}"><button class="btn plain" data-x="sort">${asc ? '正序' : '倒序'}</button></div>
        <div class="list">${idx.length ? idx.map((i) => `
          <div class="item ${i === ci ? 'cur' : ''}"><button class="main" data-jump="${i}"><div class="t">${esc(book.chapters[i].title)}</div></button>
          ${i === ci && !catEdit ? `<span class="ch">${ic('check')}</span>` : ''}
          ${catEdit ? `<div class="ops"><button class="op add" data-op="ins" data-i="${i}" aria-label="在后面插入新章">${ic('plus')}</button>
            <button class="op" data-op="up" data-i="${i}" aria-label="上移">${ic('up')}</button><button class="op" data-op="down" data-i="${i}" aria-label="下移">${ic('down')}</button>
            <button class="op" data-op="ren" data-i="${i}" aria-label="改名">${ic('pencil')}</button><button class="op del" data-op="del" data-i="${i}" aria-label="删除">${ic('x')}</button></div>` : ''}</div>`).join('')
          : '<div class="item muted">没有找到匹配的章节</div>'}</div>
        ${catEdit ? `<button class="row-btn" data-op="add">${ic('plus')} 添加新章节到末尾</button>` : ''}`;
    } else if (tab === 'bookmarks') {
      const items = [...book.bookmarks].sort((a, b) => b.createdAt - a.createdAt);
      body = items.length ? `<div class="list">${items.map((m) => {
        const c = book.chapters.findIndex((x) => x.id === m.chapterID);
        return c < 0 ? '' : `<div class="item"><button class="main" data-jump="${c}" data-block="${m.blockIndex}">
          <div class="ch">${esc(book.chapters[c].title)}</div><div class="q" style="font-size:15px;color:var(--ink)">${esc(m.excerpt)}</div></button>
          <button class="op del" data-rmbm="${m.id}" aria-label="删除书签">${ic('x')}</button></div>`;
      }).join('')}</div>` : '<p class="muted">还没有书签。在阅读页点右上角“⋯”,选“在这里加书签”。</p>';
    } else {
      const items = [...book.notes].sort((a, b) => b.createdAt - a.createdAt);
      body = items.length ? `<div class="list">${items.map((n) => {
        const c = book.chapters.findIndex((x) => x.id === n.chapterID);
        return c < 0 ? '' : `<div class="item"><button class="main" data-jump="${c}" data-block="${n.blockIndex}">
          <div class="ch">${esc(book.chapters[c].title)}</div><div>${esc(n.text)}</div>${n.quote ? `<div class="q">${esc(n.quote)}</div>` : ''}</button>
          <button class="op del" data-rmnote="${n.id}" aria-label="删除笔记">${ic('x')}</button></div>`;
      }).join('')}</div>` : '<p class="muted">还没有笔记。在阅读页点右上角“⋯”,选“在这里写笔记”。</p>';
    }
    const keepQ = document.activeElement?.id === 'catQ';
    root.innerHTML = head + `<div class="sheet-body">${body}</div>`;
    if (keepQ) { const el = root.querySelector('#catQ'); el.focus(); el.setSelectionRange(q.length, q.length); }
  };
  draw();
  root.addEventListener('input', (e) => { if (e.target.id === 'catQ') { q = e.target.value; draw(); } });
  root.addEventListener('click', async (e) => {
    const t = e.target;
    const tabBtn = t.closest('[data-tab]'); if (tabBtn) { tab = tabBtn.dataset.tab; if (tab !== 'chapters') catEdit = false; return draw(); }
    const x = t.closest('[data-x]')?.dataset.x;
    if (x === 'close') return s.close();
    if (x === 'edit') { catEdit = !catEdit; return draw(); }
    if (x === 'sort') { asc = !asc; return draw(); }
    const j = t.closest('[data-jump]');
    if (j) { if (catEdit) return; return jump(Number(j.dataset.jump), Number(j.dataset.block || 0)); }
    const rb = t.closest('[data-rmbm]'); if (rb) { cur.bookmarks = cur.bookmarks.filter((m) => m.id !== rb.dataset.rmbm); await dbPut(cur); return draw(); }
    const rn = t.closest('[data-rmnote]'); if (rn) { cur.notes = cur.notes.filter((m) => m.id !== rn.dataset.rmnote); await dbPut(cur); return draw(); }
    const op = t.closest('[data-op]'); if (!op) return;
    const i = Number(op.dataset.i);
    const after = async () => { await dbPut(cur); renderChapter(progress[cur.id]?.b || 0); draw(); };
    switch (op.dataset.op) {
      case 'add': return promptDialog('添加新章节', '新章节', (v) => {
        if (!v.trim()) { toast('章节名不能为空'); return false; }
        cur.chapters.push({ id: uid(), title: v.trim(), content: '' }); after(); toast('已添加');
      });
      case 'ins': return promptDialog('插入新章节', '新章节', (v) => {
        if (!v.trim()) { toast('章节名不能为空'); return false; }
        cur.chapters.splice(i + 1, 0, { id: uid(), title: v.trim(), content: '' });
        if (i + 1 <= ci) ci += 1;
        after(); toast('已插入');
      });
      case 'ren': return promptDialog('修改章节名', cur.chapters[i].title, (v) => {
        if (!v.trim()) { toast('章节名不能为空'); return false; }
        cur.chapters[i].title = v.trim(); after(); toast('已改名');
      });
      case 'up': case 'down': {
        const to = i + (op.dataset.op === 'up' ? -1 : 1);
        if (to < 0 || to >= cur.chapters.length) return toast(to < 0 ? '已经在最前面了' : '已经在最后面了');
        const [c] = cur.chapters.splice(i, 1); cur.chapters.splice(to, 0, c);
        if (ci === i) ci = to; else if (i < to && ci > i && ci <= to) ci -= 1; else if (i > to && ci >= to && ci < i) ci += 1;
        return after();
      }
      case 'del': {
        if (cur.chapters.length <= 1) return toast('至少要保留一章');
        return confirmDialog('删除这一章?', '这一章的正文、书签和笔记都会被删除,不能恢复。', '删除', () => {
          const [gone] = cur.chapters.splice(i, 1);
          cur.bookmarks = cur.bookmarks.filter((m) => m.chapterID !== gone.id);
          cur.notes = cur.notes.filter((m) => m.chapterID !== gone.id);
          if (ci >= cur.chapters.length) ci = cur.chapters.length - 1; else if (i < ci) ci -= 1;
          setProgress(cur.id, { b: 0 });
          after(); toast('已删除');
        });
      }
    }
  });
}

// ───────── 阅读设置 ─────────
function openSettings() {
  const s = openSheet('');
  const draw = () => {
    const slider = (key, label, step, fmt) => `<div class="setting"><div class="top"><span>${label}</span><span>${fmt(settings[key])}</span></div>
      <input type="range" data-k="${key}" min="${RANGES[key][0]}" max="${RANGES[key][1]}" step="${step}" value="${settings[key]}"></div>`;
    const swatches = (key, list) => `<div class="swatches">${list.map((c) => `<button class="swatch ${settings[key] === c ? 'on' : ''}" data-color="${key}" data-v="${c}" style="background:${c}" aria-label="${c}"></button>`).join('')}</div>`;
    s.el.innerHTML = `<div class="sheet-head"><button data-x="reset" style="color:var(--danger)">恢复默认</button><h2>阅读设置</h2><button data-x="close">完成</button></div>
      <div class="sheet-body">
        <div class="group"><h4>主题</h4><div class="seg">${[['system', '跟随系统'], ['paper', '默认'], ['eye', '护眼'], ['night', '夜间']].map(([k, n]) => `<button data-theme="${k}" class="${settings.theme === k ? 'on' : ''}">${n}</button>`).join('')}</div></div>
        <div class="group"><h4>文字</h4><div class="panel">
          ${slider('fontSize', '字号', 1, (v) => v)}
          <div class="setting"><div class="top"><span>加粗</span><input type="checkbox" class="switch" data-bold ${settings.bold ? 'checked' : ''}></div></div>
          <div class="setting"><div class="top"><span>字体颜色</span>${swatches('textColor', TEXT_COLORS)}</div></div></div></div>
        <div class="group"><h4>排版</h4><div class="panel">
          ${slider('lineHeight', '行距', 0.1, (v) => v.toFixed(1))}${slider('letterSpacing', '字距', 0.5, (v) => v.toFixed(1))}
          ${slider('paraGap', '段距', 0.1, (v) => v.toFixed(1))}${slider('padX', '左右边距', 1, (v) => v)}${slider('padY', '上下边距', 1, (v) => v)}</div></div>
        <div class="group"><h4>对话</h4><div class="panel">
          <div class="setting"><div class="top"><span>对话染色</span><input type="checkbox" class="switch" data-dlg ${settings.dialogue ? 'checked' : ''}></div></div>
          ${settings.dialogue ? `<div class="setting"><div class="top"><span>对话颜色</span>${swatches('dialogueColor', DIALOGUE_COLORS)}</div></div>` : ''}</div></div>
      </div>`;
  };
  draw();
  const refreshText = () => { applySettings(); if (cur && !editing) { const b = currentBlock(); renderChapter(b); } };
  s.el.addEventListener('input', (e) => {
    const k = e.target.dataset.k;
    if (k) {
      settings[k] = Number(e.target.value); applySettings();
      e.target.closest('.setting').querySelector('.top span:last-child').textContent =
        ['lineHeight', 'letterSpacing', 'paraGap'].includes(k) ? settings[k].toFixed(1) : settings[k];
    }
  });
  s.el.addEventListener('change', (e) => {
    if (e.target.dataset.bold !== undefined) { settings.bold = e.target.checked; applySettings(); }
    if (e.target.dataset.dlg !== undefined) { settings.dialogue = e.target.checked; refreshText(); draw(); }
  });
  s.el.addEventListener('click', (e) => {
    const t = e.target;
    const th = t.closest('[data-theme]'); if (th) { settings.theme = th.dataset.theme; applySettings(); return draw(); }
    const c = t.closest('[data-color]');
    if (c) { settings[c.dataset.color] = c.dataset.v; applySettings(); return draw(); }
    const x = t.closest('[data-x]')?.dataset.x;
    if (x === 'close') { s.close(); refreshText(); }
    if (x === 'reset') { settings = { ...DEFAULTS }; refreshText(); draw(); toast('已恢复默认设置'); }
  });
}

// ───────── 备份与恢复(和旧版网页“阅书”的备份文件互通) ─────────
function buildBackup(books) {
  return JSON.stringify({
    app: 'YueShu', version: 2, exportTime: new Date().toISOString(),
    books: books.map((b) => ({
      id: b.id, title: b.title, author: b.author, desc: b.desc,
      chapters: b.chapters.map((c) => ({ id: c.id, title: c.title, content: c.content })),
      createTime: b.createTime, lastChapterIndex: progress[b.id]?.c || 0, lastReadTime: progress[b.id]?.t || 0,
      lastBlock: progress[b.id]?.b || 0, coverBase64: b.cover || null, bookmarks: b.bookmarks, notes: b.notes,
    })),
  });
}
function parseBackup(text) {
  let data;
  try { data = JSON.parse(text); } catch { return null; }
  if (!data || !Array.isArray(data.books)) return null;
  const books = [], prog = {};
  for (const it of data.books) {
    const chapters = (Array.isArray(it.chapters) && it.chapters.length ? it.chapters : [{ title: '第一章', content: '' }])
      .map((c) => ({ id: c.id || uid(), title: c.title || '未命名章节', content: c.content || '' }));
    const ids = new Set(chapters.map((c) => c.id));
    const book = { id: String(it.id || uid()), title: it.title || '未命名', author: it.author || '佚名', desc: it.desc || '',
      cover: typeof it.coverBase64 === 'string' && it.coverBase64.startsWith('data:') ? it.coverBase64 : null,
      chapters, createTime: Number(it.createTime) || Date.now(),
      bookmarks: (it.bookmarks || []).filter((m) => ids.has(m.chapterID)),
      notes: (it.notes || []).filter((m) => ids.has(m.chapterID)) };
    books.push(book);
    if (Number(it.lastReadTime) > 0) {
      prog[book.id] = { c: Math.min(Math.max(Number(it.lastChapterIndex) || 0, 0), chapters.length - 1), b: Number(it.lastBlock) || 0, t: Number(it.lastReadTime) };
    }
  }
  return { books, prog };
}
async function restore({ books, prog }) {
  await dbClear();
  for (const b of books) await dbPut(b);
  library = books; progress = prog; saveProgressMap();
  renderLibrary();
}
function openBackup() {
  const selected = new Set(library.map((b) => b.id));
  const s = openSheet('', { tall: true });
  const draw = () => {
    s.el.innerHTML = `<div class="sheet-head"><span></span><h2>备份与恢复</h2><button data-x="close">完成</button></div>
      <div class="sheet-body">
        <div class="group"><h4>选择要备份的书(已选 ${selected.size} 本) <button data-x="all" class="link">全选</button><button data-x="none" class="link">全不选</button></h4>
          <div class="list">${library.map((b) => `<button class="item" data-sel="${b.id}"><span class="chk ${selected.has(b.id) ? 'on' : ''}">${chk(selected.has(b.id))}</span>
            <span class="main"><div class="t">${esc(b.title)}</div><div class="s">${esc(b.author)} · ${b.chapters.length} 章</div></span></button>`).join('') || '<div class="item muted">书架是空的</div>'}</div></div>
        <div class="group"><h4>备份</h4><div class="list">
          <button class="item" data-x="export"><span class="main t">导出为文件</span></button>
          <button class="item" data-x="copy"><span class="main t">复制到剪贴板</span></button></div></div>
        <div class="group"><h4>恢复</h4><div class="list">
          <button class="item" data-x="file"><span class="main t">从文件导入</span></button>
          <button class="item" data-x="paste"><span class="main t">从剪贴板导入</span></button></div>
          <div class="foot-note">导入会覆盖当前所有的书。旧版网页“阅书”导出的备份可以直接导入。</div></div>
        <input type="file" id="bkFile" accept=".json,application/json,text/plain" hidden>
      </div>`;
  };
  draw();
  const payload = () => {
    const books = library.filter((b) => selected.has(b.id));
    if (!books.length) { toast('请先勾选要备份的书'); return null; }
    return buildBackup(books);
  };
  const ask = (text) => {
    const parsed = parseBackup(text);
    if (!parsed) return toast('解析失败:不是有效的备份数据');
    if (!parsed.books.length) return toast('备份里没有书');
    confirmDialog('覆盖当前所有书?', `将导入 ${parsed.books.length} 本书,当前书架上的书会被替换。`, '导入', async () => {
      await restore(parsed); s.close(); toast(`导入成功,共 ${parsed.books.length} 本`);
    });
  };
  s.el.addEventListener('change', async (e) => {
    if (e.target.id !== 'bkFile') return;
    const f = e.target.files[0]; e.target.value = '';
    if (f) ask(await f.text());
  });
  s.el.addEventListener('click', async (e) => {
    const sel = e.target.closest('[data-sel]');
    if (sel) { const id = sel.dataset.sel; selected.has(id) ? selected.delete(id) : selected.add(id); return draw(); }
    const x = e.target.closest('[data-x]')?.dataset.x;
    if (x === 'close') s.close();
    else if (x === 'all') { library.forEach((b) => selected.add(b.id)); draw(); }
    else if (x === 'none') { selected.clear(); draw(); }
    else if (x === 'export') {
      const data = payload(); if (!data) return;
      const file = new File([data], '阅书备份.json', { type: 'application/json' });
      if (navigator.canShare?.({ files: [file] })) {
        try { await navigator.share({ files: [file] }); return; } catch (err) { if (err.name === 'AbortError') return; }
      }
      const a = document.createElement('a');
      a.href = URL.createObjectURL(file); a.download = file.name; document.body.appendChild(a); a.click(); a.remove();
      toast('已导出备份');
    } else if (x === 'copy') {
      const data = payload(); if (!data) return;
      try { await navigator.clipboard.writeText(data); toast('已复制到剪贴板'); } catch { toast('复制失败,请改用“导出为文件”'); }
    } else if (x === 'file') s.el.querySelector('#bkFile').click();
    else if (x === 'paste') {
      try {
        const text = await navigator.clipboard.readText();
        if (!text) return toast('剪贴板里没有内容');
        ask(text);
      } catch {
        promptDialog('粘贴备份内容', '', (v) => { if (!v.trim()) { toast('请先粘贴内容'); return false; } ask(v); }, { multiline: true, placeholder: '把备份内容粘贴到这里' });
      }
    }
  });
}

// ───────── 示例书与启动 ─────────
function sampleBooks() {
  const mk = (title, author, desc, chapters) => ({ id: uid(), title, author, desc, cover: null,
    chapters: chapters.map(([t, c]) => ({ id: uid(), title: t, content: c.trim().split('\n').map((l) => l.trim()).filter(Boolean).join('\n') })),
    createTime: Date.now(), bookmarks: [], notes: [] });
  return [
    mk('使用说明', '阅书', '几分钟看懂这个书房怎么用。', [
      ['第一章 欢迎来到书房', `这是一个只属于你的本地书房。书都保存在这台设备上,不需要联网。
        书架按最近阅读排序,刚读过的书永远在最前面。点一本书就能接着读,会回到你上次停下的那一行。
        点书架右上角的“管理”,可以修改书籍信息、换封面、删除不想要的书。`],
      ['第二章 导入与写作', `点“传 TXT”从文件里选一个 txt 小说。阅读器会自动识别 UTF-8、UTF-16 和 GBK 编码,并按“第几章”自动分章。
        点“写书”可以从一页空白开始,自己写一本书。进入阅读页后点右上角的“编辑”,就能直接修改正文;写完点“保存”。
        “对话会自动染色。”她说,“在阅读设置里可以换颜色,也可以关掉。”`],
      ['第三章 阅读时的小动作', `轻点屏幕中间,会呼出上下菜单:上一章、目录、设置、下一章。再点一下就收起来。
        读到章节末尾,正文下面有“上一章”“下一章”两个按钮。
        右上角的“⋯”可以在当前位置加一个书签,或者写一条笔记。它们都收在“目录”里,点一下就能跳回去。`],
      ['第四章 备份与安装', `书架上的“备份”可以把选中的书导出成文件,或者复制到剪贴板。换了设备,从同一个地方导入就能恢复。
        在 iPhone 或 iPad 的 Safari 里点“分享”,选“添加到主屏幕”,它就会像 App 一样全屏打开,没有网络也能用。
        浏览器的数据只存在这台设备上,清除网站数据会丢书,重要的书记得备份。`],
    ]),
    mk('雪夜来信', '示例作品', '一封迟到了四十年的信,和一间快要拆掉的书店。', [
      ['第一章 邮差', `入冬以后的第一场雪,下在一个星期四的傍晚。
        老邮差把自行车靠在院墙边,抖了抖肩上的雪,从帆布包最底下抽出一封信。信封很旧,边角被压得发软,收信人那一栏只写了三个字:林晚秋。
        “这是今年第三次了。”他自言自语,“明明没有这个人。”`],
      ['第二章 旧址', `第二天一早,他顺着信封上模糊的邮戳,找到了城西那条快要拆掉的巷子。
        巷尾有一间没有招牌的书店,门虚掩着,里面亮着一盏很小的灯。一个年轻人正蹲在地上整理纸箱,听见脚步声抬起头来。
        “您找谁?”
        “林晚秋。”
        年轻人愣了一下,慢慢站起来:“那是我外婆。”`],
      ['第三章 回信', `信是四十年前寄出的,中途不知被谁压在了一个分拣箱的夹层里。
        年轻人把信读了两遍,什么也没说,只是从柜台下面拿出一沓同样泛黄的信封,每一封的收信人都是同一个名字。
        窗外的雪还在下。邮差喝完了那杯热茶,把空杯子轻轻放回桌上,说:“那这封,就算送到了。”`],
    ]),
  ];
}

async function init() {
  applySettings();
  try {
    library = await dbAll();
    if (!library.length && !localStorage.getItem('yueshu.seeded')) {
      library = sampleBooks();
      for (const b of library) await dbPut(b);
      localStorage.setItem('yueshu.seeded', '1');
    }
  } catch (err) {
    toast('无法读取书架:' + err.message);
  }
  renderLibrary();
  navigator.storage?.persist?.().catch(() => {});
  if ('serviceWorker' in navigator && location.protocol.startsWith('http')) {
    navigator.serviceWorker.register('sw.js').catch(() => {});
  }
}
$('enterBtn').addEventListener('click', () => {
  const w = $('welcome');
  w.classList.add('leave');
  setTimeout(() => w.remove(), 650);
});
init();
