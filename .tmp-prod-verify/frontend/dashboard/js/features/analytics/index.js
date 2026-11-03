import { ITSM_BASE } from '../../config/constants.js';
import { escapeAttr, escapeHtml } from '../../utils/html.js';
import { formatDuration, formatPercent, formatReaction } from '../../utils/format.js';

function renderAnalyticsTable(tableId, rows) {
  const tbody = document.querySelector(`#${tableId} tbody`);
  tbody.innerHTML = rows.map((row, index) => `
    <tr>
      <td class="col-num">${index + 1}</td>
      <td class="subject" title="${escapeAttr(row.name)}">${escapeHtml(row.name)}</td>
      <td>${row.count}</td>
      <td>${formatPercent(row.share)}</td>
      <td>${row.avgResolution != null ? formatDuration(row.avgResolution) : '—'}</td>
      <td>${row.avgReaction != null ? formatReaction(row.avgReaction) : '—'}</td>
      <td>${row.closed}</td>
      <td>${row.inProgress}</td>
      <td>${row.waiting}</td>
      <td class="id-list">${row.exampleIds.map(id => `<a href="${ITSM_BASE}${id}" target="_blank" rel="noopener">${id}</a>`).join(', ')}</td>
    </tr>
  `).join('');
}

function renderCrossMatrixFromPayload({ rows, cols, values }) {
  const wrap = document.getElementById('analytics-cross-wrap');
  wrap.innerHTML = `
    <table class="matrix-table">
      <thead>
        <tr>
          <th class="col-num">№</th>
          <th>Категория \\ Блок</th>
          ${cols.map(b => `<th>${escapeHtml(b)}</th>`).join('')}
          <th>Итого</th>
        </tr>
      </thead>
      <tbody>
        ${rows.map((cat, index) => {
          const rowValues = values[index] || [];
          const rowTotal = rowValues.reduce((sum, val) => sum + val, 0);
          const cells = rowValues.map(val => `<td>${val || '·'}</td>`).join('');
          return `<tr><td class="col-num">${index + 1}</td><th>${escapeHtml(cat)}</th>${cells}<td><strong>${rowTotal}</strong></td></tr>`;
        }).join('')}
      </tbody>
    </table>
  `;
}

function renderOivWaitingTable(rows) {
  const tbody = document.querySelector('#analytics-oiv-waiting tbody');
  if (!tbody) return;

  tbody.innerHTML = rows.map((row, index) => `
    <tr>
      <td class="col-num">${index + 1}</td>
      <td class="subject" title="${escapeAttr(row.name)}">${escapeHtml(row.name)}</td>
      <td>${row.episodeCount}</td>
      <td>${row.openWaiting}</td>
      <td>${row.avgWaitingHours != null ? formatDuration(row.avgWaitingHours) : '—'}</td>
      <td>${row.medianWaitingHours != null ? formatDuration(row.medianWaitingHours) : '—'}</td>
      <td>${row.maxWaitingHours != null ? formatDuration(row.maxWaitingHours) : '—'}</td>
      <td class="id-list">${row.exampleIds.map(id => `<a href="${ITSM_BASE}${id}" target="_blank" rel="noopener">${id}</a>`).join(', ')}</td>
    </tr>
  `).join('');
}

export function updateAnalyticsFromPayload(analytics) {
  renderAnalyticsTable('analytics-category', analytics.category);
  renderAnalyticsTable('analytics-block', analytics.block);
  renderOivWaitingTable(analytics.oivWaiting || []);
  renderAnalyticsTable('analytics-errorside', analytics.errorside);
  renderCrossMatrixFromPayload(analytics.crossMatrix);
}
