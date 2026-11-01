/* ==========================================================================
   UVM · RISC-V Speedrun — progressive enhancement for labs/lab01..15 + index
   The pages are fully readable without this file; it only adds:
   theme toggle · reading progress · sidebar scroll-spy · code copy/highlight ·
   heading anchors · persistent checklists / exercises / completion · shortcuts
   ========================================================================== */
(function () {
  'use strict';

  /* ---------- storage (every access guarded: private mode / blocked storage) ---------- */
  var store = {
    get: function (k) { try { return window.localStorage.getItem('uvmrv:' + k); } catch (e) { return null; } },
    set: function (k, v) { try { window.localStorage.setItem('uvmrv:' + k, v); } catch (e) { /* ignore */ } },
    del: function (k) { try { window.localStorage.removeItem('uvmrv:' + k); } catch (e) { /* ignore */ } }
  };
  var $ = function (s, r) { return (r || document).querySelector(s); };
  var $$ = function (s, r) { return Array.prototype.slice.call((r || document).querySelectorAll(s)); };
  var body = document.body;
  var labNo = parseInt(body.getAttribute('data-lab') || '0', 10);
  var total = parseInt(body.getAttribute('data-total') || '15', 10);
  var root = document.documentElement;

  /* ---------- theme ---------- */
  function currentTheme() {
    var t = root.getAttribute('data-theme');
    if (t) return t;
    return window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
  }
  function applyTheme(t) {
    root.setAttribute('data-theme', t);
    var b = $('#theme-toggle');
    if (b) {
      b.textContent = t === 'dark' ? '☀' : '☾';
      b.setAttribute('aria-label', t === 'dark' ? 'Chuyển sang giao diện sáng' : 'Chuyển sang giao diện tối');
      b.title = b.getAttribute('aria-label');
    }
  }
  (function initTheme() {
    var saved = store.get('theme');
    if (saved === 'light' || saved === 'dark') root.setAttribute('data-theme', saved);
    applyTheme(currentTheme());
    var b = $('#theme-toggle');
    if (b) b.addEventListener('click', function () {
      var next = currentTheme() === 'dark' ? 'light' : 'dark';
      applyTheme(next); store.set('theme', next);
    });
  })();

  /* ---------- reading progress ---------- */
  (function initProgress() {
    var bar = $('#readbar');
    if (!bar) return;
    var tick = false;
    function update() {
      var h = document.documentElement.scrollHeight - window.innerHeight;
      bar.style.width = (h > 0 ? Math.min(100, (window.scrollY / h) * 100) : 0) + '%';
      tick = false;
    }
    window.addEventListener('scroll', function () { if (!tick) { tick = true; window.requestAnimationFrame(update); } }, { passive: true });
    update();
  })();

  /* ---------- mobile TOC drawer ---------- */
  (function initDrawer() {
    var t = $('#toc-toggle');
    if (!t) return;
    t.addEventListener('click', function () { body.classList.toggle('toc-open'); });
    $$('.side a').forEach(function (a) { a.addEventListener('click', function () { body.classList.remove('toc-open'); }); });
    document.addEventListener('keydown', function (e) { if (e.key === 'Escape') body.classList.remove('toc-open'); });
  })();

  /* ---------- headings: anchors + iteration badges ---------- */
  $$('.main h2[id], .main h3[id]').forEach(function (h) {
    var a = document.createElement('a');
    a.className = 'heading-anchor'; a.href = '#' + h.id; a.textContent = '#';
    a.setAttribute('aria-label', 'Liên kết tới mục này');
    h.appendChild(a);
  });
  $$('.main h3').forEach(function (h) {
    var m = /^\s*Iteration\s+(\d+)\s*[—–-]\s*/i.exec(h.textContent);
    if (!m) return;
    h.classList.add('iter');
    var first = h.firstChild;
    if (first && first.nodeType === 3) first.nodeValue = first.nodeValue.replace(/^\s*Iteration\s+\d+\s*[—–-]\s*/i, '');
    var pill = document.createElement('span');
    pill.className = 'iter-n'; pill.textContent = 'ITER ' + m[1];
    h.insertBefore(pill, h.firstChild);
  });

  /* ---------- sidebar scroll-spy ---------- */
  (function initSpy() {
    var links = $$('.side-toc a');
    if (!links.length || !('IntersectionObserver' in window)) return;
    var map = {};
    links.forEach(function (a) { map[a.getAttribute('href').slice(1)] = a; });
    var heads = $$('.main h2[id]').filter(function (h) { return map[h.id]; });
    var io = new IntersectionObserver(function (entries) {
      entries.forEach(function (en) {
        if (!en.isIntersecting) return;
        links.forEach(function (a) { a.classList.remove('active'); });
        var a = map[en.target.id];
        if (a) {
          a.classList.add('active');
          var side = $('.side');
          if (side && (a.offsetTop < side.scrollTop + 10 || a.offsetTop > side.scrollTop + side.clientHeight - 60)) {
            side.scrollTo({ top: Math.max(0, a.offsetTop - 80), behavior: 'smooth' });
          }
        }
      });
    }, { rootMargin: '-12% 0px -78% 0px', threshold: 0 });
    heads.forEach(function (h) { io.observe(h); });
  })();

  /* ---------- code: language detect, highlight, copy ---------- */
  var SV_KW = new Set(('module endmodule interface endinterface class endclass package endpackage function endfunction task endtask ' +
    'program endprogram virtual extends implements import export typedef enum struct union packed logic bit byte int integer shortint longint ' +
    'reg wire real string void input output inout ref const static automatic local protected rand randc constraint endconstraint solve before ' +
    'inside dist with if else for foreach while do repeat forever case endcase casez casex unique priority default begin end fork join join_any ' +
    'join_none return break continue assert assume cover property endproperty sequence endsequence disable iff bind clocking endclocking modport ' +
    'covergroup endgroup coverpoint cross bins illegal_bins ignore_bins wildcard option type_option new null this super initial always ' +
    'always_comb always_ff assign posedge negedge parameter localparam generate endgenerate genvar signed unsigned pure extern typedef ' +
    'throughout within intersect first_match not and or wait expect tagged this').split(/\s+/));

  function esc(s) { return s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;'); }

  function detectLang(text) {
    var lines = text.split('\n').filter(function (l) { return l.trim().length; });
    if (!lines.length) return 'text';
    var hashLines = lines.filter(function (l) { return /^\s*#\s/.test(l) || /^\s*#$/.test(l); }).length;
    if (hashLines / lines.length >= 0.5 && /UVM_|\[[A-Za-z_]+\]|xelab|\$finish|ERROR:|WARNING:|PASS|FAIL|x1=/.test(text)) return 'log';
    if (/^\s*UVM_(INFO|ERROR|WARNING|FATAL)\b/m.test(text) && !/`uvm_/.test(text)) return 'log';
    if (/^(cd|xvlog|xelab|xsim|make|mkdir|cp|source|xcrg|bash|rm|ls|export|git|python3?|\.\/|vivado|riscv|echo|cat|sed|grep|for |while |[A-Z_]+=)/.test(lines[0].trim())) return 'shell';
    if (/\b(class|module|interface|function|task|package|covergroup|property|bind|typedef|constraint|always|initial|assign|endclass|endmodule)\b/.test(text) ||
        /`(uvm_|ifndef|define|include|timescale)/.test(text)) return 'sv';
    if (/[┌└│─├▼►◄]/.test(text)) return 'diagram';
    // weak SV signal: statement-terminating semicolons, method calls or :: scoping
    var semi = lines.filter(function (l) { return /;\s*(\/\/.*)?$/.test(l); }).length;
    if (semi >= 1 && (/\w\s*\(.*\)/.test(text) || /::/.test(text) || /<=|==/.test(text))) return 'sv';
    if (/-->|<--|==>/.test(text)) return 'diagram';
    return 'text';
  }

  function highlightSV(text) {
    var re = /(\/\/[^\n]*|\/\*[\s\S]*?\*\/)|("(?:[^"\\\n]|\\.)*")|(`[A-Za-z_]\w*)|(\$[A-Za-z_]\w*)|(\b\d+'[sS]?[bBoOdDhH][0-9a-fA-F_xXzZ?]+|\b\d[\d_]*(?:\.\d+)?\b)|([A-Za-z_]\w*)/g;
    var out = '', last = 0, m;
    while ((m = re.exec(text)) !== null) {
      out += esc(text.slice(last, m.index));
      var s = m[0];
      if (m[1]) out += '<span class="tok-c">' + esc(s) + '</span>';
      else if (m[2]) out += '<span class="tok-s">' + esc(s) + '</span>';
      else if (m[3]) out += '<span class="tok-m">' + esc(s) + '</span>';
      else if (m[4]) out += '<span class="tok-sys">' + esc(s) + '</span>';
      else if (m[5]) out += '<span class="tok-n">' + esc(s) + '</span>';
      else if (SV_KW.has(s)) out += '<span class="tok-k">' + esc(s) + '</span>';
      else if (/^(uvm_\w+|UVM_\w+|type_id)$/.test(s)) out += '<span class="tok-t">' + esc(s) + '</span>';
      else out += esc(s);
      last = re.lastIndex;
    }
    return out + esc(text.slice(last));
  }

  function highlightLog(text) {
    return esc(text)
      .replace(/\b(UVM_INFO)\b/g, '<span class="tok-info">$1</span>')
      .replace(/\b(UVM_WARNING)\b/g, '<span class="tok-warn">$1</span>')
      .replace(/\b(UVM_ERROR|UVM_FATAL|FAIL|ERROR:)/g, '<span class="tok-err">$1</span>')
      .replace(/(\[[A-Za-z0-9_\/.:\- ]{1,26}\])/g, '<span class="tok-tag">$1</span>');
  }

  function highlightShell(text) {
    return text.split('\n').map(function (line) {
      var e = esc(line);
      if (/^\s*#/.test(line)) return '<span class="tok-c">' + e + '</span>';
      e = e.replace(/(^|\s)(#\s.*)$/, '$1<span class="tok-c">$2</span>');
      e = e.replace(/^(\s*)([A-Za-z_.\/][\w.\/-]*)/, '$1<span class="tok-k">$2</span>');
      e = e.replace(/(\s)(--?[A-Za-z][\w-]*)/g, '$1<span class="tok-n">$2</span>');
      return e;
    }).join('\n');
  }

  var LANG_LABEL = { sv: 'SystemVerilog / UVM', shell: 'shell', log: 'expected log', diagram: 'sơ đồ', text: 'text' };

  $$('.main pre').forEach(function (pre) {
    if (pre.closest('.codebox')) return;
    var code = pre.querySelector('code') || pre;
    var text = code.textContent.replace(/\s+$/, '');
    var lang = pre.getAttribute('data-lang') || detectLang(text);
    if (lang === 'sv') code.innerHTML = highlightSV(text);
    else if (lang === 'log') code.innerHTML = highlightLog(text);
    else if (lang === 'shell') code.innerHTML = highlightShell(text);

    var box = document.createElement('div');
    box.className = 'codebox'; box.setAttribute('data-lang', lang);
    var bar = document.createElement('div');
    bar.className = 'codebar';
    var l = document.createElement('span'); l.className = 'lang'; l.textContent = LANG_LABEL[lang] || lang;
    var btn = document.createElement('button');
    btn.type = 'button'; btn.className = 'copy'; btn.textContent = 'Copy';
    btn.addEventListener('click', function () {
      function ok() { btn.textContent = 'Đã copy ✓'; btn.classList.add('ok'); setTimeout(function () { btn.textContent = 'Copy'; btn.classList.remove('ok'); }, 1400); }
      if (navigator.clipboard && navigator.clipboard.writeText) {
        navigator.clipboard.writeText(text).then(ok, fallback);
      } else fallback();
      function fallback() {
        var ta = document.createElement('textarea'); ta.value = text; ta.style.position = 'fixed'; ta.style.opacity = '0';
        document.body.appendChild(ta); ta.select();
        try { document.execCommand('copy'); ok(); } catch (e) { btn.textContent = 'Lỗi'; }
        document.body.removeChild(ta);
      }
    });
    bar.appendChild(l); bar.appendChild(btn);
    pre.parentNode.insertBefore(box, pre);
    box.appendChild(bar); box.appendChild(pre);
  });

  /* ---------- checklist → persistent checkboxes ---------- */
  $$('.main li').forEach(function (li) {
    var n = li.firstChild;
    if (!n || n.nodeType !== 3 || !/^\s*\[( |x)\]\s/.test(n.nodeValue)) return;
    n.nodeValue = n.nodeValue.replace(/^\s*\[( |x)\]\s/, '');
    var ul = li.parentNode; if (ul.tagName === 'UL') ul.classList.add('checklist');
    var idx = $$('li', ul).indexOf(li);
    var key = 'lab' + labNo + ':chk:' + $$('ul.checklist', $('.main')).indexOf(ul) + ':' + idx;
    var label = document.createElement('label');
    var cb = document.createElement('input'); cb.type = 'checkbox';
    var span = document.createElement('span');
    while (li.firstChild) span.appendChild(li.firstChild);
    label.appendChild(cb); label.appendChild(span); li.appendChild(label);
    cb.checked = store.get(key) === '1';
    cb.addEventListener('change', function () { store.set(key, cb.checked ? '1' : '0'); });
  });

  /* ---------- exercises: done toggles + progress ---------- */
  (function initExercises() {
    var exs = $$('.ex');
    if (!exs.length) return;
    var prog = $('.ex-progress');
    function refresh() {
      var d = exs.filter(function (e) { return e.classList.contains('done'); }).length;
      if (prog) {
        $('.cnt', prog).textContent = d + ' / ' + exs.length + ' bài đã làm';
        $('.bar > i', prog).style.width = (100 * d / exs.length) + '%';
      }
    }
    exs.forEach(function (ex, i) {
      var head = $('.ex-head', ex); if (!head) return;
      var key = 'lab' + labNo + ':ex:' + i;
      var lab = document.createElement('label'); lab.className = 'ex-done';
      var cb = document.createElement('input'); cb.type = 'checkbox';
      lab.appendChild(cb); lab.appendChild(document.createTextNode('Đã làm'));
      head.appendChild(lab);
      if (store.get(key) === '1') { cb.checked = true; ex.classList.add('done'); }
      cb.addEventListener('change', function () {
        ex.classList.toggle('done', cb.checked); store.set(key, cb.checked ? '1' : '0'); refresh();
      });
    });
    refresh();
  })();

  /* ---------- lab completion + dots ---------- */
  (function initDone() {
    for (var i = 1; i <= total; i++) {
      if (store.get('done:' + i) === '1') {
        var a = $('.labdots a[data-n="' + i + '"]'); if (a) a.classList.add('done');
      }
    }
    var b = $('#mark-done');
    if (!b || !labNo) return;
    function paint() {
      var d = store.get('done:' + labNo) === '1';
      b.setAttribute('aria-pressed', d ? 'true' : 'false');
      b.textContent = d ? '✓ Đã hoàn thành lab này' : 'Đánh dấu hoàn thành';
      var a = $('.labdots a[data-n="' + labNo + '"]'); if (a) a.classList.toggle('done', d);
    }
    b.addEventListener('click', function () {
      store.set('done:' + labNo, store.get('done:' + labNo) === '1' ? '0' : '1'); paint();
    });
    paint();
  })();

  /* ---------- details controls, hash opening, print ---------- */
  function setOpen(sel, open) { $$(sel).forEach(function (d) { d.open = open; }); }
  $$('[data-act]').forEach(function (b) {
    b.addEventListener('click', function () {
      var a = b.getAttribute('data-act');
      if (a === 'expand') setOpen('.main details', true);
      else if (a === 'collapse') setOpen('.main details', false);
      else if (a === 'qa-open') setOpen('.main details.qa', true);
      else if (a === 'qa-close') setOpen('.main details.qa', false);
      else if (a === 'top') window.scrollTo({ top: 0, behavior: 'smooth' });
    });
  });
  function openForHash() {
    if (!location.hash) return;
    var t; try { t = document.getElementById(decodeURIComponent(location.hash.slice(1))); } catch (e) { return; }
    for (var n = t; n; n = n.parentElement) if (n.tagName === 'DETAILS') n.open = true;
    if (t) t.scrollIntoView();
  }
  window.addEventListener('hashchange', openForHash);
  openForHash();
  var wasOpen = [];
  window.addEventListener('beforeprint', function () {
    wasOpen = $$('details').map(function (d) { return d.open; });
    setOpen('details', true);
  });
  window.addEventListener('afterprint', function () {
    $$('details').forEach(function (d, i) { d.open = !!wasOpen[i]; });
  });

  /* ---------- keyboard: [ prev lab · ] next lab ---------- */
  document.addEventListener('keydown', function (e) {
    if (e.ctrlKey || e.metaKey || e.altKey) return;
    var tag = (e.target && e.target.tagName) || '';
    if (/INPUT|TEXTAREA|SELECT/.test(tag) || (e.target && e.target.isContentEditable)) return;
    var sel = e.key === '[' ? '.pager .prev' : e.key === ']' ? '.pager .next' : null;
    var a = sel && $(sel);
    if (a && a.href) window.location.href = a.href;
  });

  /* ---------- index page: completion state on cards ---------- */
  (function initIndex() {
    var cards = $$('.card[data-n]');
    if (!cards.length) return;
    var done = 0;
    cards.forEach(function (c) {
      if (store.get('done:' + c.getAttribute('data-n')) === '1') { c.classList.add('done'); done++; }
    });
    var el = $('#stat-done'); if (el) el.textContent = done + ' / ' + cards.length;
    var cont = $('#continue');
    if (cont) {
      var next = cards.filter(function (c) { return !c.classList.contains('done'); })[0];
      if (next) { cont.href = next.getAttribute('href'); cont.textContent = 'Tiếp tục: Lab ' + next.getAttribute('data-n') + ' →'; }
      else { cont.textContent = 'Đã xong cả 15 lab 🎯'; cont.removeAttribute('href'); }
    }
  })();
})();
