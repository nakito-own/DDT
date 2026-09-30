import { formatDuration, formatReaction } from '../../utils/format.js';

function setKpi(id, value, sub) {
  document.getElementById(id).querySelector('.value').textContent = value;
  document.getElementById(id).querySelector('.sub').textContent = sub;
}

export function updateKPIsFromPayload(kpi) {
  const total = kpi.total || 0;
  setKpi('kpi-total', total, `${kpi.open} откр. / ${kpi.closed} закр.`);
  setKpi(
    'kpi-sla',
    kpi.slaKnown ? `${Math.round(kpi.slaOk / kpi.slaKnown * 100)}%` : '—',
    `${kpi.slaOk} из ${kpi.slaKnown}`,
  );
  setKpi(
    'kpi-median',
    kpi.medianResolution != null ? formatDuration(kpi.medianResolution) : '—',
    'медиана закрытых',
  );
  setKpi(
    'kpi-confirmed',
    kpi.confirmed,
    `${total ? Math.round(kpi.confirmed / total * 100) : 0}% от всех`,
  );
  setKpi('kpi-overdue', kpi.overdueOpen, 'просрочено открытых');
  setKpi(
    'kpi-reaction',
    kpi.medianReaction != null ? formatReaction(kpi.medianReaction) : '—',
    `из ${kpi.reactionCount} с 2 комментариями`,
  );
  setKpi(
    'kpi-errors',
    kpi.errors,
    `${total ? Math.round(kpi.errors / total * 100) : 0}% от всех`,
  );
  if (kpi.topWaitingOiv && kpi.topWaitingOivHours != null) {
    setKpi(
      'kpi-waiting-oiv',
      formatDuration(kpi.topWaitingOivHours),
      `${kpi.topWaitingOiv} · ${kpi.topWaitingOivOpen} заявок · ${kpi.waitingOpen} всего`,
    );
  } else {
    setKpi('kpi-waiting-oiv', '—', kpi.waitingOpen ? `${kpi.waitingOpen} в ожидании` : 'нет данных');
  }
}
