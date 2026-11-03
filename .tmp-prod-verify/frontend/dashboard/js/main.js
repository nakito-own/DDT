import { applyChartTheme } from './charts/theme.js';
import { initSections } from './features/sections/index.js';
import { initTheme, setThemeChangeHandler } from './features/theme/index.js';
import { bootstrapDatasets, refreshActiveDataset } from './features/datasets/index.js';

async function bootstrap() {
  if (document.fonts) {
    await Promise.all([
      document.fonts.load('400 16px "Golos Text"'),
      document.fonts.load('500 16px "Golos Text"'),
      document.fonts.load('600 16px "Golos Text"'),
      document.fonts.load('700 16px "Golos Text"'),
    ]);
  }

  applyChartTheme();
  initTheme();
  initSections();
  setThemeChangeHandler(refreshActiveDataset);
  await bootstrapDatasets();
}

document.addEventListener('DOMContentLoaded', bootstrap);
