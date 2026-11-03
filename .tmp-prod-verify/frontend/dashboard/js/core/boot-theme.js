(function () {
  var theme = localStorage.getItem('dashboard-theme');
  document.documentElement.setAttribute('data-theme', theme === 'light' ? 'light' : 'dark');
})();
