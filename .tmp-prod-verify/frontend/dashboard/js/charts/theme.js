import { FONT_FAMILY } from '../config/constants.js';
import { getTheme } from '../core/theme.js';

export function applyChartTheme() {
  const isLight = getTheme() === 'light';
  Chart.defaults.color = isLight ? '#64748b' : '#8b9cb3';
  Chart.defaults.borderColor = isLight ? '#e2e8f0' : '#2d3a4f';
  Chart.defaults.font.family = FONT_FAMILY;
}
