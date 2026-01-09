import 'package:flutter/services.dart';
import 'package:get/get.dart';

/// Service for accessing device contacts and initiating communication (calls, messages).
/// Uses native iOS Contacts framework and URL schemes for communication.
class ContactsCommunicationService extends GetxService {
  static const MethodChannel _channel = MethodChannel('com.kindura.ai/contacts');

  // Observable state
  final RxBool hasContactsPermission = false.obs;
  final RxList<DeviceContact> cachedContacts = <DeviceContact>[].obs;
  final RxBool isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    _checkPermission();
  }

  /// Check if contacts permission is granted
  Future<void> _checkPermission() async {
    try {
      final result = await _channel.invokeMethod<bool>('requestContactsPermission');
      hasContactsPermission.value = result ?? false;
    } catch (e) {
      print('Error checking contacts permission: $e');
      hasContactsPermission.value = false;
    }
  }

  /// Request contacts permission from user
  Future<bool> requestPermission() async {
    try {
      final result = await _channel.invokeMethod<bool>('requestContactsPermission');
      hasContactsPermission.value = result ?? false;
      return hasContactsPermission.value;
    } catch (e) {
      print('Error requesting contacts permission: $e');
      return false;
    }
  }

  /// Get all device contacts
  Future<List<DeviceContact>> getDeviceContacts({bool forceRefresh = false}) async {
    if (!forceRefresh && cachedContacts.isNotEmpty) {
      return cachedContacts;
    }

    if (!hasContactsPermission.value) {
      final granted = await requestPermission();
      if (!granted) {
        return [];
      }
    }

    isLoading.value = true;

    try {
      final result = await _channel.invokeMethod<List<dynamic>>('getDeviceContacts');

      if (result != null) {
        final contacts = result.map((c) => DeviceContact.fromMap(c as Map<dynamic, dynamic>)).toList();
        cachedContacts.value = contacts;
        return contacts;
      }
      return [];
    } catch (e) {
      print('Error getting device contacts: $e');
      return [];
    } finally {
      isLoading.value = false;
    }
  }

  /// Search contacts by name
  Future<List<DeviceContact>> searchContacts(String query) async {
    if (query.isEmpty) {
      return [];
    }

    if (!hasContactsPermission.value) {
      final granted = await requestPermission();
      if (!granted) {
        return [];
      }
    }

    try {
      final result = await _channel.invokeMethod<List<dynamic>>(
        'searchContacts',
        {'query': query},
      );

      if (result != null) {
        return result.map((c) => DeviceContact.fromMap(c as Map<dynamic, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      print('Error searching contacts: $e');
      return [];
    }
  }

  /// Find a contact by name (fuzzy match)
  Future<DeviceContact?> findContactByName(String name) async {
    final contacts = await searchContacts(name);
    if (contacts.isNotEmpty) {
      return contacts.first;
    }

    // Try partial match in cached contacts
    if (cachedContacts.isNotEmpty) {
      final lowerName = name.toLowerCase();
      for (final contact in cachedContacts) {
        if (contact.fullName.toLowerCase().contains(lowerName) ||
            contact.givenName.toLowerCase().contains(lowerName) ||
            contact.familyName.toLowerCase().contains(lowerName) ||
            (contact.nickname?.toLowerCase().contains(lowerName) ?? false)) {
          return contact;
        }
      }
    }

    return null;
  }

  /// Send a text message (opens Messages app with pre-filled content)
  /// Note: iOS requires user to tap send - cannot send programmatically
  Future<CommunicationResult> sendMessage({
    required String phoneNumber,
    required String message,
  }) async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'sendMessage',
        {
          'phoneNumber': phoneNumber,
          'message': message,
        },
      );

      if (result != null && result['status'] == 'opened') {
        return CommunicationResult(
          success: true,
          message: 'Messages app opened. The message is ready to send.',
          requiresUserAction: true,
        );
      }

      return CommunicationResult(
        success: false,
        message: 'Failed to open Messages app',
      );
    } on PlatformException catch (e) {
      return CommunicationResult(
        success: false,
        message: e.message ?? 'Failed to send message',
        errorCode: e.code,
      );
    } catch (e) {
      return CommunicationResult(
        success: false,
        message: e.toString(),
      );
    }
  }

  /// Send message to a contact by name
  Future<CommunicationResult> sendMessageToContact({
    required String contactName,
    required String message,
  }) async {
    final contact = await findContactByName(contactName);

    if (contact == null) {
      return CommunicationResult(
        success: false,
        message: 'Contact "$contactName" not found',
      );
    }

    final phoneNumber = contact.primaryPhoneNumber;
    if (phoneNumber == null) {
      return CommunicationResult(
        success: false,
        message: '${contact.fullName} does not have a phone number',
      );
    }

    return sendMessage(phoneNumber: phoneNumber, message: message);
  }

  /// Make a phone call
  Future<CommunicationResult> makePhoneCall(String phoneNumber) async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'makeCall',
        {
          'phoneNumber': phoneNumber,
          'callType': 'phone',
        },
      );

      if (result != null && result['status'] == 'calling') {
        return CommunicationResult(
          success: true,
          message: 'Initiating phone call',
        );
      }

      return CommunicationResult(
        success: false,
        message: 'Failed to make call',
      );
    } on PlatformException catch (e) {
      return CommunicationResult(
        success: false,
        message: e.message ?? 'Failed to make call',
        errorCode: e.code,
      );
    }
  }

  /// Start a FaceTime call (video or audio)
  Future<CommunicationResult> startFaceTimeCall({
    required String contact,
    bool isVideo = true,
  }) async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'startFaceTimeCall',
        {
          'contact': contact,
          'isVideo': isVideo,
        },
      );

      if (result != null && result['status'] == 'calling') {
        return CommunicationResult(
          success: true,
          message: 'Initiating FaceTime ${isVideo ? "video" : "audio"} call',
        );
      }

      return CommunicationResult(
        success: false,
        message: 'Failed to start FaceTime call',
      );
    } on PlatformException catch (e) {
      return CommunicationResult(
        success: false,
        message: e.message ?? 'Failed to start FaceTime',
        errorCode: e.code,
      );
    }
  }

  /// Call a contact by name
  Future<CommunicationResult> callContact({
    required String contactName,
    String callType = 'phone', // 'phone', 'facetime', 'facetime-audio'
  }) async {
    final contact = await findContactByName(contactName);

    if (contact == null) {
      return CommunicationResult(
        success: false,
        message: 'Contact "$contactName" not found',
      );
    }

    final phoneNumber = contact.primaryPhoneNumber;
    if (phoneNumber == null) {
      return CommunicationResult(
        success: false,
        message: '${contact.fullName} does not have a phone number',
      );
    }

    if (callType == 'facetime' || callType == 'facetime-video') {
      return startFaceTimeCall(contact: phoneNumber, isVideo: true);
    } else if (callType == 'facetime-audio') {
      return startFaceTimeCall(contact: phoneNumber, isVideo: false);
    } else {
      return makePhoneCall(phoneNumber);
    }
  }

  /// Get formatted contacts list for agent context
  String formatContactsForAgent() {
    if (cachedContacts.isEmpty) {
      return "No contacts loaded. Request contacts permission first.";
    }

    final lines = <String>["Device contacts:"];

    for (final contact in cachedContacts.take(20)) {
      // Limit to 20 for agent context
      final phone = contact.primaryPhoneNumber ?? 'No phone';
      lines.add("- ${contact.fullName}: $phone");
    }

    if (cachedContacts.length > 20) {
      lines.add("... and ${cachedContacts.length - 20} more contacts");
    }

    return lines.join('\n');
  }
}

