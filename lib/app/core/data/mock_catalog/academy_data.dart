// AUTO-GENERATED — KPB Education catalog seed data.
// ignore_for_file: lines_longer_than_80_chars
import '../../models/app_models.dart';

const kAcademyCourses = [
    AcademyCourseModel(
      id: 'c-fulbright',
      title: LocalizedText(
          fr: 'Pack Réussite Fulbright', en: 'Fulbright Success Pack'),
      description: LocalizedText(
        fr: 'Maîtrise chaque étape du programme Fulbright avec nos experts. Inclus : Guide de rédaction du Personal Statement et simulations.',
        en: 'Master every step of the Fulbright program. Includes Personal Statement guide and interview prep.',
      ),
      coverImageUrl:
          'https://images.unsplash.com/photo-1523050853064-87a1a0b3f886',
      priceXOF: 15000,
      priceEUR: 25,
      lessonCount: 5,
    ),
    AcademyCourseModel(
      id: 'c-visa-canada',
      title:
          LocalizedText(fr: 'Objectif Visa Canada', en: 'Mission Canada Visa'),
      description: LocalizedText(
        fr: 'Tout pour votre demande de permis d\'étude : preuve de fonds, lettre d\'explication et documents requis.',
        en: 'Everything for your study permit: financial proof, explanation letter and required docs.',
      ),
      coverImageUrl:
          'https://images.unsplash.com/photo-1550751827-4bd374c3f58b',
      priceXOF: 10000,
      priceEUR: 15,
      lessonCount: 4,
    ),
  ];


const kAcademyLessons = {
    'c-fulbright': [
      AcademyLessonModel(
          id: 'l1',
          title: LocalizedText(
              fr: 'Introduction au Fulbright', en: 'Fulbright Intro'),
          videoUrl: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
          durationSeconds: 300,
          order: 1),
      AcademyLessonModel(
          id: 'l2',
          title: LocalizedText(
              fr: 'Rédiger son Personal Statement',
              en: 'Writing Personal Statement'),
          videoUrl: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
          durationSeconds: 600,
          order: 2),
      AcademyLessonModel(
          id: 'l3',
          title: LocalizedText(
              fr: 'Le relevé d\'objectifs d\'étude',
              en: 'Study Objectives Letter'),
          videoUrl: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
          durationSeconds: 450,
          order: 3),
    ],
    'c-visa-canada': [
      AcademyLessonModel(
          id: 'v1',
          title: LocalizedText(fr: 'Le CAQ (Québec)', en: 'CAQ Process'),
          videoUrl: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
          durationSeconds: 400,
          order: 1),
      AcademyLessonModel(
          id: 'v2',
          title: LocalizedText(
              fr: 'Preuves de ressources financières', en: 'Financial Proofs'),
          videoUrl: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
          durationSeconds: 800,
          order: 2),
    ],
  };
