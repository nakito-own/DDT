(function () {
  var dataset = localStorage.getItem('dashboard-dataset');
  if (dataset && dataset !== 'stp') return;

  var section = localStorage.getItem('dashboard-section');
  if (!section || section === 'overview') return;

  var layout = document.getElementById('layout-stp');
  if (!layout) return;

  var overview = layout.querySelector('.dashboard-section[data-section="overview"]');
  var target = layout.querySelector('.dashboard-section[data-section="' + section + '"]');
  if (!overview || !target) return;

  overview.hidden = true;
  target.hidden = false;

  document.querySelectorAll('.section-tab').forEach(function (btn) {
    var active = btn.dataset.section === section;
    btn.classList.toggle('active', active);
    btn.setAttribute('aria-selected', active ? 'true' : 'false');
  });
})();
