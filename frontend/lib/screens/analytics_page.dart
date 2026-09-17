import 'package:bolt_ui_kit/bolt_kit.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import '../blocs/analytics/analytics_bloc.dart';
import '../models/analytics_dashboard.dart';
import '../models/analytics_filters.dart';
import '../theme/ddt_theme.dart';
import '../theme/ddt_typography.dart';
import '../widgets/analytics_charts.dart';
import '../widgets/analytics_filters_panel.dart';
import '../widgets/ddt_section_refresh.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  late final AnalyticsBloc _bloc;

  @override
  void initState() {
    super.initState();
    _bloc = AnalyticsBloc()..add(const AnalyticsLoadRequested());
  }

  @override
  void dispose() {
    _bloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bloc,
      child: BlocBuilder<AnalyticsBloc, AnalyticsState>(
        builder: (context, state) {
          if (state.isLoading && state.dashboard == null) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state.dashboard == null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    state.errorMessage ?? 'Не удалось загрузить аналитику',
                    textAlign: TextAlign.center,
                    style: DdtTheme.style(
                      fontSize: DdtTypography.bodyLargeSize,
                      color: DdtTheme.textSecondary(context),
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Button(
                    text: 'Повторить',
                    onPressed: () =>
                        _bloc.add(const AnalyticsLoadRequested()),
                    borderRadius: DdtTheme.radius,
                  ),
                ],
              ),
            );
          }

          return DdtSectionRefreshOverlay(
            isRefreshing: state.isRefreshing,
            child: _AnalyticsDashboardView(
              dashboard: state.visibleDashboard!,
              source: state.dashboard!,
              filters: state.filters,
              errorMessage: state.errorMessage,
              onRefresh: () => _bloc.add(const AnalyticsRefreshRequested()),
              onDateColumnChanged: (key) =>
                  _bloc.add(AnalyticsDateColumnChanged(key)),
              onPeriodChanged: (start, end) => _bloc.add(
                AnalyticsPeriodChanged(start: start, end: end),
              ),
              onValueToggled: (column, value) => _bloc.add(
                AnalyticsColumnValueToggled(
                  columnKey: column,
                  valueKey: value,
                ),
              ),
              onFiltersCleared: () =>
                  _bloc.add(const AnalyticsFiltersCleared()),
            ),
          );
        },
      ),
    );
  }
}

class _AnalyticsDashboardView extends StatelessWidget {
  const _AnalyticsDashboardView({
    required this.dashboard,
    required this.source,
    required this.filters,
    required this.onRefresh,
    required this.onDateColumnChanged,
    required this.onPeriodChanged,
    required this.onValueToggled,
    required this.onFiltersCleared,
    this.errorMessage,
  });

  final AnalyticsDashboard dashboard;
  final AnalyticsDashboard source;
  final AnalyticsFilters filters;
  final VoidCallback onRefresh;
  final ValueChanged<String> onDateColumnChanged;
  final void Function(DateTime? start, DateTime? end) onPeriodChanged;
  final void Function(String column, String value) onValueToggled;
  final VoidCallback onFiltersCleared;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final fetched = DateFormat('dd.MM.yyyy HH:mm').format(
      dashboard.fetchedAt.toLocal(),
    );

    final dateLabel = filters.resolvedDateColumn(source.columns);
    final activeFilters = filters.hasPeriod || filters.hasColumnFilters;

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 980;
        final showSideFilters = constraints.maxWidth >= 860;
        final chartHeight = wide ? 320.h : 280.h;

