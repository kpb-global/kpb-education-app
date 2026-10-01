import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/config/app_config.dart';
import '../../core/config/app_routes.dart';
import '../../core/controllers/app_controller.dart';
import '../../core/data/eef_calendar.dart';
import '../../core/navigation/app_boot_screen.dart';
import '../../core/services/analytics_service.dart';
import '../../core/ui/kpb_components.dart';
import '../../core/utils/whatsapp_utils.dart';
import '../ai_advisor/ai_consent.dart';
import '../tools/cv_generator_screen.dart';
import '../tools/interview_simulator_screen.dart';
import '../tools/motivation_letters_screen.dart';
import 'eef_interest_controller.dart';
import 'eef_interest_sheet.dart';
import 'eef_official_links.dart';
import 'eef_profile_prefill.dart';

/// L'espace « Études en France » : le hub.
///
/// ## Ce qu'il est, et ce qu'il n'est pas
///
/// Il réunit, en un écran, ce qui EXISTE déjà et sert la candidature : chercher
/// sa formation (le catalogue serveur), préparer son CV, ses lettres de
/// motivation et son entretien (les outils existants), parler à un conseiller, et
/// tenir son profil à jour. Chaque tuile ouvre un écran qui marche.
///
/// Il ne montre PAS de modules « en préparation ». La coquille de la build 49
/// annonçait trois chantiers dont un seul existait ; ce hub n'annonce que ce
/// qu'il livre. La sélection de formations, la fiche formation, la checklist et
/// le projet d'études arrivent dans une build suivante, et cet écran ne les
/// promet pas : une tuile qui mène nulle part est exactement le « produit cassé »
/// que la coquille refusait d'être.
///
/// ## Ce que le hub dit de la procédure
///
/// La candidature elle-même se dépose sur la plateforme officielle — pas dans
/// KPB. Le héros le dit dans son corps (jamais dans son titre : la règle de
/// nommage interdit d'utiliser le nom de l'agence comme enseigne), avec le lien
/// vers cette plateforme, et la même règle que la vitrine : la suspension d'un
/// pays REMPLACE la date, elle ne s'y ajoute pas (`EefCalendar.timingLabel`).
class EefHomeScreen extends StatefulWidget {
  const EefHomeScreen({super.key, this.source = 'direct'});

  /// Par quelle porte l'étudiant est arrivé (voir `logEefSpaceViewed`).
  final String source;

  @override
  State<EefHomeScreen> createState() => _EefHomeScreenState();
}

class _EefHomeScreenState extends State<EefHomeScreen> {
  late final EefInterestController _interest;
  late final AppController _app;

  @override
  void initState() {
    super.initState();
    _app = Get.find<AppController>();
    // `AppApiClient` n'est pas enregistré dans GetX : il vit sur AppController.
    _interest = EefInterestController(apiClient: _app.apiClient);
    AnalyticsService.instance.logEefSpaceViewed(widget.source);
    // Un invité n'a pas de session : l'appel partirait pour revenir en 401.
    if (!_app.isGuestMode) _interest.load();
  }

  @override
  void dispose() {
    _interest.dispose();
    super.dispose();
  }

  void _track(String tile) =>
      AnalyticsService.instance.logEefHubTileOpened(tile);

  void _openCatalog() {
    _track('catalogue');
    Get.toNamed(AppRoutes.etudesEnFranceCatalog, arguments: 'hub');
  }

  /// Les trois outils passent par `openAiToolIfConsented`, qui gère déjà
  /// l'invité (mur de conversion) et le consentement IA : le hub n'a pas à
  /// recopier ces règles, et une porte de plus qui les oublierait rejouerait le
  /// défaut PARC-05.
  void _openTool(String tile, Widget Function() page) {
    _track(tile);
    openAiToolIfConsented(context, page);
  }

  void _talkToAdvisor() {
    _track('conseiller');
    openWhatsAppOrToast(
      prefill: kpbWhatsAppPrefill(custom: 'eef_hub_whatsapp_prefill'.tr),
      source: 'eef_home',
      contextType: 'eef_hub',
    );
  }

  Future<void> _declare() async {
    _track('profil');
    await showEefInterestSheet(context, controller: _interest);
  }

  Future<void> _edit() async {
    _track('profil');
    await showEefInterestSheet(
      context,
      controller: _interest,
      mode: EefSheetMode.edit,
    );
  }

