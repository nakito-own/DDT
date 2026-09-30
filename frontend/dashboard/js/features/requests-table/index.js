import { isOverdue } from '../../domain/records.js';
import {
  escapeAttr,
  escapeHtml,
} from '../../utils/html.js';
import {
  formatDate,
  formatDuration,
  formatReaction,
  formatStateLabel,
  typeBadgeClass,
} from '../../utils/format.js';

export function updateRequestsTableFromPayload({ items, total, limit }) {
  const tbody = document.querySelector('#requests-table tbody');

  tbody.innerHTML = items.map(record => `
    <tr>
      <td><a href="${record.permalink || '#'}" target="_blank" rel="noopener">${record.id}</a></td>
      <td><span class="badge ${record.state}">${formatStateLabel(record)}</span></td>
      <td><span class="badge ${typeBadgeClass(record.type)}">${escapeHtml(record.type || '—')}</span></td>
      <td>${escapeHtml(record.block || '—')}</td>
      <td class="subject" title="${escapeAttr(record.problemCategory || '')}">${escapeHtml(record.problemCategory || '—')}</td>
      <td class="subject" title="${escapeAttr(record.subject || '')}">${escapeHtml(record.subject || '—')}</td>
      <td>${escapeHtml(record.member || '—')}</td>
      <td>${escapeHtml(record.requestedBy || '—')}</td>
      <td>${escapeHtml(record.oiv || '—')}</td>
      <td>${formatDate(record.createdAt)}</td>
      <td>${formatDate(record.completedAt)}</td>
      <td>${record.resolutionHours != null ? formatDuration(record.resolutionHours) : '—'}</td>
      <td>${record.reactionHours != null ? formatReaction(record.reactionHours) : '—'}</td>
      <td>${escapeHtml(record.errorSide || '—')}</td>
      <td>${record.slaMet === true ? '✓' : record.slaMet === false ? '✗' : isOverdue(record) ? '⚠' : '—'}</td>
    </tr>
  `).join('');

  document.getElementById('table-note').textContent =
    total > limit ? `Показано ${items.length} из ${total} записей` : `${total} записей`;
}
