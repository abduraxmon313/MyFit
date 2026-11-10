import '../models/trainer_course.dart';

/// "Darslar" tab categories, in display order.
///
/// Each category is a [TrainerCourse] whose lessons are its ordered videos.
/// Videos are uploaded later (Firebase Storage + Firestore), so the lists
/// start empty.
const kLessonCategories = <TrainerCourse>[
  TrainerCourse(
    id: 'nutrition',
    title: 'To‘g‘ri ovqatlanish | Ozish va Semirish',
    description: 'Vazn yo‘qotish va vazn olish uchun to‘g‘ri ovqatlanish.',
    lessons: [],
  ),
  TrainerCourse(
    id: 'diet-cooking',
    title: 'Dietada taomni mazali pishirish',
    description: 'Parhez taomlarini mazali tayyorlash usullari.',
    lessons: [],
  ),
  TrainerCourse(
    id: 'fullbody',
    title: 'FullBody mashqlar',
    description: 'Butun tana mushaklarini bitta mashg‘ulotda ishlatish.',
    lessons: [],
  ),
  TrainerCourse(
    id: 'split-3',
    title: 'Haftada 3 kunlik trenirovka',
    description: 'Haftasiga 3 kun shug‘ullanish dasturi.',
    lessons: [],
  ),
  TrainerCourse(
    id: 'split-4',
    title: 'Haftada 4 kunlik trenirovka',
    description: 'Haftasiga 4 kun shug‘ullanish dasturi.',
    lessons: [],
  ),
  TrainerCourse(
    id: 'split-5',
    title: 'Haftada 5 kunlik trenirovka',
    description: 'Haftasiga 5 kun shug‘ullanish dasturi.',
    lessons: [],
  ),
  TrainerCourse(
    id: 'superset',
    title: 'SuperSet mashqlar',
    description: 'Ikki mashqni dam olmasdan ketma-ket bajarish.',
    lessons: [],
  ),
  TrainerCourse(
    id: 'dropset',
    title: 'DropSet mashqlar',
    description: 'Og‘irlikni kamaytirib, yondashuvni davom ettirish.',
    lessons: [],
  ),
  TrainerCourse(
    id: 'sportpit',
    title: 'SportPitlar',
    description: 'Sport ozuqalari: qaysi biri, qachon va qancha.',
    lessons: [],
  ),
  TrainerCourse(
    id: 'women-gym',
    title: 'Ayollar uchun fitnes zalda mashqlar',
    description: 'Ayollar uchun trenajyor zalidagi mashg‘ulotlar.',
    lessons: [],
  ),
  TrainerCourse(
    id: 'women-workouts',
    title: 'Ayollar uchun mashqlar',
    description: 'Uyda va zalda bajariladigan mashqlar.',
    lessons: [],
  ),
  TrainerCourse(
    id: 'women-nutrition',
    title: 'Ayollar uchun to‘g‘ri ovqatlanish',
    description: 'Ayollar organizmiga mos ovqatlanish tavsiyalari.',
    lessons: [],
  ),
  TrainerCourse(
    id: 'cardio',
    title: 'Ozish uchun kardio mashqlar',
    description: 'Yog‘ yoqish uchun kardio mashg‘ulotlari.',
    lessons: [],
  ),
];
