import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/controllers/app_controller.dart';
import '../../core/models/app_models.dart';
import '../../core/ui/kpb_components.dart';
import '../../core/utils/country_utils.dart';
import '../../core/utils/whatsapp_utils.dart';
import '../cases/case_composer_sheet.dart';
import '../france/france_private_admission_screen.dart';
import 'eligibility_quiz_screen.dart';

class CountryDetailScreen extends StatefulWidget {
  const CountryDetailScreen({super.key, required this.countryId});

  final String countryId;

  @override
  State<CountryDetailScreen> createState() => _CountryDetailScreenState();
}

class _CountryDetailScreenState extends State<CountryDetailScreen> {
  late final AppController _controller;
  CountryModel? _country;
  var _loading = true;

  @override
  void initState() {
    super.initState();
    _controller = Get.find<AppController>();
    _load();
  }

  Future<void> _load() async {
    try {
      final country = await _controller.loadCountryDetail(widget.countryId);
      if (!mounted) return;
      setState(() {
        _country = country;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  String get _countryKey => normalizeCountryId(widget.countryId);

  List<InstitutionModel> _partnerInstitutions(CountryModel country) {
    return _controller.institutions
        .where(
          (i) =>
              i.countryId == country.id ||
              i.countryId == _countryKey ||
              i.countryId == widget.countryId,
        )
        .where((i) => i.isPartner)
        .take(8)
        .toList();
  }

  List<ScholarshipModel> _countryScholarships(CountryModel country) {
    return _controller.scholarships
        .where(
          (s) =>
              s.countryId == country.id ||
              s.countryId == _countryKey ||
              s.countryId == widget.countryId,
        )
        .take(4)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: context.kpb.pageBg,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final country = _country ?? _controller.countryByIdOrNull(_countryKey);
    if (country == null) {
      return const Scaffold(
        body: Center(child: Text('Pays introuvable')),
      );
    }

    final locale = _controller.localeCode;
    final partners = _partnerInstitutions(country);
    final scholarships = _countryScholarships(country);
    final bullets = country.whyStudyBulletsFor(locale);
    final steps = country.howItWorksStepsFor(locale);
    final mvpNote = country.mvpNote.resolve(locale);

    return Scaffold(
      backgroundColor: context.kpb.pageBg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 240,
            pinned: true,
            backgroundColor: KpbColors.navy,
            foregroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            flexibleSpace: FlexibleSpaceBar(
              background: _CountryHero(country: country, controller: _controller),
              collapseMode: CollapseMode.parallax,
            ),
            actions: [
              IconButton(
                icon: Icon(
                  _controller.isSaved(SavedItemType.country, country.id)
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  color: Colors.white,
                ),
                onPressed: () =>
                    _controller.toggleSaved(SavedItemType.country, country.id),
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(KpbSpacing.pagePad),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (mvpNote.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: context.kpb.gray100,
                          borderRadius: KpbRadius.mdBr,
                          border: Border.all(color: context.kpb.gray200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.schedule_rounded,
                                size: 18, color: context.kpb.textSecondary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                mvpNote,
                                style: KpbTextStyles.bodySm.copyWith(
                                  color: context.kpb.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (country.id == 'fra' || country.id == 'france')
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: KpbCard(
                        onTap: () =>
                            Get.to(() => const FrancePrivateAdmissionScreen()),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: KpbColors.skyLight,
                                borderRadius: KpbRadius.mdBr,
                              ),
                              child: const Icon(Icons.school_outlined,
                                  color: KpbColors.blue),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Admission écoles privées',
                                    style: KpbTextStyles.titleMd,
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Parcours dédié · Septembre 2026',
                                    style: KpbTextStyles.caption,
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.chevron_right_rounded,
                                color: context.kpb.gray400),
                          ],
                        ),
                      ),
                    ),
                  FilledButton.icon(
                    onPressed: () => Get.to(
                      () => EligibilityQuizScreen(countryId: country.id),
                    ),
                    icon: const Icon(Icons.quiz_outlined),
                    label: const Text('Faire le quiz d\'éligibilité'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _SectionCard(
                    icon: Icons.lightbulb_outline_rounded,
                    iconColor: KpbColors.gold,
                    title: 'Pourquoi ce pays ?',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (country.marketingDescription.fr.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Text(
                              _controller.resolve(country.marketingDescription),
                              style: KpbTextStyles.body,
                            ),
                          ),
                        Text(
                          _controller.resolve(country.whyStudy),
                          style: KpbTextStyles.body,
                        ),
                        if (bullets.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          ...bullets.map(
                            (bullet) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.check_circle_outline,
                                      size: 18, color: KpbColors.success),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(bullet, style: KpbTextStyles.bodySm),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (steps.isNotEmpty)
                    _SectionCard(
                      icon: Icons.route_outlined,
                      iconColor: KpbColors.blue,
                      title: 'Comment ça se passe',
                      child: Column(
                        children: [
                          for (var i = 0; i < steps.length; i++) ...[
                            if (i > 0) const SizedBox(height: 10),
                            _StepRow(index: i + 1, text: steps[i]),
                          ],
                        ],
                      ),
                    ),
                  _SectionCard(
                    icon: Icons.payments_outlined,
                    iconColor: KpbColors.blue,
                    title: 'Coûts',
                    child: Column(
                      children: [
                        if (country.costsOverview.fr.isNotEmpty)
                          Text(
                            _controller.resolve(country.costsOverview),
                            style: KpbTextStyles.body,
                          ),
                        if (country.costsOverview.fr.isNotEmpty)
                          const SizedBox(height: 10),
                        KpbInfoRow(
                          icon: Icons.school_outlined,
                          label: 'Frais de scolarité',
                          value: _controller.resolve(country.tuitionRange),
                          iconColor: KpbColors.blue,
                        ),
                        const KpbDivider(indent: 48),
                        KpbInfoRow(
                          icon: Icons.home_outlined,
                          label: 'Coût de la vie / mois',
                          value: _controller.resolve(country.livingCostRange),
                          iconColor: KpbColors.success,
                        ),
                        const KpbDivider(indent: 48),
                        KpbInfoRow(
                          icon: Icons.article_outlined,
                          label: 'Visa & assurance',
                          value: _controller.resolve(country.visaOverview),
                          iconColor: KpbColors.warning,
                        ),
                      ],
                    ),
                  ),
                  _SectionCard(
                    icon: Icons.translate_rounded,
                    iconColor: KpbColors.success,
                    title: 'Langue requise',
                    child: Text(
                      country.languageSection.fr.isNotEmpty
                          ? _controller.resolve(country.languageSection)
                          : _controller.resolve(country.mainLanguage),
                      style: KpbTextStyles.body,
                    ),
                  ),
                  _SectionCard(
                    icon: Icons.account_balance_outlined,
                    iconColor: KpbColors.blue,
                    title: 'Écoles partenaires dans ce pays',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (country.partnerSchools.fr.isNotEmpty)
                          Text(
                            _controller.resolve(country.partnerSchools),
                            style: KpbTextStyles.bodySm,
                          ),
                        if (partners.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 130,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: partners.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 10),
                              itemBuilder: (context, index) {
                                final inst = partners[index];
                                return SizedBox(
                                  width: 220,
                                  child: KpbCard(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _controller.resolve(inst.name),
                                          style: KpbTextStyles.titleMd,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _controller.resolve(inst.location),
                                          style: KpbTextStyles.caption,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const Spacer(),
                                        const KpbBadge(
                                          label: 'Partenaire',
                                          color: KpbColors.success,
                                          small: true,
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (country.scholarshipsSection.fr.isNotEmpty ||
                      scholarships.isNotEmpty)
                    _SectionCard(
                      icon: Icons.emoji_events_outlined,
                      iconColor: KpbColors.gold,
                      title: 'Bourses disponibles',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (country.scholarshipsSection.fr.isNotEmpty)
                            Text(
                              _controller.resolve(country.scholarshipsSection),
                              style: KpbTextStyles.body,
                            ),
                          ...scholarships.map(
                            (s) => Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Row(
                                children: [
                                  const Icon(Icons.star_outline,
                                      size: 16, color: KpbColors.gold),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _controller.resolve(s.name),
                                      style: KpbTextStyles.bodySm,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  KpbCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Accompagnement KPB',
                          style: KpbTextStyles.titleMd,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Nos conseillers t\'accompagnent de l\'éligibilité jusqu\'à l\'obtention du visa.',
                          style: KpbTextStyles.body,
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: () => showModalBottomSheet<void>(
                            context: context,
                            isScrollControlled: true,
                            builder: (_) => CaseComposerSheet(
                              caseType: CaseType.applicationSupport,
                              title:
                                  'Étudier en ${_controller.resolve(country.name)}',
                              contextLabel: _controller.resolve(country.name),
                              countryId: country.id,
                            ),
                          ),
                          child: const Text('Demander un accompagnement'),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: () => openWhatsAppOrToast(
                            prefill: kpbWhatsAppPrefill(
                              custom:
                                  _controller.resolve(country.whatsAppPrefill),
                              country: _controller.resolve(country.name),
                            ),
                          ),
                          icon: const Icon(Icons.chat_outlined),
                          label: const Text('Discuter sur WhatsApp'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _BottomCta(country: country, controller: _controller),
    );
  }
}

class _CountryHero extends StatelessWidget {
  const _CountryHero({required this.country, required this.controller});

  final CountryModel country;
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final tagline = controller.resolve(country.tagline);
    final intake = controller.resolve(country.nextIntakeLabel);
    final language = controller.resolve(country.mainLanguage);

    return Container(
      decoration: const BoxDecoration(gradient: KpbColors.heroGradient),
      padding: const EdgeInsets.fromLTRB(24, 100, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            displayCountryFlag(id: country.id, flagEmoji: country.flagEmoji),
            style: const TextStyle(fontSize: 52),
          ),
          const SizedBox(height: 8),
          Text(
            controller.resolve(country.name),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          if (tagline.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              tagline,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (intake.isNotEmpty)
                _HeroChip(icon: Icons.calendar_month_outlined, label: intake),
              if (language.isNotEmpty)
                _HeroChip(icon: Icons.language_outlined, label: language),
              _HeroChip(
                icon: Icons.school_outlined,
                label: controller.resolve(country.tuitionRange),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: KpbRadius.pillBr,
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: KpbCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: iconColor, size: 20),
                const SizedBox(width: 8),
                Text(title, style: KpbTextStyles.titleMd),
              ],
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.index, required this.text});

  final int index;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: const BoxDecoration(
            color: KpbColors.blue,
            borderRadius: KpbRadius.smBr,
          ),
          child: Center(
            child: Text(
              '$index',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: KpbTextStyles.bodySm)),
      ],
    );
  }
}

class _BottomCta extends StatelessWidget {
  const _BottomCta({required this.country, required this.controller});

  final CountryModel country;
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        KpbSpacing.pagePad,
        12,
        KpbSpacing.pagePad,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: context.kpb.cardBg,
        border: Border(top: BorderSide(color: context.kpb.gray100)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => openWhatsAppOrToast(
                prefill: kpbWhatsAppPrefill(
                  custom: controller.resolve(country.whatsAppPrefill),
                  country: controller.resolve(country.name),
                ),
              ),
              icon: const Icon(Icons.chat_outlined, size: 18),
              label: const Text('WhatsApp'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: FilledButton(
              onPressed: () => Get.to(
                () => EligibilityQuizScreen(countryId: country.id),
              ),
              child: const Text('Quiz éligibilité'),
            ),
          ),
        ],
      ),
    );
  }
}
