import {
  MULTI_FILTERS,
  SEARCHABLE_KEYS,
  STATE_LABELS,
  STATUS_GROUP_LABELS,
} from '../../config/constants.js';
import { store } from '../../core/state.js';
import { fetchFilterOptions, queryDataset } from '../../data/api.js';
import { escapeAttr, escapeHtml } from '../../utils/html.js';
import { updateKPIsFromPayload } from '../kpi/index.js';
import { updateAnalyticsFromPayload } from '../analytics/index.js';
import { updateRequestsTableFromPayload } from '../requests-table/index.js';
import { updateChartsFromPayload } from '../../charts/index.js';

function toggleDropdown(dropdown) {
  const isOpen = dropdown.classList.contains('open');
  closeAllDropdowns();
  if (!isOpen) {
    dropdown.classList.add('open');
    dropdown.querySelector('.dropdown-trigger').setAttribute('aria-expanded', 'true');
    const search = dropdown.querySelector('.dropdown-search');
    if (search) {
      search.value = '';
      dropdown.querySelectorAll('.dropdown-option').forEach(opt => { opt.hidden = false; });
      search.focus();
    }
  }
}

function closeAllDropdowns() {
  document.querySelectorAll('.dropdown-filter.open').forEach(dropdown => {
    dropdown.classList.remove('open');
    dropdown.querySelector('.dropdown-trigger').setAttribute('aria-expanded', 'false');
  });
}

function getSelectedValues(key) {
  const dropdown = document.querySelector(`.dropdown-filter[data-key="${key}"]`);
  if (!dropdown) return [];
  return [...dropdown.querySelectorAll('.dropdown-options input[type="checkbox"]:checked')].map(cb => cb.value);
}

function updateDropdownLabel(dropdown, key) {
  const labelEl = dropdown.querySelector('.dropdown-label');
  const selected = [...dropdown.querySelectorAll('.dropdown-options input[type="checkbox"]:checked')];
  const total = dropdown.querySelectorAll('.dropdown-options input[type="checkbox"]').length;

  labelEl.classList.remove('placeholder');

  if (!selected.length || selected.length === total) {
    labelEl.textContent = 'Все';
    labelEl.classList.add('placeholder');
  } else if (selected.length === 1) {
    const val = selected[0].value;
    if (key === 'state') labelEl.textContent = STATE_LABELS[val];
    else if (key === 'statusGroup') labelEl.textContent = STATUS_GROUP_LABELS[val];
    else labelEl.textContent = val;
  } else {
    labelEl.textContent = `Выбрано: ${selected.length}`;
  }
}

export function getFilterValues() {
  const dateField = document.getElementById('date-field').value;
  const dateFrom = document.getElementById('date-from').value || null;
  const dateTo = document.getElementById('date-to').value || null;

  const multi = {};
  MULTI_FILTERS.forEach(({ key }) => {
    const selected = getSelectedValues(key);
    const total = document.querySelectorAll(`.dropdown-filter[data-key="${key}"] .dropdown-options input[type="checkbox"]`).length;
    if (selected.length && selected.length < total) multi[key] = selected;
  });

  return { dateField, dateFrom, dateTo, multi };
}

function getActiveStpVersion() {
  const select = document.getElementById('stp-version');
  return select?.value || store.stpVersion || null;
}

function buildQueryPayload(extra = {}) {
  const filters = getFilterValues();
  const version = getActiveStpVersion();
  return {
    dateField: filters.dateField,
    dateFrom: filters.dateFrom,
    dateTo: filters.dateTo,
    multi: filters.multi,
    trendGroupBy: document.getElementById('trend-group-by').value,
    tableLimit: 200,
    tableOffset: 0,
    ...(version ? { version } : {}),
    ...extra,
  };
}

export async function applyFilters() {
  const applyBtn = document.getElementById('apply-btn');
  if (applyBtn) applyBtn.disabled = true;

  try {
    const result = await queryDataset('stp', buildQueryPayload());
    store.lastQuery = result;
    store.totalCount = result.totalCount;
    store.filteredCount = result.filteredCount;

    document.getElementById('filtered-count').textContent = result.filteredCount;
    document.getElementById('total-count').textContent = result.totalCount;

    updateKPIsFromPayload(result.kpi);
    updateChartsFromPayload(result.charts);
    updateAnalyticsFromPayload(result.analytics);
    updateRequestsTableFromPayload(result.records);
  } finally {
    if (applyBtn) applyBtn.disabled = false;
  }
}

