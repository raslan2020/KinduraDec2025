class ConservationModel {
  bool? status;
  List<Result>? result;

  ConservationModel({this.status, this.result});

  ConservationModel.fromJson(Map<String, dynamic> json) {
    status = json['status'];
    if (json['result'] != null) {
      result = <Result>[];
      json['result'].forEach((v) {
        result!.add(new Result.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['status'] = this.status;
    if (this.result != null) {
      data['result'] = this.result!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class Result {
  int? id;
  String? status;
  String? uploadedAt;
  String? summarizePatientReport;
  Conservation? conservation;
  String? errorMessage;

  Result(
      {this.id,
      this.status,
      this.uploadedAt,
      this.summarizePatientReport,
      this.conservation,
      this.errorMessage});

  Result.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    status = json['status'];
    uploadedAt = json['uploaded_at'];
    summarizePatientReport = json['summarize_patient_report'];
    conservation = json['conservation'] != null
        ? new Conservation.fromJson(json['conservation'])
        : null;
    errorMessage = json['error_message'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this.id;
    data['status'] = this.status;
    data['uploaded_at'] = this.uploadedAt;
    data['summarize_patient_report'] = this.summarizePatientReport;
    if (this.conservation != null) {
      data['conservation'] = this.conservation!.toJson();
    }
    data['error_message'] = this.errorMessage;
    return data;
  }
}

class Conservation {
  Conversation? conversation;
  CourseDetail? courseDetail;
  Item? item;

  Conservation({this.conversation, this.courseDetail, this.item});

  Conservation.fromJson(Map<String, dynamic> json) {
    // Handle Toon format: msgs at root level
    if (json.containsKey('msgs')) {
      conversation = Conversation.fromJson(json);
      // Handle Toon course detail (crs instead of course_detail)
      if (json['crs'] != null) {
        courseDetail = CourseDetail.fromJson({
          'course_id': json['crs']['id'],
          'course_name': json['crs']['n'],
          'course_schedule': json['crs']['s'],
        });
      }
    } else {
      // Legacy format
      conversation = json['conversation'] != null
          ? Conversation.fromJson(json['conversation'])
          : null;
      courseDetail = json['course_detail'] != null
          ? CourseDetail.fromJson(json['course_detail'])
          : null;
    }
    item = json['item'] != null ? Item.fromJson(json['item']) : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    if (this.conversation != null) {
      data['conversation'] = this.conversation!.toJson();
    }
    if (this.courseDetail != null) {
      data['course_detail'] = this.courseDetail!.toJson();
    }
    if (this.item != null) {
      data['item'] = this.item!.toJson();
    }
    return data;
  }
}

class Conversation {
  List<MessagePair> messages;

  Conversation({required this.messages});

  factory Conversation.fromJson(Map<String, dynamic> json) {
    final List<MessagePair> messages = [];

    // Try to parse Toon format first (msgs array with r/c fields)
    if (json.containsKey('msgs') && json['msgs'] is List) {
      final msgs = json['msgs'] as List;
      MessagePair? currentPair;

      for (var msg in msgs) {
        if (msg is Map<String, dynamic>) {
          final role = msg['r'] as String?;
          final content = msg['c'] as String?;

          if (role == 'a') {
            // AI message
            if (currentPair != null && currentPair.ai == null) {
              currentPair.ai = content;
            } else {
              currentPair = MessagePair(ai: content);
              messages.add(currentPair);
            }
          } else if (role == 'u') {
            // User/Human message
            if (currentPair != null && currentPair.human == null) {
              currentPair.human = content;
            } else {
              currentPair = MessagePair(human: content);
              messages.add(currentPair);
            }
          }
        }
      }
    } else {
      // Fallback to legacy format (ai_1, human_1, ai_2, human_2, etc.)
      int i = 1;
      while (true) {
        final aiKey = 'ai_$i';
        final humanKey = 'human_$i';

        if (!json.containsKey(aiKey) && !json.containsKey(humanKey)) break;

        messages.add(MessagePair(
          ai: json[aiKey],
          human: json[humanKey],
        ));
        i++;
      }
    }

    return Conversation(messages: messages);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {};
    for (var i = 0; i < messages.length; i++) {
      final index = i + 1;
      final msg = messages[i];
      if (msg.ai != null) data['ai_$index'] = msg.ai;
      if (msg.human != null) data['human_$index'] = msg.human;
    }
    return data;
  }
}

class MessagePair {
  String? ai;
  String? human;

  MessagePair({this.ai, this.human});
}

class CourseDetail {
  int? courseId;
  String? courseName;
  List<CourseSchedule>? courseSchedule;

  CourseDetail({this.courseId, this.courseName, this.courseSchedule});

  CourseDetail.fromJson(Map<String, dynamic> json) {
    courseId = json['course_id'];
    courseName = json['course_name'];
    if (json['course_schedule'] != null) {
      courseSchedule = <CourseSchedule>[];
      json['course_schedule'].forEach((v) {
        courseSchedule!.add(new CourseSchedule.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['course_id'] = this.courseId;
    data['course_name'] = this.courseName;
    if (this.courseSchedule != null) {
      data['course_schedule'] =
          this.courseSchedule!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class CourseSchedule {
  int? id;
  int? medicineId;
  String? medicineName;
  String? medicineDescription;
  String? time;
  String? dosage;
  bool? isActive;
  bool? taken;

  CourseSchedule(
      {this.id,
      this.medicineId,
      this.medicineName,
      this.medicineDescription,
      this.time,
      this.dosage,
      this.isActive,
      this.taken});

  CourseSchedule.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    medicineId = json['medicine_id'];
    medicineName = json['medicine_name'];
    medicineDescription = json['medicine_description'];
    time = json['time'];
    dosage = json['dosage'];
    isActive = json['is_active'];
    taken = json['taken'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this.id;
    data['medicine_id'] = this.medicineId;
    data['medicine_name'] = this.medicineName;
    data['medicine_description'] = this.medicineDescription;
    data['time'] = this.time;
    data['dosage'] = this.dosage;
    data['is_active'] = this.isActive;
    data['taken'] = this.taken;
    return data;
  }
}

class Item {
  List<Items>? items;

  Item({this.items});

  Item.fromJson(Map<String, dynamic> json) {
    if (json['items'] != null) {
      items = <Items>[];
      json['items'].forEach((v) {
        items!.add(new Items.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    if (this.items != null) {
      data['items'] = this.items!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class Items {
  String? id;
  String? type;
  String? role;
  List<String>? content;
  bool? interrupted;

  Items({this.id, this.type, this.role, this.content, this.interrupted});

  Items.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    type = json['type'];
    role = json['role'];
    content = json['content'].cast<String>();
    interrupted = json['interrupted'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this.id;
    data['type'] = this.type;
    data['role'] = this.role;
    data['content'] = this.content;
    data['interrupted'] = this.interrupted;
    return data;
  }
}
