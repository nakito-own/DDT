import {
  enumeratePeriods,
  formatISODate,
  formatPeriodLabel,
  getPeriodKey,
  getWeekStart,
  parseISODate,
} from '../utils/dates.js';

export function buildTrendBuckets(records, groupBy) {
  const buckets = {};

  records.forEach(record => {
    const createdKey = getPeriodKey(record.createdAt, groupBy);
    if (createdKey) {
      if (!buckets[createdKey]) buckets[createdKey] = { created: 0, closed: 0 };
      buckets[createdKey].created += 1;
    }

    if (record.completedAt) {
      const closedKey = getPeriodKey(record.completedAt, groupBy);
      if (closedKey) {
        if (!buckets[closedKey]) buckets[closedKey] = { created: 0, closed: 0 };
        buckets[closedKey].closed += 1;
      }
    }
  });

  const keys = Object.keys(buckets).sort();
  if (!keys.length) return { labels: [], created: [], closed: [] };

  const fullKeys = enumeratePeriods(keys[0], keys[keys.length - 1], groupBy);
  return {
    labels: fullKeys.map(k => formatPeriodLabel(k, groupBy)),
    created: fullKeys.map(k => buckets[k]?.created ?? 0),
    closed: fullKeys.map(k => buckets[k]?.closed ?? 0),
  };
}

export function buildDailyDetailBuckets(records) {
  const days = {};

  records.forEach(record => {
    if (record.createdAt) {
      const d = record.createdAt.slice(0, 10);
      if (!days[d]) days[d] = { created: 0, closed: 0, reactions: [] };
      days[d].created += 1;
    }
    if (record.completedAt) {
      const d = record.completedAt.slice(0, 10);
      if (!days[d]) days[d] = { created: 0, closed: 0, reactions: [] };
      days[d].closed += 1;
    }
    if (record.createdAt && record.reactionHours != null) {
      const d = record.createdAt.slice(0, 10);
      if (!days[d]) days[d] = { created: 0, closed: 0, reactions: [] };
      days[d].reactions.push(record.reactionHours);
    }
  });

  return Object.keys(days).sort().map(day => ({ day, ...days[day] }));
}
