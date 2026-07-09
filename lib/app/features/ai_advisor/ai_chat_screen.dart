import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/controllers/app_controller.dart';
import '../../core/services/coach_service.dart';
import '../tools/motivation_letters_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Palette (App-engagement handoff · "KPB Intelligence" / Copilote screen).
// Local to this file — same per-file pattern as the other restyled Student
// surfaces (#110–117). Visual only; all coach/quota/streaming logic is real and
// preserved.
// ─────────────────────────────────────────────────────────────────────────────
class _Palette {
  static const navy = Color(0xFF0F172A);
  static const blue = Color(0xFF2563EB);
  static const sky = Color(0xFF38BDF8);
  static const slate = Color(0xFF64748B);
  static const slate400 = Color(0xFF94A3B8);
  static const cbd5e1 = Color(0xFFCBD5E1);
  static const border = Color(0xFFE2E8F0);
  static const line = Color(0xFFF1F5F9);
  static const page = Color(0xFFF8FAFC);
  static const card = Color(0xFFFFFFFF);
  static const chipBorder = Color(0xFFBFDBFE);
  static const green = Color(0xFF16A34A);
  static const amber = Color(0xFFB45309);
  static const amberBg = Color(0xFFFEF3C7);
  // rgba(15,23,42,0.04) — soft card shadow from the handoff.
  static const cardShadow = Color(0x0A0F172A);

  static const heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [blue, sky],
  );
}

const _cardShadow = <BoxShadow>[
  BoxShadow(color: _Palette.cardShadow, blurRadius: 2, offset: Offset(0, 1)),
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
      backgroundColor: _Palette.page,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            if (_remainingMessages <= 0)
              Container(
                width: double.infinity,
                color: _Palette.amberBg,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Text(
                  'coach_quota_exhausted'.tr,
                  style: const TextStyle(
                    color: _Palette.amber,
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
        color: _Palette.card,
        border: Border(bottom: BorderSide(color: _Palette.border)),
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
                    color: _Palette.navy, size: 20),
              ),
            ),
          ),
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              gradient: _Palette.heroGradient,
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
                    color: _Palette.navy,
                  ),
                ),
                Text(
                  'coach_status_tagline'.tr,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: _Palette.green,
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
                color: _Palette.line,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                '$_remainingMessages/$_weeklyQuota',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: _Palette.slate,
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
          color: isUser ? _Palette.blue : _Palette.card,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
          border: isUser ? null : Border.all(color: _Palette.border),
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
                  color: isUser ? Colors.white70 : _Palette.slate400,
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
    final baseColor = isUser ? Colors.white : _Palette.navy;
    final boldColor = isUser ? Colors.white : _Palette.blue;
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
          color: _Palette.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _Palette.border),
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
                  color: _Palette.card,
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: _Palette.chipBorder, width: 1.5),
                ),
                child: Text(
                  sug,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _Palette.blue,
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
        color: _Palette.page,
        border: Border(top: BorderSide(color: _Palette.border, width: 0.5)),
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
                  color: _Palette.line,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.edit_note_rounded,
                    color: _Palette.slate, size: 22),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                color: _Palette.card,
                borderRadius: BorderRadius.circular(100),
                border: Border.all(color: _Palette.border, width: 1.5),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _textController,
                style: const TextStyle(
                  color: _Palette.navy,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  hintText: 'coach_input_hint'.tr,
                  hintStyle:
                      const TextStyle(color: _Palette.slate400, fontSize: 13),
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
                  color: _Palette.blue,
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

  static const _colors = [_Palette.slate400, _Palette.cbd5e1, _Palette.border];

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
