export function countFourmeBy(records, key, labelKey = null) {
  const map = {};
  records.forEach(record => {
    const v = record[key] || record[labelKey] || '—';
    const label = labelKey ? (record[labelKey] || v) : v;
    map[label] = (map[label] || 0) + 1;
  });
  return Object.entries(map).sort((a, b) => b[1] - a[1]);
}

export function aggregateFourmeGroups(records, groupKey, labelKey = null) {
  const total = records.length || 1;
  const groups = new Map();

  records.forEach(record => {
    const name = record[groupKey] || (labelKey ? record[labelKey] : null) || '—';
    if (!groups.has(name)) {
      groups.set(name, {
        name,
        ids: [],
        completed: 0,
        waiting: 0,
        inProgress: 0,
        resolutionHours: [],
        reopenCount: 0,
        slaKnown: 0,
        slaOk: 0,
      });
    }
    const group = groups.get(name);
    group.ids.push(record.id);
    if (record.status === 'completed') group.completed += 1;
    else if (record.status === 'waiting_for_customer') group.waiting += 1;
    else group.inProgress += 1;
    if (record.resolutionHours != null) group.resolutionHours.push(record.resolutionHours);
    if (record.reopenCount > 0) group.reopenCount += 1;
    if (record.slaMet != null) {
      group.slaKnown += 1;
      if (record.slaMet) group.slaOk += 1;
    }
  });

  return [...groups.values()]
    .map(group => ({
      name: group.name,
      count: group.ids.length,
      share: (group.ids.length / total) * 100,
      avgResolution: avg(group.resolutionHours),
      completed: group.completed,
      waiting: group.waiting,
      inProgress: group.inProgress,
      reopenCount: group.reopenCount,
      slaRate: group.slaKnown ? (group.slaOk / group.slaKnown) * 100 : null,
      exampleIds: group.ids.slice(0, 8),
    }))
    .sort((a, b) => b.count - a.count);
}

function avg(arr) {
  if (!arr.length) return null;
  return arr.reduce((a, b) => a + b, 0) / arr.length;
}
