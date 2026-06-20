import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/controllers/app_controller.dart';
import '../../core/models/app_models.dart';
import '../../core/ui/kpb_components.dart';
import 'academy_player_screen.dart';

class AcademyCourseScreen extends StatelessWidget {
  const AcademyCourseScreen({super.key, required this.course});

  final AcademyCourseModel course;

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AppController>();
    final isPurchased = controller.hasPurchased(course.id);
    final lessons = controller.getCourseLessons(course.id);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: context.kpb.pageBg,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context, course, isDark),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(KpbSpacing.pagePad),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      KpbBadge(label: 'COURS EXPERT', color: isDark ? KpbColors.blueMid : KpbColors.blue),
                      const SizedBox(width: 8),
                      Text(
                        '${course.lessonCount} sessions',
                        style: KpbTextStyles.label.copyWith(color: context.kpb.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    controller.resolve(course.title),
                    style: KpbTextStyles.displaySm.copyWith(color: context.kpb.textPrimary),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    controller.resolve(course.description),
                    style: KpbTextStyles.body.copyWith(color: context.kpb.textSecondary),
                  ),
                  const SizedBox(height: 32),
                  
                  // Benefit Section
                  _buildBenefitCard(context, isDark),
                  
                  const SizedBox(height: 32),
                  Text(
                    'Programme de la formation',
                    style: KpbTextStyles.titleLg.copyWith(color: context.kpb.textPrimary),
                  ),
                  const SizedBox(height: 16),
                  
                  // Lessons Preview
                  ...lessons.map((l) => _LessonPreviewTile(lesson: l, index: lessons.indexOf(l) + 1, isDark: isDark)),
                  
                  const SizedBox(height: 140), // Padding for bottom bar
                ],
              ),
            ),
          ),
        ],
      ),
      bottomSheet: _buildBottomBar(context, controller, isPurchased, isDark),
    );
  }

  Widget _buildAppBar(BuildContext context, AcademyCourseModel course, bool isDark) {
    return SliverAppBar(
      expandedHeight: 260,
      pinned: true,
      backgroundColor: context.kpb.pageBg,
      leading: Padding(
        padding: const EdgeInsets.all(8.0),
        child: CircleAvatar(
          backgroundColor: Colors.black.withValues(alpha: 0.4),
          child: IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
            onPressed: () => Get.back(),
          ),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (course.coverImageUrl != null)
              KpbNetworkImage(
                imageUrl: course.coverImageUrl!,
                targetWidth: MediaQuery.of(context).size.width,
                fallbackColor: context.kpb.surfaceBg,
                errorIcon: null,
              ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.3),
                    context.kpb.pageBg,
                  ],
                  stops: const [0.0, 1.0],
                ),
              ),
            ),
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 2),
                ),
                child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 40),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildBenefitCard(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(KpbSpacing.lg),
      decoration: BoxDecoration(
        color: context.kpb.cardBg,
        borderRadius: KpbRadius.xlBr,
        border: Border.all(color: context.kpb.gray100),
        boxShadow: KpbShadow.soft,
      ),
      child: Column(
        children: [
          _BenefitRow(icon: Icons.video_library_rounded, text: 'Vidéos pas-à-pas en HD', isDark: isDark),
          const SizedBox(height: 16),
          _BenefitRow(icon: Icons.description_rounded, text: 'Modèles de lettres de motivation', isDark: isDark),
          const SizedBox(height: 16),
          _BenefitRow(icon: Icons.verified_user_rounded, text: 'Astuces de conseillers senior KPB', isDark: isDark),
        ],
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context, AppController controller, bool isPurchased, bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(KpbSpacing.pagePad, 16, KpbSpacing.pagePad, 32),
      decoration: BoxDecoration(
        color: context.kpb.surfaceBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(KpbRadius.xl)),
        boxShadow: KpbShadow.float,
      ),
      child: isPurchased
          ? KpbButton(
              text: 'Continuer la formation',
              onPressed: () => Get.to(() => AcademyPlayerScreen(course: course)),
              bgColor: KpbColors.success,
              icon: Icons.play_circle_fill_rounded,
            )
          : Row(
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reste à payer',
                      style: KpbTextStyles.label.copyWith(color: context.kpb.textSecondary),
                    ),
                    Text(
                      '${course.priceXOF} FCFA',
                      style: TextStyle(
                        color: context.kpb.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: KpbButton(
                    text: 'Acheter le pack',
                    onPressed: () => _handlePurchase(context, controller, isDark),
                    bgColor: KpbColors.blue,
                  ),
                ),
              ],
            ),
    );
  }

  void _handlePurchase(BuildContext context, AppController controller, bool isDark) {
     showModalBottomSheet(
       context: context,
       backgroundColor: context.kpb.pageBg,
       isScrollControlled: true,
       shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
       builder: (context) => Padding(
         padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
         child: Container(
           padding: const EdgeInsets.all(KpbSpacing.xl),
           child: Column(
             mainAxisSize: MainAxisSize.min,
             children: [
               Container(
                 padding: const EdgeInsets.all(16),
                 decoration: BoxDecoration(
                   color: (KpbColors.blue).withValues(alpha: 0.1),
                   shape: BoxShape.circle,
                 ),
                 child: Icon(Icons.shopping_bag_outlined, color: KpbColors.blue, size: 48),
               ),
               const SizedBox(height: 24),
               Text(
                 'Finaliser l\'achat',
                 style: KpbTextStyles.headline.copyWith(color: context.kpb.textPrimary),
               ),
               const SizedBox(height: 12),
               Text(
                 'Vous allez débloquer la formation "${controller.resolve(course.title)}" définitevement sur votre compte.',
                 textAlign: TextAlign.center,
                 style: KpbTextStyles.body.copyWith(color: context.kpb.textSecondary),
               ),
               const SizedBox(height: 32),
               KpbButton(
                 text: 'Confirmer et payer',
                 onPressed: () {
                   controller.purchaseCourse(course.id);
                   Get.back();
                   Get.snackbar(
                      'Félicitations !',
                      'Formation débloquée avec succès. Vous pouvez maintenant suivre les cours.',
                      backgroundColor: KpbColors.success,
                      colorText: Colors.white,
                      snackPosition: SnackPosition.TOP,
                   );
                 },
                 bgColor: KpbColors.success,
                 icon: Icons.check_circle_outline_rounded,
               ),
               const SizedBox(height: 16),
             ],
           ),
         ),
       ),
     );
  }
}

class _BenefitRow extends StatelessWidget {
  const _BenefitRow({required this.icon, required this.text, required this.isDark});
  final IconData icon;
  final String text;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: (KpbColors.blue).withValues(alpha: 0.15),
            borderRadius: KpbRadius.mdBr,
          ),
          child: Icon(icon, color: KpbColors.blue, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(text, style: KpbTextStyles.titleMd.copyWith(color: context.kpb.textPrimary)),
        ),
      ],
    );
  }
}

class _LessonPreviewTile extends StatelessWidget {
  const _LessonPreviewTile({required this.lesson, required this.index, required this.isDark});
  final AcademyLessonModel lesson;
  final int index;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AppController>();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.kpb.cardBg,
        borderRadius: KpbRadius.mdBr,
        border: Border.all(color: context.kpb.gray100),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: context.kpb.surfaceBg,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$index',
                style: TextStyle(
                  color: KpbColors.blue,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              controller.resolve(lesson.title),
              style: KpbTextStyles.titleMd.copyWith(color: context.kpb.textPrimary),
            ),
          ),
          Icon(Icons.lock_outline_rounded, color: context.kpb.textMuted, size: 20),
        ],
      ),
    );
  }
}
