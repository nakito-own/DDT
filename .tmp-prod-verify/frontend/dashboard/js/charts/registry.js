import { store } from '../core/state.js';

export function destroyAllCharts() {
  Object.keys(store.charts).forEach(key => destroyChart(key));
}

export function destroyChart(key) {
  if (store.charts[key]) {
    store.charts[key].destroy();
    delete store.charts[key];
  }
}

export function resizeCharts() {
  Object.values(store.charts).forEach(chart => {
    if (chart) chart.resize();
  });
}

export function setChart(key, chart) {
  store.charts[key] = chart;
}
