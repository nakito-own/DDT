import 'package:bolt_ui_kit/bolt_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../models/app_section.dart';
import '../theme/ddt_theme.dart';
import '../widgets/ddt_shell_layout.dart';
import 'calendar_page.dart';
import 'contacts_page.dart';
import 'mail_page.dart';
import 'settings_page.dart';
import 'tasks_shell_page.dart';

class MainShellPage extends StatefulWidget {
  const MainShellPage({super.key});

  @override
  State<MainShellPage> createState() => _MainShellPageState();
}

class _MainShellPageState extends State<MainShellPage> {
  AppSection _selectedSection = AppSection.tasks;

  @override
  Widget build(BuildContext context) {
    return DdtShellLayout(
      title: _selectedSection.label,
      selectedSection: _selectedSection,
      onSectionSelected: (section) => setState(() => _selectedSection = section),
      child: _buildSectionContent(),
    );
  }

  Widget _buildSectionContent() {
    switch (_selectedSection) {
      case AppSection.tasks:
        return const TasksShellPage();
      case AppSection.mail:
        return const MailPage();
      case AppSection.calendar:
        return const CalendarPage();
      case AppSection.contacts:
        return const ContactsPage();
      case AppSection.space:
      case AppSection.automations:
      case AppSection.linkArchive:
        return _PlaceholderSection(section: _selectedSection);
      case AppSection.settings:
        return const SettingsPage();
    }
  }
}

class _PlaceholderSection extends StatelessWidget {
  const _PlaceholderSection({required this.section});

  final AppSection section;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AppCard(
        type: CardType.outlined,
        borderRadius: DdtTheme.radius,
        padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 24.h),
        child: Text(
          'Раздел «${section.label}» в разработке',
          style: DdtTheme.style(
            fontSize: 16.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.primary,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