  /// Confirme puis exécute le retrait — même contrat que la vitrine : la
  /// confirmation évite le tap accidentel, et l'issue est dite dans les deux
  /// sens. Le texte de consentement promet « tu peux te retirer à tout moment,
  /// depuis cet écran » : une fois la vitrine remplacée par ce hub, c'est ici que
  /// la promesse doit être tenue.
  Future<void> _confirmWithdraw() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('eef_withdraw_confirm_title'.tr),
        content: Text('eef_withdraw_confirm_body'.tr),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('eef_withdraw_cancel'.tr),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: KpbColors.error),
            child: Text('eef_withdraw_confirm_cta'.tr),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final ok = await _interest.withdraw();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'eef_withdraw_done'.tr : 'eef_withdraw_failed'.tr),
      ),
    );
  }

  /// La conversion invité : même action que [KpbGuestGate] (voir la vitrine).
  void _convertGuest() {
    _app.leaveGuestForSignup(source: 'eef_home');
    Get.offAll<void>(() => const AppBootScreen());
  }

  @override
  Widget build(BuildContext context) {
    final country = _app.profile?.countryOfResidence;

    return Scaffold(
      appBar: AppBar(title: Text('eef_title'.tr)),
      body: ListenableBuilder(
        listenable: _interest,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.fromLTRB(
            KpbSpacing.pagePad,
            KpbSpacing.md,
            KpbSpacing.pagePad,
            KpbSpacing.xl,
          ),
          children: [
            _Hero(country: country),
            const SizedBox(height: KpbSpacing.lg),
            _HubTile(
              icon: Icons.travel_explore_rounded,
              color: KpbColors.blue,
              title: 'eef_hub_formations_title'.tr,
              subtitle: 'eef_hub_formations_body'.tr,
              emphasized: true,
              onTap: _openCatalog,
            ),
            // Les trois outils IA suivent le même masque que la boîte à outils
            // (`AppConfig.aiToolsEnabled`) : deux portes, une règle.
            if (AppConfig.aiToolsEnabled) ...[
              const SizedBox(height: KpbSpacing.lg),
              Text('eef_hub_tools_heading'.tr, style: KpbTextStyles.titleSm),
              const SizedBox(height: KpbSpacing.sm),
              _HubTile(
                icon: Icons.description_rounded,
                color: KpbColors.blue,
                title: 'cv_generator_title'.tr,
                subtitle: 'student_tools_cv_subtitle'.tr,
                onTap: () => _openTool('cv', () => const CvGeneratorScreen()),
              ),
              const SizedBox(height: KpbSpacing.sm),
              _HubTile(
                icon: Icons.mail_outline_rounded,
                color: KpbColors.success,
                title: 'letters_title'.tr,
                subtitle: 'student_tools_letters_subtitle'.tr,
                onTap: () => _openTool(
                  'lettres',
                  () => const MotivationLettersScreen(),
                ),
              ),
              const SizedBox(height: KpbSpacing.sm),
              _HubTile(
                icon: Icons.record_voice_over_rounded,
                color: KpbColors.gold,
                title: 'interview_title'.tr,
                subtitle: 'student_tools_interview_subtitle'.tr,
                onTap: () => _openTool(
                  'entretien',
                  () => const InterviewSimulatorScreen(),
                ),
              ),
            ],
            const SizedBox(height: KpbSpacing.lg),
            _ProfileBlock(
              controller: _interest,
              isGuest: _app.isGuestMode,
              onDeclare: _declare,
              onEdit: _edit,
              onWithdraw: _confirmWithdraw,
              onSignUp: _convertGuest,
            ),
            const SizedBox(height: KpbSpacing.lg),
            _HubTile(
              icon: Icons.support_agent_rounded,
              color: KpbColors.actionPrimary,
              title: 'eef_hub_advisor_title'.tr,
              subtitle: 'eef_hub_advisor_body'.tr,
              onTap: _talkToAdvisor,
            ),
            const SizedBox(height: KpbSpacing.lg),
            const EefAffiliationNotice(),
          ],
        ),
      ),
    );
  }
}

/// Le héros : ce que l'étudiant prépare, et où se dépose réellement la
/// candidature.
class _Hero extends StatelessWidget {
  const _Hero({required this.country});

  final String? country;

