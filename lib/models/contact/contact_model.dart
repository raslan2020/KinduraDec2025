import 'package:json_annotation/json_annotation.dart';

part 'contact_model.g.dart';

/// Contact type enumeration
enum ContactType {
  @JsonValue('family')
  family,
  @JsonValue('caregiver')
  caregiver,
  @JsonValue('emergency')
  emergency,
  @JsonValue('doctor')
  doctor,
  @JsonValue('pharmacy')
  pharmacy,
  @JsonValue('other')
  other,
}

/// Relationship type enumeration
enum RelationshipType {
  @JsonValue('spouse')
  spouse,
  @JsonValue('parent')
  parent,
  @JsonValue('child')
  child,
  @JsonValue('sibling')
  sibling,
  @JsonValue('friend')
  friend,
  @JsonValue('caregiver')
  caregiver,
  @JsonValue('doctor')
  doctor,
  @JsonValue('nurse')
  nurse,
  @JsonValue('other')
  other,
}

/// Extension for ContactType display names
extension ContactTypeExtension on ContactType {
  String get displayName {
    switch (this) {
      case ContactType.family:
        return 'Family Member';
      case ContactType.caregiver:
        return 'Caregiver';
      case ContactType.emergency:
        return 'Emergency Contact';
      case ContactType.doctor:
        return 'Doctor';
      case ContactType.pharmacy:
        return 'Pharmacy';
      case ContactType.other:
        return 'Other';
    }
  }
}

/// Extension for RelationshipType display names
extension RelationshipTypeExtension on RelationshipType {
  String get displayName {
    switch (this) {
      case RelationshipType.spouse:
        return 'Spouse';
      case RelationshipType.parent:
        return 'Parent';
      case RelationshipType.child:
        return 'Child';
      case RelationshipType.sibling:
        return 'Sibling';
      case RelationshipType.friend:
        return 'Friend';
      case RelationshipType.caregiver:
        return 'Caregiver';
      case RelationshipType.doctor:
        return 'Doctor';
      case RelationshipType.nurse:
        return 'Nurse';
      case RelationshipType.other:
        return 'Other';
    }
  }
}

/// Contact model for family members, caregivers, emergency contacts
@JsonSerializable()
class Contact {
  final int id;
  final String name;
  @JsonKey(name: 'contact_type')
  final ContactType contactType;
  @JsonKey(name: 'contact_type_display')
  final String? contactTypeDisplay;
  final RelationshipType relationship;
  @JsonKey(name: 'relationship_display')
  final String? relationshipDisplay;
  @JsonKey(name: 'phone_number')
  final String? phoneNumber;
  final String? email;
  @JsonKey(name: 'is_emergency')
  final bool isEmergency;
  @JsonKey(name: 'is_primary')
  final bool isPrimary;
  final String? notes;
  @JsonKey(name: 'facetime_id')
  final String? facetimeId;
  @JsonKey(name: 'facetime_available')
  final bool? facetimeAvailable;
  @JsonKey(name: 'facetime_target')
  final String? facetimeTarget;
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;
  @JsonKey(name: 'updated_at')
  final DateTime? updatedAt;
  @JsonKey(name: 'is_active')
  final bool isActive;

  const Contact({
    required this.id,
    required this.name,
    required this.contactType,
    this.contactTypeDisplay,
    required this.relationship,
    this.relationshipDisplay,
    this.phoneNumber,
    this.email,
    this.isEmergency = false,
    this.isPrimary = false,
    this.notes,
    this.facetimeId,
    this.facetimeAvailable,
    this.facetimeTarget,
    this.createdAt,
    this.updatedAt,
    this.isActive = true,
  });

  factory Contact.fromJson(Map<String, dynamic> json) => _$ContactFromJson(json);
  Map<String, dynamic> toJson() => _$ContactToJson(this);

  /// Check if FaceTime is available for this contact
  bool get canFaceTime => facetimeAvailable == true || facetimeTarget != null;

  /// Get the FaceTime URL for video call
  String? get facetimeUrl =>
      canFaceTime ? 'facetime://${facetimeTarget ?? phoneNumber ?? email}' : null;

  /// Get the FaceTime Audio URL for audio-only call
  String? get facetimeAudioUrl =>
      canFaceTime ? 'facetime-audio://${facetimeTarget ?? phoneNumber ?? email}' : null;

  /// Get display text for contact type
  String get typeDisplay => contactTypeDisplay ?? contactType.displayName;

  /// Get display text for relationship
  String get relationDisplay => relationshipDisplay ?? relationship.displayName;

  /// Copy with method for updating contact
  Contact copyWith({
    int? id,
    String? name,
    ContactType? contactType,
    String? contactTypeDisplay,
    RelationshipType? relationship,
    String? relationshipDisplay,
    String? phoneNumber,
    String? email,
    bool? isEmergency,
    bool? isPrimary,
    String? notes,
    String? facetimeId,
    bool? facetimeAvailable,
    String? facetimeTarget,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
  }) {
    return Contact(
      id: id ?? this.id,
      name: name ?? this.name,
      contactType: contactType ?? this.contactType,
      contactTypeDisplay: contactTypeDisplay ?? this.contactTypeDisplay,
      relationship: relationship ?? this.relationship,
      relationshipDisplay: relationshipDisplay ?? this.relationshipDisplay,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email ?? this.email,
      isEmergency: isEmergency ?? this.isEmergency,
      isPrimary: isPrimary ?? this.isPrimary,
      notes: notes ?? this.notes,
      facetimeId: facetimeId ?? this.facetimeId,
      facetimeAvailable: facetimeAvailable ?? this.facetimeAvailable,
      facetimeTarget: facetimeTarget ?? this.facetimeTarget,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
    );
  }
}

/// Model for creating a new contact
@JsonSerializable()
class CreateContactRequest {
  final String name;
  @JsonKey(name: 'contact_type')
  final String contactType;
  final String relationship;
  @JsonKey(name: 'phone_number')
  final String? phoneNumber;
  final String? email;
  @JsonKey(name: 'is_emergency')
  final bool isEmergency;
  @JsonKey(name: 'is_primary')
  final bool isPrimary;
  final String? notes;
  @JsonKey(name: 'facetime_id')
  final String? facetimeId;

  const CreateContactRequest({
    required this.name,
    required this.contactType,
    required this.relationship,
    this.phoneNumber,
    this.email,
    this.isEmergency = false,
    this.isPrimary = false,
    this.notes,
    this.facetimeId,
  });

  factory CreateContactRequest.fromJson(Map<String, dynamic> json) =>
      _$CreateContactRequestFromJson(json);
  Map<String, dynamic> toJson() => _$CreateContactRequestToJson(this);
}
