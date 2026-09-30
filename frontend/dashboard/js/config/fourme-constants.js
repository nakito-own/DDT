export const FOURME_FILTERS = [
  { key: 'statusLabel', label: 'Статус' },
  { key: 'categoryLabel', label: 'Тип запроса' },
  { key: 'impactLabel', label: 'Impact' },
  { key: 'serviceShort', label: 'Сервис' },
  { key: 'memberShort', label: 'Исполнитель' },
  { key: 'source', label: 'Источник' },
  { key: 'organization', label: 'Организация' },
  { key: 'completionReasonLabel', label: 'Причина закрытия' },
  { key: 'team', label: 'Команда' },
  { key: 'agileColumn', label: 'Agile-колонка' },
];

export const FOURME_SEARCHABLE_KEYS = new Set(['organization', 'requestedBy', 'subject', 'memberShort', 'serviceShort']);

export const FOURME_DATE_FIELDS = [
  { value: 'createdAt', label: 'Дата создания' },
  { value: 'completedAt', label: 'Дата закрытия' },
  { value: 'updatedAt', label: 'Дата обновления' },
  { value: 'resolutionTarget', label: 'Целевой срок (SLA)' },
];
