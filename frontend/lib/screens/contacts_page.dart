import 'package:bolt_ui_kit/bolt_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../controllers/contacts_controller.dart';
import '../models/contact.dart';
import '../theme/ddt_theme.dart';

class ContactsPage extends StatelessWidget {
  const ContactsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(ContactsController());

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: 12.h),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Поиск контактов',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: DdtTheme.radius),
            ),
            onChanged: controller.updateSearch,
          ),
        ),
        Expanded(
          child: Obx(() {
            if (controller.isLoading.value && controller.contacts.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            if (controller.errorMessage.value != null &&
                controller.contacts.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(controller.errorMessage.value!),
                    SizedBox(height: 12.h),
                    Button(
                      text: 'Повторить',
                      onPressed: controller.loadContacts,
                      borderRadius: DdtTheme.radius,
                    ),
                  ],
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: controller.loadContacts,
              child: DdtTheme.glass(
                context: context,
                padding: EdgeInsets.all(16.w),
                child: controller.contacts.isEmpty
                    ? ListView(
                        children: [
                          SizedBox(height: 120.h),
                          Center(
                            child: Text(
                              'Контакты не найдены',
                              style: DdtTheme.style(fontSize: 15.sp),
                            ),
                          ),
                        ],
                      )
                    : ListView.separated(
                        itemCount: controller.contacts.length,
                        separatorBuilder: (_, __) => SizedBox(height: 8.h),
                        itemBuilder: (context, index) {
                          return ContactListItem(
                            contact: controller.contacts[index],
                          );
                        },
                      ),
              ),
            );
          }),
        ),
      ],
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
              fontSize: 15.sp,
              fontWeight: FontWeight.w700,
              color: DdtTheme.taskCardTextPrimary(context),
            ),
          ),
          if (contact.emails.isNotEmpty) ...[
            SizedBox(height: 6.h),
            ...contact.emails.map(
              (email) => Text(
                email,
                style: DdtTheme.style(fontSize: 13.sp),
              ),
            ),
          ],
          if (contact.phones.isNotEmpty) ...[
            SizedBox(height: 6.h),
            ...contact.phones.map(
              (phone) => Text(
                phone,
                style: DdtTheme.style(
                  fontSize: 13.sp,
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
