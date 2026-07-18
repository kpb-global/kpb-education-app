import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Network state exposed to assistive technologies by Success Lab screens.
enum SuccessLabNetworkUiState {
  stable,
  busy,
  offline,
}

/// Shared accessibility boundary for every Success Lab screen.
///
/// It keeps focus traversal deterministic, makes non-list states scrollable on
/// short screens and at 200% text, and exposes slow/offline/recovered changes
/// through a localized live region without duplicating visible copy.
class SuccessLabAccessibleBody extends StatefulWidget {
  const SuccessLabAccessibleBody({
    super.key,
    required this.child,
    required this.networkState,
    required this.busyLabel,
    this.ensureScrollable = false,
  });

  final Widget child;
  final SuccessLabNetworkUiState networkState;
  final String busyLabel;
  final bool ensureScrollable;

  @override
  State<SuccessLabAccessibleBody> createState() =>
      _SuccessLabAccessibleBodyState();
}

class _SuccessLabAccessibleBodyState extends State<SuccessLabAccessibleBody> {
  Timer? _recoveryTimer;
  bool _announceRecovery = false;
  bool _waitingForRecovery = false;

  @override
  void initState() {
    super.initState();
    _waitingForRecovery =
        widget.networkState == SuccessLabNetworkUiState.offline;
  }

  @override
  void didUpdateWidget(covariant SuccessLabAccessibleBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.networkState == SuccessLabNetworkUiState.offline) {
      _recoveryTimer?.cancel();
      _announceRecovery = false;
      _waitingForRecovery = true;
    } else if (_waitingForRecovery &&
        widget.networkState == SuccessLabNetworkUiState.stable) {
      _waitingForRecovery = false;
      _recoveryTimer?.cancel();
      _announceRecovery = true;
      _recoveryTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) setState(() => _announceRecovery = false);
      });
    }
  }

  @override
  void dispose() {
    _recoveryTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final focusContent = FocusTraversalGroup(
      policy: ReadingOrderTraversalPolicy(),
      child: widget.child,
    );
    Widget content = focusContent;
    if (widget.ensureScrollable) {
      content = LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          key: const ValueKey<String>('success-lab-state-scroll'),
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight:
                  constraints.hasBoundedHeight ? constraints.maxHeight : 0,
            ),
            child: focusContent,
          ),
        ),
      );
    }

    final announcement = switch (widget.networkState) {
      SuccessLabNetworkUiState.offline =>
        '${'offline_title'.tr}. ${'offline_body'.tr}',
      SuccessLabNetworkUiState.busy => widget.busyLabel,
      SuccessLabNetworkUiState.stable when _announceRecovery =>
        '${'online_title'.tr}. ${'online_body'.tr}',
      SuccessLabNetworkUiState.stable => null,
    };

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        content,
        if (announcement != null)
          Align(
            alignment: Alignment.topLeft,
            child: IgnorePointer(
              child: Semantics(
                key: const ValueKey<String>(
                  'success-lab-network-announcement',
                ),
                container: true,
                liveRegion: true,
                label: announcement,
                child: const SizedBox(width: 1, height: 1),
              ),
            ),
          ),
      ],
    );
  }
}

/// Whether dense horizontal content should stack for small screens or large
/// accessibility text. The threshold is based on the rendered 16px body size,
/// not the deprecated textScaleFactor API.
bool successLabUseStackedLayout(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  final scaledBodySize = MediaQuery.textScalerOf(context).scale(16);
  return width < 360 || scaledBodySize >= 24;
}
