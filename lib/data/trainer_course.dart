import '../models/trainer_course.dart';

/// Course outline used until the real course is loaded from Firebase.
/// Titles are structural placeholders; no videos are attached yet.
const kTrainerCourse = TrainerCourse(
  id: 'main',
  title: 'Murabbiy video kursi',
  description:
      'Murabbiy tomonidan tayyorlangan mashg‘ulotlar ketma-ketligi. Har bir darsni tartib bilan o‘ting.',
  lessons: [
    CourseLesson(
      id: 'l1',
      order: 1,
      title: 'Kirish va xavfsizlik',
      description:
          'Kurs tuzilishi, jihozlar va jarohatdan saqlanish qoidalari.',
    ),
    CourseLesson(
      id: 'l2',
      order: 2,
      title: 'To‘g‘ri isinish',
      description:
          'Har bir mashg‘ulotdan oldin bajariladigan isinish majmuasi.',
    ),
    CourseLesson(
      id: 'l3',
      order: 3,
      title: 'Asosiy texnika',
      description: 'Asosiy harakatlarni to‘g‘ri bajarish texnikasi.',
    ),
    CourseLesson(
      id: 'l4',
      order: 4,
      title: 'Yuqori tana mashqlari',
      description: 'Ko‘krak, yelka, qo‘l va orqa mushaklari uchun mashqlar.',
    ),
    CourseLesson(
      id: 'l5',
      order: 5,
      title: 'Pastki tana mashqlari',
      description: 'Oyoq va dumba mushaklari uchun mashqlar.',
    ),
    CourseLesson(
      id: 'l6',
      order: 6,
      title: 'Kardio va chidamlilik',
      description: 'Yurak-qon tomir tizimini mustahkamlovchi mashg‘ulot.',
    ),
    CourseLesson(
      id: 'l7',
      order: 7,
      title: 'Cho‘zilish va tiklanish',
      description: 'Mashg‘ulotdan keyingi cho‘zilish va dam olish.',
    ),
    CourseLesson(
      id: 'l8',
      order: 8,
      title: 'Haftalik reja',
      description: 'Darslarni haftaga taqsimlash bo‘yicha tavsiyalar.',
    ),
  ],
);
