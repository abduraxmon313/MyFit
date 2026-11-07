const fs = require('node:fs');
const queries = ['milk', 'cheese', 'cream butter', 'salmon tuna carp trout', 'buckwheat', 'pasta spaghetti macaroni', 'nuts seeds', 'coffee tea beverages', 'carbonated juice', 'sugars honey jams', 'mayonnaise ketchup sauces', 'pizza burger sandwich', 'frankfurter potatoes fried', 'chocolate cookies cake ice cream', 'kefir', 'oil sunflower'];
(async () => {
  fs.mkdirSync('data_sources/usda', {recursive: true});
  for (let i = 0; i < queries.length; i++) {
    const path = `data_sources/usda/${i}.json`;
    if (fs.existsSync(path)) continue;
    const url = new URL('https://api.nal.usda.gov/fdc/v1/foods/search');
    url.search = new URLSearchParams({api_key: 'DEMO_KEY', query: queries[i], dataType: 'SR Legacy', pageSize: '200'});
    const response = await fetch(url, {signal: AbortSignal.timeout(20000)});
    if (!response.ok) throw new Error(`USDA ${response.status}: ${queries[i]}`);
    const json = await response.json();
    const foods = json.foods.map(f => ({fdcId:f.fdcId, description:f.description, dataType:f.dataType, foodNutrients:f.foodNutrients.map(n => ({nutrientId:n.nutrientId, nutrientName:n.nutrientName, unitName:n.unitName, value:n.value}))}));
    fs.writeFileSync(path, JSON.stringify(foods));
    console.log(`${i}: ${queries[i]}: ${foods.length}`);
  }
})().catch(e => { console.error(e.message); process.exitCode = 1; });
