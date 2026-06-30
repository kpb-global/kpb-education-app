part of 'app_models.dart';

class CommercialLead {
  const CommercialLead({
    required this.id,
    required this.referenceCode,
    required this.title,
    required this.status,
    required this.studentName,
    this.studentLevel,
    this.leadTag,
    this.discussionMotive,
    required this.createdAt,
    required this.updatedAt,
    this.unreadMessages = 0,
  });

  final String id;
  final String referenceCode;
  final String title;
  final String status;
  final String studentName;
  final String? studentLevel;
  final String? leadTag;
  final String? discussionMotive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int unreadMessages;

  factory CommercialLead.fromApi(Map<String, dynamic> json) {
    return CommercialLead(
      id: json['id'] as String? ?? '',
      referenceCode: json['referenceCode'] as String? ?? '',
      title: json['title'] as String? ?? '',
      status: json['status'] as String? ?? '',
      studentName: json['studentName'] as String? ?? '',
      studentLevel: json['studentLevel'] as String?,
      leadTag: json['leadTag'] as String?,
      discussionMotive: json['discussionMotive'] as String?,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
      unreadMessages: json['unreadMessages'] as int? ?? 0,
    );
  }
}

class CommercialStats {
  const CommercialStats({
    required this.totalLeads,
    required this.convertedLast30Days,
    this.avgFirstResponseMinutes,
  });

  final int totalLeads;
  final int convertedLast30Days;
  final int? avgFirstResponseMinutes;

  factory CommercialStats.fromApi(Map<String, dynamic> json) {
    return CommercialStats(
      totalLeads: json['totalLeads'] as int? ?? 0,
      convertedLast30Days: json['convertedLast30Days'] as int? ?? 0,
      avgFirstResponseMinutes: json['avgFirstResponseMinutes'] as int?,
    );
  }

  static const empty = CommercialStats(
    totalLeads: 0,
    convertedLast30Days: 0,
  );
}

/// A single video from the KPB YouTube playlist (Chantier C — section Parcours).
