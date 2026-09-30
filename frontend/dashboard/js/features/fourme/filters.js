import { FOURME_FILTERS, FOURME_SEARCHABLE_KEYS } from '../../config/fourme-constants.js';
import { store } from '../../core/state.js';
import { fetchFilterOptions, queryDataset } from '../../data/api.js';
import { escapeAttr, escapeHtml } from '../../utils/html.js';
import { updateFourmeKPIsFromPayload } from './kpi.js';
import { updateFourmeChartsFromPayload } from './charts.js';
import { updateFourmeAnalyticsFromPayload } from './analytics.js';
import { updateFourmeTableFromPayload } from './table.js';

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
  document.querySelectorAll('#layout-4me .dropdown-filter.open').forEach(dropdown => {
    dropdown.classList.remove('open');
    dropdown.querySelector('.dropdown-trigger').setAttribute('aria-expanded', 'false');
  });
}

function getSelectedValues(key) {
  const dropdown = document.querySelector(`#layout-4me .dropdown-filter[data-key="${key}"]`);
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
    labelEl.textContent = selected[0].value;
  } else {
    labelEl.textContent = `Выбрано: ${selected.length}`;
  }
}

export function getFourmeFilterValues() {
  const dateField = document.getElementById('fourme-date-field').value;
  const dateFrom = document.getElementById('fourme-date-from').value || null;
  const dateTo = document.getElementById('fourme-date-to').value || null;
  const multi = {};

  FOURME_FILTERS.forEach(({ key }) => {
    const selected = getSelectedValues(key);
    const total = document.querySelectorAll(`#layout-4me .dropdown-filter[data-key="${key}"] .dropdown-options input[type="checkbox"]`).length;
    if (selected.length && selected.length < total) multi[key] = selected;
  });

  return { dateField, dateFrom, dateTo, multi };
}

function buildFourmeQueryPayload(extra = {}) {
  const filters = getFourmeFilterValues();
  return {
    dateField: filters.dateField,
    dateFrom: filters.dateFrom,
    dateTo: filters.dateTo,
    multi: filters.multi,
    trendGroupBy: document.getElementById('fourme-trend-group-by').value,
    tableLimit: 200,
    tableOffset: 0,
    ...extra,
  };
}

export async function applyFourmeFilters() {
  const applyBtn = document.getElementById('fourme-apply-btn');
  if (applyBtn) applyBtn.disabled = true;

  try {
    const result = await queryDataset('4me', buildFourmeQueryPayload());
    store.fourme.lastQuery = result;
    store.fourme.totalCount = result.totalCount;
    store.fourme.filteredCount = result.filteredCount;

    document.getElementById('fourme-filtered-count').textContent = result.filteredCount;
    document.getElementById('fourme-total-count').textContent = result.totalCount;

    updateFourmeKPIsFromPayload(result.kpi);
    updateFourmeChartsFromPayload(result.charts);
    updateFourmeAnalyticsFromPayload(result.analytics);
    updateFourmeTableFromPayload(result.records);
  } finally {
    if (applyBtn) applyBtn.disabled = false;
  }
}

export function resetFourmeFilters() {
  document.getElementById('fourme-date-from').value = '';
  document.getElementById('fourme-date-to').value = '';
  document.getElementById('fourme-date-field').value = 'createdAt';
  document.querySelectorAll('#layout-4me .dropdown-filter').forEach(dropdown => {
    dropdown.querySelectorAll('.dropdown-options input[type="checkbox"]').forEach(cb => {
      cb.checked = false;
    });
    dropdown.querySelectorAll('.dropdown-option').forEach(opt => { opt.hidden = false; });
    const search = dropdown.querySelector('.dropdown-search');
    if (search) search.value = '';
    updateDropdownLabel(dropdown, dropdown.dataset.key);
  });
  closeAllDropdowns();
  applyFourmeFilters();
}

export async function buildFourmeFilters() {
  const options = await fetchFilterOptions('4me');
  const container = document.getElementById('fourme-multi-filters');
  container.innerHTML = '';

  FOURME_FILTERS.forEach(({ key, label }) => {
    const values = options[key] || [];
    const searchable = FOURME_SEARCHABLE_KEYS.has(key) && values.length > 6;

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
          ${values.map(v => `
            <label class="dropdown-option" data-value="${escapeAttr(v)}">
              <input type="checkbox" value="${escapeAttr(v)}">
              <span>${escapeHtml(v)}</span>
            </label>`).join('')}
        </div>
      </div>
    `;
    container.appendChild(group);
    updateDropdownLabel(group, key);
  });
}

export function bindFourmeFilterEvents() {
  document.getElementById('fourme-apply-btn').addEventListener('click', applyFourmeFilters);
  document.getElementById('fourme-reset-btn').addEventListener('click', resetFourmeFilters);

  document.querySelectorAll('#layout-4me input[type="date"], #fourme-date-field').forEach(el => {
    el.addEventListener('change', applyFourmeFilters);
  });

  document.getElementById('fourme-trend-group-by').addEventListener('change', applyFourmeFilters);
  document.getElementById('fourme-trend-chart-type').addEventListener('change', () => {
    if (store.fourme.lastQuery?.charts) {
      updateFourmeChartsFromPayload(store.fourme.lastQuery.charts);
    }
  });

  document.getElementById('fourme-multi-filters').addEventListener('click', (e) => {
    const dropdown = e.target.closest('.dropdown-filter');
    if (!dropdown) return;

    if (e.target.closest('.dropdown-trigger')) {
      toggleDropdown(dropdown);
      return;
    }

    const actionBtn = e.target.closest('[data-action]');
    if (actionBtn) {
      const action = actionBtn.dataset.action;
      dropdown.querySelectorAll('.dropdown-options input[type="checkbox"]').forEach(cb => {
        cb.checked = action === 'all';
        if (action === 'clear') cb.checked = false;
      });
      updateDropdownLabel(dropdown, dropdown.dataset.key);
      applyFourmeFilters();
      return;
    }

    if (e.target.matches('.dropdown-options input[type="checkbox"]')) {
      updateDropdownLabel(dropdown, dropdown.dataset.key);
      applyFourmeFilters();
    }
  });

  document.getElementById('fourme-multi-filters').addEventListener('input', (e) => {
    if (!e.target.matches('.dropdown-search')) return;
    const query = e.target.value.trim().toLowerCase();
    e.target.closest('.dropdown-filter').querySelectorAll('.dropdown-option').forEach(opt => {
      opt.hidden = query && !opt.textContent.toLowerCase().includes(query);
    });
  });

  document.addEventListener('click', (e) => {
    if (!e.target.closest('#layout-4me .dropdown-filter')) {
      closeAllDropdowns();
    }
  });
}
