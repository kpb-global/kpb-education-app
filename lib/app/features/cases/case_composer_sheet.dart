import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/controllers/app_controller.dart';
import '../../core/models/app_models.dart';

class CaseComposerSheet extends StatefulWidget {
  const CaseComposerSheet({
    super.key,
    required this.caseType,
    required this.title,
    required this.contextLabel,
  });

  final CaseType caseType;
  final String title;
  final String contextLabel;

  @override
  State<CaseComposerSheet> createState() => _CaseComposerSheetState();
}

class _CaseComposerSheetState extends State<CaseComposerSheet> {
  final _descriptionController = TextEditingController();
  ContactMethod _contactMethod = ContactMethod.inApp;

  AppController get _controller => Get.find<AppController>();

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'create_case'.tr,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          Text(widget.title),
          const SizedBox(height: 16),
          TextField(
            controller: _descriptionController,
            minLines: 3,
            maxLines: 5,
            decoration: InputDecoration(
              labelText: 'description'.tr,
              hintText: 'case_description_hint'.tr,
            ),
          ),
          const SizedBox(height: 16),
          Text('contact_method'.tr),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: ContactMethod.values.map((method) {
              final selected = _contactMethod == method;
              return ChoiceChip(
                label: Text(_label(method)),
                selected: selected,
                onSelected: (_) => setState(() {
                  _contactMethod = method;
                }),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('close'.tr),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    final description = _descriptionController.text.trim().isEmpty
                        ? 'case_default_title'.trParams({'title': widget.title})
                        : _descriptionController.text.trim();
                    _controller.submitCase(
                      type: widget.caseType,
                      title: widget.title,
                      description: description,
                      contextLabel: widget.contextLabel,
                      contactMethod: _contactMethod,
                    );
                    Navigator.of(context).pop();
                    Get.snackbar(
                      'KPB Education',
                      'request_submitted'.tr,
                      snackPosition: SnackPosition.BOTTOM,
                    );
                  },
                  child: Text('submit'.tr),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _label(ContactMethod method) {
    switch (method) {
      case ContactMethod.inApp:
        return 'In-app';
      case ContactMethod.whatsapp:
        return 'WhatsApp';
      case ContactMethod.phone:
        return 'Phone call';
    }
  }
}
