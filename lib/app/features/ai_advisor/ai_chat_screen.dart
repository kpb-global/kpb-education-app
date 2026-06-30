import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/controllers/app_controller.dart';
import '../../core/services/coach_service.dart';
import '../../core/ui/app_tokens.dart';
import '../../core/ui/kpb_theme_ext.dart';

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
          text:
              "Bonjour ${profile.fullName.split(' ').first} ! Je suis ton Coach KPB. 🤖\n\nPose-moi tes questions sur les écoles, le budget ou les filières partenaires.",
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

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    if (_remainingMessages <= 0) {
      Get.snackbar(
        'Quota Coach IA atteint',
        'Tu as atteint la limite de $_weeklyQuota messages cette semaine. Reviens la semaine prochaine ou contacte un conseiller humain.',
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
              text: event.message ?? 'Coach indisponible.',
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
          text: 'Impossible de joindre le coach IA pour le moment.',
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
      backgroundColor: context.kpb.pageBg,
      body: Container(
        decoration: const BoxDecoration(
          color: KpbColors.bgDarkMidnight,
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(context),
              if (_remainingMessages <= 0)
                Container(
                  width: double.infinity,
                  color: KpbColors.gold.withValues(alpha: 0.15),
                  padding: const EdgeInsets.symmetric(
                    horizontal: KpbSpacing.pagePad,
                    vertical: 8,
                  ),
                  child: Text(
                    'Quota épuisé — Premium bientôt disponible ou contacte un conseiller KPB.',
                    style: TextStyle(
                      color: KpbColors.gold.withValues(alpha: 0.95),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(KpbSpacing.pagePad),
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
              if (_messages.length <= 2 &&
                  !_isTyping &&
                  _suggestions.isNotEmpty)
                _buildSuggestions(),
              _buildInputBar(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: KpbSpacing.pagePad,
        vertical: KpbSpacing.sm + 4,
      ),
      decoration: BoxDecoration(
        color: KpbColors.bgDarkCard.withValues(alpha: 0.8),
        border: const Border(
          bottom: BorderSide(color: KpbColors.glassBorder),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Get.back(),
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          ),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: KpbColors.stitchHeroGradient,
              borderRadius: KpbRadius.mdBr,
            ),
            child: const Icon(Icons.psychology_rounded,
                color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Coach IA',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                Row(
                  children: [
                    Icon(Icons.circle,
                        size: 8, color: KpbColors.stitchCyberCyan),
                    const SizedBox(width: 4),
                    Text(
                      'En ligne • $_remainingMessages/$_weeklyQuota restants cette semaine',
                      style: TextStyle(
                        fontSize: 11,
                        color: KpbColors.textDarkSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(AiMessage msg) {
    final bubbleBg = msg.isUser ? KpbColors.blue : KpbColors.bgDarkCard;
    final bubbleBorder = msg.isUser
        ? Border.all(color: KpbColors.blue.withValues(alpha: 0.5))
        : Border.all(color: KpbColors.glassBorder);
    final textStyle = TextStyle(
      color: Colors.white,
      fontSize: 14.5,
      height: 1.45,
    );

    return Align(
      alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: KpbSpacing.md),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: bubbleBg,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(KpbRadius.md),
            topRight: const Radius.circular(KpbRadius.md),
            bottomLeft: Radius.circular(msg.isUser ? KpbRadius.md : 4),
            bottomRight: Radius.circular(msg.isUser ? 4 : KpbRadius.md),
          ),
          border: bubbleBorder,
          boxShadow: KpbShadow.soft,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _parseAndRichText(msg.text, textStyle),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.bottomRight,
              child: Text(
                "${msg.timestamp.hour.toString().padLeft(2, '0')}:${msg.timestamp.minute.toString().padLeft(2, '0')}",
                style: const TextStyle(
                  fontSize: 9.5,
                  color: KpbColors.textDarkSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _parseAndRichText(String text, TextStyle baseStyle) {
    final words = <InlineSpan>[];
    final lines = text.split('\n');

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.isEmpty) {
        words.add(const TextSpan(text: '\n'));
        continue;
      }

      final parts = line.split('**');
      final spans = <InlineSpan>[];
      for (var j = 0; j < parts.length; j++) {
        final isBold = j % 2 == 1;
        spans.add(TextSpan(
          text: parts[j],
          style: TextStyle(
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w400,
            color: isBold ? KpbColors.stitchCyberCyan : Colors.white,
          ),
        ));
      }

      words.add(TextSpan(children: spans));
      if (i < lines.length - 1) {
        words.add(const TextSpan(text: '\n'));
      }
    }

    return RichText(
      text: TextSpan(
        style: baseStyle,
        children: words,
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: KpbSpacing.md),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: KpbColors.bgDarkCard,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(KpbRadius.md),
            topRight: Radius.circular(KpbRadius.md),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(KpbRadius.md),
          ),
          border: Border.all(color: KpbColors.glassBorder),
        ),
        child: SizedBox(
          width: 40,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(3, (index) {
              return _TypingDot(index: index);
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestions() {
    return Container(
      height: 42,
      margin: const EdgeInsets.only(bottom: KpbSpacing.sm),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: KpbSpacing.pagePad),
        itemCount: _suggestions.length,
        itemBuilder: (context, index) {
          final sug = _suggestions[index];
          return GestureDetector(
            onTap: () => _sendMessage(sug),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: KpbColors.bgDarkCard,
                borderRadius: KpbRadius.pillBr,
                border: Border.all(
                    color: KpbColors.stitchCyberCyan.withValues(alpha: 0.3)),
              ),
              child: Center(
                child: Text(
                  sug,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: KpbColors.stitchCyberCyan,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInputBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        KpbSpacing.pagePad,
        KpbSpacing.sm,
        KpbSpacing.pagePad,
        KpbSpacing.md,
      ),
      decoration: BoxDecoration(
        color: KpbColors.bgDarkMidnight,
        border: const Border(
          top: BorderSide(color: KpbColors.glassBorder, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: KpbColors.bgDarkCard,
                borderRadius: KpbRadius.mdBr,
                border: Border.all(color: KpbColors.glassBorder),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: TextField(
                controller: _textController,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: const InputDecoration(
                  hintText: 'Posez votre question sur les écoles, budgets...',
                  hintStyle: TextStyle(
                      color: KpbColors.textDarkSecondary, fontSize: 13),
                  border: InputBorder.none,
                ),
                onSubmitted: _sendMessage,
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => _sendMessage(_textController.text),
            child: Container(
              height: 48,
              width: 48,
              decoration: BoxDecoration(
                gradient: KpbColors.stitchHeroGradient,
                borderRadius: KpbRadius.mdBr,
                boxShadow: KpbShadow.blue,
              ),
              child:
                  const Icon(Icons.send_rounded, color: Colors.white, size: 20),
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
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: KpbColors.stitchCyberCyan,
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }
}