        final dashboardScroll = CustomScrollView(
          slivers: [
            SliverPadding(
              padding: EdgeInsets.only(bottom: 12.h),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Обработка заявок 4me',
                            style: DdtTheme.style(
                              fontSize: DdtTypography.panelTitleSize,
                              fontWeight: FontWeight.w800,
                              color: DdtTheme.textPrimary(context),
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            activeFilters
                                ? 'Лист «${dashboard.sheetName}» · ${dashboard.kpis.total} заявок после фильтра · обновлено $fetched'
                                : 'Лист «${dashboard.sheetName}» · обновлено $fetched',
                            style: DdtTheme.style(
                              fontSize: DdtTypography.captionSize,
                              color: DdtTheme.textMuted(context),
                            ),
                          ),
                          if (errorMessage != null)
                            Padding(
                              padding: EdgeInsets.only(top: 6.h),
                              child: Text(
                                errorMessage!,
                                style: DdtTheme.style(
                                  fontSize: DdtTypography.captionSize,
                                  color: const Color(0xFFC62828),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Обновить',
                      onPressed: onRefresh,
                      icon: Icon(
                        CupertinoIcons.arrow_clockwise,
                        color: AppColors.primary,
                        size: 22.sp,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(child: _KpiGrid(kpis: dashboard.kpis)),
            SliverPadding(
              padding: EdgeInsets.only(top: 12.h),
              sliver: SliverToBoxAdapter(
                child: _ResponsivePair(
                  wide: wide,
                  height: chartHeight,
                  left: AnalyticsPanel(
                    title: 'Статусы',
                    subtitle: 'Текущее распределение заявок',
                    child: AnalyticsDonutChart(points: dashboard.series.status),
                  ),
                  right: AnalyticsPanel(
                    title: 'Типы обращений',
                    subtitle: 'Ошибка, консультация, доступ и доработки',
                    child: AnalyticsBarChart(points: dashboard.series.type),
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.only(top: 12.h),
              sliver: SliverToBoxAdapter(
                child: _ResponsivePair(
                  wide: wide,
                  height: chartHeight,
                  left: AnalyticsPanel(
                    title: 'Блоки системы',
                    subtitle: 'Где чаще всего возникают заявки',
                    child: AnalyticsBarChart(points: dashboard.series.block),
                  ),
                  right: AnalyticsPanel(
                    title: 'Основные темы',
                    subtitle: 'Повторяющиеся формулировки заявок',
                    child: AnalyticsBarChart(
                      points: dashboard.series.topics,
                      colorForIndex: (index) => analyticsSeriesColor(index + 2),
                    ),
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.only(top: 12.h),
              sliver: SliverToBoxAdapter(
                child: SizedBox(
                  height: 280.h,
                  child: AnalyticsPanel(
                    title: 'Появление заявок по неделям',
                    subtitle: dateLabel.isEmpty
                        ? 'По дате из таблицы'
                        : 'По колонке «$dateLabel»',
                    child: AnalyticsWeeklyChart(
                      points: dashboard.series.createdWeekly,
                    ),
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.only(top: 12.h),
              sliver: SliverToBoxAdapter(
                child: SizedBox(
                  height: chartHeight,
                  child: AnalyticsPanel(
                    title: 'Категории',
                    subtitle: 'Топ категорий из таблицы',
                    child: AnalyticsBarChart(
                      points: dashboard.series.category,
                      colorForIndex: (index) => analyticsSeriesColor(index + 4),
                    ),
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.only(top: 12.h, bottom: 8.h),
              sliver: SliverToBoxAdapter(
                child: AnalyticsPanel(
                  title: 'Последние заявки',
                  expandChild: false,
                  child: _RecentTickets(tickets: dashboard.recent),
                ),
              ),
            ),
          ],
        );

        final filtersPanel = AnalyticsFiltersPanel(
          columns: source.columns,
          filters: filters,
          tickets: source.applications,
          onDateColumnChanged: onDateColumnChanged,
          onPeriodChanged: onPeriodChanged,
          onValueToggled: onValueToggled,
          onCleared: onFiltersCleared,
        );

        if (!showSideFilters) {
          return Column(
            children: [
              SizedBox(height: 280.h, child: filtersPanel),
              SizedBox(height: 12.h),
              Container(height: 1, color: DdtTheme.sidePanelDivider(context)),
              SizedBox(height: 12.h),
              Expanded(child: dashboardScroll),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: 300.w, child: filtersPanel),
            SizedBox(width: 12.w),
            Container(width: 1, color: DdtTheme.sidePanelDivider(context)),
            SizedBox(width: 12.w),
            Expanded(child: dashboardScroll),
          ],
        );
      },
    );
  }
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.kpis});

  final AnalyticsKpis kpis;

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        'Всего',
        '${kpis.total}',
        AppColors.primary,
        kpis.sheetTotal != null && kpis.sheetTotal != kpis.total
            ? 'в сводке листа: ${kpis.sheetTotal}'
            : null,
      ),
      ('Открытые', '${kpis.open}', const Color(0xFF00838F), null),
      ('В процессе', '${kpis.inProgress}', const Color(0xFF1976D2), null),
      (
        'Ожидание клиента',
        '${kpis.waitingCustomer}',
        const Color(0xFFF9A825),
        kpis.sheetWaitingLeft != null
            ? 'осталось по сводке: ${kpis.sheetWaitingLeft}'
            : null,
      ),
      ('Завершено', '${kpis.completed}', const Color(0xFF2E7D32), null),
      (
        'Срок закрытия',
        kpis.avgCloseDays == null ? '—' : '${kpis.avgCloseDays} дн.',
        const Color(0xFF7B1FA2),
        'среднее по закрытым',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1100
            ? 6
            : constraints.maxWidth >= 760
            ? 3
            : 2;
        const gap = 12.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final item in items)
              SizedBox(
                width: width,
                child: AnalyticsKpiCard(
                  label: item.$1,
                  value: item.$2,
                  color: item.$3,
                  hint: item.$4,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ResponsivePair extends StatelessWidget {
  const _ResponsivePair({
    required this.wide,
    required this.height,
    required this.left,
    required this.right,
  });

  final bool wide;
  final double height;
  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    if (!wide) {
      return Column(
        children: [
          SizedBox(height: height, child: left),
          SizedBox(height: 12.h),
          SizedBox(height: height, child: right),
        ],
      );
    }

    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: left),
          SizedBox(width: 12.w),
          Expanded(child: right),
        ],
      ),
    );
  }
}

class _RecentTickets extends StatelessWidget {
  const _RecentTickets({required this.tickets});

  final List<AnalyticsTicket> tickets;

  @override
  Widget build(BuildContext context) {
    if (tickets.isEmpty) {
      return Text(
        'Нет заявок для отображения',
        style: DdtTheme.style(color: DdtTheme.textMuted(context)),
      );
    }

    final dateFormat = DateFormat('dd.MM.yyyy');
    return Column(
      children: [
        for (var index = 0; index < tickets.length; index++) ...[
          if (index > 0) SizedBox(height: 8.h),
          _RecentTicketRow(ticket: tickets[index], dateFormat: dateFormat),
        ],
      ],
    );
  }
}

class _RecentTicketRow extends StatelessWidget {
  const _RecentTicketRow({required this.ticket, required this.dateFormat});

  final AnalyticsTicket ticket;
  final DateFormat dateFormat;

  @override
  Widget build(BuildContext context) {
    final status = ticket.statusBucket ?? ticket.status ?? '—';
    return DecoratedBox(
      decoration: BoxDecoration(
        color: DdtTheme.textMuted(context).withValues(alpha: 0.06),
        borderRadius: DdtTheme.radius,
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
        child: Row(
          children: [
            SizedBox(
              width: 86.w,
              child: Text(
                ticket.ticketId,
                style: DdtTheme.style(
                  fontSize: DdtTypography.labelSmallSize,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
            Expanded(
              child: Text(
                ticket.subject ?? 'Без темы',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DdtTheme.style(
                  fontSize: DdtTypography.bodySize,
                  color: DdtTheme.textPrimary(context),
                ),
              ),
            ),
            SizedBox(width: 12.w),
            if (ticket.type != null)
              Padding(
                padding: EdgeInsets.only(right: 12.w),
                child: Text(
                  ticket.type!,
                  style: DdtTheme.style(
                    fontSize: DdtTypography.captionSize,
                    color: DdtTheme.textMuted(context),
                  ),
                ),
              ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: analyticsStatusColor(status).withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                status,
                style: DdtTheme.style(
                  fontSize: DdtTypography.microSize,
                  fontWeight: FontWeight.w700,
                  color: analyticsStatusColor(status),
                ),
              ),
            ),
            SizedBox(width: 12.w),
            SizedBox(
              width: 72.w,
              child: Text(
                ticket.createdAt == null
                    ? '—'
                    : dateFormat.format(ticket.createdAt!),
                textAlign: TextAlign.right,
                style: DdtTheme.style(
                  fontSize: DdtTypography.captionSize,
                  color: DdtTheme.textMuted(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
