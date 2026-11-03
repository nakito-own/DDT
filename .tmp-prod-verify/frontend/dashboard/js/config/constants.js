export const FONT_FAMILY = '"Golos Text", system-ui, -apple-system, sans-serif';

export const THEME_STORAGE_KEY = 'dashboard-theme';
export const SECTION_STORAGE_KEY = 'dashboard-section';
export const STP_VERSION_STORAGE_KEY = 'dashboard-stp-version';
export const SECTIONS = ['overview', 'analytics', 'table'];

export const ITSM_BASE = 'https://sc-tech-solutions.itsm.mos.ru/requests/';

export const COLORS = [
  '#3b82f6', '#22c55e', '#f59e0b', '#ef4444', '#a855f7',
  '#06b6d4', '#ec4899', '#84cc16', '#f97316', '#6366f1',
];

export const MULTI_FILTERS = [
  { key: 'state', label: 'Состояние' },
  { key: 'status', label: 'Статус' },
  { key: 'status4me', label: 'Статус 4me' },
  { key: 'type', label: 'Тип' },
  { key: 'block', label: 'Блок' },
  { key: 'problemCategory', label: 'Категория проблемы' },
  { key: 'member', label: 'Исполнитель' },
  { key: 'requestedBy', label: 'Заявитель' },
  { key: 'oiv', label: 'ОИВ' },
  { key: 'organization', label: 'Организация' },
  { key: 'module', label: 'Модуль' },
  { key: 'solved', label: 'Решено' },
  { key: 'userConfirmed', label: 'Подтверждение' },
  { key: 'errorSide', label: 'Сторона ошибки' },
  { key: 'statusGroup', label: 'Группа статуса' },
];

export const SEARCHABLE_KEYS = new Set([
  'organization', 'requestedBy', 'problemCategory', 'subject', 'member', 'oiv',
]);

export const STATE_LABELS = { closed: 'Закрыта', open: 'Открыта' };

export const STATUS_GROUP_LABELS = {
  closed: 'Закрыто',
  in_progress: 'В работе',
  waiting: 'Ожидание действий от клиента',
};
