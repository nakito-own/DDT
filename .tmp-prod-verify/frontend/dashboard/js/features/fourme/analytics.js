import { escapeAttr, escapeHtml } from '../../utils/html.js';
import { formatDuration, formatPercent } from '../../utils/format.js';

function renderTable(tableId, rows) {
  const tbody = document.getElementById(tableId)?.querySelector('tbody');
  if (!tbody) return;
  tbody.innerHTML = rows.map((row, index) => `
    <tr>
      <td class="col-num">${index + 1}</td>
      <td class="subject" title="${escapeAttr(row.name)}">${escapeHtml(row.name)}</td>
      <td>${row.count}</td>
      <td>${formatPercent(row.share)}</td>
      <td>${row.avgResolution != null ? formatDuration(row.avgResolution) : '—'}</td>
      <td>${row.completed}</td>
      <td>${row.inProgress}</td>
      <td>${row.waiting}</td>
      <td>${row.reopenCount}</td>
      <td>${row.slaRate != null ? formatPercent(row.slaRate) : '—'}</td>
      <td class="id-list">${row.exampleIds.map(id => `<a href="https://sc-tech-solutions.itsm.mos.ru/requests/${id}" target="_blank" rel="noopener">${id}</a>`).join(', ')}</td>
    </tr>
  `).join('');
}

function renderCrossMatrixFromPayload({ rows, cols, values }) {
  document.getElementById('fourme-analytics-cross-wrap').innerHTML = `
    <table class="matrix-table">
      <thead>
        <tr>
          <th class="col-num">№</th>
          <th>Тип \\ Сервис</th>
          ${cols.map(s => `<th>${escapeHtml(s)}</th>`).join('')}
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

export function updateFourmeAnalyticsFromPayload(analytics) {
  renderTable('fourme-analytics-service', analytics.service);
  renderTable('fourme-analytics-member', analytics.member);
  renderTable('fourme-analytics-org', analytics.organization);
  renderTable('fourme-analytics-source', analytics.source);
  renderCrossMatrixFromPayload(analytics.crossMatrix);
}
