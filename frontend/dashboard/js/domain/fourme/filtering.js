export function filterFourmeRecords(records, { dateField, dateFrom, dateTo, multi }) {
  return records.filter(record => {
    for (const [key, values] of Object.entries(multi)) {
      if (!values.includes(String(record[key] ?? ''))) return false;
    }

    if (dateFrom || dateTo) {
      const val = record[dateField];
      if (!val) return false;
      const d = val.slice(0, 10);
      if (dateFrom && d < dateFrom) return false;
      if (dateTo && d > dateTo) return false;
    }

    return true;
  });
}
