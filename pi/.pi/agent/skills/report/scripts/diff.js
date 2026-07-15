// Turn every <div class="report-diff" data-diff="BASE64"> into a rich diff.
//
// diff2html miscalculates layout when it renders into a hidden container, so a
// diff inside a closed <details> is deferred until that <details> first opens.
(function () {
  function render(el) {
    if (el.dataset.rendered) return;
    el.dataset.rendered = "1";
    var diff;
    try {
      diff = decodeURIComponent(escape(atob(el.dataset.diff)));
    } catch (e) {
      return; // leave the empty container rather than break the page
    }
    new Diff2HtmlUI(
      el,
      diff,
      {
        drawFileList: false,
        matching: "lines",
        outputFormat: "side-by-side",
        highlight: true,
        // Match the report's always-dark highlight.js code theme, otherwise
        // diff2html's light line backgrounds clash with the dark code cells.
        colorScheme: "dark",
      },
      window.hljs
    ).draw();
  }

  document.querySelectorAll(".report-diff").forEach(function (el) {
    var details = el.closest("details");
    if (details && !details.open) {
      details.addEventListener("toggle", function handler() {
        if (details.open) {
          details.removeEventListener("toggle", handler);
          render(el);
        }
      });
    } else {
      render(el);
    }
  });
})();
