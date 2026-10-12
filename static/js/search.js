// 사이트 안 검색: 처음 검색할 때 index.json(모든 글의 제목·본문)을 한 번 받아 와서 찾습니다.
(function () {
  var input = document.getElementById("q");
  var out = document.getElementById("results");
  if (!input || !out) return;
  var root = (document.querySelector('link[rel="home"]') || {}).href || "/";
  if (root.slice(-1) !== "/") root = root.replace(/[^/]*$/, "");
  var data = null, loading = null, timer = null;

  function load() {
    if (data) return Promise.resolve(data);
    if (!loading) {
      loading = fetch(root + "index.json").then(function (r) { return r.json(); })
        .then(function (d) { data = d; return d; });
    }
    return loading;
  }
  function esc(s) { return s.replace(/[&<>"]/g, function (c) { return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]; }); }
  function hl(text, terms) {
    var h = esc(text);
    terms.forEach(function (t) {
      var re = new RegExp(esc(t).replace(/[.*+?^${}()|[\]\\]/g, "\\$&"), "gi");
      h = h.replace(re, function (m) { return "<mark>" + m + "</mark>"; });
    });
    return h;
  }
  function run() {
    var q = input.value.trim();
    if (!q) { out.innerHTML = ""; return; }
    var terms = q.split(/\s+/).filter(Boolean);
    load().then(function (items) {
      var res = [];
      items.forEach(function (it) {
        var t = it.t.toLowerCase(), c = it.c.toLowerCase(), score = 0, ok = true;
        terms.forEach(function (term) {
          var x = term.toLowerCase();
          if (t.indexOf(x) >= 0) score += 10;
          var n = c.split(x).length - 1;
          if (n === 0 && t.indexOf(x) < 0) ok = false;
          score += Math.min(n, 10);
        });
        if (ok) res.push({ it: it, score: score });
      });
      res.sort(function (a, b) { return b.score - a.score; });
      if (!res.length) { out.innerHTML = '<li class="r-meta">찾는 낱말이 들어 있는 글이 없습니다.</li>'; return; }
      out.innerHTML = res.slice(0, 30).map(function (r) {
        var it = r.it, low = it.c.toLowerCase(), pos = low.indexOf(terms[0].toLowerCase());
        var start = Math.max(0, pos - 40), snip = (start > 0 ? "…" : "") + it.c.substr(start, 140) + "…";
        return '<li><a class="r-title" href="' + root + it.u + '">' + hl(it.t, terms) + "</a>" +
          '<span class="r-meta">' + esc(it.s) + " · " + it.d + "</span>" +
          '<div class="r-snip">' + hl(snip, terms) + "</div></li>";
      }).join("");
    });
  }
  input.addEventListener("focus", load, { once: true });
  input.addEventListener("input", function () { clearTimeout(timer); timer = setTimeout(run, 150); });
})();
