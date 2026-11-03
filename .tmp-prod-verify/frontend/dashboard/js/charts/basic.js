import { COLORS, FONT_FAMILY } from '../config/constants.js';
import { getTheme } from '../core/theme.js';
import { truncate } from '../utils/format.js';
import { destroyChart, setChart } from './registry.js';

function cssColor(name, fallback) {
  const value = getComputedStyle(document.documentElement).getPropertyValue(name).trim();
  return value || fallback;
}

function getChartLabelColor() {
  const isLight = getTheme() === 'light';
  return cssColor('--text', isLight ? '#1a2332' : '#e7ecf3');
}

function formatSharePct(pct) {
  if (pct > 0 && pct < 0.1) return `${pct.toFixed(2)}%`;
  if (pct < 10) return `${pct.toFixed(1)}%`;
  return `${Math.round(pct)}%`;
}

function getDoughnutShares(values) {
  const total = values.reduce((sum, value) => sum + (Number(value) || 0), 0);
  return values.map((value) => {
    const count = Number(value) || 0;
    const pct = total > 0 ? (count / total) * 100 : 0;
    return { count, pct, total };
  });
}

function doughnutLegendLabels(chart) {
  const { labels } = chart.data;
  const dataset = chart.data.datasets[0];
  const shares = getDoughnutShares(dataset.data);
  const textColor = cssColor('--text', getTheme() === 'light' ? '#1a2332' : '#e7ecf3');

  return labels.map((label, index) => {
    const { count, pct } = shares[index];
    return {
      text: `${truncate(String(label), 32)} — ${count} (${formatSharePct(pct)})`,
      fillStyle: dataset.backgroundColor[index],
      strokeStyle: dataset.backgroundColor[index],
      fontColor: textColor,
      lineWidth: 0,
      hidden: !chart.getDataVisibility(index),
      index,
      datasetIndex: 0,
    };
  });
}

const doughnutPercentLabelsPlugin = {
  id: 'doughnutPercentLabels',
  afterDatasetsDraw(chart) {
    const meta = chart.getDatasetMeta(0);
    if (!meta?.data?.length) return;

    const values = chart.data.datasets[0].data;
    const shares = getDoughnutShares(values);
    if (shares[0]?.total <= 0) return;

    const { ctx } = chart;
    const textColor = getChartLabelColor();

    ctx.save();
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';

    meta.data.forEach((arc, index) => {
      const { count, pct } = shares[index];
      if (count <= 0 || pct < 10 || arc.hidden) return;

      const { x, y, startAngle, endAngle, outerRadius, innerRadius } = arc.getProps(
        ['x', 'y', 'startAngle', 'endAngle', 'outerRadius', 'innerRadius'],
        true,
      );

      const angle = (startAngle + endAngle) / 2;
      const arcSpan = endAngle - startAngle;
      const isCompact = pct < 6 || arcSpan < 0.22;
      const fontSize = pct < 3 ? 8 : pct < 6 ? 9 : 11;
      const label = formatSharePct(pct);

      ctx.font = `600 ${fontSize}px ${FONT_FAMILY}`;

      const ringWidth = outerRadius - innerRadius;
      const textHalf = ctx.measureText(label).width / 2;
      const radialInset = Math.max(2, Math.min(textHalf * 0.35, ringWidth * 0.15));
      const radiusFactor = isCompact ? 0.38 : 0.55;
      let radius = innerRadius + ringWidth * radiusFactor;
      radius = Math.min(radius, outerRadius - textHalf - radialInset);
      radius = Math.max(radius, innerRadius + radialInset);

      const labelX = x + Math.cos(angle) * radius;
      const labelY = y + Math.sin(angle) * radius;

      ctx.fillStyle = textColor;
      ctx.fillText(label, labelX, labelY);
    });

    ctx.restore();
  },
};

function formatHoursAxis(value) {
  if (value == null) return '';
  if (value < 24) return `${Math.round(value)} ч`;
  return `${(value / 24).toFixed(1)} д`;
}

export function renderHoursBarChart(canvasId, entries, limit) {
  const top = limit ? entries.slice(0, limit) : entries;
  const labels = top.map(e => truncate(e[0], 36));
  const values = top.map(e => e[1]);

  destroyChart(canvasId);
  const ctx = document.getElementById(canvasId);
  const wrap = ctx?.closest('.chart-wrap');
  if (wrap) {
    wrap.style.height = `${Math.max(260, top.length * 28 + 48)}px`;
  }

  setChart(canvasId, new Chart(ctx, {
    type: 'bar',
    data: {
      labels,
      datasets: [{
        data: values,
        backgroundColor: labels.map((_, i) => COLORS[i % COLORS.length]),
        borderRadius: 4,
      }],
    },
    options: {
      indexAxis: 'y',
      responsive: true,
      maintainAspectRatio: false,
      plugins: {
        legend: { display: false },
        tooltip: {
          callbacks: {
            label: (ctx) => ` ${formatHoursAxis(ctx.parsed.x)}`,
          },
        },
      },
      scales: {
        x: {
          beginAtZero: true,
          ticks: { callback: (value) => formatHoursAxis(Number(value)) },
        },
      },
    },
  }));
}

export function renderBarChart(canvasId, entries, variant = 'bar', limit = 10) {
  const top = entries.slice(0, limit);
  const labels = top.map(e => truncate(e[0], 40));
  const values = top.map(e => e[1]);
  const horizontal = variant === 'horizontalBar';

  destroyChart(canvasId);
  const ctx = document.getElementById(canvasId);

  setChart(canvasId, new Chart(ctx, {
    type: 'bar',
    data: {
      labels,
      datasets: [{
        data: values,
        backgroundColor: labels.map((_, i) => COLORS[i % COLORS.length]),
        borderRadius: 4,
      }],
    },
    options: {
      indexAxis: horizontal ? 'y' : 'x',
      responsive: true,
      maintainAspectRatio: false,
      plugins: { legend: { display: false } },
      scales: {
        x: { beginAtZero: true, ticks: horizontal ? { stepSize: 1 } : {} },
        y: { beginAtZero: true, ticks: !horizontal ? { stepSize: 1 } : {} },
      },
    },
  }));
}

export function renderDoughnut(canvasId, entries) {
  destroyChart(canvasId);
  const ctx = document.getElementById(canvasId);

  setChart(canvasId, new Chart(ctx, {
    type: 'doughnut',
    data: {
      labels: entries.map(e => e[0]),
      datasets: [{
        data: entries.map(e => e[1]),
        backgroundColor: entries.map((_, i) => COLORS[i % COLORS.length]),
        borderWidth: 0,
      }],
    },
    plugins: [doughnutPercentLabelsPlugin],
    options: {
      responsive: true,
      maintainAspectRatio: false,
      plugins: {
        legend: {
          position: 'right',
          align: 'center',
          labels: {
            boxWidth: 12,
            padding: 12,
            font: { size: 13, family: FONT_FAMILY },
            generateLabels: doughnutLegendLabels,
          },
        },
      },
    },
  }));
}
