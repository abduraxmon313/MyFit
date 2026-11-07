const test = require("node:test");
const assert = require("node:assert/strict");
const helpers = require("../fatsecret_helpers");

test("normalizes a metric serving to 100 g", () => {
  const food = helpers.normalizeFood({
    food_id: "42",
    food_name: "Test food",
    servings: {
      serving: {
        metric_serving_amount: "50",
        metric_serving_unit: "g",
        calories: "100",
        protein: "5",
        fat: "2",
        carbohydrate: "10",
        fiber: "1",
      },
    },
  });
  assert.equal(food.calories, 200);
  assert.equal(food.protein, 10);
  assert.equal(food.fat, 4);
  assert.equal(food.carbohydrates, 20);
  assert.equal(food.fiber, 2);
  assert.equal(food.hasWaterData, false);
});

test("prefers an exact 100 g serving", () => {
  const serving = helpers.selectServing({
    servings: {serving: [
      {metric_serving_amount: "30", metric_serving_unit: "g"},
      {metric_serving_amount: "100", metric_serving_unit: "g"},
    ]},
  });
  assert.equal(serving.metric_serving_amount, "100");
});

test("does not turn missing or malformed nutrients into measured zero", () => {
  const food = helpers.normalizeFood({food_id: 1, food_name: "Incomplete", servings: {serving: {
    metric_serving_amount: "100", metric_serving_unit: "g", calories: "0", fat: "0", carbohydrate: "0", protein: "", sodium: "12mg", sugar: "-1",
  }}});
  assert.equal(food.calories, 0);
  assert.ok(food.knownNutrients.includes("calories"));
  assert.equal(food.protein, undefined);
  assert.ok(food.missingNutrients.includes("protein"));
  assert.equal(food.sodiumMg, undefined);
  assert.equal(food.sugars, undefined);
});

test("liquid-only foods retain ml and original portion quantities", () => {
  const food = helpers.normalizeFood({food_id: 2, food_name: "Drink", servings: {serving: [
    {serving_id: "a", serving_description: "1 bottle", metric_serving_amount: "250", metric_serving_unit: "ml", calories:"100", protein:"0", fat:"0", carbohydrate:"25", sodium:"30", sugar:"25"},
  ]}});
  assert.equal(food.basisUnit, "ml");
  assert.equal(food.calories, 40);
  assert.equal(food.sodiumMg, 12);
  assert.equal(food.salt, 0.03);
  assert.equal(food.sugars, 10);
  assert.equal(food.servings[0].amount, 250);
});

test("a gram serving takes precedence over a volume serving", () => {
  const food = helpers.normalizeFood({food_id: 3, food_name: "Oil", servings: {serving: [
    {metric_serving_amount:"100", metric_serving_unit:"ml", calories:"800"},
    {metric_serving_amount:"50", metric_serving_unit:"g", calories:"450", sugar:"0", saturated_fat:"7", calcium:"2"},
  ]}});
  assert.equal(food.basisUnit, "g");
  assert.equal(food.calories, 900);
  assert.equal(food.saturatedFat, 14);
  assert.equal(food.calciumMg, 4);
  assert.ok(food.knownNutrients.includes("sugars"));
});
