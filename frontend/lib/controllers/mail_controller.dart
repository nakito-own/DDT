import 'package:get/get.dart';

import '../models/mail_message.dart';
import '../services/ews_api.dart';

class MailController extends GetxController {
  MailController({EwsApi? api}) : _api = api ?? ewsApi;

  final EwsApi _api;

  final RxBool isLoading = false.obs;
  final RxnString errorMessage = RxnString();
  final Rxn<MailFolders> folders = Rxn<MailFolders>();
  final RxList<MailMessage> messages = <MailMessage>[].obs;
  final RxnString selectedMessageId = RxnString();
  final Rxn<MailMessage> selectedMessage = Rxn<MailMessage>();
  final RxBool isLoadingDetail = false.obs;
  final RxBool isSending = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadInbox();
  }

  Future<void> loadInbox() async {
    isLoading.value = true;
    errorMessage.value = null;

    try {
      final results = await Future.wait([
        _api.fetchMailFolders(),
        _api.fetchInbox(),
      ]);
      folders.value = results[0] as MailFolders;
      messages.assignAll(results[1] as List<MailMessage>);

      final selectedId = selectedMessageId.value;
      if (selectedId != null) {
        final index = messages.indexWhere((item) => item.id == selectedId);
        if (index >= 0) {
          selectedMessage.value = messages[index];
        }
      }
    } catch (error) {
      errorMessage.value = error.toString().replaceFirst('Exception: ', '');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> selectMessage(MailMessage message) async {
    selectedMessageId.value = message.id;
    selectedMessage.value = message;

    final wasUnread = !message.isRead;
    if (wasUnread) {
      _setMessageReadLocally(message.id);
    }

    final hasCachedBody = message.body != null && message.body!.isNotEmpty;
    if (hasCachedBody) {
      if (wasUnread) {
        _markReadOnServer(message.id);
      }
      return;
    }

    isLoadingDetail.value = true;
    try {
      final detail = await _api.fetchMessage(
        message.id,
        markRead: wasUnread,
      );
      selectedMessage.value = detail;
      _mergeMessageDetail(detail);
    } catch (error) {
      errorMessage.value = error.toString().replaceFirst('Exception: ', '');
    } finally {
      isLoadingDetail.value = false;
    }
  }

  void _setMessageReadLocally(String messageId) {
    final index = messages.indexWhere((item) => item.id == messageId);
    if (index >= 0 && !messages[index].isRead) {
      final updated = messages[index].copyWith(isRead: true);
      messages[index] = updated;
      if (selectedMessage.value?.id == messageId) {
        selectedMessage.value = updated;
      }
    }
  }

  void _mergeMessageDetail(MailMessage detail) {
    final index = messages.indexWhere((item) => item.id == detail.id);
    if (index < 0) {
      return;
    }

    messages[index] = messages[index].copyWith(
      body: detail.body,
      bodyType: detail.bodyType,
      preview: detail.preview,
      isRead: detail.isRead,
    );
  }

  void _markReadOnServer(String messageId) {
    _api.markMessageRead(messageId).catchError((_) => null);
  }

  Future<bool> sendMessage({
    required List<String> to,
    required String subject,
    required String body,
    List<String> cc = const [],
  }) async {
    isSending.value = true;
    errorMessage.value = null;

    try {
      await _api.sendMail(
        to: to,
        cc: cc,
        subject: subject,
        body: body,
      );
      await loadInbox();
      return true;
    } catch (error) {
      errorMessage.value = error.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      isSending.value = false;
    }
  }
}