  @override
  Widget build(BuildContext context) {
    // Le MÊME point unique que la vitrine et la carte d'accueil : la suspension
    // REMPLACE la date. Un étudiant dont le pays est suspendu ne lit jamais
    // « ouverture le 1er octobre » ici.
    final suspended = EefCalendar.isSuspendedFor(country);
    final timing = EefCalendar.timingLabel(country: country);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(KpbSpacing.lg),
      decoration: const BoxDecoration(
        gradient: KpbColors.heroGradient,
        borderRadius: KpbRadius.lgBr,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'eef_hub_hero_title'.tr,
            style:
                KpbTextStyles.displayXs.copyWith(color: KpbColors.textOnDark),
          ),
          const SizedBox(height: KpbSpacing.sm),
          Text(
            'eef_hub_hero_body'.tr,
            style:
                KpbTextStyles.body.copyWith(color: KpbColors.textOnDarkMuted),
          ),
          if (suspended) ...[
            const SizedBox(height: KpbSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.report_problem_outlined,
                  size: 18,
                  color: KpbColors.errorOnDark,
                ),
                const SizedBox(width: KpbSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'eef_suspended_notice'.tr,
                        style: KpbTextStyles.bodySm
                            .copyWith(color: KpbColors.errorOnDark),
                      ),
                      EefOfficialLink(
                        url: EefCalendar.suspensionSourceFor(country),
                        labelKey: 'eef_official_suspension_link',
                        color: KpbColors.errorOnDark,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ] else if (timing != null) ...[
            const SizedBox(height: KpbSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.event_outlined,
                  size: 18,
                  color: KpbColors.actionOnDark,
                ),
                const SizedBox(width: KpbSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        timing,
                        style: KpbTextStyles.bodySm
                            .copyWith(color: KpbColors.actionOnDark),
                      ),
                      const SizedBox(height: KpbSpacing.xs),
                      // Les clôtures divergent par pays (le Maroc ferme le
                      // 15 novembre) : une date d'ouverture sans ce caveat se lit
                      // « j'ai tout le temps ».
                      Text(
                        'eef_deadline_varies_notice'.tr,
                        style: KpbTextStyles.caption
                            .copyWith(color: KpbColors.textOnDarkMuted),
                      ),
                      EefOfficialLink(
                        url: EefCalendar.platformUrl,
                        labelKey: 'eef_official_platform_link',
                        color: KpbColors.actionOnDark,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Une tuile du hub : une icône, un titre, une phrase, un chevron. Une liste
/// plutôt qu'une grille — à l'échelle de texte 1,3 d'un petit téléphone, deux
/// colonnes coupent les titres.
class _HubTile extends StatelessWidget {
  const _HubTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.emphasized = false,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return KpbCard(
      onTap: onTap,
      variant:
          emphasized ? KpbCardVariant.highlighted : KpbCardVariant.standard,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: KpbRadius.smBr,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: KpbSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: KpbTextStyles.titleSm),
                const SizedBox(height: KpbSpacing.xs),
                Text(
                  subtitle,
                  style: KpbTextStyles.bodySm
                      .copyWith(color: context.kpb.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: KpbSpacing.sm),
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Icon(
              Icons.chevron_right_rounded,
              color: context.kpb.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

/// « Mon profil Études en France » : ce que l'étudiant a déclaré, comment le
/// modifier, et comment se retirer.
///
/// ## Pourquoi ce bloc est dans le hub
///
/// La déclaration n'était ouverte que par la vitrine, qui disparaît quand
/// l'espace s'ouvre. Le texte de consentement promet « tu peux te retirer à tout
/// moment, depuis cet écran » : sans ce bloc, la promesse devenait fausse le jour
/// de l'ouverture, et le consentement au rappel, irrévocable depuis l'app.
class _ProfileBlock extends StatelessWidget {
  const _ProfileBlock({
    required this.controller,
    required this.isGuest,
    required this.onDeclare,
    required this.onEdit,
    required this.onWithdraw,
    required this.onSignUp,
  });

  final EefInterestController controller;
  final bool isGuest;
  final VoidCallback onDeclare;
  final VoidCallback onEdit;
  final VoidCallback onWithdraw;
  final VoidCallback onSignUp;

  @override
  Widget build(BuildContext context) {
    if (isGuest) {
      return KpbCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('eef_profile_title'.tr, style: KpbTextStyles.titleSm),
            const SizedBox(height: KpbSpacing.xs),
            Text(
              'eef_hub_guest_body'.tr,
              style:
                  KpbTextStyles.bodySm.copyWith(color: context.kpb.textMuted),
            ),
            const SizedBox(height: KpbSpacing.md),
            KpbButton(
              label: 'eef_guest_cta'.tr,
              icon: Icons.login_rounded,
              fullWidth: true,
              onTap: onSignUp,
            ),
          ],
        ),
      );
    }

    if (controller.declared) {
      final interest = controller.interest;
      final level = eefLevelLabel(interest.currentLevel);
      final target = eefLevelLabel(interest.targetLevel);
      final fields = interest.fieldIds.map(eefFieldLabel).join(', ');

      return KpbCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.check_circle_outline_rounded,
                  color: KpbColors.success,
                  size: 20,
                ),
                const SizedBox(width: KpbSpacing.sm),
                Expanded(
                  child: Text(
                    'eef_profile_title'.tr,
                    style: KpbTextStyles.titleSm,
                  ),
                ),
              ],
            ),
            const SizedBox(height: KpbSpacing.sm),
            if (level != null)
              _ProfileLine(
                'eef_profile_level_line'.trParams({'level': level}),
              ),
            if (target != null)
              _ProfileLine(
                'eef_profile_target_line'.trParams({'level': target}),
              ),
            _ProfileLine(
              fields.isEmpty
                  ? 'eef_profile_no_fields'.tr
                  : 'eef_profile_fields_line'.trParams({'fields': fields}),
            ),
            const SizedBox(height: KpbSpacing.xs),
            Text(
              'eef_profile_recorded_body'.tr,
              style: KpbTextStyles.caption.copyWith(
                color: context.kpb.textMuted,
              ),
            ),
            const SizedBox(height: KpbSpacing.md),
            KpbButton(
              label: 'eef_profile_edit_cta'.tr,
              variant: KpbButtonVariant.secondary,
              fullWidth: true,
              loading: controller.busy,
              onTap: controller.busy ? null : onEdit,
            ),
            // En `tertiary`, pas en `danger` : se retirer d'une liste d'intérêt
            // n'est pas supprimer un compte. La confirmation suffit à éviter le
            // tap accidentel.
            KpbButton(
              label: 'eef_withdraw_cta'.tr,
              variant: KpbButtonVariant.tertiary,
              fullWidth: true,
              onTap: controller.busy ? null : onWithdraw,
            ),
          ],
        ),
      );
    }

