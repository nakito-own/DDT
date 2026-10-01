import 'dart:math' as math;

import 'package:bolt_ui_kit/bolt_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/analytics_dashboard.dart';
import '../theme/ddt_theme.dart';
import '../theme/ddt_typography.dart';
import '../utils/analytics_formatters.dart';
import 'analytics_charts.dart';

const _successColor = analyticsPositiveColor;
const _warningColor = Color(0xFFF9A825);
const _dangerColor = Color(0xFFC62828);
const _purpleColor = Color(0xFF7B1FA2);

class AnalyticsTableColumn {
  const AnalyticsTableColumn(
    this.title, {
    this.width = 110,
    this.align = TextAlign.left,
  });

  final String title;
  final double width;
  final TextAlign align;
}

/// Scrollable table with a sticky header, stretched to the available width.
class AnalyticsDataTable extends StatelessWidget {
  const AnalyticsDataTable({
    super.key,
    required this.columns,
    required this.rows,
    this.maxHeight = 520,
  });

  final List<AnalyticsTableColumn> columns;
  final List<List<Widget>> rows;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return SizedBox(height: 80.h, child: const AnalyticsEmptyChart());
    }

    final borderColor = DdtTheme.textMuted(context).withValues(alpha: 0.14);
    final baseWidth = columns.fold<double>(
      0,
      (sum, column) => sum + column.width,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = math.max(1.0, constraints.maxWidth / baseWidth);
        final widths = [for (final column in columns) column.width * scale];

        Widget cell(int index, Widget child, {bool header = false}) {
          return SizedBox(
            width: widths[index],
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 8.w,
                vertical: header ? 8.h : 7.h,
              ),
              child: Align(
                alignment: switch (columns[index].align) {
                  TextAlign.center => Alignment.center,
                  TextAlign.right => Alignment.centerRight,
                  _ => Alignment.centerLeft,
                },
                child: child,
              ),
            ),
          );
        }

        final header = DecoratedBox(
          decoration: BoxDecoration(
            color: DdtTheme.textMuted(context).withValues(alpha: 0.07),
            border: Border(bottom: BorderSide(color: borderColor)),
          ),
          child: Row(
            children: [
              for (var i = 0; i < columns.length; i++)
                cell(
                  i,
                  Text(
                    columns[i].title.toUpperCase(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: columns[i].align,
                    style: DdtTheme.style(
                      fontSize: DdtTypography.microSize,
                      fontWeight: FontWeight.w700,
                      color: DdtTheme.textMuted(context),
                    ),
                  ),
                  header: true,
                ),
            ],
          ),
        );

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: widths.fold<double>(0, (sum, width) => sum + width),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxHeight.h),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  header,
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: rows.length,
                      itemBuilder: (context, rowIndex) => _HoverRow(
                        borderColor: borderColor,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            for (var i = 0; i < columns.length; i++)
                              cell(i, rows[rowIndex][i]),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HoverRow extends StatefulWidget {
  const _HoverRow({required this.borderColor, required this.child});

  final Color borderColor;
  final Widget child;

  @override
  State<_HoverRow> createState() => _HoverRowState();
}

class _HoverRowState extends State<_HoverRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _hovered
              ? AppColors.primary.withValues(alpha: 0.05)
              : Colors.transparent,
          border: Border(bottom: BorderSide(color: widget.borderColor)),
        ),
        child: widget.child,
      ),
    );
  }
}

class _CellText extends StatelessWidget {
  const _CellText(
    this.text, {
    this.align = TextAlign.left,
    this.bold = false,
    this.muted = false,
    this.tooltip = false,
  });

  final String text;
  final TextAlign align;
  final bool bold;
  final bool muted;
  final bool tooltip;

  @override
  Widget build(BuildContext context) {
    final label = Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: align,
      style: DdtTheme.style(
        fontSize: DdtTypography.labelSmallSize,
        fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
        color: muted
            ? DdtTheme.textMuted(context)
            : DdtTheme.textPrimary(context),
      ),
    );
    if (!tooltip || text.length < 24) return label;
    return Tooltip(
      message: text,
      waitDuration: const Duration(milliseconds: 400),
      child: label,
    );
  }
}

class _TicketLink extends StatelessWidget {
  const _TicketLink({required this.id, required this.url});

  final String id;
  final String? url;

  @override
  Widget build(BuildContext context) {
    final style = DdtTheme.style(
      fontSize: DdtTypography.labelSmallSize,
      fontWeight: FontWeight.w600,
      color: AppColors.primary,
    );
    final target = url;
    if (target == null || target.isEmpty) return Text(id, style: style);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () =>
            launchUrl(Uri.parse(target), mode: LaunchMode.externalApplication),
        child: Text(id, style: style),
      ),
    );
  }
}

class _TicketLinks extends StatelessWidget {
  const _TicketLinks({required this.ids, required this.baseUrl});

