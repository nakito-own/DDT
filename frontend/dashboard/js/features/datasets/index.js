import {
  DATASET_IDS,
  DATASET_STORAGE_KEY,
  DEFAULT_DATASET,
  getDatasetConfig,
} from '../../config/datasets.js';
import { store } from '../../core/state.js';
import { loadDatasetMeta, setDateBounds, setHeaderMeta } from '../../data/loader.js';
import { destroyAllCharts } from '../../charts/registry.js';
import { applyFilters, buildFilters, bindFilterEvents, resetFilters } from '../filters/index.js';
import { bootstrapFourme, refreshFourmeDashboard } from '../fourme/bootstrap.js';
import { initStpVersion, resolveInitialVersion } from '../stp/version.js';
import { setSection } from '../sections/index.js';
import { SECTIONS, SECTION_STORAGE_KEY } from '../../config/constants.js';

export function getActiveDatasetId() {
  return store.activeDatasetId;
}

export function getActiveDataset() {
  return getDatasetConfig(store.activeDatasetId);
}

function showLayout(id) {
  DATASET_IDS.forEach(datasetId => {
    const layout = document.getElementById(getDatasetConfig(datasetId).layoutId);
    if (layout) layout.hidden = datasetId !== id;
  });
}

let stpEventsBound = false;

async function bootstrapStp(config) {
  const previewMeta = await loadDatasetMeta(config.apiId);
  const initialVersion = resolveInitialVersion(previewMeta);
  const meta = initialVersion
    ? await loadDatasetMeta(config.apiId, initialVersion)
    : previewMeta;

  initStpVersion({
    ...previewMeta,
    versions: previewMeta.versions?.length ? previewMeta.versions : meta.versions,
    version: initialVersion,
    defaultVersion: previewMeta.defaultVersion || meta.defaultVersion,
  });

  setHeaderMeta(meta);
  setDateBounds(meta.dateBounds);
  await buildFilters(initialVersion);
  if (!stpEventsBound) {
    bindFilterEvents();
    stpEventsBound = true;
  }
  resetFilters();
  return meta;
}

async function loadDataset(id) {
  const config = getDatasetConfig(id);
  store.activeDatasetId = config.id;

  document.querySelectorAll('.dataset-tab').forEach(btn => {
    const isActive = btn.dataset.dataset === config.id;
    btn.classList.toggle('active', isActive);
    btn.setAttribute('aria-selected', isActive ? 'true' : 'false');
  });

  document.getElementById('dashboard-title').textContent = config.title;
  localStorage.setItem(DATASET_STORAGE_KEY, config.id);
  showLayout(config.id);
  destroyAllCharts();

  if (config.type === '4me') {
    await bootstrapFourme(config.apiId);
  } else {
    await bootstrapStp(config);
  }

  const savedSection = localStorage.getItem(SECTION_STORAGE_KEY);
  if (SECTIONS.includes(savedSection)) {
    setSection(savedSection);
  }
}

export async function setDataset(id) {
  const next = DATASET_IDS.includes(id) ? id : DEFAULT_DATASET;
  if (next === store.activeDatasetId) {
    const hasData = next === '4me'
      ? store.fourme.lastQuery != null
      : store.lastQuery != null;
    if (hasData) return;
  }
  await loadDataset(next);
}

export function refreshActiveDataset() {
  if (store.activeDatasetId === '4me') {
    refreshFourmeDashboard();
  } else if (store.lastQuery) {
    applyFilters();
  }
}

export function initDatasets() {
  const saved = localStorage.getItem(DATASET_STORAGE_KEY);
  return DATASET_IDS.includes(saved) ? saved : DEFAULT_DATASET;
}

export async function bootstrapDatasets() {
  const initial = initDatasets();

  document.querySelector('.dataset-nav').addEventListener('click', (e) => {
    const btn = e.target.closest('.dataset-tab');
    if (btn) setDataset(btn.dataset.dataset);
  });

  await loadDataset(initial);
}
