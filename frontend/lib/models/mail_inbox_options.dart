enum MailInboxFilter {
  all,
  toMe,
  flagged,
  mentions;

  String get apiValue => switch (this) {
        MailInboxFilter.all => 'all',
        MailInboxFilter.toMe => 'to_me',
        MailInboxFilter.flagged => 'flagged',
        MailInboxFilter.mentions => 'mentions',
      };

  String get label => switch (this) {
        MailInboxFilter.all => 'Все',
        MailInboxFilter.toMe => 'Мне',
        MailInboxFilter.flagged => 'Помеченные',
        MailInboxFilter.mentions => 'Упоминания',
      };
}

enum MailInboxSort {
  dateAsc,
  dateDesc,
  fromAddress,
  toAddress,
  subject,
  attachments,
  importance;

  String get apiValue => switch (this) {
        MailInboxSort.dateAsc => 'date_asc',
        MailInboxSort.dateDesc => 'date_desc',
        MailInboxSort.fromAddress => 'from',
        MailInboxSort.toAddress => 'to',
        MailInboxSort.subject => 'subject',
        MailInboxSort.attachments => 'attachments',
        MailInboxSort.importance => 'importance',
      };

  String get label => switch (this) {
        MailInboxSort.dateAsc => 'Дата по возрастанию',
        MailInboxSort.dateDesc => 'Дата по убыванию',
        MailInboxSort.fromAddress => 'От',
        MailInboxSort.toAddress => 'Кому',
        MailInboxSort.subject => 'Тема',
        MailInboxSort.attachments => 'Вложения',
        MailInboxSort.importance => 'Важность',
      };
}