    // La lecture a échoué : on ne SAIT pas si l'étudiant a déclaré. Proposer
    // « Compléter mon profil » le ferait redéclarer (et masquerait « Me retirer »,
    // seul endroit où le retrait est tenu) ; on le dit et on propose de réessayer.
    if (controller.readFailed) {
      return KpbCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('eef_profile_title'.tr, style: KpbTextStyles.titleSm),
            const SizedBox(height: KpbSpacing.xs),
            Text(
              'eef_profile_read_failed'.tr,
              style:
                  KpbTextStyles.bodySm.copyWith(color: context.kpb.textMuted),
            ),
            const SizedBox(height: KpbSpacing.md),
            KpbButton(
              label: 'eef_sheet_retry'.tr,
              variant: KpbButtonVariant.secondary,
              fullWidth: true,
              loading: controller.phase == EefInterestPhase.loading,
              onTap: controller.load,
            ),
          ],
        ),
      );
    }

    return KpbCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('eef_profile_title'.tr, style: KpbTextStyles.titleSm),
          const SizedBox(height: KpbSpacing.xs),
          Text(
            'eef_profile_empty_body'.tr,
            style: KpbTextStyles.bodySm.copyWith(color: context.kpb.textMuted),
          ),
          const SizedBox(height: KpbSpacing.md),
          KpbButton(
            label: 'eef_profile_declare_cta'.tr,
            icon: Icons.person_outline_rounded,
            fullWidth: true,
            loading: controller.busy,
            onTap: controller.busy ? null : onDeclare,
          ),
        ],
      ),
    );
  }
}

class _ProfileLine extends StatelessWidget {
  const _ProfileLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: KpbSpacing.xs),
      child: Text(text, style: KpbTextStyles.bodySm),
    );
  }
}
