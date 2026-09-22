// Deep-link / push landing for a single Parcours story (`/parcours/<slug>`).
//
// Every in-app entry point opens a story with the object already in hand
// (`Get.to(() => ParcoursStoryScreen(story: …))`). A push only carries the
// slug, and the backend has no by-slug endpoint, so this screen resolves it:
// the loaded catalog first, then the featured story (the weekly push is the
// featured one), then a forced catalog refresh — the offline cache may predate
// a story published this week. An unknown slug falls back to the library
// rather than a dead end.

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/controllers/app_controller.dart';
import '../../core/models/app_models.dart';
import 'parcours_feed_screen.dart';
import 'parcours_screen.dart';
import 'parcours_story_screen.dart';

class ParcoursLinkScreen extends StatefulWidget {
  const ParcoursLinkScreen({super.key, required this.slug});

  final String slug;

  @override
  State<ParcoursLinkScreen> createState() => _ParcoursLinkScreenState();
}

class _ParcoursLinkScreenState extends State<ParcoursLinkScreen> {
  static const _source = 'deep_link';

  final _ctrl = Get.find<AppController>();
  ParcoursStory? _story;
  bool _resolved = false;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  ParcoursStory? _fromCatalog() {
    for (final s in _ctrl.parcoursStories) {
      if (s.slug == widget.slug) return s;
    }
    return null;
  }

  /// Waits for a catalog load already in flight (bounded). True when there
  /// was one, i.e. the backend has just been asked.
  Future<bool> _awaitInFlightLoad() async {
    if (!_ctrl.isLoadingParcours) return false;
    final deadline = DateTime.now().add(const Duration(seconds: 30));
    while (_ctrl.isLoadingParcours && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    return true;
  }

  Future<void> _resolve() async {
    var story = _fromCatalog();
    var askedBackend = false;
    if (story == null) {
      // Cold start from the push: Home may already be loading the catalog, and
      // a second call would return at once without waiting for it.
      askedBackend = await _awaitInFlightLoad();
      if (!askedBackend) {
        askedBackend = await _ctrl.fetchParcoursStories();
      }
      story = _fromCatalog();
    }
    if (story == null) {
      try {
        final featured = await _ctrl.apiClient.fetchStoryOfWeek();
        if (featured?.slug == widget.slug) story = featured;
      } catch (_) {
        // Best-effort: fall through to the forced refresh.
      }
    }
    // Only when the first call stopped at the cache: re-issuing a request that
    // just failed would keep the spinner up for another full network timeout.
    if (story == null && !askedBackend) {
      await _ctrl.fetchParcoursStories(force: true);
      story = _fromCatalog();
    }
    if (!mounted) return;
    setState(() {
      _story = story;
      _resolved = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_resolved) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final story = _story;
    if (story == null) return const ParcoursScreen();
    if (story.isVideo) {
      return ParcoursFeedScreen(stories: [story], analyticsSource: _source);
    }
    return ParcoursStoryScreen(story: story, analyticsSource: _source);
  }
}
