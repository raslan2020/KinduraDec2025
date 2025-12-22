// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'contact_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Contact _$ContactFromJson(Map<String, dynamic> json) => Contact(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      contactType: $enumDecode(_$ContactTypeEnumMap, json['contact_type']),
      contactTypeDisplay: json['contact_type_display'] as String?,
      relationship:
          $enumDecode(_$RelationshipTypeEnumMap, json['relationship']),
      relationshipDisplay: json['relationship_display'] as String?,
      phoneNumber: json['phone_number'] as String?,
      email: json['email'] as String?,
      isEmergency: json['is_emergency'] as bool? ?? false,
      isPrimary: json['is_primary'] as bool? ?? false,
      notes: json['notes'] as String?,
      facetimeId: json['facetime_id'] as String?,
      facetimeAvailable: json['facetime_available'] as bool?,
      facetimeTarget: json['facetime_target'] as String?,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.parse(json['updated_at'] as String),
      isActive: json['is_active'] as bool? ?? true,
    );

Map<String, dynamic> _$ContactToJson(Contact instance) => <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'contact_type': _$ContactTypeEnumMap[instance.contactType]!,
      'contact_type_display': instance.contactTypeDisplay,
      'relationship': _$RelationshipTypeEnumMap[instance.relationship]!,
      'relationship_display': instance.relationshipDisplay,
      'phone_number': instance.phoneNumber,
      'email': instance.email,
      'is_emergency': instance.isEmergency,
      'is_primary': instance.isPrimary,
      'notes': instance.notes,
      'facetime_id': instance.facetimeId,
      'facetime_available': instance.facetimeAvailable,
      'facetime_target': instance.facetimeTarget,
      'created_at': instance.createdAt?.toIso8601String(),
      'updated_at': instance.updatedAt?.toIso8601String(),
      'is_active': instance.isActive,
    };

const _$ContactTypeEnumMap = {
  ContactType.family: 'family',
  ContactType.caregiver: 'caregiver',
  ContactType.emergency: 'emergency',
  ContactType.doctor: 'doctor',
  ContactType.pharmacy: 'pharmacy',
  ContactType.other: 'other',
};

const _$RelationshipTypeEnumMap = {
  RelationshipType.spouse: 'spouse',
  RelationshipType.parent: 'parent',
  RelationshipType.child: 'child',
  RelationshipType.sibling: 'sibling',
  RelationshipType.friend: 'friend',
  RelationshipType.caregiver: 'caregiver',
  RelationshipType.doctor: 'doctor',
  RelationshipType.nurse: 'nurse',
  RelationshipType.other: 'other',
};

CreateContactRequest _$CreateContactRequestFromJson(
        Map<String, dynamic> json) =>
    CreateContactRequest(
      name: json['name'] as String,
      contactType: json['contact_type'] as String,
      relationship: json['relationship'] as String,
      phoneNumber: json['phone_number'] as String?,
      email: json['email'] as String?,
      isEmergency: json['is_emergency'] as bool? ?? false,
      isPrimary: json['is_primary'] as bool? ?? false,
      notes: json['notes'] as String?,
      facetimeId: json['facetime_id'] as String?,
    );

Map<String, dynamic> _$CreateContactRequestToJson(
        CreateContactRequest instance) =>
    <String, dynamic>{
      'name': instance.name,
      'contact_type': instance.contactType,
      'relationship': instance.relationship,
      'phone_number': instance.phoneNumber,
      'email': instance.email,
      'is_emergency': instance.isEmergency,
      'is_primary': instance.isPrimary,
      'notes': instance.notes,
      'facetime_id': instance.facetimeId,
    };