/// Model for a device contact
class DeviceContact {
  final String id;
  final String givenName;
  final String familyName;
  final String fullName;
  final String? nickname;
  final String? organization;
  final List<PhoneNumber> phoneNumbers;
  final List<Email> emails;
  final bool hasImage;

  DeviceContact({
    required this.id,
    required this.givenName,
    required this.familyName,
    required this.fullName,
    this.nickname,
    this.organization,
    required this.phoneNumbers,
    required this.emails,
    this.hasImage = false,
  });

  factory DeviceContact.fromMap(Map<dynamic, dynamic> map) {
    final phones = (map['phoneNumbers'] as List<dynamic>?)
            ?.map((p) => PhoneNumber.fromMap(p as Map<dynamic, dynamic>))
            .toList() ??
        [];

    final emailList = (map['emails'] as List<dynamic>?)
            ?.map((e) => Email.fromMap(e as Map<dynamic, dynamic>))
            .toList() ??
        [];

    return DeviceContact(
      id: map['id'] as String? ?? '',
      givenName: map['givenName'] as String? ?? '',
      familyName: map['familyName'] as String? ?? '',
      fullName: map['fullName'] as String? ?? '',
      nickname: map['nickname'] as String?,
      organization: map['organization'] as String?,
      phoneNumbers: phones,
      emails: emailList,
      hasImage: map['hasImage'] as bool? ?? false,
    );
  }

  /// Get primary phone number (first mobile, or first available)
  String? get primaryPhoneNumber {
    if (phoneNumbers.isEmpty) return null;

    // Prefer mobile numbers
    final mobile = phoneNumbers.firstWhereOrNull(
      (p) => p.label.toLowerCase().contains('mobile') || p.label.toLowerCase().contains('cell'),
    );
    if (mobile != null) return mobile.number;

    // Fall back to first number
    return phoneNumbers.first.number;
  }

  /// Get primary email
  String? get primaryEmail {
    if (emails.isEmpty) return null;
    return emails.first.email;
  }
}

/// Phone number with label
class PhoneNumber {
  final String label;
  final String number;

  PhoneNumber({required this.label, required this.number});

  factory PhoneNumber.fromMap(Map<dynamic, dynamic> map) {
    return PhoneNumber(
      label: map['label'] as String? ?? '',
      number: map['number'] as String? ?? '',
    );
  }
}

/// Email with label
class Email {
  final String label;
  final String email;

  Email({required this.label, required this.email});

  factory Email.fromMap(Map<dynamic, dynamic> map) {
    return Email(
      label: map['label'] as String? ?? '',
      email: map['email'] as String? ?? '',
    );
  }
}

/// Result of a communication action
class CommunicationResult {
  final bool success;
  final String message;
  final String? errorCode;
  final bool requiresUserAction;

  CommunicationResult({
    required this.success,
    required this.message,
    this.errorCode,
    this.requiresUserAction = false,
  });
}
