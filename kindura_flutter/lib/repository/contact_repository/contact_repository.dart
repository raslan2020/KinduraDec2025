import 'package:kindura_ai/data/network/network_api_services.dart';
import 'package:kindura_ai/models/contact/contact_model.dart';
import 'package:kindura_ai/data/response/api_response.dart';
import 'package:kindura_ai/res/app_url/app_url.dart';

class ContactRepository {
  final _apiService = NetworkApiServices();

  /// Get all contacts for current user
  Future<ApiResponse<List<Contact>>> getContacts({
    String? type,
    bool? emergencyOnly,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (type != null) queryParams['type'] = type;
      if (emergencyOnly == true) queryParams['emergency'] = 'true';

      final response = await _apiService.getApi(
        '${AppUrl.baseUrl}/contacts/',
        queryParameters: queryParams,
      );

      if (response['status'] == true) {
        final List<dynamic> contactsJson = response['result'] ?? [];
        final contacts = <Contact>[];
        for (var i = 0; i < contactsJson.length; i++) {
          try {
            contacts.add(Contact.fromJson(contactsJson[i]));
          } catch (e) {
            print('Error parsing contact $i: $e');
          }
        }
        return ApiResponse.completed(contacts);
      } else {
        return ApiResponse.error(response['message'] ?? 'Failed to load contacts');
      }
    } catch (e) {
      return ApiResponse.error(e.toString());
    }
  }

  /// Get emergency contacts only
  Future<ApiResponse<List<Contact>>> getEmergencyContacts() async {
    try {
      final response = await _apiService.getApi(
        '${AppUrl.baseUrl}/contacts/emergency/',
      );

      if (response['status'] == true) {
        final List<dynamic> contactsJson = response['result'] ?? [];
        final contacts = contactsJson.map((e) => Contact.fromJson(e)).toList();
        return ApiResponse.completed(contacts);
      } else {
        return ApiResponse.error(response['message'] ?? 'Failed to load emergency contacts');
      }
    } catch (e) {
      return ApiResponse.error(e.toString());
    }
  }

  /// Get specific contact by ID
  Future<ApiResponse<Contact>> getContact(int contactId) async {
    try {
      final response = await _apiService.getApi(
        '${AppUrl.baseUrl}/contacts/$contactId/',
      );

      if (response['status'] == true) {
        final contact = Contact.fromJson(response['result']);
        return ApiResponse.completed(contact);
      } else {
        return ApiResponse.error(response['message'] ?? 'Failed to load contact');
      }
    } catch (e) {
      return ApiResponse.error(e.toString());
    }
  }

  /// Create new contact
  Future<ApiResponse<Contact>> createContact(CreateContactRequest request) async {
    try {
      final data = request.toJson();
      final response = await _apiService.postApi(
        data,
        '${AppUrl.baseUrl}/contacts/',
      );

      if (response['status'] == true) {
        final contact = Contact.fromJson(response['result']);
        return ApiResponse.completed(contact);
      } else {
        return ApiResponse.error(response['message'] ?? 'Failed to create contact');
      }
    } catch (e) {
      return ApiResponse.error(e.toString());
    }
  }

  /// Update existing contact
  Future<ApiResponse<Contact>> updateContact(int contactId, Map<String, dynamic> data) async {
    try {
      final response = await _apiService.putApi(
        data,
        '${AppUrl.baseUrl}/contacts/$contactId/',
      );

      if (response['status'] == true) {
        final contact = Contact.fromJson(response['result']);
        return ApiResponse.completed(contact);
      } else {
        return ApiResponse.error(response['message'] ?? 'Failed to update contact');
      }
    } catch (e) {
      return ApiResponse.error(e.toString());
    }
  }

  /// Delete contact (soft delete)
  Future<ApiResponse<bool>> deleteContact(int contactId) async {
    try {
      final response = await _apiService.deleteApi(
        '${AppUrl.baseUrl}/contacts/$contactId/',
      );

      if (response['status'] == true) {
        return ApiResponse.completed(true);
      } else {
        return ApiResponse.error(response['message'] ?? 'Failed to delete contact');
      }
    } catch (e) {
      return ApiResponse.error(e.toString());
    }
  }

  /// Get FaceTime info for a contact
  Future<ApiResponse<Map<String, dynamic>>> getFacetimeInfo(int contactId) async {
    try {
      final response = await _apiService.getApi(
        '${AppUrl.baseUrl}/contacts/$contactId/facetime_info/',
      );

      if (response['status'] == true) {
        return ApiResponse.completed(response['result']);
      } else {
        return ApiResponse.error(response['message'] ?? 'FaceTime not available');
      }
    } catch (e) {
      return ApiResponse.error(e.toString());
    }
  }
}
