import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kindura_ai/models/contact/contact_model.dart';
import 'package:kindura_ai/repository/contact_repository/contact_repository.dart';
import 'package:kindura_ai/data/response/status.dart';
import 'package:url_launcher/url_launcher.dart';

class ContactsController extends GetxController {
  final _repository = ContactRepository();

  // State
  final contacts = <Contact>[].obs;
  final requestStatus = Status.LOADING.obs;
  final errorMessage = ''.obs;

  // Filter
  final selectedFilter = 'All'.obs;
  final filterTypes = ['All', 'Family', 'Caregiver', 'Emergency', 'Doctor', 'Other'];

  @override
  void onInit() {
    super.onInit();
    loadContacts();
  }

  Future<void> loadContacts() async {
    requestStatus.value = Status.LOADING;

    String? typeFilter;
    if (selectedFilter.value != 'All') {
      typeFilter = selectedFilter.value.toLowerCase();
    }

    final response = await _repository.getContacts(type: typeFilter);

    response.when(
      success: (data) {
        contacts.value = data;
        requestStatus.value = Status.COMPLETED;
      },
      error: (message) {
        errorMessage.value = message;
        requestStatus.value = Status.ERROR;
      },
      loading: () {},
    );
  }

  void onFilterChanged(String filter) {
    selectedFilter.value = filter;
    loadContacts();
  }

  Future<void> deleteContact(int contactId) async {
    final response = await _repository.deleteContact(contactId);

    response.when(
      success: (_) {
        contacts.removeWhere((c) => c.id == contactId);
        Get.snackbar(
          'Success',
          'Contact deleted successfully',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green.shade100,
        );
      },
      error: (message) {
        Get.snackbar(
          'Error',
          message,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.shade100,
        );
      },
      loading: () {},
    );
  }

  Future<void> createContact(CreateContactRequest request) async {
    final response = await _repository.createContact(request);

    response.when(
      success: (contact) {
        contacts.add(contact);
        Get.snackbar(
          'Success',
          'Contact added successfully',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green.shade100,
        );
      },
      error: (message) {
        Get.snackbar(
          'Error',
          message,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.shade100,
        );
      },
      loading: () {},
    );
  }

  Future<void> updateContact(int contactId, Map<String, dynamic> data) async {
    final response = await _repository.updateContact(contactId, data);

    response.when(
      success: (contact) {
        final index = contacts.indexWhere((c) => c.id == contactId);
        if (index != -1) {
          contacts[index] = contact;
        }
        Get.snackbar(
          'Success',
          'Contact updated successfully',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green.shade100,
        );
      },
      error: (message) {
        Get.snackbar(
          'Error',
          message,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.shade100,
        );
      },
      loading: () {},
    );
  }

  /// Launch FaceTime video call
  Future<void> callFaceTime(Contact contact) async {
    final target = contact.facetimeTarget ?? contact.phoneNumber ?? contact.email;
    if (target == null) {
      Get.snackbar(
        'Error',
        'No FaceTime contact available',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade100,
      );
      return;
    }

    final url = Uri.parse('facetime://$target');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      Get.snackbar(
        'Error',
        'Could not launch FaceTime',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade100,
      );
    }
  }

  /// Launch FaceTime audio-only call
  Future<void> callFaceTimeAudio(Contact contact) async {
    final target = contact.facetimeTarget ?? contact.phoneNumber ?? contact.email;
    if (target == null) {
      Get.snackbar(
        'Error',
        'No FaceTime contact available',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade100,
      );
      return;
    }

    final url = Uri.parse('facetime-audio://$target');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      Get.snackbar(
        'Error',
        'Could not launch FaceTime Audio',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade100,
      );
    }
  }

  /// Launch phone call
  Future<void> callPhone(Contact contact) async {
    if (contact.phoneNumber == null) {
      Get.snackbar(
        'Error',
        'No phone number available',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade100,
      );
      return;
    }

    final url = Uri.parse('tel:${contact.phoneNumber}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      Get.snackbar(
        'Error',
        'Could not make phone call',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade100,
      );
    }
  }

  List<Contact> get filteredContacts {
    if (selectedFilter.value == 'All') {
      return contacts;
    }
    return contacts.where((c) =>
      c.contactType.name.toLowerCase() == selectedFilter.value.toLowerCase()
    ).toList();
  }

  List<Contact> get emergencyContacts {
    return contacts.where((c) => c.isEmergency).toList();
  }
}
