import { API_BASE } from '../config/datasets.js';

async function request(path, options = {}) {
  const res = await fetch(`${API_BASE}${path}`, {
    headers: { 'Content-Type': 'application/json', ...options.headers },
    ...options,
  });
  if (!res.ok) {
    const detail = await res.text().catch(() => res.statusText);
    throw new Error(`API ${res.status}: ${detail}`);
  }
  return res.json();
}

export function fetchDatasets() {
  return request('/datasets');
}

export function fetchMeta(datasetId, version = null) {
  const query = version ? `?version=${encodeURIComponent(version)}` : '';
  return request(`/${datasetId}/meta${query}`);
}

export function fetchFilterOptions(datasetId, version = null) {
  const query = version ? `?version=${encodeURIComponent(version)}` : '';
  return request(`/${datasetId}/filter-options${query}`);
}

export function queryDataset(datasetId, filters) {
  return request(`/${datasetId}/query`, {
    method: 'POST',
    body: JSON.stringify(filters),
  });
}
