import { STATUS_GROUP_LABELS } from '../config/constants.js';
import { avg } from '../utils/math.js';

const STATUS_GROUP_ORDER = ['in_progress', 'waiting', 'closed'];

export function countByStatusGroup(records) {
  const counts = {};
  records.forEach(record => {
    const key = record.statusGroup || 'unknown';
    counts[key] = (counts[key] || 0) + 1;
  });

  const ordered = STATUS_GROUP_ORDER
    .filter(key => counts[key])
    .map(key => [STATUS_GROUP_LABELS[key], counts[key]]);

  const extra = Object.entries(counts)
    .filter(([key]) => !STATUS_GROUP_ORDER.includes(key))
    .map(([key, count]) => [STATUS_GROUP_LABELS[key] || key, count])
    .sort((a, b) => b[1] - a[1]);

  return [...ordered, ...extra];
}

export function countBy(records, key) {
  const map = {};
  records.forEach(record => {
    const v = record[key] || '—';
    map[v] = (map[v] || 0) + 1;
  });
  return Object.entries(map).sort((a, b) => b[1] - a[1]);
}

export function dominantValue(records, key) {
  const entries = countBy(records, key);
  return entries.length ? entries[0][0] : '—';
}

export function aggregateGroups(records, groupKey, withErrorSide = true) {
  const total = records.length || 1;
  const groups = new Map();

  records.forEach(record => {
    const name = record[groupKey] || '—';
    if (!groups.has(name)) {
      groups.set(name, {
        name,
        ids: [],
        closed: 0,
        inProgress: 0,
        waiting: 0,
        resolutionHours: [],
        reactionHours: [],
        records: [],
      });
    }
    const group = groups.get(name);
    group.ids.push(record.id);
    group.records.push(record);
    if (record.statusGroup === 'closed') group.closed += 1;
    else if (record.statusGroup === 'waiting') group.waiting += 1;
    else group.inProgress += 1;
    if (record.resolutionHours != null) group.resolutionHours.push(record.resolutionHours);
    if (record.reactionHours != null) group.reactionHours.push(record.reactionHours);
  });

  return [...groups.values()]
    .map(group => ({
      name: group.name,
      count: group.ids.length,
      share: (group.ids.length / total) * 100,
      avgResolution: avg(group.resolutionHours),
      avgReaction: avg(group.reactionHours),
      closed: group.closed,
      inProgress: group.inProgress,
      waiting: group.waiting,
      errorSide: withErrorSide ? dominantValue(group.records, 'errorSide') : null,
      exampleIds: group.ids.slice(0, 8),
    }))
    .sort((a, b) => b.count - a.count);
}
