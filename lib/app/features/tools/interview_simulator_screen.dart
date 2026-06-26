import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/controllers/app_controller.dart';
import '../../core/ui/kpb_components.dart';

/// AI Interview Simulator — visa / admission / scholarship mock interviews
/// with per-answer scoring and feedback (powered by Groq).
class InterviewSimulatorScreen extends StatefulWidget {
  const InterviewSimulatorScreen({super.key});

  @override
  State<InterviewSimulatorScreen> createState() =>
      _InterviewSimulatorScreenState();
}

enum _Stage { pickType, loading, interview, feedback }

class _InterviewSimulatorScreenState extends State<InterviewSimulatorScreen> {
  final _ctrl = Get.find<AppController>();
  final _answerCtrl = TextEditingController();

  _Stage _stage = _Stage.pickType;
  String _type = 'visa';
  List<String> _questions = [];
  int _currentIndex = 0;
  bool _evaluating = false;
  Map<String, dynamic>? _feedback;

  @override
  void dispose() {
    _answerCtrl.dispose();
    super.dispose();
  }

  Future<void> _start(String type) async {
    setState(() {
      _type = type;
      _stage = _Stage.loading;
    });
    try {
      final p = _ctrl.profile;
      final fieldId = p?.fieldIds.isNotEmpty == true ? p!.fieldIds.first : '';
      final field = _ctrl.fields
          .where((f) => f.id == fieldId)
          .map((f) => _ctrl.resolve(f.name))
          .firstOrNull ?? '';
      final targetId = p?.targetCountryIds.isNotEmpty == true
          ? p!.targetCountryIds.first
          : '';
      final country = _ctrl.countries
          .where((c) => c.id == targetId)
          .map((c) => _ctrl.resolve(c.name))
          .firstOrNull ?? '';

      final result = await _ctrl.apiClient.post('tools/interview/questions', {
        'type': type,
        'fieldOfStudy': field,
        'targetCountry': country,
        'language': _ctrl.localeCode == 'en' ? 'en' : 'fr',
      });
      final qs = (result['questions'] as List?)?.cast<String>() ?? [];
      if (mounted) {
        setState(() {
          _questions = qs;
          _currentIndex = 0;
          _stage = qs.isEmpty ? _Stage.pickType : _Stage.interview;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _stage = _Stage.pickType);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur IA — verifiez votre connexion')),
        );
      }
    }
  }

  Future<void> _submitAnswer() async {
    if (_answerCtrl.text.trim().isEmpty) return;
    setState(() => _evaluating = true);
    try {
      final result = await _ctrl.apiClient.post('tools/interview/feedback', {
        'type': _type,
        'question': _questions[_currentIndex],
        'answer': _answerCtrl.text.trim(),
        'language': _ctrl.localeCode == 'en' ? 'en' : 'fr',
      });
      if (mounted) {
        setState(() {
          _feedback = result;
          _stage = _Stage.feedback;
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur IA — verifiez votre connexion')),
        );
      }
    } finally {
      if (mounted) setState(() => _evaluating = false);
    }
  }

  void _next() {
    _answerCtrl.clear();
    setState(() {
      _feedback = null;
      if (_currentIndex < _questions.length - 1) {
        _currentIndex++;
        _stage = _Stage.interview;
      } else {
        _stage = _Stage.pickType; // finished
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Simulateur d\'entretien')),
      body: switch (_stage) {
        _Stage.pickType => _buildPicker(context),
        _Stage.loading => const Center(child: CircularProgressIndicator()),
        _Stage.interview => _buildInterview(context),
        _Stage.feedback => _buildFeedback(context),
      },
    );
  }

  // ── Type picker ──────────────────────────────────────────────────────────
  Widget _buildPicker(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(KpbSpacing.pagePad),
      children: [
        Text(
          'Entraine-toi avec un examinateur IA. Choisis un type d\'entretien :',
          style: TextStyle(fontSize: 14, color: context.kpb.textMuted),
        ),
        const SizedBox(height: KpbSpacing.lg),
        _typeCard(
          'visa',
          Icons.flight_takeoff_rounded,
          KpbColors.blue,
          'Entretien de visa étudiant',
          'Questions consulaires : financement, retour, projet d\'études.',
        ),
        const SizedBox(height: KpbSpacing.md),
        _typeCard(
          'admission',
          Icons.school_rounded,
          KpbColors.success,
          'Entretien d\'admission',
          'Motivation, parcours, adéquation avec le programme.',
        ),
        const SizedBox(height: KpbSpacing.md),
        _typeCard(
          'scholarship',
          Icons.emoji_events_rounded,
          KpbColors.gold,
          'Entretien de bourse',
          'Impact, leadership, projet de retour et engagement.',
        ),
      ],
    );
  }

