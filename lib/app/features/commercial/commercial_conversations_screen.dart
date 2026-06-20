import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/controllers/app_controller.dart';
import '../../core/models/app_models.dart';
import '../../core/ui/kpb_components.dart';
import '../cases/case_detail_screen.dart';

/// Conversations actives — commercial (M9).
class CommercialConversationsScreen extends StatefulWidget {
  const CommercialConversationsScreen({super.key});

  @override
  State<CommercialConversationsScreen> createState() =>
      _CommercialConversationsScreenState();
}

class _CommercialConversationsScreenState
    extends State<CommercialConversationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Get.find<AppController>().fetchCommercialLeads();
    });
  }

  Future<void> _refresh() =>
      Get.find<AppController>().fetchCommercialLeads();

  /// Conversations are leads sorted with unread first, then most recent.
  List<CommercialLead> _conversationOrder(List<CommercialLead> leads) {
    final sorted = [...leads];
    sorted.sort((a, b) {
      if ((a.unreadMessages > 0) != (b.unreadMessages > 0)) {
        return a.unreadMessages > 0 ? -1 : 1;
      }
      return b.updatedAt.compareTo(a.updatedAt);
    });
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<AppController>(
      builder: (controller) {
        final leads = _conversationOrder(controller.commercialLeads);

        return Scaffold(
          appBar: AppBar(title: Text('nav_commercial_chat'.tr)),
          body: _buildBody(controller, leads),
        );
      },
    );
  }

  Widget _buildBody(AppController controller, List<CommercialLead> leads) {
    if (controller.isLoadingCommercialLeads && leads.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (leads.isEmpty) {
      // Surface a connection error distinctly from a genuine empty inbox.
      if (controller.commercialLeadsError != null) {
        return KpbEmptyState(
          icon: Icons.cloud_off_outlined,
          title: 'Erreur de chargement',
          subtitle: controller.commercialLeadsError!,
          actionLabel: 'Réessayer',
          onAction: _refresh,
        );
      }
      return KpbEmptyState(
        icon: Icons.chat_bubble_outline_rounded,
        title: 'commercial_no_chat_title'.tr,
        subtitle: 'commercial_no_chat_body'.tr,
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: leads.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final lead = leads[index];
          final hasUnread = lead.unreadMessages > 0;
          return ListTile(
            leading: CircleAvatar(
              child: Text(
                lead.studentName.isNotEmpty
                    ? lead.studentName[0].toUpperCase()
                    : '?',
              ),
            ),
            title: Text(lead.studentName),
            subtitle: Text(lead.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: hasUnread
                ? CircleAvatar(
                    radius: 12,
                    backgroundColor: KpbColors.error,
                    child: Text(
                      lead.unreadMessages > 9 ? '9+' : '${lead.unreadMessages}',
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  )
                : const Icon(Icons.chevron_right_rounded),
            onTap: () => Get.to(() => CaseDetailScreen(caseId: lead.id)),
          );
        },
      ),
    );
  }
}
