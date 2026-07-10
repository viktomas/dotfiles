(function () {
  'use strict';

  // A note is { quote, note, el }, keyed by a numeric id. Each highlight may be
  // several <mark> elements (one per text node) sharing that id via data-ann-id.
  const notes = new Map();
  let nextId = 1;
  let pendingRange = null;

  const addBtn = document.getElementById('ann-add');
  const exportBtn = document.getElementById('ann-export');

  const marksOf = (id) => document.querySelectorAll(`mark.ann[data-ann-id="${id}"]`);
  const inIgnored = (node) =>
    (node.nodeType === 3 ? node.parentElement : node)
      .closest('#ann-add,#ann-export,.ann-note,figure.diagram,pre');

  function updateCount() {
    exportBtn.dataset.count = notes.size;
  }

  function setActive(id, on) {
    marksOf(id).forEach((m) => m.classList.toggle('ann-active', on));
  }

  // ── highlighting ──────────────────────────────────────────────────────────

  // Wrap each text node touched by the range in its own <mark>, so highlighting
  // works across element/block boundaries without nesting blocks inside a mark.
  function wrapRange(range, id) {
    const root = range.commonAncestorContainer;
    const walker = document.createTreeWalker(
      root.nodeType === 3 ? root.parentNode : root,
      NodeFilter.SHOW_TEXT,
    );
    const targets = [];
    for (let n = walker.nextNode(); n; n = walker.nextNode()) {
      if (range.intersectsNode(n) && n.textContent.trim()) targets.push(n);
    }

    let wrapped = false;
    for (const textNode of targets) {
      const start = textNode === range.startContainer ? range.startOffset : 0;
      const end = textNode === range.endContainer ? range.endOffset : textNode.length;
      if (start >= end) continue;

      let node = start > 0 ? textNode.splitText(start) : textNode;
      if (end - start < node.length) node.splitText(end - start);

      const mark = document.createElement('mark');
      mark.className = 'ann';
      mark.dataset.annId = id;
      node.replaceWith(mark);
      mark.appendChild(node);
      wrapped = true;
    }
    return wrapped;
  }

  function unwrap(id) {
    marksOf(id).forEach((mark) => {
      const parent = mark.parentNode;
      mark.replaceWith(...mark.childNodes);
      parent.normalize();
    });
  }

  // ── margin notes ────────────────────────────────────────────────────────────

  const autosize = (ta) => {
    ta.style.height = 'auto';
    ta.style.height = `${ta.scrollHeight}px`;
  };

  // Position every note in the right margin, aligned to its highlight, stacking
  // downward so cards never overlap.
  function layout() {
    const body = document.body.getBoundingClientRect();
    const left = body.right + window.scrollX + 16;
    const width = Math.max(140, Math.min(240, document.documentElement.clientWidth - body.right - 28));

    const ordered = [...notes.keys()]
      .map((id) => ({ id, top: marksOf(id)[0].getBoundingClientRect().top + window.scrollY }))
      .sort((a, b) => a.top - b.top);

    let bottom = 0;
    for (const { id, top } of ordered) {
      const el = notes.get(id).el;
      el.style.width = `${width}px`;
      el.style.left = `${left}px`;
      el.style.top = `${Math.max(top, bottom)}px`;
      bottom = parseFloat(el.style.top) + el.offsetHeight + 8;
    }
  }

  function addNote(id) {
    const el = document.createElement('div');
    el.className = 'ann-note';
    el.dataset.annId = id;
    el.innerHTML = '<button class="ann-del" title="Delete note">\u00d7</button><textarea placeholder="Note\u2026"></textarea>';

    const ta = el.querySelector('textarea');
    ta.value = notes.get(id).note;
    ta.addEventListener('input', () => {
      notes.get(id).note = ta.value;
      autosize(ta);
      layout();
    });
    ta.addEventListener('focus', () => setActive(id, true));
    ta.addEventListener('blur', () => setActive(id, false));
    el.querySelector('.ann-del').addEventListener('click', () => removeNote(id));

    document.body.appendChild(el);
    notes.get(id).el = el;
    autosize(ta);
    updateCount();
    layout();
    return ta;
  }

  function removeNote(id) {
    unwrap(id);
    notes.get(id).el?.remove();
    notes.delete(id);
    updateCount();
    layout();
  }

  // ── interactions ────────────────────────────────────────────────────────────

  document.addEventListener('mouseup', (e) => {
    if (e.target === addBtn) return;

    const sel = window.getSelection();
    const range = sel && !sel.isCollapsed && sel.rangeCount ? sel.getRangeAt(0) : null;
    if (!range || sel.toString().trim().length < 2 || inIgnored(range.commonAncestorContainer)) {
      addBtn.style.display = 'none';
      return;
    }

    pendingRange = range.cloneRange();
    const rect = range.getBoundingClientRect();
    addBtn.style.display = 'block';
    addBtn.style.left = `${rect.left + window.scrollX}px`;
    addBtn.style.top = `${rect.bottom + window.scrollY + 6}px`;
  });

  addBtn.addEventListener('click', () => {
    addBtn.style.display = 'none';
    if (!pendingRange) return;

    const id = nextId++;
    const quote = pendingRange.toString().trim();
    if (wrapRange(pendingRange, id)) {
      notes.set(id, { quote, note: '', el: null });
      addNote(id).focus();
    }
    window.getSelection().removeAllRanges();
    pendingRange = null;
  });

  document.addEventListener('click', (e) => {
    const mark = e.target.closest?.('mark.ann');
    if (!mark) return;
    const ta = notes.get(Number(mark.dataset.annId)).el.querySelector('textarea');
    ta.focus();
    ta.scrollIntoView({ behavior: 'smooth', block: 'center' });
  });

  window.addEventListener('resize', layout);

  // ── export ────────────────────────────────────────────────────────────────

  const escapeHtml = (s) =>
    s.replace(/[&<>]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;' }[c]));

  exportBtn.addEventListener('click', () => {
    // Walk marks in document order, emitting each note once.
    const seen = new Set();
    const blocks = [];
    for (const mark of document.querySelectorAll('mark.ann')) {
      const id = Number(mark.dataset.annId);
      if (seen.has(id)) continue;
      seen.add(id);
      const { quote, note } = notes.get(id);
      blocks.push(`> ${quote.split('\n').join('\n> ')}\n\n${note.trim() || '_(no comment)_'}\n\n---\n`);
    }
    if (!blocks.length) return;

    const md = blocks.join('\n');
    navigator.clipboard.writeText(md).then(() => {
      const original = exportBtn.textContent;
      exportBtn.textContent = '\u2713 Copied';
      setTimeout(() => { exportBtn.textContent = original; }, 1500);
    }).catch(() => {
      window.open('', '_blank').document.write(`<pre>${escapeHtml(md)}</pre>`);
    });
  });
})();
