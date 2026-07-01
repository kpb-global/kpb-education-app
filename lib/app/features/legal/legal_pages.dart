import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/ui/app_tokens.dart';
import '../../core/ui/kpb_theme_ext.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Privacy Policy Screen
// ─────────────────────────────────────────────────────────────────────────────
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('privacy_policy'.tr),
        backgroundColor: context.kpb.pageBg,
        surfaceTintColor: Colors.transparent,
      ),
      backgroundColor: context.kpb.pageBg,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(KpbSpacing.pagePad),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'privacy_policy'.tr,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: context.kpb.textPrimary,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'last_updated_april_2026'.tr,
              style: TextStyle(fontSize: 13, color: context.kpb.textMuted),
            ),
            const SizedBox(height: KpbSpacing.lg),
            _LegalSection(
              title: 'privacy_s1_title'.tr,
              body:
                  'KPB Education (ci-après "nous", "notre", "KPB") est responsable du traitement des données personnelles collectées via l\'application mobile KPB Education.\n\n'
                  'Contact : contact@kpbeducation.com',
            ),
            _LegalSection(
              title: 'privacy_s2_title'.tr,
              body: 'Nous collectons les données suivantes :\n\n'
                  '• Identité : nom complet, adresse e-mail, numéro de téléphone, WhatsApp\n'
                  '• Profil académique : niveau d\'études, niveau cible, compétences linguistiques, notes, filières d\'intérêt, pays de destination\n'
                  '• Données d\'utilisation : résultats d\'orientation, éléments sauvegardés, historique de recherche\n'
                  '• Données techniques : identifiant de l\'appareil (pour les notifications push), données analytiques anonymisées via Firebase Analytics\n'
                  '• Diagnostics : rapports d\'incidents et erreurs techniques via Firebase Crashlytics ; métriques agrégées de synchronisation des contenus (succès ou échec, durée, source locale/cache)',
            ),
            _LegalSection(
              title: 'privacy_s3_title'.tr,
              body: 'Vos données sont utilisées pour :\n\n'
                  '• Personnaliser vos recommandations de filières, pays et bourses\n'
                  '• Gérer vos dossiers de candidature et vos rendez-vous\n'
                  '• Vous envoyer des notifications pertinentes (mises à jour de dossier, deadlines)\n'
                  '• Améliorer nos services via des statistiques agrégées et anonymisées\n'
                  '• Communiquer avec vous dans le cadre de vos démarches',
            ),
            _LegalSection(
              title: 'privacy_s4_title'.tr,
              body:
                  '• Consentement : vous acceptez cette politique lors de la création de votre compte\n'
                  '• Exécution du contrat : le traitement est nécessaire pour fournir nos services\n'
                  '• Intérêt légitime : amélioration de nos services et sécurité de la plateforme',
            ),
            _LegalSection(
              title: 'privacy_s5_title'.tr,
              body: 'Vos données ne sont PAS vendues à des tiers.\n\n'
                  'Elles peuvent être partagées avec :\n'
                  '• Nos conseillers internes pour le suivi de vos dossiers\n'
                  '• Nos partenaires institutionnels (universités) uniquement avec votre accord explicite lors de la soumission d\'un dossier\n'
                  '• Firebase / Google (Analytics, Crashlytics, Cloud Messaging) pour l\'analytique, la stabilité et les notifications push\n'
                  '• Les autorités compétentes si la loi l\'exige',
            ),
            _LegalSection(
              title: 'privacy_s6_title'.tr,
              body:
                  '• Données de profil : conservées tant que votre compte est actif\n'
                  '• Données de dossier : conservées 3 ans après la clôture du dossier\n'
                  '• Données analytiques : agrégées et anonymisées, conservées indéfiniment\n'
                  '• En cas de suppression de compte : vos données personnelles sont supprimées sous 30 jours',
            ),
            _LegalSection(
              title: 'privacy_s7_title'.tr,
              body: '• Communication chiffrée via HTTPS/TLS\n'
                  '• Mots de passe hachés (bcrypt)\n'
                  '• Tokens d\'authentification sécurisés (JWT)\n'
                  '• Données sensibles (tokens) stockées dans le Keychain (iOS) / Keystore (Android)\n'
                  '• Accès restreint aux données de production',
            ),
            _LegalSection(
              title: 'privacy_s8_title'.tr,
              body:
                  'Conformément au RGPD et aux lois applicables, vous avez le droit :\n\n'
                  '• D\'accéder à vos données personnelles\n'
                  '• De rectifier vos données\n'
                  '• De supprimer votre compte et vos données\n'
                  '• De limiter le traitement\n'
                  '• De vous opposer au traitement\n'
                  '• De portabilité de vos données\n\n'
                  'Pour exercer ces droits, contactez-nous à : privacy@kpbeducation.com',
            ),
            _LegalSection(
              title: 'privacy_s9_title'.tr,
              body:
                  'Nous utilisons Firebase Analytics (Google) pour collecter des données d\'usage anonymisées :\n\n'
                  '• Écrans consultés, actions effectuées (orientation, recherche, sauvegarde)\n'
                  '• Aucune donnée personnelle identifiable n\'est transmise à Google\n'
                  '• Vous pouvez désactiver la collecte depuis les paramètres de votre profil',
            ),
            _LegalSection(
              title: 'privacy_s10_title'.tr,
              body:
                  'Cette politique peut être mise à jour. Nous vous informerons de tout changement significatif via une notification dans l\'application.\n\n'
                  'En continuant à utiliser l\'application après une mise à jour, vous acceptez la nouvelle politique.',
            ),
            const SizedBox(height: KpbSpacing.xxl),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Terms of Service Screen
