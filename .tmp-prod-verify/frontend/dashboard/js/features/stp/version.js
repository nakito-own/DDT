import { STP_VERSION_STORAGE_KEY } from '../../config/constants.js';
import { store } from '../../core/state.js';
import { loadDatasetMeta, setDateBounds, setHeaderMeta } from '../../data/loader.js';
import { destroyAllCharts } from '../../charts/registry.js';
import { buildFilters, resetFilters } from '../filters/index.js';
import { escapeAttr, escapeHtml } from '../../utils/html.js';

function versionGroupVisible(visible) {
  const group = document.getElementById('stp-version-group');
  if (group) group.hidden = !visible;
}

export function populateVersionSelect(versions, selectedId) {
  const select = document.getElementById('stp-version');
  if (!select) return;

  select.innerHTML = versions.map(({ id, label, total }) => (
    `<option value="${escapeAttr(id)}">${escapeHtml(label)} (${total})</option>`
  )).join('');

  if (selectedId && versions.some(v => v.id === selectedId)) {
    select.value = selectedId;
  } else if (versions.length) {
    select.value = versions[versions.length - 1].id;
  }

  store.stpVersion = select.value || null;
  versionGroupVisible(versions.length > 1);
}

export function resolveInitialVersion(meta) {
  const saved = localStorage.getItem(STP_VERSION_STORAGE_KEY);
  if (saved && meta.versions.some(v => v.id === saved)) {
    return saved;
  }
  return meta.version || meta.defaultVersion || meta.versions.at(-1)?.id || null;
}

export async function switchStpVersion(version) {
  if (!version || version === store.stpVersion) {
    if (store.lastQuery?.version === version) return;
  }

  store.stpVersion = version;
  localStorage.setItem(STP_VERSION_STORAGE_KEY, version);

  const select = document.getElementById('stp-version');
  if (select && select.value !== version) {
    select.value = version;
  }

  destroyAllCharts();

  const meta = await loadDatasetMeta('stp', version);
  store.stpVersions = meta.versions;
  setHeaderMeta(meta);
  setDateBounds(meta.dateBounds);
  await buildFilters(version);
  resetFilters();
}

export function initStpVersion(meta) {
  store.stpVersions = meta.versions || [];
  const initial = resolveInitialVersion(meta);
  populateVersionSelect(store.stpVersions, initial);
  store.stpVersion = initial;

  if (!window.__stpVersionListenerBound) {
    window.__stpVersionListenerBound = true;
    window.addEventListener('stp-version-change', (event) => {
      switchStpVersion(event.detail.version);
    });
  }
}
