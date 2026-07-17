import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/controllers/app_controller.dart';
import '../../core/services/coach_service.dart';
import '../tools/motivation_letters_screen.dart';
import '../../core/ui/app_tokens.dart';

// Couleurs : tokens sémantiques centraux (KpbColors/KpbShadow — architecture §10.2).
const _cardShadow = <BoxShadow>[
  BoxShadow(color: KpbShadow.softNavy, blurRadius: 2, offset: Offset(0, 1)),
];

class AiMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  const AiMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final _coach = CoachService();
  final List<AiMessage> _messages = [];
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isTyping = false;
  int _remainingMessages = 5;
  int _weeklyQuota = 5;
  List<String> _suggestions = const [];
  String? _assistantDraft;

  @override
  void initState() {
    super.initState();
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    final controller = Get.find<AppController>();
    final profile = controller.profile;
    if (profile == null) return;

    final quota = await _coach.fetchQuota(profile.id);
    final suggestions = await _coach.fetchSuggestions(profile.id);
    final conversationId =
        await _coach.ensureConversation(userId: profile.id, profile: profile);
    final history = await _coach.fetchHistory(conversationId);

    if (!mounted) return;
    setState(() {
      _remainingMessages = quota.remaining;
      _weeklyQuota = quota.limit;
      _suggestions = suggestions;
      if (history.isNotEmpty) {
        // Rehydrate the persisted conversation (survives app restarts).
        _messages.addAll(history.map(
          (m) => AiMessage(
            text: m.content,
            isUser: m.isUser,
            timestamp: DateTime.now(),
          ),
        ));
      } else {
        _messages.add(AiMessage(
          text: 'coach_welcome_message'
              .trParams({'name': profile.fullName.split(' ').first}),
          isUser: false,
          timestamp: DateTime.now(),
        ));
      }
    });
    _scrollToBottom();
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Honest tap target for the quota chip. Premium is NOT built yet (a later
  /// PR), so this only surfaces the real remaining/limit — never a paywall or
  /// fake checkout.
  void _showQuotaInfo() {
    Get.snackbar(
      'coach_quota_info_title'.tr,
      'coach_quota_info_body'.trParams({
        'rem': '$_remainingMessages',
        'total': '$_weeklyQuota',
      }),
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 3),
    );
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    if (_remainingMessages <= 0) {
      Get.snackbar(
        'coach_quota_reached_title'.tr,
        'coach_quota_reached_body'.trParams({'quota': '$_weeklyQuota'}),
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 4),
      );
      return;
    }

    final controller = Get.find<AppController>();
    final profile = controller.profile;
    if (profile == null) return;

    setState(() {
      _messages.add(AiMessage(
        text: text,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _isTyping = true;
      _assistantDraft = '';
    });
    _scrollToBottom();
    _textController.clear();

    var assistantIndex = -1;

    try {
      await for (final event in _coach.sendMessage(
        userId: profile.id,
        profile: profile,
        message: text,
      )) {
        if (!mounted) return;

        if (event.type == 'error') {
          setState(() {
            _isTyping = false;
            _messages.add(AiMessage(
              text: event.message ?? 'coach_unavailable'.tr,
              isUser: false,
              timestamp: DateTime.now(),
            ));
          });
          break;
        }

        if (event.type == 'token' && event.text != null) {
          _assistantDraft = '${_assistantDraft ?? ''}${event.text}';
          if (assistantIndex == -1) {
            _messages.add(AiMessage(
              text: _assistantDraft!,
              isUser: false,
              timestamp: DateTime.now(),
            ));
            assistantIndex = _messages.length - 1;
          } else {
            _messages[assistantIndex] = AiMessage(
              text: _assistantDraft!,
              isUser: false,
              timestamp: _messages[assistantIndex].timestamp,
            );
          }
          setState(() {});
          _scrollToBottom();
        }

        if (event.type == 'done') {
          setState(() {
            _isTyping = false;
            if (event.quotaRemaining != null) {
              _remainingMessages = event.quotaRemaining!;
            } else {
              _remainingMessages =
                  (_remainingMessages - 1).clamp(0, _weeklyQuota);
            }
          });
        }
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isTyping = false;
        _messages.add(AiMessage(
          text: 'coach_unreachable'.tr,
          isUser: false,
          timestamp: DateTime.now(),
        ));
      });
    }

    if (mounted && _isTyping) {
      setState(() => _isTyping = false);
    }
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KpbColors.canvas,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            if (_remainingMessages <= 0)
              Container(
                width: double.infinity,
                color: KpbColors.warningLight,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Text(
                  'coach_quota_exhausted'.tr,
                  style: const TextStyle(
                    color: KpbColors.warning,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length +
                    (_isTyping && _assistantDraft == null ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _messages.length) {
                    return _buildTypingIndicator();
                  }
                  final msg = _messages[index];
                  return _buildMessageBubble(msg);
                },
              ),
            ),
            if (_messages.length <= 2 && !_isTyping && _suggestions.isNotEmpty)
              _buildSuggestions(),
            _buildInputBar(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: const BoxDecoration(
        color: KpbColors.surface,
        border: Border(bottom: BorderSide(color: KpbColors.border)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Get.back(),
            child: Semantics(
              button: true,
              label: 'a11y_back'.tr,
              child: const SizedBox(
                width: 36,
                height: 36,
                child: Icon(Icons.arrow_back_rounded,
                    color: KpbColors.brandNavy, size: 20),
              ),
            ),
          ),
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [KpbColors.actionPrimary, KpbColors.decorSky],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.smart_toy_rounded,
                color: Colors.white, size: 19),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'coach_ai_title'.tr,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: KpbColors.brandNavy,
                  ),
                ),
                Text(
                  'coach_status_tagline'.tr,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: KpbColors.success,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Real quota chip — bound to CoachService quota. Tap is an honest
          // info toast (Premium is a later PR), never a paywall.
          GestureDetector(
            onTap: _showQuotaInfo,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: KpbColors.surfaceMuted,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                '$_remainingMessages/$_weeklyQuota',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: KpbColors.textMuted,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(AiMessage msg) {
    final isUser = msg.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * (isUser ? 0.82 : 0.88),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: isUser ? KpbColors.actionPrimary : KpbColors.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
          border: isUser ? null : Border.all(color: KpbColors.border),
          boxShadow: isUser ? null : _cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _parseAndRichText(msg.text, isUser),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.bottomRight,
              child: Text(
                "${msg.timestamp.hour.toString().padLeft(2, '0')}:${msg.timestamp.minute.toString().padLeft(2, '0')}",
                style: TextStyle(
                  fontSize: 9.5,
                  color: isUser ? Colors.white70 : KpbColors.textFaint,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Renders **bold** markdown. On the user's blue bubble everything is white;
  /// on the assistant's white bubble body is navy and bold is accented blue.
  Widget _parseAndRichText(String text, bool isUser) {
    final baseColor = isUser ? Colors.white : KpbColors.brandNavy;
    final boldColor = isUser ? Colors.white : KpbColors.actionPrimary;
    final baseStyle = TextStyle(color: baseColor, fontSize: 13, height: 1.5);

    final spans = <InlineSpan>[];
    final lines = text.split('\n');

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.isEmpty) {
        spans.add(const TextSpan(text: '\n'));
        continue;
      }
      final parts = line.split('**');
      for (var j = 0; j < parts.length; j++) {
        final isBold = j % 2 == 1;
        spans.add(TextSpan(
          text: parts[j],
          style: TextStyle(
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w500,
            color: isBold ? boldColor : baseColor,
          ),
        ));
      }
      if (i < lines.length - 1) {
        spans.add(const TextSpan(text: '\n'));
      }
    }

    return RichText(text: TextSpan(style: baseStyle, children: spans));
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: KpbColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: KpbColors.border),
          boxShadow: _cardShadow,
        ),
        child: const SizedBox(
          width: 34,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _TypingDot(index: 0),
              _TypingDot(index: 1),
              _TypingDot(index: 2),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: _suggestions.map((sug) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: GestureDetector(
              onTap: () => _sendMessage(sug),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: KpbColors.surface,
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(
                      color: KpbColors.actionPrimary.withValues(alpha: 0.3),
                      width: 1.5),
                ),
                child: Text(
                  sug,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: KpbColors.actionPrimary,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildInputBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: const BoxDecoration(
        color: KpbColors.canvas,
        border: Border(top: BorderSide(color: KpbColors.border, width: 0.5)),
      ),
      child: Row(
        children: [
          // Left round button → the real motivation-letter tool.
          Semantics(
            button: true,
            label: 'coach_generate_letter'.tr,
            child: GestureDetector(
              onTap: () => Get.to(() => const MotivationLettersScreen()),
              child: Container(
                width: 46,
                height: 46,
                decoration: const BoxDecoration(
                  color: KpbColors.surfaceMuted,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.edit_note_rounded,
                    color: KpbColors.textMuted, size: 22),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                color: KpbColors.surface,
                borderRadius: BorderRadius.circular(100),
                border: Border.all(color: KpbColors.border, width: 1.5),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _textController,
                style: const TextStyle(
                  color: KpbColors.brandNavy,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  hintText: 'coach_input_hint'.tr,
                  hintStyle:
                      const TextStyle(color: KpbColors.textFaint, fontSize: 13),
                  border: InputBorder.none,
                  isCollapsed: true,
                ),
                onSubmitted: _sendMessage,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Semantics(
            button: true,
            label: 'a11y_send_message'.tr,
            child: GestureDetector(
              onTap: () => _sendMessage(_textController.text),
              child: Container(
                height: 46,
                width: 46,
                decoration: const BoxDecoration(
                  color: KpbColors.actionPrimary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.send_rounded,
                    color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypingDot extends StatefulWidget {
  final int index;
  const _TypingDot({required this.index});

  @override
  State<_TypingDot> createState() => _TypingDotState();
}

class _TypingDotState extends State<_TypingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _anim;

  static const _colors = [
    KpbColors.textFaint,
    KpbColors.borderStrong,
    KpbColors.border
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _anim = Tween<double>(begin: 0, end: -6).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeInOut,
      ),
    );

    Future.delayed(Duration(milliseconds: widget.index * 150), () {
      if (mounted) {
        _animController.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _anim.value),
          child: Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: _colors[widget.index % _colors.length],
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }
}
