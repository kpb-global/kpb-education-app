import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import '../../core/controllers/app_controller.dart';
import '../../core/models/app_models.dart';
import '../../core/ui/app_tokens.dart';

class AcademyPlayerScreen extends StatefulWidget {
  const AcademyPlayerScreen({
    super.key,
    required this.course,
    this.initialLessonIndex = 0,
  });

  final AcademyCourseModel course;
  final int initialLessonIndex;

  @override
  State<AcademyPlayerScreen> createState() => _AcademyPlayerScreenState();
}

class _AcademyPlayerScreenState extends State<AcademyPlayerScreen> {
  late List<AcademyLessonModel> _lessons;
  late int _currentIndex;
  YoutubePlayerController? _ytController;

  @override
  void initState() {
    super.initState();
    final controller = Get.find<AppController>();
    _lessons = controller.getCourseLessons(widget.course.id);
    _currentIndex = widget.initialLessonIndex;
    if (_lessons.isNotEmpty) {
      _initPlayer(_lessons[_currentIndex].videoUrl);
    }
  }

  void _initPlayer(String url) {
    final videoId = YoutubePlayer.convertUrlToId(url);
    if (videoId != null) {
      if (_ytController != null) {
        _ytController!.load(videoId);
      } else {
        _ytController = YoutubePlayerController(
          initialVideoId: videoId,
          flags: const YoutubePlayerFlags(
            autoPlay: true,
            mute: false,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _ytController?.dispose();
    super.dispose();
  }

  void _onLessonTap(int index) {
    if (index == _currentIndex) return;
    setState(() {
      _currentIndex = index;
    });
    _initPlayer(_lessons[index].videoUrl);
  }

  @override
  Widget build(BuildContext context) {
    final ytController = _ytController;
    if (ytController == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: const Center(
          child: Text(
            'No lessons available',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    final controller = Get.find<AppController>();
    final currentLesson = _lessons[_currentIndex];

    return YoutubePlayerBuilder(
      player: YoutubePlayer(
        controller: ytController,
        showVideoProgressIndicator: true,
        progressIndicatorColor: KpbColors.blue,
        onReady: () => ytController.addListener(() {}),
      ),
      builder: (context, player) {
        return Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: const Text(
              'Formation KPB',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Video Player Area
              AspectRatio(
                aspectRatio: 16 / 9,
                child: player,
              ),
              
              // Lesson Info
              Padding(
                padding: const EdgeInsets.all(KpbSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      controller.resolve(currentLesson.title),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Session ${_currentIndex + 1} sur ${_lessons.length}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              
              const Divider(color: Colors.white10, height: 1),
              
              // Lessons List
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _lessons.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 1),
                  itemBuilder: (context, index) {
                    final lesson = _lessons[index];
                    final isCurrent = index == _currentIndex;
                    
                    return ListTile(
                      onTap: () => _onLessonTap(index),
                      tileColor: isCurrent ? KpbColors.blue.withValues(alpha: 0.1) : null,
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: isCurrent ? KpbColors.blue : Colors.white10,
                          borderRadius: KpbRadius.mdBr,
                        ),
                        child: Center(
                          child: Icon(
                            isCurrent ? Icons.play_arrow_rounded : Icons.lock_outline_rounded, // or play icon if purchased
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                      title: Text(
                        controller.resolve(lesson.title),
                        style: TextStyle(
                          color: isCurrent ? Colors.white : Colors.white70,
                          fontSize: 15,
                          fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                      subtitle: Text(
                        '${(lesson.durationSeconds / 60).floor()} min',
                        style: const TextStyle(
                          color: Colors.white30,
                          fontSize: 12,
                        ),
                      ),
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