  Widget _typeCard(String type, IconData icon, Color color, String title,
      String subtitle) {
    return KpbCard(
      onTap: () => _start(type),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: KpbRadius.mdBr,
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: context.kpb.textPrimary)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: TextStyle(
                        fontSize: 12, color: context.kpb.textMuted)),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: context.kpb.textMuted),
        ],
      ),
    );
  }

  // ── Interview question ─────────────────────────────────────────────────────
  Widget _buildInterview(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(KpbSpacing.pagePad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Progress
          Row(
            children: [
              Text(
                'Question ${_currentIndex + 1} / ${_questions.length}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: context.kpb.textMuted,
                ),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (_currentIndex + 1) / _questions.length,
              minHeight: 6,
              backgroundColor: context.kpb.gray200,
              valueColor: const AlwaysStoppedAnimation(KpbColors.blue),
            ),
          ),
          const SizedBox(height: KpbSpacing.lg),

          // Question bubble
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(KpbSpacing.md),
            decoration: BoxDecoration(
              color: KpbColors.blue.withValues(alpha: 0.08),
              borderRadius: KpbRadius.lgBr,
              border: Border.all(color: KpbColors.blue.withValues(alpha: 0.2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.record_voice_over_rounded,
                    color: KpbColors.blue, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _questions[_currentIndex],
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: context.kpb.textPrimary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: KpbSpacing.lg),

          // Answer field
          Expanded(
            child: TextField(
              controller: _answerCtrl,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              decoration: const InputDecoration(
                hintText: 'Tape ta réponse ici...',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
          ),
          const SizedBox(height: KpbSpacing.md),

          KpbButton(
            label: _evaluating ? 'Évaluation...' : 'Soumettre ma réponse',
            icon: Icons.send_rounded,
            fullWidth: true,
            onTap: _evaluating ? null : _submitAnswer,
          ),
        ],
      ),
    );
  }

  // ── Feedback ────────────────────────────────────────────────────────────────
  Widget _buildFeedback(BuildContext context) {
    final fb = _feedback ?? {};
    final score = (fb['score'] as num?)?.toInt() ?? 0;
    final strengths = (fb['strengths'] as List?)?.cast<String>() ?? [];
    final improvements = (fb['improvements'] as List?)?.cast<String>() ?? [];
    final modelAnswer = fb['modelAnswer'] as String? ?? '';
    final scoreColor = score >= 75
        ? KpbColors.success
        : score >= 50
            ? KpbColors.gold
            : KpbColors.error;

    return ListView(
      padding: const EdgeInsets.all(KpbSpacing.pagePad),
      children: [
        // Score ring
        Center(
          child: Column(
            children: [
              SizedBox(
                width: 110,
                height: 110,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 110,
                      height: 110,
                      child: CircularProgressIndicator(
                        value: score / 100,
                        strokeWidth: 9,
                        backgroundColor: context.kpb.gray200,
                        valueColor: AlwaysStoppedAnimation(scoreColor),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$score',
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            color: scoreColor,
                          ),
                        ),
                        Text('/ 100',
                            style: TextStyle(
                                fontSize: 11, color: context.kpb.textMuted)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: KpbSpacing.lg),

        if (strengths.isNotEmpty)
          _feedbackBlock(
            context,
            'Points forts',
            Icons.check_circle_rounded,
            KpbColors.success,
            strengths,
          ),
        if (improvements.isNotEmpty)
          _feedbackBlock(
            context,
            'À améliorer',
            Icons.lightbulb_rounded,
            KpbColors.gold,
            improvements,
          ),

        if (modelAnswer.isNotEmpty) ...[
          const SizedBox(height: KpbSpacing.md),
          KpbCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.star_rounded,
                        color: KpbColors.blue, size: 20),
                    const SizedBox(width: 8),
                    Text('model_answer'.tr,
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: context.kpb.textPrimary)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(modelAnswer,
                    style: TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: context.kpb.textPrimary)),
              ],
            ),
          ),
        ],

        const SizedBox(height: KpbSpacing.lg),
        KpbButton(
          label: _currentIndex < _questions.length - 1
              ? 'Question suivante'
              : 'Terminer',
          icon: Icons.arrow_forward_rounded,
          fullWidth: true,
          onTap: _next,
        ),
      ],
    );
  }

  Widget _feedbackBlock(BuildContext context, String title, IconData icon,
      Color color, List<String> items) {
    return Padding(
      padding: const EdgeInsets.only(bottom: KpbSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Text(title,
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: context.kpb.textPrimary)),
            ],
          ),
          const SizedBox(height: 6),
          ...items.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 4, left: 24),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• ', style: TextStyle(color: color)),
                    Expanded(
                      child: Text(s,
                          style: TextStyle(
                              fontSize: 13, color: context.kpb.textPrimary)),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
