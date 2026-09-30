import { fetchMeta } from './api.js';

export async function loadDatasetMeta(datasetId, version = null) {
  const meta = await fetchMeta(datasetId, version);
  return {
    exportedAt: meta.exportedAt,
    sourceFile: meta.sourceFile || '—',
    total: meta.total,
    dateBounds: meta.dateBounds,
    versions: meta.versions || [],
    defaultVersion: meta.defaultVersion || null,
    version: meta.version || version || null,
  };
}

export function setHeaderMeta({ exportedAt, sourceFile, total }) {
  document.getElementById('export-date').textContent = exportedAt;
  document.getElementById('source-file').textContent = sourceFile;
  document.getElementById('total-header').textContent = total;
}

export function setDateBounds(bounds, prefix = '') {
  if (!bounds?.min || !bounds?.max) return;

  const from = document.getElementById(`${prefix}date-from`);
  const to = document.getElementById(`${prefix}date-to`);
  if (!from || !to) return;

  from.min = bounds.min;
  from.max = bounds.max;
  to.min = bounds.min;
  to.max = bounds.max;
}
