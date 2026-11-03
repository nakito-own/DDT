import { escapeAttr, escapeHtml } from '../../utils/html.js';
import { formatDate, formatDuration } from '../../utils/format.js';

export function updateFourmeTableFromPayload({ items, total, limit }) {
  const tbody = document.getElementById('fourme-requests-table')?.querySelector('tbody');
  if (!tbody) return;

  tbody.innerHTML = items.map(record => `
    <tr>
      <td><a href="${record.permalink}" target="_blank" rel="noopener">${record.id}</a></td>
      <td>${escapeHtml(record.statusLabel || '—')}</td>
      <td>${escapeHtml(record.categoryLabel || '—')}</td>
      <td class="subject" title="${escapeAttr(record.serviceInstance || '')}">${escapeHtml(record.serviceShort || '—')}</td>
      <td class="subject" title="${escapeAttr(record.subject || '')}">${escapeHtml(record.subject || '—')}</td>
      <td>${escapeHtml(record.memberShort || '—')}</td>
      <td>${escapeHtml(record.organization || '—')}</td>
      <td>${escapeHtml(record.source || '—')}</td>
      <td>${formatDate(record.createdAt)}</td>
      <td>${formatDate(record.completedAt)}</td>
      <td>${record.resolutionHours != null ? formatDuration(record.resolutionHours) : '—'}</td>
      <td>${record.slaMet === true ? '✓' : record.slaMet === false ? '✗' : '—'}</td>
      <td>${escapeHtml(record.completionReasonLabel || '—')}</td>
      <td>${record.reopenCount || 0}</td>
    </tr>
  `).join('');

  document.getElementById('fourme-table-note').textContent =
    total > limit ? `Показано ${items.length} из ${total} записей` : `${total} записей`;
}
