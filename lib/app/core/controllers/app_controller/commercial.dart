part of '../app_controller.dart';

mixin _CommercialMixin on _AppControllerBase {
  List<CommercialLead> get commercialLeads =>
      List.unmodifiable(_commercialLeads);

  Future<void> fetchCommercialLeads({String filter = 'all'}) async {
    if (!isCommercial || !AppConfig.enableRemoteSync) return;
    final email = profile?.email;
    if (email == null || email.isEmpty) return;
    // Dedup the simultaneous startup fetch from the Leads + Conversations tabs.
    if (isLoadingCommercialLeads) return;

    isLoadingCommercialLeads = true;
    commercialLeadsError = null;
    update();

    try {
      final items = await _apiClient.listCommercialLeads(
        email: email,
        filter: filter,
      );
      _commercialLeads
        ..clear()
        ..addAll(items);
    } catch (e, s) {
      commercialLeadsError = userFacingSyncError(e, localeCode);
      safeRecordError(
        e,
        s,
        reason: 'fetchCommercialLeads',
        domain: CrashlyticsObsDomain.sync,
        operation: 'fetch_commercial_leads',
      );
    } finally {
      isLoadingCommercialLeads = false;
      update();
    }
  }

  Future<void> updateCommercialLeadTag(
    String caseId, {
    required String leadTag,
    String? discussionMotive,
  }) async {
    if (!AppConfig.enableRemoteSync) return;
    try {
      await _apiClient.updateCommercialLead(
        caseId,
        leadTag: leadTag,
        discussionMotive: discussionMotive,
      );
      await fetchCommercialLeads();
    } catch (e, s) {
      safeRecordError(
        e,
        s,
        reason: 'updateCommercialLeadTag',
        domain: CrashlyticsObsDomain.sync,
        operation: 'update_commercial_lead',
      );
      rethrow;
    }
  }

  /// Records a counsellor verdict ('validated' | 'redo' | 'doubtful') on an
  /// uploaded case document (Feature D). Patches the in-memory lead so the
  /// Dossiers list stays consistent, and returns the updated document.
  Future<CommercialLeadDocument> reviewCommercialDocument(
    String caseId,
    String documentId, {
    required String status,
  }) async {
    try {
      final data = await _apiClient.reviewCommercialDocument(
        documentId,
        status: status,
      );
      final updatedDoc = CommercialLeadDocument.fromApi(data);
      final idx = _commercialLeads.indexWhere((l) => l.id == caseId);
      if (idx != -1) {
        final lead = _commercialLeads[idx];
        final docs = lead.documents
            .map((d) => d.id == updatedDoc.id ? updatedDoc : d)
            .toList(growable: false);
        _commercialLeads[idx] = lead.copyWith(documents: docs);
        update();
      }
      return updatedDoc;
    } catch (e, s) {
      safeRecordError(
        e,
        s,
        reason: 'reviewCommercialDocument',
        domain: CrashlyticsObsDomain.sync,
        operation: 'review_commercial_document',
      );
      rethrow;
    }
  }

  Future<void> fetchCommercialStats() async {
    if (!isCommercial || !AppConfig.enableRemoteSync) return;
    final email = profile?.email;
    if (email == null || email.isEmpty) return;

    isLoadingCommercialStats = true;
    update();

    try {
      final data = await _apiClient.getCommercialStats(email: email);
      commercialStats = CommercialStats.fromApi(data);
    } catch (e, s) {
      safeRecordError(
        e,
        s,
        reason: 'fetchCommercialStats',
        domain: CrashlyticsObsDomain.sync,
        operation: 'fetch_commercial_stats',
      );
    } finally {
      isLoadingCommercialStats = false;
      update();
    }
  }
}
