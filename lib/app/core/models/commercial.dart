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
    this.documents = const <CommercialLeadDocument>[],
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

  /// Uploaded case documents the counsellor can review (Feature D).
  final List<CommercialLeadDocument> documents;

  factory CommercialLead.fromApi(Map<String, dynamic> json) {
    final rawDocs = json['documents'];
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
      documents: rawDocs is List
          ? rawDocs
              .whereType<Map<String, dynamic>>()
              .map(CommercialLeadDocument.fromApi)
              .toList()
          : const <CommercialLeadDocument>[],
    );
  }

  CommercialLead copyWith({List<CommercialLeadDocument>? documents}) {
    return CommercialLead(
      id: id,
      referenceCode: referenceCode,
      title: title,
      status: status,
      studentName: studentName,
      studentLevel: studentLevel,
      leadTag: leadTag,
      discussionMotive: discussionMotive,
      createdAt: createdAt,
      updatedAt: updatedAt,
      unreadMessages: unreadMessages,
      documents: documents ?? this.documents,
    );
  }
}

/// A single uploaded document on a case, with the counsellor's review verdict.
/// [reviewStatus] is one of 'validated' | 'redo' | 'doubtful', or null when
/// still pending review.
class CommercialLeadDocument {
  const CommercialLeadDocument({
    required this.id,
    required this.title,
    required this.isProvided,
    this.uploadedAt,
    this.reviewStatus,
    this.reviewedByName,
    this.reviewedAt,
  });

  final String id;
  final String title;
  final bool isProvided;
  final DateTime? uploadedAt;
  final String? reviewStatus;
  final String? reviewedByName;
  final DateTime? reviewedAt;

  bool get isReviewed => reviewStatus != null && reviewStatus!.isNotEmpty;

  factory CommercialLeadDocument.fromApi(Map<String, dynamic> json) {
    return CommercialLeadDocument(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      isProvided: json['isProvided'] as bool? ?? false,
      uploadedAt: DateTime.tryParse(json['uploadedAt'] as String? ?? ''),
      reviewStatus: json['reviewStatus'] as String?,
      reviewedByName: json['reviewedByName'] as String?,
      reviewedAt: DateTime.tryParse(json['reviewedAt'] as String? ?? ''),
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
