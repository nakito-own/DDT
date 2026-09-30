import { store } from '../../core/state.js';
import {
  applyFourmeFilters,
  bindFourmeFilterEvents,
  buildFourmeFilters,
  resetFourmeFilters,
} from './filters.js';
import { loadDatasetMeta, setDateBounds, setHeaderMeta } from '../../data/loader.js';

let fourmeEventsBound = false;

export async function bootstrapFourme(apiId = '4me') {
  const meta = await loadDatasetMeta(apiId);
  setDateBounds(meta.dateBounds, 'fourme-');
  await buildFourmeFilters();
  if (!fourmeEventsBound) {
    bindFourmeFilterEvents();
    fourmeEventsBound = true;
  }
  resetFourmeFilters();
  setHeaderMeta(meta);
  return meta;
}

export function refreshFourmeDashboard() {
  if (store.fourme.lastQuery) {
    applyFourmeFilters();
  }
}
