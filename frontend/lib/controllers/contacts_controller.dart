import 'package:get/get.dart';

import '../models/contact.dart';
import '../services/ews_api.dart';

class ContactsController extends GetxController {
  ContactsController({EwsApi? api}) : _api = api ?? ewsApi;

  final EwsApi _api;

  final RxBool isLoading = false.obs;
  final RxnString errorMessage = RxnString();
  final RxList<Contact> contacts = <Contact>[].obs;
  final RxString searchQuery = ''.obs;

  @override
  void onInit() {
    super.onInit();
    loadContacts();
  }

  Future<void> loadContacts({String? search}) async {
    isLoading.value = true;
    errorMessage.value = null;

    try {
      final query = search ?? searchQuery.value;
      final result = await _api.fetchContacts(search: query);
      contacts.assignAll(result);
    } catch (error) {
      errorMessage.value = error.toString().replaceFirst('Exception: ', '');
    } finally {
      isLoading.value = false;
    }
  }

  void updateSearch(String value) {
    searchQuery.value = value;
    loadContacts(search: value);
  }
}
