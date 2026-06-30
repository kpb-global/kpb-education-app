// M-Parcours (Chantier C) — "Parcours & Témoignages KPB".
//
// A dedicated, free section fed by the KPB YouTube channel playlist (videos
// come from the backend proxy, cached offline). Tapping a card opens an in-app
// player. The Academy module stays separate for paid courses.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import '../../core/controllers/app_controller.dart';
import '../../core/models/app_models.dart';
import '../../core/ui/kpb_components.dart';

class ParcoursScreen extends StatefulWidget {
  const ParcoursScreen({super.key});

  @override
  State<ParcoursScreen> createState() => _ParcoursScreenState();
}

class _ParcoursScreenState extends State<ParcoursScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Get.find<AppController>().fetchParcoursVideos();
    });
  }

  Future<void> _refresh() =>
      Get.find<AppController>().fetchParcoursVideos(force: true);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.kpb.pageBg,
      appBar: AppBar(
        title: const Text('Parcours & Témoignages'),
        backgroundColor: Colors.transparent,
      ),
      body: GetBuilder<AppController>(
        builder: (controller) {
          final videos = controller.parcoursVideos;

          if (controller.isLoadingParcours && videos.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (videos.isEmpty) {
            // Distinguish "not configured" from a transient error.
            if (!controller.parcoursConfigured) {
              return const _ParcoursEmptyState(
                icon: Icons.video_library_outlined,
                title: 'Bientôt disponible',
                subtitle:
                    'Les vidéos de parcours et témoignages arrivent très vite. Reviens bientôt !',
              );
            }
            return _ParcoursEmptyState(
              icon: Icons.wifi_off_rounded,
              title: 'Contenu indisponible',
              subtitle: controller.parcoursError ??
                  'Impossible de charger les vidéos pour le moment.',
              onRetry: _refresh,
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: CustomScrollView(
              slivers: [
                const SliverToBoxAdapter(child: _ParcoursIntro()),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    KpbSpacing.pagePad,
                    KpbSpacing.sm,
                    KpbSpacing.pagePad,
                    100, // clear the floating nav bar if shown
                  ),
                  sliver: SliverList.separated(
                    itemCount: videos.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: KpbSpacing.md),
                    itemBuilder: (context, index) => _VideoCard(
                      video: videos[index],
                      onTap: () => Get.to(
                        () => ParcoursPlayerScreen(
                          videos: videos,
                          initialIndex: index,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ParcoursIntro extends StatelessWidget {
  const _ParcoursIntro();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        KpbSpacing.pagePad,
        KpbSpacing.md,
        KpbSpacing.pagePad,
        0,
      ),
      padding: const EdgeInsets.all(KpbSpacing.md),
      decoration: BoxDecoration(
        gradient: KpbColors.heroGradient,
        borderRadius: KpbRadius.lgBr,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ils l\'ont fait avant toi',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Témoignages, conseils et parcours d\'étudiants accompagnés par KPB. Inspire-toi de leur expérience.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoCard extends StatelessWidget {
  const _VideoCard({required this.video, required this.onTap});

  final YoutubeVideo video;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return KpbCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: KpbRadius.lgBr,
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail with a play overlay.
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (video.thumbnailUrl.isNotEmpty &&
                        !Get.find<AppController>().dataSaverEnabled)
                      CachedNetworkImage(
                        imageUrl: video.thumbnailUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, __) =>
                            Container(color: context.kpb.gray100),
                        errorWidget: (_, __, ___) => Container(
                          color: context.kpb.gray100,
                          child: Icon(Icons.broken_image_outlined,
                              color: context.kpb.gray400),
                        ),
                      )
                    else
                      Container(
                        color: context.kpb.gray100,
                        child: Icon(Icons.ondemand_video_rounded,
                            color: context.kpb.gray400, size: 40),
                      ),
                    Center(
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.play_arrow_rounded,
                            color: Colors.white, size: 32),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(KpbSpacing.md),
              child: Text(
                video.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: KpbTextStyles.titleMd,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ParcoursEmptyState extends StatelessWidget {
  const _ParcoursEmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onRetry,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Future<void> Function()? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(KpbSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: context.kpb.gray400),
            const SizedBox(height: KpbSpacing.md),
            Text(title,
                style: KpbTextStyles.titleLg, textAlign: TextAlign.center),
            const SizedBox(height: KpbSpacing.sm),
            Text(
              subtitle,
              style: KpbTextStyles.body.copyWith(color: context.kpb.textMuted),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: KpbSpacing.lg),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Réessayer'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Player — embeds the selected video and lets the user jump between videos.
// ─────────────────────────────────────────────────────────────────────────────

class ParcoursPlayerScreen extends StatefulWidget {
  const ParcoursPlayerScreen({
    super.key,
    required this.videos,
    this.initialIndex = 0,
  });

  final List<YoutubeVideo> videos;
  final int initialIndex;

  @override
  State<ParcoursPlayerScreen> createState() => _ParcoursPlayerScreenState();
}

class _ParcoursPlayerScreenState extends State<ParcoursPlayerScreen> {
  late int _currentIndex;
  YoutubePlayerController? _controller;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.videos.length - 1);
    final video = widget.videos[_currentIndex];
    _controller = YoutubePlayerController(
      initialVideoId: video.videoId,
      flags: const YoutubePlayerFlags(autoPlay: true, mute: false),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _playAt(int index) {
    if (index == _currentIndex) return;
    setState(() => _currentIndex = index);
    _controller?.load(widget.videos[index].videoId);
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller!;
    final current = widget.videos[_currentIndex];

    return YoutubePlayerBuilder(
      player: YoutubePlayer(
        controller: controller,
        showVideoProgressIndicator: true,
        progressIndicatorColor: KpbColors.blue,
      ),
      builder: (context, player) {
        return Scaffold(
          backgroundColor: context.kpb.pageBg,
          appBar: AppBar(
            backgroundColor: Colors.black,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
            title: const Text(
              'Parcours KPB',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold),
            ),
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                color: Colors.black,
                child: AspectRatio(aspectRatio: 16 / 9, child: player),
              ),
              Padding(
                padding: const EdgeInsets.all(KpbSpacing.lg),
                child: Text(
                  current.title,
                  style: KpbTextStyles.headline
                      .copyWith(color: context.kpb.textPrimary),
                ),
              ),
              Divider(color: context.kpb.gray100, height: 1),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: widget.videos.length,
                  separatorBuilder: (_, __) => Divider(
                      color: context.kpb.gray100, height: 1, indent: 84),
                  itemBuilder: (context, index) {
                    final v = widget.videos[index];
                    final isCurrent = index == _currentIndex;
                    return ListTile(
                      onTap: () => _playAt(index),
                      tileColor: isCurrent
                          ? KpbColors.blue.withValues(alpha: 0.06)
                          : Colors.transparent,
                      leading: ClipRRect(
                        borderRadius: KpbRadius.smBr,
                        child: SizedBox(
                          width: 64,
                          height: 40,
                          child: v.thumbnailUrl.isNotEmpty &&
                                  !Get.find<AppController>().dataSaverEnabled
                              ? CachedNetworkImage(
                                  imageUrl: v.thumbnailUrl, fit: BoxFit.cover)
                              : Container(
                                  color: context.kpb.gray100,
                                  child: Icon(Icons.ondemand_video_rounded,
                                      color: context.kpb.gray400, size: 18),
                                ),
                        ),
                      ),
                      title: Text(
                        v.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isCurrent
                              ? KpbColors.blue
                              : context.kpb.textPrimary,
                          fontSize: 14,
                          fontWeight:
                              isCurrent ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                      trailing: isCurrent
                          ? Icon(Icons.equalizer_rounded, color: KpbColors.blue)
                          : null,
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
