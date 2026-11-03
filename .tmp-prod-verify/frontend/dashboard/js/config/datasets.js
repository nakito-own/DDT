export const API_BASE = '/api';
export const DATASET_STORAGE_KEY = 'dashboard-dataset';
export const DEFAULT_DATASET = 'stp';

export const DATASETS = {
  stp: {
    id: 'stp',
    type: 'stp',
    label: 'Аналитика СТП',
    title: 'КРР МР — Аналитика СТП',
    apiId: 'stp',
    layoutId: 'layout-stp',
  },
  '4me': {
    id: '4me',
    type: '4me',
    label: 'Export 4me',
    title: 'КРР МР — Export 4me',
    apiId: '4me',
    layoutId: 'layout-4me',
  },
};

export const DATASET_IDS = Object.keys(DATASETS);

export function getDatasetConfig(id) {
  return DATASETS[id] || DATASETS[DEFAULT_DATASET];
}
