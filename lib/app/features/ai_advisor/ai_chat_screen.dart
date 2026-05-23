import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  static const _weeklyQuota = 5;
  static const _quotaWeekKey = 'kpb.ai_coach.quota.week';
  static const _quotaCountKey = 'kpb.ai_coach.quota.count';

  final List<AiMessage> _messages = [];
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isTyping = false;
  int _remainingMessages = _weeklyQuota;

  final List<String> _suggestions = [
    "Quelles écoles pour un budget de 10 000€ ?",
    "Top écoles de commerce en France",
    "Formations Tech (EPITA, Epitech...)",
    "Comment postuler en école privée ?",
  ];

  @override
  void initState() {
    super.initState();
    _messages.add(AiMessage(
      text: "Bonjour ! Je suis votre conseiller d'orientation intelligent KPB Education. 🤖✨\n\nJe suis là pour vous guider vers la meilleure formation privée en France selon vos critères. "
          "Dites-moi tout : quel est votre budget annuel, votre filière d'intérêt (Commerce, Informatique, Jeux Vidéo, Ingénierie) ou votre projet d'études ?",
      isUser: false,
      timestamp: DateTime.now(),
    ));
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

  void _sendMessage(String text) {
    if (text.trim().isEmpty) return;
    if (_remainingMessages <= 0) {
      Get.snackbar(
        'Quota Coach IA atteint',
        'Tu as atteint la limite de 5 messages cette semaine. Reviens la semaine prochaine ou passe par un conseiller humain.',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 4),
      );
      return;
    }
    setState(() {
      _messages.add(AiMessage(
        text: text,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _isTyping = true;
      _remainingMessages -= 1;
    });
    unawaited(_persistQuotaCount());
    _scrollToBottom();
    _textController.clear();

    // Mock AI response logic with slight delay
    Timer(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      final responseText = _generateAiResponse(text);
      setState(() {
        _isTyping = false;
        _messages.add(AiMessage(
          text: responseText,
          isUser: false,
          timestamp: DateTime.now(),
        ));
      });
      _scrollToBottom();
    });
  }

  String _generateAiResponse(String query) {
    final q = query.toLowerCase();

    if (q.contains('budget') || q.contains('frais') || q.contains('cout') || q.contains('coût') || q.contains('tarif') || q.contains('scolarit')) {
      return "💸 **Analyse des Budgets & Frais de Scolarité** :\n\n"
          "Les frais de scolarité dans nos écoles privées partenaires en France s'échelonnent généralement de **8 000 € à 16 000 € par an** selon le cycle (BBA, Bachelor ou Master/MSc) :\n\n"
          "• **Moins de 10 000 €/an** :\n"
          "  - **ISG Paris** (BBA/Bachelor) : env. 8 900 €/an\n"
          "  - **Epitech Paris** (Bachelor Coding & Digital) : env. 9 200 €/an\n"
          "  - **EPITA Paris** (Classes préparatoires intégrées) : env. 9 900 €/an\n\n"
          "• **De 10 000 € à 15 000 €/an** :\n"
          "  - **SKEMA Business School** (BBA/MSc) : env. 11 000 € à 14 000 €/an\n"
          "  - **Rubika Valenciennes** (Animation 3D / Design / Jeu Vidéo) : env. 10 500 €/an\n"
          "  - **EDHEC / EM Lyon** (Bachelors / MSc de spécialisation) : env. 12 500 € à 15 000 €/an\n\n"
          "• **Écoles d'Élite (Master Grande École)** :\n"
          "  - **HEC Paris / ESSEC / ESCP** : de 16 000 € à plus de 24 000 € pour les derniers cycles d'excellence.\n\n"
          "💡 *Conseil KPB* : La plupart de ces écoles proposent des paiements échelonnés en 3, 4 ou 10 fois pour faciliter vos démarches financières !";
    }

    if (q.contains('commerce') || q.contains('business') || q.contains('management') || q.contains('hec') || q.contains('essec') || q.contains('escp') || q.contains('edhec') || q.contains('skema') || q.contains('isg') || q.contains('marketing') || q.contains('finance')) {
      return "💼 **Top Écoles de Commerce Partenaires en France** :\n\n"
          "Voici une sélection d'écoles d'élite avec lesquelles nous collaborons pour des inscriptions directes sécurisées :\n\n"
          "1️⃣ **HEC Paris** & **ESSEC** : Les leaders incontestés. Formations d'excellence mondiale en Management, Finance et Stratégie.\n"
          "2️⃣ **EM Lyon** & **ESCP Business School** : Réputées pour l'entrepreneuriat international et la finance d'entreprise.\n"
          "3️⃣ **EDHEC** & **SKEMA** : Excellents Bachelors et Masters en double-diplôme, forte présence à l'international.\n"
          "4️⃣ **ISG Paris** : Une école moderne et très ouverte aux étudiants internationaux, proposant d'excellents cursus BBA et MBA spécialisés à un coût très compétitif (env. 9 000 €/an).\n\n"
          "✨ *Avantage KPB* : En postulant via notre plateforme, vous bénéficiez d'une exemption de certains frais de dossier et d'un accompagnement personnalisé pour la préparation de vos oraux d'admission ! Vous voulez démarrer une candidature ?";
    }

    if (q.contains('tech') || q.contains('informatique') || q.contains('ingénieur') || q.contains('code') || q.contains('epita') || q.contains('epitech') || q.contains('rubika') || q.contains('jeu') || q.contains('design') || q.contains('animation')) {
      return "💻 **Filières Tech, Ingénierie & Design Numérique** :\n\n"
          "Pour les profils scientifiques et créatifs, la France abrite des fleurons de l'éducation privée :\n\n"
          "• **EPITA Paris** : L'école d'ingénieurs de référence en Intelligence Artificielle, Cybersécurité et Software Engineering. Diplôme CTI (reconnu par l'État au plus haut niveau).\n"
          "• **Epitech Paris** : La pédagogie par projet active par excellence. Parfait pour les profils passionnés de développement logiciel et d'innovation web qui veulent coder dès le premier jour.\n"
          "• **Rubika Valenciennes** : Classée dans le Top 3 mondial des écoles d'Animation 3D, de Design Industriel et de Jeu Vidéo. Un taux d'employabilité de 99% chez Pixar, Ubisoft et d'autres grands studios.\n\n"
          "👉 *Quelle école vous inspire le plus pour votre carrière ?* Nous pouvons planifier un entretien blanc pour consolider vos chances d'admission.";
    }

    if (q.contains('postuler') || q.contains('inscription') || q.contains('dossier') || q.contains('comment') || q.contains('candidat') || q.contains('admiss')) {
      return "📝 **Comment postuler et garantir votre admission ?**\n\n"
          "Le processus d'admission directe via KPB Education est simplifié et hautement sécurisé :\n\n"
          "1️⃣ **Créez votre dossier sur l'application** : Allez dans l'onglet **Dossier** et cliquez sur 'Nouveau dossier'.\n"
          "2️⃣ **Téléchargez vos pièces justificatives** : Bulletins de notes (les 3 dernières années), diplômes, CV et lettre de motivation.\n"
          "3️⃣ **Sélectionnez vos vœux d'écoles** : Vous pouvez choisir jusqu'à 3 écoles partenaires (comme EPITA, Rubika, SKEMA, ISG...).\n"
          "4️⃣ **Validation KPB** : Notre équipe de conseillers audite votre dossier sous 48h, l'optimise, puis le soumet directement aux directeurs d'admissions des écoles concernées.\n\n"
          "🚀 *Statistique clé* : 98% des étudiants accompagnés par KPB obtiennent au moins une admission ferme dans nos établissements partenaires ! Cliquez sur l'onglet **Dossier** (3ème bouton de la barre de navigation) pour démarrer !";
    }

    if (q.contains('pays') || q.contains('destination') || q.contains('france') || q.contains('canada') || q.contains('maroc')) {
      return "🌍 **Comparatif des Destinations d'Études** :\n\n"
          "• **France (Inscriptions Directes Privées)** : \n"
          "  - Logement facilité dans nos résidences partenaires.\n"
          "  - Pas de procédure Campus France bloquante si vous postulez dans certaines écoles privées hors plateforme nationale.\n"
          "  - Alternance possible en Master pour financer 100% de vos études.\n\n"
          "• **Canada (Universités Partenaires)** :\n"
          "  - Opportunités de travail post-études de 3 ans.\n"
          "  - Pédagogie anglo-saxonne très valorisée.\n\n"
          "Faisons correspondre cela avec vos objectifs professionnels. Préférez-vous l'Europe ou l'Amérique du Nord ?";
    }

    return "🤖 **J'ai bien noté votre message !**\n\n"
        "Pour affiner ma recommandation, pourriez-vous me préciser :\n"
        "1. Votre dernier diplôme obtenu ou niveau actuel (Bac, Licence...)\n"
        "2. Votre budget annuel maximum pour les frais de scolarité (ex: 8 000€, 12 000€)\n"
        "3. La filière de vos rêves (Commerce, Ingénierie, Informatique, Design)\n\n"
        "Vous pouvez aussi à tout moment aller dans l'onglet **Orientation** pour faire notre questionnaire complet, ou dans l'onglet **Dossier** pour soumettre vos bulletins pour une étude gratuite par nos conseillers humains !";
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    unawaited(_loadQuotaState());
  }

  String _currentWeekKey() {
    final now = DateTime.now();
    final firstDay = DateTime(now.year, 1, 1);
    final week = ((now.difference(firstDay).inDays + firstDay.weekday - 1) / 7).floor() + 1;
    return '${now.year}-$week';
  }

  Future<void> _loadQuotaState() async {
    final prefs = await SharedPreferences.getInstance();
    final weekKey = _currentWeekKey();
    final storedWeek = prefs.getString(_quotaWeekKey);
    if (storedWeek != weekKey) {
      await prefs.setString(_quotaWeekKey, weekKey);
      await prefs.setInt(_quotaCountKey, 0);
      if (!mounted) return;
      setState(() => _remainingMessages = _weeklyQuota);
      return;
    }
    final used = prefs.getInt(_quotaCountKey) ?? 0;
    if (!mounted) return;
    setState(() => _remainingMessages = (_weeklyQuota - used).clamp(0, _weeklyQuota));
  }

  Future<void> _persistQuotaCount() async {
    final prefs = await SharedPreferences.getInstance();
    final weekKey = _currentWeekKey();
    await prefs.setString(_quotaWeekKey, weekKey);
    final used = (_weeklyQuota - _remainingMessages).clamp(0, _weeklyQuota);
    await prefs.setInt(_quotaCountKey, used);
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
              // ── Header ───────────────────────────────────────────────────
              _buildHeader(context),

              // ── Chat Messages ────────────────────────────────────────────
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(KpbSpacing.pagePad),
                  itemCount: _messages.length + (_isTyping ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == _messages.length) {
                      return _buildTypingIndicator();
                    }
                    final msg = _messages[index];
                    return _buildMessageBubble(msg);
                  },
                ),
              ),

              // ── Suggestion Chips ──────────────────────────────────────────
              if (_messages.length <= 2 && !_isTyping) _buildSuggestions(),

              // ── Input Field ──────────────────────────────────────────────
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
            child: const Icon(Icons.psychology_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Conseiller IA",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                Row(
                  children: [
                    Icon(Icons.circle, size: 8, color: KpbColors.stitchCyberCyan),
                    SizedBox(width: 4),
                    Text(
                      "En ligne • $_remainingMessages/$_weeklyQuota restants cette semaine",
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
    // Simple custom parser for markdown elements like bold **text** or bullet list •
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
                border: Border.all(color: KpbColors.stitchCyberCyan.withValues(alpha: 0.3)),
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
                  hintText: "Posez votre question sur les écoles, budgets...",
                  hintStyle: TextStyle(color: KpbColors.textDarkSecondary, fontSize: 13),
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
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
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

class _TypingDotState extends State<_TypingDot> with SingleTickerProviderStateMixin {
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
