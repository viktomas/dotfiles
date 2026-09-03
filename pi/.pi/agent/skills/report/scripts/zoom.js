(function () {
  'use strict';

  const dialog = document.getElementById('zoom-overlay');

  // Open a zoomed clone when a diagram is clicked; close on any click inside
  // the dialog. Escape-to-close and the backdrop come free with <dialog>.
  document.addEventListener('click', (e) => {
    if (dialog.open) {
      dialog.close();
      return;
    }
    const svg = e.target.closest?.('figure.diagram svg');
    if (svg) {
      dialog.replaceChildren(svg.cloneNode(true));
      dialog.showModal();
    }
  });

  dialog.addEventListener('close', () => dialog.replaceChildren());
})();