  final List<String> ids;
  final String baseUrl;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6.w,
      runSpacing: 2.h,
      children: [
        for (final id in ids)
          _TicketLink(id: id, url: baseUrl.isEmpty ? null : '$baseUrl$id'),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.label, this.color);

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tint = color;
    if (tint == null) return _CellText(label);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: isDark ? 0.22 : 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label.toUpperCase(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: DdtTheme.style(
          fontSize: DdtTypography.microSize,
          fontWeight: FontWeight.w700,
          color: tint,
        ),
      ),
    );
  }
}

const _numColumn = AnalyticsTableColumn(
  '№',
  width: 44,
  align: TextAlign.center,
);

Widget _rowNumber(int index) =>
    _CellText('${index + 1}', align: TextAlign.center, muted: true);

/// Aggregates by category / block / error side («Сводная аналитика»).
class AnalyticsGroupTable extends StatelessWidget {
  const AnalyticsGroupTable({
    super.key,
    required this.nameTitle,
    required this.rows,
    required this.itsmBaseUrl,
  });

  final String nameTitle;
  final List<AnalyticsGroupRow> rows;
  final String itsmBaseUrl;

  @override
  Widget build(BuildContext context) {
    return AnalyticsDataTable(
      columns: [
        _numColumn,
        AnalyticsTableColumn(nameTitle, width: 240),
        const AnalyticsTableColumn('Кол-во', width: 70, align: TextAlign.right),
        const AnalyticsTableColumn('Доля', width: 70, align: TextAlign.right),
        const AnalyticsTableColumn(
          'Ср. обработка',
          width: 100,
          align: TextAlign.right,
        ),
        const AnalyticsTableColumn(
          'Ср. реакция',
          width: 90,
          align: TextAlign.right,
        ),
        const AnalyticsTableColumn(
          'Закрыто',
          width: 76,
          align: TextAlign.right,
        ),
        const AnalyticsTableColumn(
          'В работе',
          width: 76,
          align: TextAlign.right,
        ),
        const AnalyticsTableColumn(
          'Ожидание действий от клиента',
          width: 130,
          align: TextAlign.right,
        ),
        const AnalyticsTableColumn('Примеры ID', width: 360),
      ],
      rows: [
        for (var i = 0; i < rows.length; i++)
          [
            _rowNumber(i),
            _CellText(rows[i].name, tooltip: true),
            _CellText('${rows[i].count}', align: TextAlign.right, bold: true),
            _CellText(
              formatAnalyticsShare(rows[i].share),
              align: TextAlign.right,
            ),
            _CellText(
              formatAnalyticsDuration(rows[i].avgResolutionHours),
              align: TextAlign.right,
            ),
            _CellText(
              formatAnalyticsReaction(rows[i].avgReactionHours),
              align: TextAlign.right,
            ),
            _CellText('${rows[i].closed}', align: TextAlign.right),
            _CellText('${rows[i].inProgress}', align: TextAlign.right),
            _CellText('${rows[i].waiting}', align: TextAlign.right),
            _TicketLinks(ids: rows[i].exampleIds, baseUrl: itsmBaseUrl),
          ],
      ],
    );
  }
}

class AnalyticsOivWaitingTable extends StatelessWidget {
  const AnalyticsOivWaitingTable({
    super.key,
    required this.rows,
    required this.itsmBaseUrl,
  });

  final List<AnalyticsOivWaitingRow> rows;
  final String itsmBaseUrl;

  @override
  Widget build(BuildContext context) {
    return AnalyticsDataTable(
      columns: const [
        _numColumn,
        AnalyticsTableColumn('ОИВ', width: 240),
        AnalyticsTableColumn('Эпизодов', width: 80, align: TextAlign.right),
        AnalyticsTableColumn(
          'Сейчас в ожидании',
          width: 110,
          align: TextAlign.right,
        ),
        AnalyticsTableColumn('Ср. время', width: 90, align: TextAlign.right),
        AnalyticsTableColumn('Медиана', width: 90, align: TextAlign.right),
        AnalyticsTableColumn('Макс.', width: 90, align: TextAlign.right),
        AnalyticsTableColumn('Примеры ID', width: 360),
      ],
      rows: [
        for (var i = 0; i < rows.length; i++)
          [
            _rowNumber(i),
            _CellText(rows[i].name, tooltip: true),
            _CellText(
              '${rows[i].episodeCount}',
              align: TextAlign.right,
              bold: true,
            ),
            _CellText('${rows[i].openWaiting}', align: TextAlign.right),
            _CellText(
              formatAnalyticsDuration(rows[i].avgWaitingHours),
              align: TextAlign.right,
            ),
            _CellText(
              formatAnalyticsDuration(rows[i].medianWaitingHours),
              align: TextAlign.right,
            ),
            _CellText(
              formatAnalyticsDuration(rows[i].maxWaitingHours),
              align: TextAlign.right,
            ),
            _TicketLinks(ids: rows[i].exampleIds, baseUrl: itsmBaseUrl),
          ],
      ],
    );
  }
}

