const fs = require('node:fs');
const files = ['lib/screens/home_page.dart', 'lib/screens/meals_page.dart', 'lib/screens/food_history_page.dart'];
for (const path of files) {
  let text = fs.readFileSync(path, 'utf8');
  text = text.replace(/(\$\{food\.grams[^\n]*?\}) \$\{context\.tr\('g'\)\}/g, "$1 ${context.tr(food.basisUnit)}");
  fs.writeFileSync(path, text);
}
const path = 'lib/l10n/app_localizations.dart';
let text = fs.readFileSync(path, 'utf8');
const translations = {
  ru: {'ml':'мл', 'Yana ko‘rsatish':'Показать ещё', 'Oziq qiymati 100 {unit} uchun':'Пищевая ценность на 100 {unit}', '1–5000 {unit} oralig‘ida miqdor kiriting.':'Введите количество от 1 до 5000 {unit}.', 'Mahsulot bazalarda topilmadi.':'Продукт не найден в базах данных.', 'Qiymatlar mahsulotda ko‘rsatilgan 100 g yoki 100 ml uchun.':'Значения указаны на 100 г или 100 мл в зависимости от продукта.'},
  en: {'ml':'ml', 'Yana ko‘rsatish':'Show more', 'Oziq qiymati 100 {unit} uchun':'Nutrition per 100 {unit}', '1–5000 {unit} oralig‘ida miqdor kiriting.':'Enter an amount between 1 and 5000 {unit}.', 'Mahsulot bazalarda topilmadi.':'Product not found in the databases.', 'Qiymatlar mahsulotda ko‘rsatilgan 100 g yoki 100 ml uchun.':'Values are per 100 g or 100 ml as shown for each product.'},
};
for (const [language, values] of Object.entries(translations)) {
  const marker = `'${language}': {`;
  const section = text.split(marker)[1]?.split("    },")[0] ?? '';
  const additions = Object.entries(values).filter(([key]) => !section.includes(`'${key}':`) && !section.includes(`${JSON.stringify(key)}:`)).map(([key, value]) => `      ${JSON.stringify(key)}: ${JSON.stringify(value)},`).join('\n');
  text = text.replace(marker, `${marker}\n${additions}`);
}
fs.writeFileSync(path, text);
