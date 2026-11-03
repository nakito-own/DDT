(function () {
  var dataset = localStorage.getItem('dashboard-dataset');
  if (!dataset || dataset === 'stp') return;

  document.addEventListener('DOMContentLoaded', function () {
    document.querySelectorAll('.dataset-tab').forEach(function (btn) {
      var active = btn.dataset.dataset === dataset;
      btn.classList.toggle('active', active);
      btn.setAttribute('aria-selected', active ? 'true' : 'false');
    });

    var title = document.getElementById('dashboard-title');
    if (title && dataset === '4me') {
      title.textContent = 'КРР МР — Export 4me';
    }

    var stpLayout = document.getElementById('layout-stp');
    var fourmeLayout = document.getElementById('layout-4me');
    if (stpLayout && fourmeLayout) {
      stpLayout.hidden = dataset !== 'stp';
      fourmeLayout.hidden = dataset !== '4me';
    }
  });
})();
