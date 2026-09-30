import { COLORS } from '../../config/constants.js';
import { destroyChart, setChart } from '../../charts/registry.js';
import { renderBarChart, renderDoughnut } from '../../charts/basic.js';

function renderFourmeTrendChartFromBuckets(trend, groupBy) {
  const chartType = document.getElementById('fourme-trend-chart-type').value;
  const { labels, created, closed } = trend;
  const isLine = chartType === 'line';

  destroyChart('fourme-chart-trend');
  const ctx = document.getElementById('fourme-chart-trend');
  setChart('fourme-chart-trend', new Chart(ctx, {
    type: isLine ? 'line' : 'bar',
    data: {
      labels,
      datasets: isLine
        ? [
            { label: 'Создано', data: created, borderColor: COLORS[0], backgroundColor: 'rgba(59,130,246,0.15)', fill: true, tension: 0.3 },
            { label: 'Закрыто', data: closed, borderColor: COLORS[1], backgroundColor: 'rgba(34,197,94,0.1)', fill: true, tension: 0.3 },
          ]
        : [
            { label: 'Создано', data: created, backgroundColor: COLORS[0], borderRadius: 4, maxBarThickness: 28 },
            { label: 'Закрыто', data: closed, backgroundColor: COLORS[1], borderRadius: 4, maxBarThickness: 28 },
          ],
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      plugins: { legend: { position: 'top' } },
      scales: {
        x: { ticks: { maxRotation: groupBy === 'day' ? 45 : 0, autoSkip: true } },
        y: { beginAtZero: true, ticks: { stepSize: 1 } },
      },
    },
  }));
}

export function updateFourmeChartsFromPayload(charts) {
  const groupBy = document.getElementById('fourme-trend-group-by').value;
  renderFourmeTrendChartFromBuckets(charts.trend, groupBy);
  renderDoughnut('fourme-chart-status', charts.status);
  renderDoughnut('fourme-chart-category', charts.category);
  renderBarChart('fourme-chart-service', charts.service, 'horizontalBar', 10);
  renderBarChart('fourme-chart-member', charts.member, 'horizontalBar', 10);
  renderBarChart('fourme-chart-source', charts.source, 'bar', 10);
  renderBarChart('fourme-chart-completion', charts.completion, 'bar', 10);
  renderDoughnut('fourme-chart-impact', charts.impact);
  renderBarChart('fourme-chart-agile', charts.agile, 'bar', 10);
}
