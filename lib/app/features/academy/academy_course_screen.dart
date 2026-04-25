import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:get/get.dart';

import '../../core/controllers/app_controller.dart';
import '../../core/models/app_models.dart';
import '../../core/ui/app_tokens.dart';
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

    return Scaffold(
      backgroundColor: KpbColors.bgDarkMidnight,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context, course),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(KpbSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const KpbBadge(label: 'COURS EXPERT', color: KpbColors.blue),
                      const SizedBox(width: 8),
                      Text(
                        '${course.lessonCount} sessions',
                        style: const TextStyle(color: Colors.white54, fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    controller.resolve(course.title),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    controller.resolve(course.description),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // Benefit Section
                  _buildBenefitCard(),
                  
                  const SizedBox(height: 32),
                  const Text(
                    'Programme de la formation',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  
                  // Lessons Preview
                  ...lessons.map((l) => _LessonPreviewTile(lesson: l, index: lessons.indexOf(l) + 1)),
                  
                  const SizedBox(height: 120),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomSheet: _buildBottomBar(context, controller, isPurchased),
    );
  }

  Widget _buildAppBar(BuildContext context, AcademyCourseModel course) {
    return SliverAppBar(
      expandedHeight: 240,
      pinned: true,
      backgroundColor: KpbColors.bgDarkMidnight,
      leading: IconButton(
        icon: const Icon(Icons.close_rounded, color: Colors.white),
        onPressed: () => Get.back(),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (course.coverImageUrl != null)
              CachedNetworkImage(
                imageUrl: course.coverImageUrl!,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(color: KpbColors.bgDarkCard),
                errorWidget: (context, url, error) => Container(color: KpbColors.bgDarkCard),
              ),
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, KpbColors.bgDarkMidnight],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBenefitCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: KpbColors.bgDarkCard,
        borderRadius: KpbRadius.lgBr,
        border: Border.all(color: KpbColors.glassBorder),
      ),
      child: const Column(
        children: [
          _BenefitRow(icon: Icons.video_library_rounded, text: 'Vidéos pas-à-pas en HD'),
          SizedBox(height: 12),
          _BenefitRow(icon: Icons.description_rounded, text: 'Modèles de lettres de motivation'),
          SizedBox(height: 12),
          _BenefitRow(icon: Icons.verified_user_rounded, text: 'Astuces de conseillers senior KPB'),
        ],
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context, AppController controller, bool isPurchased) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: BoxDecoration(
        color: KpbColors.bgDarkCard,
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
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
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
                    ),
                    Text(
                      '${course.priceXOF} FCFA',
                      style: const TextStyle(
                        color: Colors.white,
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
                    onPressed: () => _handlePurchase(context, controller),
                    bgColor: KpbColors.blue,
                  ),
                ),
              ],
            ),
    );
  }

  void _handlePurchase(BuildContext context, AppController controller) {
     // Mock purchase flow
     showModalBottomSheet(
       context: context,
       backgroundColor: KpbColors.bgDarkMidnight,
       shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
       builder: (context) => Container(
         padding: const EdgeInsets.all(32),
         child: Column(
           mainAxisSize: MainAxisSize.min,
           children: [
             const Icon(Icons.shopping_bag_outlined, color: KpbColors.blue, size: 48),
             const SizedBox(height: 16),
             const Text(
               'Finaliser l\'achat',
               style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
             ),
             const SizedBox(height: 8),
             Text(
               'Vous allez débloquer le ${controller.resolve(course.title)} définitevement.',
               textAlign: TextAlign.center,
               style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
             ),
             const SizedBox(height: 32),
             KpbButton(
               text: 'Confirmer et débloquer',
               onPressed: () {
                 controller.purchaseCourse(course.id);
                 Get.back(); // close sheet
                 Get.snackbar(
                    'Félicitations !',
                    'Formation débloquée avec succès.',
                    backgroundColor: KpbColors.success,
                    colorText: Colors.white,
                 );
               },
             ),
           ],
         ),
       ),
     );
  }
}

class _BenefitRow extends StatelessWidget {
  const _BenefitRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: KpbColors.blue, size: 20),
        const SizedBox(width: 12),
        Text(text, style: const TextStyle(color: Colors.white, fontSize: 14)),
      ],
    );
  }
}

class _LessonPreviewTile extends StatelessWidget {
  const _LessonPreviewTile({required this.lesson, required this.index});
  final AcademyLessonModel lesson;
  final int index;

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AppController>();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: KpbRadius.mdBr,
      ),
      child: Row(
        children: [
          Text(
            '$index',
            style: const TextStyle(color: KpbColors.blue, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              controller.resolve(lesson.title),
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
          const Icon(Icons.lock_outline_rounded, color: Colors.white24, size: 16),
        ],
      ),
    );
  }
}
