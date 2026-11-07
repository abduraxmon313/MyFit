const fs = require('node:fs');
const folder = 'data_sources/usda';
const foods = new Map();
for (const file of fs.readdirSync(folder).filter(x => x.endsWith('.json'))) {
  for (const food of JSON.parse(fs.readFileSync(`${folder}/${file}`, 'utf8').replace(/^\uFEFF/, ''))) foods.set(food.fdcId, food);
}
const archivePath = `${folder}/sr-legacy/FoodData_Central_sr_legacy_food_json_2018-04.json`;
if (fs.existsSync(archivePath)) {
  const archive = JSON.parse(fs.readFileSync(archivePath, 'utf8'));
  for (const food of archive.SRLegacyFoods) foods.set(food.fdcId, food);
}
if (process.argv[2] === '--inspect') {
  const food = foods.get(172217);
  console.log(JSON.stringify({keys:Object.keys(food), portions:food.foodPortions?.slice(0, 3)}, null, 2));
  process.exit(0);
}
for (const food of foods.values()) {
  if (process.argv[2]) {
    if (new RegExp(process.argv[2], 'i').test(food.description)) console.log(`${food.fdcId}\t${food.description}`);
    continue;
  }
  if (/^(Milk, (whole|reduced|lowfat|nonfat)|Buttermilk|Kefir|Cheese, (cheddar|mozzarella|cream|parmesan|feta|swiss|processed)|Cream, (fluid|sour)|Butter,|Fish, (salmon|tuna|carp|trout)|Buckwheat|Spaghetti|Macaroni|Pasta|Nuts,|Seeds,|Peanuts|Beverages,|Carbonated|Sugars|Honey|Jams|Salad dressing, mayonnaise|Catsup|Sauce|Pizza|Fast foods|Frankfurter|Potatoes, french|Chocolate|Candies|Cookies|Cake|Ice creams|Oil, sunflower)/i.test(food.description)) {
    console.log(`${food.fdcId}\t${food.description}`);
  }
}
