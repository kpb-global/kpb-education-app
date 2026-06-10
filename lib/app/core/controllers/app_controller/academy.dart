part of '../app_controller.dart';

mixin _AcademyMixin on _AppControllerBase {
  AcademyCourseModel? getAcademyCourse(String? id) {
    if (id == null) return null;
    return academyCourses.firstWhereOrNull((c) => c.id == id);
  }

  List<AcademyLessonModel> getCourseLessons(String courseId) {
    return MockCatalog.academyLessons[courseId] ?? [];
  }

  bool hasPurchased(String courseId) {
    return _purchasedCourseIds.contains(courseId);
  }

  void purchaseCourse(String courseId) {
    if (!_purchasedCourseIds.contains(courseId)) {
      _purchasedCourseIds.add(courseId);
      _persist();
      update();
    }
  }
}