class AnalyticsCrossMatrixTable extends StatelessWidget {
  const AnalyticsCrossMatrixTable({super.key, required this.matrix});

  final AnalyticsCrossMatrix matrix;

  @override
  Widget build(BuildContext context) {
    if (matrix.isEmpty) {
      return AnalyticsDataTable(columns: const [_numColumn], rows: const []);
    }
    return AnalyticsDataTable(
      maxHeight: 620,
      columns: [
        _numColumn,
        const AnalyticsTableColumn('Категория \\ Блок', width: 240),
        for (final col in matrix.cols)
          AnalyticsTableColumn(col, width: 96, align: TextAlign.center),
        const AnalyticsTableColumn('Итого', width: 70, align: TextAlign.center),
      ],
      rows: [
        for (var i = 0; i < matrix.rows.length; i++)
          [
            _rowNumber(i),
            _CellText(matrix.rows[i], bold: true, tooltip: true),
            for (final value in _rowValues(i))
              _CellText(
                value == 0 ? '·' : '$value',
                align: TextAlign.center,
                muted: value == 0,
              ),
            _CellText(
              '${_rowValues(i).fold<int>(0, (sum, value) => sum + value)}',
              align: TextAlign.center,
              bold: true,
            ),
          ],
      ],
    );
  }

  List<int> _rowValues(int index) {
    final values = index < matrix.values.length
        ? matrix.values[index]
        : const <int>[];
    return [
      for (var col = 0; col < matrix.cols.length; col++)
        col < values.length ? values[col] : 0,
    ];
  }
}

/// «Таблица заявок».
class AnalyticsRequestsTable extends StatelessWidget {
  const AnalyticsRequestsTable({super.key, required this.rows});

  final List<AnalyticsTableRow> rows;

  static Color? _typeColor(String? type) => switch (type) {
    'Ошибка' => _dangerColor,
    'Консультация' => _warningColor,
    'Доработка' => _purpleColor,
    _ => null,
  };

  Widget _sla(AnalyticsTableRow row) {
    final (label, color) = switch (row.slaMet) {
      true => ('✓', _successColor),
      false => ('✗', _dangerColor),
      null when row.isOverdue => ('⚠', _warningColor),
      null => ('—', null),
    };
    return Builder(
      builder: (context) => Text(
        label,
        style: DdtTheme.style(
          fontSize: DdtTypography.labelSize,
          fontWeight: FontWeight.w700,
          color: color ?? DdtTheme.textMuted(context),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnalyticsDataTable(
      maxHeight: 640,
      columns: const [
        AnalyticsTableColumn('ID', width: 90),
        AnalyticsTableColumn('Состояние', width: 100),
        AnalyticsTableColumn('Тип', width: 130),
        AnalyticsTableColumn('Блок', width: 130),
        AnalyticsTableColumn('Категория', width: 220),
        AnalyticsTableColumn('Тема', width: 260),
        AnalyticsTableColumn('Исполнитель', width: 150),
        AnalyticsTableColumn('Заявитель', width: 180),
        AnalyticsTableColumn('ОИВ', width: 160),
        AnalyticsTableColumn('Создана', width: 96),
        AnalyticsTableColumn('Закрыта', width: 96),
        AnalyticsTableColumn('Обработка', width: 86, align: TextAlign.right),
        AnalyticsTableColumn('Реакция', width: 80, align: TextAlign.right),
        AnalyticsTableColumn('Сторона', width: 120),
        AnalyticsTableColumn('SLA', width: 50, align: TextAlign.center),
      ],
      rows: [
        for (final row in rows)
          [
            _TicketLink(id: row.id, url: row.permalink),
            _Badge(
              row.stateLabel,
              row.isClosed ? _successColor : AppColors.primary,
            ),
            _Badge(row.type ?? '—', _typeColor(row.type)),
            _CellText(row.block ?? '—', tooltip: true),
            _CellText(row.problemCategory ?? '—', tooltip: true),
            _CellText(row.subject ?? '—', tooltip: true),
            _CellText(row.member ?? '—', tooltip: true),
            _CellText(row.requestedBy ?? '—', tooltip: true),
            _CellText(row.oiv ?? '—', tooltip: true),
            _CellText(formatAnalyticsDate(row.createdAt)),
            _CellText(formatAnalyticsDate(row.completedAt)),
            _CellText(
              formatAnalyticsDuration(row.resolutionHours),
              align: TextAlign.right,
            ),
            _CellText(
              formatAnalyticsReaction(row.reactionHours),
              align: TextAlign.right,
            ),
            _CellText(row.errorSide ?? '—'),
            _sla(row),
          ],
      ],
    );
  }
}
