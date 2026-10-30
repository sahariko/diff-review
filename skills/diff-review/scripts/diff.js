(function () {
  // Jump to a diff line (or file): open its file, pick the anchor that is actually visible (unified vs split), flash it.
  function go(target) {
    var fileId = target.split("-")[0];
    var file = document.getElementById(fileId);
    if (file && file.tagName === "DETAILS") file.open = true;
    var el = null;
    document.querySelectorAll('[data-a="' + target + '"]').forEach(function (n) {
      if (!el && n.offsetParent !== null) el = n;
    });
    el = el || file;
    if (!el) return;
    el.scrollIntoView({ block: "center" });
    el.classList.add("flash");
    setTimeout(function () { el.classList.remove("flash"); }, 2500);
  }
  document.addEventListener("click", function (ev) {
    var a = ev.target.closest("[data-target]");
    if (a) { ev.preventDefault(); go(a.getAttribute("data-target")); }
    var b = ev.target.closest(".tabs button");
    if (b) {
      var card = b.closest(".shot");
      card.setAttribute("data-show", b.getAttribute("data-s"));
      card.querySelectorAll(".tabs button").forEach(function (x) { x.setAttribute("aria-pressed", String(x === b)); });
    }
  });
  var toggle = document.getElementById("quiet-toggle");
  if (toggle) toggle.addEventListener("change", function () {
    document.querySelectorAll('details[data-quiet="1"]').forEach(function (d) { d.open = toggle.checked; });
  });
  // Highlight the contents link for whatever is at the top of the screen.
  var spy = Array.prototype.slice.call(document.querySelectorAll("#guide, #visual, #files, details.file"));
  var links = document.querySelectorAll(".toc a");
  var top = document.getElementById("to-top");
  if (top) top.addEventListener("click", function () {
    var calm = window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    window.scrollTo({ top: 0, behavior: calm ? "auto" : "smooth" });
  });
  var ticking = false;
  function mark() {
    ticking = false;
    var cur = null;
    spy.forEach(function (el) { if (el.getBoundingClientRect().top <= window.innerHeight * 0.5) cur = el; });
    if (top) top.hidden = window.scrollY < 500;
    var id = cur && cur.id;
    links.forEach(function (a) {
      var t = a.getAttribute("data-spy") || a.getAttribute("data-target");
      a.classList.toggle("active", t === id);
      if (t === id) a.setAttribute("aria-current", "location"); else a.removeAttribute("aria-current");
    });
  }
  window.addEventListener("scroll", function () { if (!ticking) { ticking = true; requestAnimationFrame(mark); } }, { passive: true });
  mark();
})();
