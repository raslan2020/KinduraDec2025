import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:kindura_ai/common_widgets/loading_indicator.dart';
import 'package:kindura_ai/data/response/status.dart';
import 'package:kindura_ai/models/contact/contact_model.dart';
import 'package:kindura_ai/res/colors/app_color.dart';
import 'package:kindura_ai/screens/contacts/contacts_controller.dart';

class ContactsScreen extends StatelessWidget {
  ContactsScreen({super.key});

  final controller = Get.put(ContactsController());

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppColor.black;
    final bgColor = isDark ? const Color(0xFF0F172A) : AppColor.surface;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text('My Contacts', style: TextStyle(color: textColor)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        actions: [
          IconButton(
            icon: Icon(Icons.add, color: AppColor.primaryColor),
            onPressed: () => _showAddContactDialog(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter chips
          Container(
            height: 50.h,
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: controller.filterTypes.length,
              itemBuilder: (context, index) {
                final filter = controller.filterTypes[index];
                return Obx(() => Padding(
                  padding: EdgeInsets.only(right: 8.w),
                  child: FilterChip(
                    label: Text(filter),
                    selected: controller.selectedFilter.value == filter,
                    onSelected: (_) => controller.onFilterChanged(filter),
                    selectedColor: AppColor.primaryColor.withValues(alpha: 0.2),
                    checkmarkColor: AppColor.primaryColor,
                    backgroundColor: isDark ? const Color(0xFF1E293B) : null,
                    labelStyle: TextStyle(
                      color: controller.selectedFilter.value == filter
                          ? AppColor.primaryColor
                          : textColor,
                    ),
                  ),
                ));
              },
            ),
          ),
          SizedBox(height: 8.h),
          // Contacts list
          Expanded(
            child: Obx(() {
              switch (controller.requestStatus.value) {
                case Status.LOADING:
                  return Center(child: LoadingIndicator());
                case Status.ERROR:
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 48.sp, color: Colors.red),
                        SizedBox(height: 16.h),
                        Text(controller.errorMessage.value),
                        SizedBox(height: 16.h),
                        ElevatedButton(
                          onPressed: controller.loadContacts,
                          child: Text('Retry'),
                        ),
                      ],
                    ),
                  );
                case Status.COMPLETED:
                  if (controller.contacts.isEmpty) {
                    return _buildEmptyState(context);
                  }
                  return RefreshIndicator(
                    onRefresh: controller.loadContacts,
                    child: ListView.builder(
                      padding: EdgeInsets.all(16.w),
                      itemCount: controller.contacts.length,
                      itemBuilder: (context, index) {
                        return _buildContactCard(context, controller.contacts[index]);
                      },
                    ),
                  );
                default:
                  return Container();
              }
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppColor.black;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 64.sp, color: AppColor.gray500),
          SizedBox(height: 16.h),
          Text(
            'No contacts yet',
            style: TextStyle(fontSize: 18.sp, color: textColor),
          ),
          SizedBox(height: 8.h),
          Text(
            'Add family members, caregivers, or emergency contacts',
            style: TextStyle(fontSize: 14.sp, color: AppColor.gray500),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 24.h),
          ElevatedButton.icon(
            onPressed: () => _showAddContactDialog(context),
            icon: Icon(Icons.add),
            label: Text('Add Contact'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColor.primaryColor,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactCard(BuildContext context, Contact contact) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppColor.black;
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;

    return Card(
      margin: EdgeInsets.only(bottom: 12.h),
      color: cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.w)),
      child: InkWell(
        onTap: () => _showContactDetails(context, contact),
        borderRadius: BorderRadius.circular(12.w),
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Avatar
                  CircleAvatar(
                    radius: 24.w,
                    backgroundColor: _getContactColor(contact.contactType),
                    child: Text(
                      contact.name.isNotEmpty ? contact.name[0].toUpperCase() : '?',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  // Name and type
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                contact.name,
                                style: TextStyle(
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w600,
                                  color: textColor,
                                ),
                              ),
                            ),
                            if (contact.isEmergency)
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade100,
                                  borderRadius: BorderRadius.circular(4.w),
                                ),
                                child: Text(
                                  'Emergency',
                                  style: TextStyle(
                                    fontSize: 10.sp,
                                    color: Colors.red.shade700,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          '${contact.typeDisplay} • ${contact.relationDisplay}',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: isDark ? Colors.grey.shade400 : AppColor.gray500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12.h),
              // Contact info
              if (contact.phoneNumber != null)
                Padding(
                  padding: EdgeInsets.only(bottom: 4.h),
                  child: Row(
                    children: [
                      Icon(Icons.phone, size: 16.sp, color: isDark ? Colors.grey.shade400 : AppColor.gray500),
                      SizedBox(width: 8.w),
                      Text(
                        contact.phoneNumber!,
                        style: TextStyle(fontSize: 14.sp, color: textColor),
                      ),
                    ],
                  ),
                ),
              if (contact.email != null)
                Row(
                  children: [
                    Icon(Icons.email, size: 16.sp, color: isDark ? Colors.grey.shade400 : AppColor.gray500),
                    SizedBox(width: 8.w),
                    Text(
                      contact.email!,
                      style: TextStyle(fontSize: 14.sp, color: textColor),
                    ),
                  ],
                ),
              SizedBox(height: 12.h),
              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (contact.phoneNumber != null)
                    IconButton(
                      icon: Icon(Icons.phone, color: Colors.green),
                      onPressed: () => controller.callPhone(contact),
                      tooltip: 'Call',
                    ),
                  if (contact.canFaceTime) ...[
                    IconButton(
                      icon: Icon(Icons.video_call, color: AppColor.primaryColor),
                      onPressed: () => controller.callFaceTime(contact),
                      tooltip: 'FaceTime Video',
                    ),
                    IconButton(
                      icon: Icon(Icons.phone_in_talk, color: AppColor.primaryColor),
                      onPressed: () => controller.callFaceTimeAudio(contact),
                      tooltip: 'FaceTime Audio',
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getContactColor(ContactType type) {
    switch (type) {
      case ContactType.family:
        return Colors.blue;
      case ContactType.caregiver:
        return Colors.purple;
      case ContactType.emergency:
        return Colors.red;
      case ContactType.doctor:
        return Colors.teal;
      case ContactType.pharmacy:
        return Colors.green;
      case ContactType.other:
        return Colors.grey;
    }
  }

  void _showContactDetails(BuildContext context, Contact contact) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppColor.black;
    final bgColor = isDark ? const Color(0xFF1E293B) : Colors.white;

    Get.bottomSheet(
      Container(
        padding: EdgeInsets.all(20.w),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20.w)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 40.w,
              backgroundColor: _getContactColor(contact.contactType),
              child: Text(
                contact.name.isNotEmpty ? contact.name[0].toUpperCase() : '?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            SizedBox(height: 16.h),
            Text(
              contact.name,
              style: TextStyle(
                fontSize: 24.sp,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            Text(
              '${contact.typeDisplay} • ${contact.relationDisplay}',
              style: TextStyle(fontSize: 14.sp, color: isDark ? Colors.grey.shade400 : AppColor.gray500),
            ),
            SizedBox(height: 24.h),
            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (contact.phoneNumber != null)
                  _buildActionButton(
                    icon: Icons.phone,
                    label: 'Call',
                    color: Colors.green,
                    onTap: () => controller.callPhone(contact),
                  ),
                if (contact.canFaceTime)
                  _buildActionButton(
                    icon: Icons.video_call,
                    label: 'FaceTime',
                    color: AppColor.primaryColor,
                    onTap: () => controller.callFaceTime(contact),
                  ),
                _buildActionButton(
                  icon: Icons.edit,
                  label: 'Edit',
                  color: Colors.orange,
                  onTap: () {
                    Get.back();
                    _showEditContactDialog(context, contact);
                  },
                ),
                _buildActionButton(
                  icon: Icons.delete,
                  label: 'Delete',
                  color: Colors.red,
                  onTap: () {
                    Get.back();
                    _confirmDelete(context, contact);
                  },
                ),
              ],
            ),
            SizedBox(height: 20.h),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24.sp),
          ),
          SizedBox(height: 4.h),
          Text(label, style: TextStyle(fontSize: 12.sp, color: color)),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, Contact contact) {
    Get.dialog(
      AlertDialog(
        title: Text('Delete Contact'),
        content: Text('Are you sure you want to delete ${contact.name}?'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Get.back();
              controller.deleteContact(contact.id);
            },
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showAddContactDialog(BuildContext context) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final emailController = TextEditingController();
    final notesController = TextEditingController();
    final selectedType = 'family'.obs;
    final selectedRelationship = 'other'.obs;
    final isEmergency = false.obs;

    Get.dialog(
      AlertDialog(
        title: Text('Add Contact'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(labelText: 'Name *'),
              ),
              SizedBox(height: 12.h),
              TextField(
                controller: phoneController,
                decoration: InputDecoration(labelText: 'Phone Number'),
                keyboardType: TextInputType.phone,
              ),
              SizedBox(height: 12.h),
              TextField(
                controller: emailController,
                decoration: InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
              ),
              SizedBox(height: 12.h),
              Obx(() => DropdownButtonFormField<String>(
                value: selectedType.value,
                decoration: InputDecoration(labelText: 'Contact Type'),
                items: ['family', 'caregiver', 'emergency', 'doctor', 'pharmacy', 'other']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e.capitalizeFirst!)))
                    .toList(),
                onChanged: (v) => selectedType.value = v ?? 'family',
              )),
              SizedBox(height: 12.h),
              Obx(() => DropdownButtonFormField<String>(
                value: selectedRelationship.value,
                decoration: InputDecoration(labelText: 'Relationship'),
                items: ['spouse', 'parent', 'child', 'sibling', 'friend', 'caregiver', 'doctor', 'nurse', 'other']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e.capitalizeFirst!)))
                    .toList(),
                onChanged: (v) => selectedRelationship.value = v ?? 'other',
              )),
              SizedBox(height: 12.h),
              TextField(
                controller: notesController,
                decoration: InputDecoration(labelText: 'Notes'),
                maxLines: 2,
              ),
              SizedBox(height: 12.h),
              Obx(() => SwitchListTile(
                title: Text('Emergency Contact'),
                value: isEmergency.value,
                onChanged: (v) => isEmergency.value = v,
                contentPadding: EdgeInsets.zero,
              )),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isEmpty) {
                Get.snackbar('Error', 'Name is required');
                return;
              }
              final request = CreateContactRequest(
                name: nameController.text,
                contactType: selectedType.value,
                relationship: selectedRelationship.value,
                phoneNumber: phoneController.text.isEmpty ? null : phoneController.text,
                email: emailController.text.isEmpty ? null : emailController.text,
                notes: notesController.text.isEmpty ? null : notesController.text,
                isEmergency: isEmergency.value,
              );
              Get.back();
              controller.createContact(request);
            },
            child: Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showEditContactDialog(BuildContext context, Contact contact) {
    final nameController = TextEditingController(text: contact.name);
    final phoneController = TextEditingController(text: contact.phoneNumber ?? '');
    final emailController = TextEditingController(text: contact.email ?? '');
    final notesController = TextEditingController(text: contact.notes ?? '');
    final selectedType = contact.contactType.name.obs;
    final selectedRelationship = contact.relationship.name.obs;
    final isEmergency = contact.isEmergency.obs;

    Get.dialog(
      AlertDialog(
        title: Text('Edit Contact'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(labelText: 'Name *'),
              ),
              SizedBox(height: 12.h),
              TextField(
                controller: phoneController,
                decoration: InputDecoration(labelText: 'Phone Number'),
                keyboardType: TextInputType.phone,
              ),
              SizedBox(height: 12.h),
              TextField(
                controller: emailController,
                decoration: InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
              ),
              SizedBox(height: 12.h),
              Obx(() => DropdownButtonFormField<String>(
                value: selectedType.value,
                decoration: InputDecoration(labelText: 'Contact Type'),
                items: ['family', 'caregiver', 'emergency', 'doctor', 'pharmacy', 'other']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e.capitalizeFirst!)))
                    .toList(),
                onChanged: (v) => selectedType.value = v ?? 'family',
              )),
              SizedBox(height: 12.h),
              Obx(() => DropdownButtonFormField<String>(
                value: selectedRelationship.value,
                decoration: InputDecoration(labelText: 'Relationship'),
                items: ['spouse', 'parent', 'child', 'sibling', 'friend', 'caregiver', 'doctor', 'nurse', 'other']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e.capitalizeFirst!)))
                    .toList(),
                onChanged: (v) => selectedRelationship.value = v ?? 'other',
              )),
              SizedBox(height: 12.h),
              TextField(
                controller: notesController,
                decoration: InputDecoration(labelText: 'Notes'),
                maxLines: 2,
              ),
              SizedBox(height: 12.h),
              Obx(() => SwitchListTile(
                title: Text('Emergency Contact'),
                value: isEmergency.value,
                onChanged: (v) => isEmergency.value = v,
                contentPadding: EdgeInsets.zero,
              )),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isEmpty) {
                Get.snackbar('Error', 'Name is required');
                return;
              }
              final data = {
                'name': nameController.text,
                'contact_type': selectedType.value,
                'relationship': selectedRelationship.value,
                'phone_number': phoneController.text.isEmpty ? null : phoneController.text,
                'email': emailController.text.isEmpty ? null : emailController.text,
                'notes': notesController.text.isEmpty ? null : notesController.text,
                'is_emergency': isEmergency.value,
              };
              Get.back();
              controller.updateContact(contact.id, data);
            },
            child: Text('Save'),
          ),
        ],
      ),
    );
  }
}
