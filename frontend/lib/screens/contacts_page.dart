import 'package:bolt_ui_kit/bolt_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../blocs/contacts/contacts_bloc.dart';
import '../models/contact.dart';
import '../theme/ddt_theme.dart';
import '../widgets/ddt_app_input.dart';
import '../theme/ddt_typography.dart';

class ContactsPage extends StatefulWidget {
  const ContactsPage({super.key});

  @override
  State<ContactsPage> createState() => _ContactsPageState();
}

class _ContactsPageState extends State<ContactsPage> {
  late final ContactsBloc _bloc;

  @override
  void initState() {
    super.initState();
    _bloc = ContactsBloc()..add(const ContactsLoadRequested());
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
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.only(bottom: 12.h),
            child: DdtAppInput(
              hint: 'Поиск контактов',
              type: InputType.search,
              variant: DdtInputVariant.pill,
              prefixIcon: Icons.search,
              onChanged: (value) =>
                  _bloc.add(ContactsSearchQueryChanged(value)),
            ),
          ),
          Expanded(
            child: BlocBuilder<ContactsBloc, ContactsState>(
              builder: (context, state) {
                if (state.isLoading && state.contacts.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (state.errorMessage != null && state.contacts.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(state.errorMessage!),
                        SizedBox(height: 12.h),
                        Button(
                          text: 'Повторить',
                          onPressed: () =>
                              _bloc.add(const ContactsLoadRequested()),
                          borderRadius: DdtTheme.radius,
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async =>
                      _bloc.add(const ContactsLoadRequested()),
                  child: DdtTheme.glass(
                    context: context,
                    padding: EdgeInsets.all(16.w),
                    child: state.contacts.isEmpty
                        ? ListView(
                            children: [
                              SizedBox(height: 120.h),
                              Center(
                                child: Text(
                                  'Контакты не найдены',
                                  style: DdtTheme.style(
                                    fontSize: DdtTypography.bodyLargeSize,
                                  ),
                                ),
                              ),
                            ],
                          )
                        : ListView.separated(
                            itemCount: state.contacts.length,
                            separatorBuilder: (_, __) => SizedBox(height: 8.h),
                            itemBuilder: (context, index) {
                              return ContactListItem(
                                contact: state.contacts[index],
                              );
                            },
                          ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class ContactListItem extends StatelessWidget {
  const ContactListItem({super.key, required this.contact});

  final Contact contact;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      type: CardType.outlined,
      borderRadius: DdtTheme.radius,
      padding: EdgeInsets.all(14.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            contact.displayName,
            style: DdtTheme.style(
              fontSize: DdtTypography.bodyLargeSize,
              fontWeight: FontWeight.w700,
              color: DdtTheme.taskCardTextPrimary(context),
            ),
          ),
          if (contact.emails.isNotEmpty) ...[
            SizedBox(height: 6.h),
            ...contact.emails.map(
              (email) => Text(
                email,
                style: DdtTheme.style(fontSize: DdtTypography.labelSize),
              ),
            ),
          ],
          if (contact.phones.isNotEmpty) ...[
            SizedBox(height: 6.h),
            ...contact.phones.map(
              (phone) => Text(
                phone,
                style: DdtTheme.style(
                  fontSize: DdtTypography.labelSize,
                  color: DdtTheme.taskCardTextSecondary(context),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
