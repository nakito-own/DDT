import { formatDuration, formatPercent } from '../../utils/format.js';

function setKpi(id, value, sub) {
  document.getElementById(id).querySelector('.value').textContent = value;
  document.getElementById(id).querySelector('.sub').textContent = sub;
}

export function updateFourmeKPIsFromPayload(kpi) {
  const total = kpi.total || 0;
  setKpi('fourme-kpi-total', total, `${kpi.open} откр. / ${kpi.completed} закр.`);
  setKpi(
    'fourme-kpi-completed',
    kpi.completed ? formatPercent(kpi.completed / total * 100) : '—',
    `${kpi.completed} заявок`,
  );
  setKpi('fourme-kpi-waiting', kpi.waiting, `${kpi.waiting} Ожидание действий от клиента`);
  setKpi(
    'fourme-kpi-sla',
    kpi.slaKnown ? formatPercent(kpi.slaOk / kpi.slaKnown * 100) : '—',
    `${kpi.slaOk} из ${kpi.slaKnown}`,
  );
  setKpi(
    'fourme-kpi-median',
    kpi.medianResolution != null ? formatDuration(kpi.medianResolution) : '—',
    'медиана закрытых',
  );
  setKpi(
    'fourme-kpi-reopen',
    kpi.reopened,
    `${total ? Math.round(kpi.reopened / total * 100) : 0}% от всех`,
  );
  setKpi('fourme-kpi-reviewed', kpi.reviewed, 'проверено');
}
