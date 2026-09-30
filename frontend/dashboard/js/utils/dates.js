export function formatISODate(date) {
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, '0');
  const d = String(date.getDate()).padStart(2, '0');
  return `${y}-${m}-${d}`;
}

export function parseISODate(isoDate) {
  const [y, m, d] = isoDate.split('-').map(Number);
  return new Date(y, m - 1, d);
}

export function getWeekStart(isoDate) {
  const [y, m, d] = isoDate.split('-').map(Number);
  const date = new Date(y, m - 1, d);
  const weekday = date.getDay();
  const diff = weekday === 0 ? -6 : 1 - weekday;
  date.setDate(date.getDate() + diff);
  return formatISODate(date);
}

export function getPeriodKey(isoDate, groupBy) {
  if (!isoDate) return null;
  const day = isoDate.slice(0, 10);
  if (groupBy === 'day') return day;
  if (groupBy === 'month') return day.slice(0, 7);
  return getWeekStart(day);
}

export function formatPeriodLabel(key, groupBy) {
  if (groupBy === 'month') {
    const [y, m] = key.split('-');
    return `${m}.${y}`;
  }
  if (groupBy === 'day') {
    const [y, m, d] = key.split('-');
    return `${d}.${m}.${y.slice(2)}`;
  }
  const start = parseISODate(key);
  const end = new Date(start);
  end.setDate(end.getDate() + 6);
  const fmt = (date) => date.toLocaleDateString('ru-RU', { day: '2-digit', month: '2-digit' });
  return `${fmt(start)}–${fmt(end)}`;
}

export function enumeratePeriods(minKey, maxKey, groupBy) {
  const result = [];

  if (groupBy === 'month') {
    const [startY, startM] = minKey.split('-').map(Number);
    const [endY, endM] = maxKey.split('-').map(Number);
    let y = startY;
    let m = startM;
    while (y < endY || (y === endY && m <= endM)) {
      result.push(`${y}-${String(m).padStart(2, '0')}`);
      m += 1;
      if (m > 12) {
        m = 1;
        y += 1;
      }
    }
    return result;
  }

  const stepDays = groupBy === 'week' ? 7 : 1;
  let cursor = parseISODate(minKey);
  const end = parseISODate(maxKey);

  while (cursor <= end) {
    const key = groupBy === 'week'
      ? getWeekStart(formatISODate(cursor))
      : formatISODate(cursor);
    if (!result.length || result[result.length - 1] !== key) {
      result.push(key);
    }
    cursor.setDate(cursor.getDate() + stepDays);
  }

  return result;
}
