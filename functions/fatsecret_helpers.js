function asList(value) {
  if (value == null) return [];
  return Array.isArray(value) ? value : [value];
}

function number(value) {
  const parsed = Number.parseFloat(String(value ?? "0"));
  return Number.isFinite(parsed) ? parsed : 0;
}

// Missing, negative and malformed values must never masquerade as measured zero.
function nutrient(value) {
  if (value == null || String(value).trim() === "") return null;
  const parsed = Number(value);
  return Number.isFinite(parsed) && parsed >= 0 ? parsed : null;
}

function selectServing(food) {
  const servings = asList(food?.servings?.serving);
  const metric = servings.filter((serving) => {
    const unit = String(serving.metric_serving_unit ?? "").toLowerCase();
    return (unit === "g" || unit === "ml") &&
      number(serving.metric_serving_amount) > 0;
  });
  const grams = metric.filter((serving) =>
    String(serving.metric_serving_unit).toLowerCase() === "g");
  const compatible = grams.length ? grams : metric;
  return compatible.find((serving) => number(serving.metric_serving_amount) === 100) ??
    compatible.find((serving) => number(serving.is_default) === 1) ??
    compatible[0] ?? null;
}

function normalizeFood(food) {
  const serving = selectServing(food);
  if (!serving) return null;
  const amount = number(serving.metric_serving_amount);
  if (amount <= 0) return null;
  const factor = 100 / amount;
  const brand = String(food.brand_name ?? "").trim();
  const rawName = String(food.food_name ?? "").trim();
  if (!rawName) return null;
  const fields = {
    calories: "calories", protein: "protein", fat: "fat",
    carbohydrates: "carbohydrate", fiber: "fiber", sugars: "sugar",
    saturatedFat: "saturated_fat", monounsaturatedFat: "monounsaturated_fat",
    polyunsaturatedFat: "polyunsaturated_fat", sodiumMg: "sodium",
    potassiumMg: "potassium", ironMg: "iron", calciumMg: "calcium",
    cholesterolMg: "cholesterol", phosphorusMg: "phosphorus",
    magnesiumMg: "magnesium", zincMg: "zinc", vitaminEMg: "vitamin_e",
    vitaminDMcg: "vitamin_d",
  };
  const values = {};
  const knownNutrients = [];
  const missingNutrients = [];
  for (const [key, source] of Object.entries(fields)) {
    const value = nutrient(serving[source]);
    const scaled = value == null ? null : value * factor;
    if (scaled != null && Number.isFinite(scaled)) {
      values[key] = scaled;
      knownNutrients.push(key);
    } else {
      missingNutrients.push(key);
    }
  }
  if (values.sodiumMg != null) {
    values.salt = values.sodiumMg * 2.5 / 1000;
    knownNutrients.push("salt");
  }
  const basisUnit = String(serving.metric_serving_unit).toLowerCase();
  const servings = asList(food.servings?.serving)
    .filter((item) => String(item.metric_serving_unit).toLowerCase() === basisUnit &&
      nutrient(item.metric_serving_amount) > 0)
    .map((item) => ({
      id: String(item.serving_id ?? ""),
      description: String(item.serving_description ?? item.measurement_description ?? ""),
      amount: nutrient(item.metric_serving_amount),
      unit: basisUnit,
    })).filter((item) => item.description);
  return {
    id: number(food.food_id),
    name: brand && !rawName.toLowerCase().includes(brand.toLowerCase())
      ? `${rawName} — ${brand}`
      : rawName,
    ...values,
    knownNutrients,
    missingNutrients,
    basisUnit,
    servings,
    dataSource: "FatSecret",
    productType: food.food_type ?? null,
    labelDetails: food.food_url ?? null,
    water: 0,
    hasWaterData: false,
  };
}

module.exports = {asList, number, nutrient, selectServing, normalizeFood};
