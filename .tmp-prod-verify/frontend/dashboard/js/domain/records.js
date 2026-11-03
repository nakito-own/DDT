export function normalizeRecord(record) {
  return {
    ...record,
    state: record.state === 'closed' ? 'closed' : 'open',
    stateLabel: record.state === 'closed' ? 'закрыта' : 'открыта',
  };
}

export function isOverdue(record) {
  if (record.state !== 'open' || !record.slaTarget) return false;
  return Date.now() > new Date(record.slaTarget).getTime();
}
