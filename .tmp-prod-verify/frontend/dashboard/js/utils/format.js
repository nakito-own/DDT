export function formatDate(iso) {
  if (!iso) return '—';
  return iso.slice(0, 10);
}

export function formatDuration(hours) {
  if (hours < 24) return `${Math.round(hours)} ч`;
  const days = Math.round(hours / 24);
  return `${days} д`;
}

export function formatReaction(hours) {
  if (hours == null) return '—';
  if (hours < 1) return `${Math.round(hours * 60)} мин`;
  if (hours < 24) return `${hours.toFixed(1)} ч`;
  return `${(hours / 24).toFixed(1)} д`;
}

export function formatPercent(value) {
  return `${value.toFixed(1)}%`;
}

export function formatStateLabel(record) {
  return record.state === 'closed' ? 'закрыта' : 'открыта';
}

export function formatDayLabel(isoDate) {
  const [, m, d] = isoDate.split('-');
  return `${d}.${m}`;
}

export function truncate(s, n) {
  return s.length > n ? s.slice(0, n - 1) + '…' : s;
}

export function typeBadgeClass(type) {
  if (type === 'Ошибка') return 'incident';
  if (type === 'Консультация') return 'rfi';
  if (type === 'Доработка') return 'rfc';
  return '';
}
