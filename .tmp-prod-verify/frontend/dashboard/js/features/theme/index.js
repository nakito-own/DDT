import { THEME_STORAGE_KEY } from '../../config/constants.js';
import { getTheme } from '../../core/theme.js';
import { applyChartTheme } from '../../charts/theme.js';

export { getTheme };

let onThemeChange = null;

export function setThemeChangeHandler(handler) {
  onThemeChange = handler;
}

export function setTheme(theme) {
  const next = theme === 'light' ? 'light' : 'dark';
  document.documentElement.setAttribute('data-theme', next);
  localStorage.setItem(THEME_STORAGE_KEY, next);
  applyChartTheme();
  onThemeChange?.();
}

export function initTheme() {
  applyChartTheme();
  document.getElementById('theme-toggle').addEventListener('click', () => {
    setTheme(getTheme() === 'light' ? 'dark' : 'light');
  });
}