// ─────────────────────────────────────────────────────────────────────────────
class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('terms_of_use_2'.tr),
        backgroundColor: context.kpb.pageBg,
        surfaceTintColor: Colors.transparent,
      ),
      backgroundColor: context.kpb.pageBg,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(KpbSpacing.pagePad),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'terms_of_use'.tr,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: context.kpb.textPrimary,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'last_updated_april_2026'.tr,
              style: TextStyle(fontSize: 13, color: context.kpb.textMuted),
            ),
            const SizedBox(height: KpbSpacing.lg),
            _LegalSection(
              title: 'terms_s1_title'.tr,
              body:
                  'Les présentes Conditions Générales d\'Utilisation (ci-après "CGU") régissent l\'accès et l\'utilisation de l\'application mobile KPB Education, éditée par KPB Education.\n\n'
                  'L\'application fournit des services d\'orientation, d\'information et d\'accompagnement pour les étudiants souhaitant poursuivre leurs études à l\'étranger.',
            ),
            _LegalSection(
              title: 'terms_s2_title'.tr,
              body:
                  'En créant un compte et en utilisant l\'application, vous acceptez sans réserve les présentes CGU.\n\n'
                  'Si vous n\'acceptez pas ces conditions, veuillez ne pas utiliser l\'application.',
            ),
            _LegalSection(
              title: 'terms_s3_title'.tr,
              body:
                  '• L\'inscription est gratuite et ouverte aux étudiants, parents et partenaires institutionnels\n'
                  '• Vous devez fournir des informations exactes et à jour\n'
                  '• Vous êtes responsable de la confidentialité de votre mot de passe\n'
                  '• Vous devez être âgé d\'au moins 16 ans pour créer un compte',
            ),
            _LegalSection(
              title: 'terms_s4_title'.tr,
              body: 'KPB Education propose :\n\n'
                  '• Un test d\'orientation personnalisé\n'
                  '• Un catalogue de filières, pays, institutions, programmes et bourses\n'
                  '• Un système de mise en relation avec des conseillers\n'
                  '• Un suivi de dossiers de candidature\n'
                  '• Des contenus éducatifs (articles, guides)\n'
                  '• Un espace communautaire\n\n'
                  'Les informations fournies sont à titre indicatif et ne constituent pas un engagement contractuel de résultat.',
            ),
            _LegalSection(
              title: 'terms_s5_title'.tr,
              body:
                  'Certains services d\'accompagnement (suivi de dossier, consultation personnalisée) peuvent être soumis à des frais.\n\n'
                  'Les tarifs sont affichés avant toute souscription. Aucun paiement n\'est prélevé sans votre consentement explicite.',
            ),
            _LegalSection(
              title: 'terms_s6_title'.tr,
              body: 'Vous vous engagez à :\n\n'
                  '• Utiliser l\'application de manière loyale et conformément aux lois en vigueur\n'
                  '• Ne pas fournir de fausses informations\n'
                  '• Ne pas tenter d\'accéder de manière non autorisée aux systèmes de KPB Education\n'
                  '• Respecter les autres utilisateurs dans les espaces communautaires\n'
                  '• Ne pas utiliser l\'application à des fins commerciales non autorisées',
            ),
            _LegalSection(
              title: 'terms_s7_title'.tr,
              body:
                  'L\'ensemble des contenus de l\'application (textes, images, logos, code source) est la propriété de KPB Education ou de ses partenaires et est protégé par les lois relatives à la propriété intellectuelle.\n\n'
                  'Toute reproduction ou diffusion non autorisée est interdite.',
            ),
            _LegalSection(
              title: 'terms_s8_title'.tr,
              body:
                  'KPB Education s\'efforce de fournir des informations exactes et à jour, mais ne garantit pas :\n\n'
                  '• L\'exactitude ou l\'exhaustivité des informations sur les programmes, bourses ou institutions\n'
                  '• L\'obtention d\'une admission ou d\'une bourse\n'
                  '• La disponibilité continue et ininterrompue de l\'application\n\n'
                  'KPB Education ne saurait être tenu responsable des décisions prises par l\'utilisateur sur la base des informations fournies.',
            ),
            _LegalSection(
              title: 'terms_s9_title'.tr,
              body:
                  '• Vous pouvez supprimer votre compte à tout moment depuis les paramètres de l\'application\n'
                  '• KPB Education se réserve le droit de suspendre ou supprimer un compte en cas de violation des présentes CGU\n'
                  '• En cas de résiliation, vos données personnelles seront traitées conformément à notre Politique de Confidentialité',
            ),
            _LegalSection(
              title: 'terms_s10_title'.tr,
              body: 'Les présentes CGU sont soumises au droit en vigueur.\n\n'
                  'En cas de litige, les parties s\'engagent à chercher une résolution amiable avant tout recours judiciaire.',
            ),
            _LegalSection(
              title: 'terms_s11_title'.tr,
              body: 'Pour toute question relative aux présentes CGU :\n\n'
                  'Email : contact@kpbeducation.com\n'
                  'Site web : www.kpbeducation.com',
            ),
            const SizedBox(height: KpbSpacing.xxl),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared Section Widget
// ─────────────────────────────────────────────────────────────────────────────
class _LegalSection extends StatelessWidget {
  const _LegalSection({required this.title, required this.body});
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: KpbSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: context.kpb.textPrimary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: context.kpb.textSecondary,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
