import { COLORS, FONT_FAMILY } from '../config/constants.js';
import { getTheme } from '../core/theme.js';
import { avg } from '../utils/math.js';
import { formatDayLabel, truncate } from '../utils/format.js';
import { destroyChart, setChart } from './registry.js';
import { renderBarChart, renderDoughnut, renderHoursBarChart } from './basic.js';

const createdCountLabelsPlugin = {
  id: 'createdCountLabels',
  afterDatasetsDraw(chart) {
    const createdMeta = chart.getDatasetMeta(0);
    if (!createdMeta || createdMeta.hidden) return;

    const ctx = chart.ctx;
    ctx.save();
    ctx.fillStyle = getTheme() === 'light' ? '#2563eb' : '#93c5fd';
    ctx.font = `600 11px ${FONT_FAMILY}`;
    ctx.textAlign = 'center';
    ctx.textBaseline = 'bottom';

    createdMeta.data.forEach((el, i) => {
      const value = chart.data.datasets[0].data[i];
      if (value == null) return;
      const { x, y } = el.getProps(['x', 'y'], true);
      ctx.fillText(String(value), x, y - 6);
    });

    ctx.restore();
  },
};

export function renderTrendChartFromBuckets(trend, groupBy) {
  const chartType = document.getElementById('trend-chart-type').value;
  const { labels, created, closed } = trend;
  const isLine = chartType === 'line';

  destroyChart('monthly');
  const ctx = document.getElementById('chart-monthly');

  setChart('monthly', new Chart(ctx, {
    type: isLine ? 'line' : 'bar',
    data: {
      labels,
      datasets: isLine
        ? [
            {
              label: 'Создано',
              data: created,
              borderColor: COLORS[0],
              backgroundColor: 'rgba(59,130,246,0.15)',
              fill: true,
              tension: 0.3,
              pointRadius: groupBy === 'day' ? 2 : 3,
            },
            {
              label: 'Закрыто',
              data: closed,
              borderColor: COLORS[1],
              backgroundColor: 'rgba(34,197,94,0.1)',
              fill: true,
              tension: 0.3,
              pointRadius: groupBy === 'day' ? 2 : 3,
            },
          ]
        : [
            {
              label: 'Создано',
              data: created,
              backgroundColor: COLORS[0],
              borderRadius: 4,
              maxBarThickness: 28,
            },
            {
              label: 'Закрыто',
              data: closed,
              backgroundColor: COLORS[1],
              borderRadius: 4,
              maxBarThickness: 28,
            },
          ],
    },
    plugins: [createdCountLabelsPlugin],
    options: {
      responsive: true,
      maintainAspectRatio: false,
      layout: { padding: { top: 18 } },
      plugins: { legend: { position: 'top' } },
      scales: {
        x: {
          ticks: {
            maxRotation: groupBy === 'day' ? 45 : 0,
            autoSkip: true,
            maxTicksLimit: groupBy === 'day' ? 20 : groupBy === 'week' ? 16 : 12,
          },
        },
        y: {
          beginAtZero: true,
          suggestedMax: Math.max(1, ...created, ...closed) + 2,
          ticks: { stepSize: 1 },
        },
      },
    },
  }));
}

export function renderDailyDetailChartFromPayload(dayBuckets) {
  const labels = dayBuckets.map(b => b.day);

  destroyChart('chart-daily-detail');
  const ctx = document.getElementById('chart-daily-detail');

  setChart('chart-daily-detail', new Chart(ctx, {
    type: 'bar',
    data: {
      labels: labels.map(formatDayLabel),
      datasets: [
        {
          type: 'bar',
          label: 'Создано',
          data: dayBuckets.map(b => b.created),
          backgroundColor: COLORS[0],
          borderRadius: 4,
          yAxisID: 'y',
        },
        {
          type: 'bar',
          label: 'Закрыто',
          data: dayBuckets.map(b => b.closed),
          backgroundColor: COLORS[1],
          borderRadius: 4,
          yAxisID: 'y',
        },
        {
          type: 'line',
          label: 'Ср. реакция (ч)',
          data: dayBuckets.map(b => (
            b.reactions.length ? Math.round(avg(b.reactions) * 10) / 10 : null
          )),
          borderColor: COLORS[2],
          backgroundColor: COLORS[2],
          yAxisID: 'y1',
          tension: 0.3,
          spanGaps: true,
        },
      ],
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      plugins: { legend: { position: 'top' } },
      scales: {
        y: { beginAtZero: true, position: 'left', ticks: { stepSize: 1 } },
        y1: {
          beginAtZero: true,
          position: 'right',
          grid: { drawOnChartArea: false },
          title: { display: true, text: 'часы' },
        },
      },
    },
  }));
}

export function renderStatusByCategoryChartFromPayload({ categories, closed, inProgress, waiting }) {
  const topCategories = categories;

  destroyChart('chart-status-category');
  const ctx = document.getElementById('chart-status-category');

  setChart('chart-status-category', new Chart(ctx, {
    type: 'bar',
    data: {
      labels: topCategories.map(c => truncate(c, 28)),
      datasets: [
        { label: 'Закрыто', data: closed, backgroundColor: COLORS[1], borderRadius: 4 },
        { label: 'В работе', data: inProgress, backgroundColor: COLORS[0], borderRadius: 4 },
        { label: 'Ожидание действий от клиента', data: waiting, backgroundColor: COLORS[2], borderRadius: 4 },
      ],
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      plugins: { legend: { position: 'top' } },
      scales: {
        x: { stacked: true },
        y: { stacked: true, beginAtZero: true, ticks: { stepSize: 1 } },
      },
    },
  }));
}

export function renderSolvedChartFromPayload({ labels, solved, confirmed }) {
  const solvedMap = solved;
  const confirmedMap = confirmed;

  destroyChart('chart-solved');
  const ctx = document.getElementById('chart-solved');

  setChart('chart-solved', new Chart(ctx, {
    type: 'bar',
    data: {
      labels,
      datasets: [
        {
          label: 'Решено',
          data: labels.map(l => solvedMap[l] || 0),
          backgroundColor: COLORS[1],
          borderRadius: 4,
        },
        {
          label: 'Подтверждение',
          data: labels.map(l => confirmedMap[l] || 0),
          backgroundColor: COLORS[0],
          borderRadius: 4,
        },
      ],
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      plugins: { legend: { position: 'top' } },
      scales: { y: { beginAtZero: true, ticks: { stepSize: 1 } } },
    },
  }));
}

export function updateChartsFromPayload(charts) {
  const groupBy = document.getElementById('trend-group-by').value;
  renderTrendChartFromBuckets(charts.trend, groupBy);
  renderDoughnut('chart-type', charts.type);
  renderBarChart('chart-block', charts.block, 'horizontalBar', 10);
  renderBarChart('chart-oiv', charts.oiv, 'horizontalBar', 10);
  renderBarChart('chart-module', charts.module, 'bar');
  renderBarChart('chart-problem', charts.problemCategory, 'horizontalBar', 10);
  renderDoughnut('chart-status-group', charts.statusGroup);
  renderHoursBarChart('chart-oiv-waiting', charts.oivWaiting || []);
  renderDoughnut('chart-errorside', charts.errorSide);
  renderDailyDetailChartFromPayload(charts.dailyDetail);
  renderStatusByCategoryChartFromPayload(charts.statusByCategory);
  renderSolvedChartFromPayload(charts.solved);
}
