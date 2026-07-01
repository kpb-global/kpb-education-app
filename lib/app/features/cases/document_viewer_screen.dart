import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../../core/ui/app_tokens.dart';

class DocumentViewerScreen extends StatelessWidget {
  /// Renders a PDF from a network URL or a local File.
  const DocumentViewerScreen({
    super.key,
    required this.title,
    this.url,
    this.file,
  }) : assert(url != null || file != null, 'Must provide either url or file');

  final String title;
  final String? url;
  final File? file;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontSize: 16)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 1,
        shadowColor: Colors.black12,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Get.back(),
        ),
        actions: [
          if (url != null)
            IconButton(
              icon: const Icon(Icons.download_rounded),
              onPressed: () {
                // Future enhancement: Download and save the PDF locally.
                Get.snackbar(
                  'doc_viewer_download_title'.tr,
                  'doc_viewer_download_body'.tr,
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: KpbColors.blue,
                  colorText: Colors.white,
                );
              },
            ),
        ],
      ),
      body: url != null
          ? SfPdfViewer.network(
              url!,
              canShowScrollHead: false,
              canShowScrollStatus: false,
            )
          : SfPdfViewer.file(
              file!,
              canShowScrollHead: false,
              canShowScrollStatus: false,
            ),
    );
  }
}