export function resetFilters() {
  document.getElementById('date-from').value = '';
  document.getElementById('date-to').value = '';
  document.getElementById('date-field').value = 'createdAt';
  document.querySelectorAll('.dropdown-filter').forEach(dropdown => {
    dropdown.querySelectorAll('.dropdown-options input[type="checkbox"]').forEach(cb => {
      cb.checked = false;
    });
    dropdown.querySelectorAll('.dropdown-option').forEach(opt => { opt.hidden = false; });
    const search = dropdown.querySelector('.dropdown-search');
    if (search) search.value = '';
    updateDropdownLabel(dropdown, dropdown.dataset.key);
  });
  closeAllDropdowns();
  applyFilters();
}

export async function buildFilters(version = null) {
  const activeVersion = version || getActiveStpVersion();
  const options = await fetchFilterOptions('stp', activeVersion);
  const container = document.getElementById('multi-filters');
  container.innerHTML = '';

  MULTI_FILTERS.forEach(({ key, label }) => {
    const values = options[key] || [];
    const searchable = SEARCHABLE_KEYS.has(key) && values.length > 6;

    const group = document.createElement('div');
    group.className = 'dropdown-filter';
    group.dataset.key = key;

    group.innerHTML = `
      <label>${escapeHtml(label)}</label>
      <button type="button" class="dropdown-trigger" aria-expanded="false">
        <span class="dropdown-label placeholder">Все</span>
        <span class="dropdown-chevron">▼</span>
      </button>
      <div class="dropdown-panel">
        ${searchable ? '<input type="search" class="dropdown-search" placeholder="Поиск…">' : ''}
        <div class="dropdown-actions">
          <button type="button" data-action="all">Выбрать все</button>
          <button type="button" data-action="clear">Сбросить</button>
        </div>
        <div class="dropdown-options">
          ${values.map(v => {
            const display = key === 'state'
              ? STATE_LABELS[v]
              : key === 'statusGroup'
                ? STATUS_GROUP_LABELS[v]
                : v;
            return `
            <label class="dropdown-option" data-value="${escapeAttr(v)}">
              <input type="checkbox" value="${escapeAttr(v)}">
              <span>${escapeHtml(display)}</span>
            </label>`;
          }).join('')}
        </div>
      </div>
    `;

    container.appendChild(group);
    updateDropdownLabel(group, key);
  });
}

export function bindFilterEvents() {
  document.getElementById('apply-btn').addEventListener('click', applyFilters);
  document.getElementById('reset-btn').addEventListener('click', resetFilters);

  const versionSelect = document.getElementById('stp-version');
  if (versionSelect && !versionSelect.dataset.bound) {
    versionSelect.dataset.bound = '1';
    versionSelect.addEventListener('change', () => {
      window.dispatchEvent(new CustomEvent('stp-version-change', {
        detail: { version: versionSelect.value },
      }));
    });
  }

  document.querySelectorAll('input[type="date"], #date-field').forEach(el => {
    el.addEventListener('change', applyFilters);
  });

  document.getElementById('trend-group-by').addEventListener('change', applyFilters);
  document.getElementById('trend-chart-type').addEventListener('change', () => {
    if (store.lastQuery?.charts) {
      updateChartsFromPayload(store.lastQuery.charts);
    }
  });

  document.getElementById('multi-filters').addEventListener('click', (e) => {
    const dropdown = e.target.closest('.dropdown-filter');
    if (!dropdown) return;

    if (e.target.closest('.dropdown-trigger')) {
      toggleDropdown(dropdown);
      return;
    }

    const actionBtn = e.target.closest('[data-action]');
    if (actionBtn) {
      const action = actionBtn.dataset.action;
      const boxes = dropdown.querySelectorAll('.dropdown-options input[type="checkbox"]');
      boxes.forEach(cb => {
        cb.checked = action === 'all';
        if (action === 'clear') cb.checked = false;
      });
      updateDropdownLabel(dropdown, dropdown.dataset.key);
      applyFilters();
      return;
    }

    if (e.target.matches('.dropdown-options input[type="checkbox"]')) {
      updateDropdownLabel(dropdown, dropdown.dataset.key);
      applyFilters();
    }
  });

  document.getElementById('multi-filters').addEventListener('input', (e) => {
    if (!e.target.matches('.dropdown-search')) return;
    const query = e.target.value.trim().toLowerCase();
    e.target.closest('.dropdown-filter').querySelectorAll('.dropdown-option').forEach(opt => {
      const text = opt.textContent.toLowerCase();
      opt.hidden = query && !text.includes(query);
    });
  });

  document.addEventListener('click', (e) => {
    if (!e.target.closest('.dropdown-filter')) {
      closeAllDropdowns();
    }
  });

  document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') closeAllDropdowns();
  });
}
