import { SECTIONS, SECTION_STORAGE_KEY } from '../../config/constants.js';
import { resizeCharts } from '../../charts/registry.js';

function getVisibleSections() {
  const layout = document.querySelector('.dataset-layout:not([hidden])');
  return layout ? layout.querySelectorAll('.dashboard-section') : [];
}

export function setSection(section) {
  const next = SECTIONS.includes(section) ? section : 'overview';

  getVisibleSections().forEach(el => {
    el.hidden = el.dataset.section !== next;
  });

  document.querySelectorAll('.section-tab').forEach(btn => {
    const isActive = btn.dataset.section === next;
    btn.classList.toggle('active', isActive);
    btn.setAttribute('aria-selected', isActive ? 'true' : 'false');
  });

  localStorage.setItem(SECTION_STORAGE_KEY, next);

  if (next === 'overview') {
    requestAnimationFrame(resizeCharts);
  }
}

export function initSections() {
  const saved = localStorage.getItem(SECTION_STORAGE_KEY);
  setSection(SECTIONS.includes(saved) ? saved : 'overview');

  document.querySelector('.section-nav').addEventListener('click', (e) => {
    const btn = e.target.closest('.section-tab');
    if (btn) setSection(btn.dataset.section);
  });
}
