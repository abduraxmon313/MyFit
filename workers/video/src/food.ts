import { ApiError, invalid, unavailable } from "./errors";

/**
 * Calorie API (https://calorieapi.com/docs) proxy. The app never sees the
 * key; every call needs a Firebase ID token (checked in index.ts).
 *
 *  POST /food/barcode { barcode }        -> { food | null }
 *  POST /food/search  { query, limit? }  -> { foods: [...] }
 *
 * Results are normalized to per-100 g values and cached for a day to save
 * the monthly quota.
 */

export const CALORIE_API_BASE = "https://calorieapiadmin.com/api/v1";
const CACHE_SECONDS = 24 * 60 * 60;
const MAX_LIMIT = 10;

export interface NormalizedFood {
  id: string;
  name: string;
  brand: string | null;
  barcode: string | null;
  basisUnit: "g" | "ml";
  per100: {
    calories: number | null;
    protein: number | null;
    carbohydrates: number | null;
    fat: number | null;
    fiber: number | null;
    sugars: number | null;
    saturatedFat: number | null;
    salt: number | null;
    sodiumMg: number | null;
  };
  serving: { label: string; amount: number; unit: "g" | "ml" } | null;
  ingredients: string | null;
  source: "Calorie API";
}

export interface FoodCache {
  get(key: string): Promise<unknown | null>;
  put(key: string, value: unknown, ttlSeconds: number): Promise<void>;
}

export interface FoodDeps {
  apiKey: string;
  fetcher?: typeof fetch;
  cache?: FoodCache;
}

const num = (value: unknown): number | null =>
  typeof value === "number" && Number.isFinite(value) && value >= 0 ? value : null;
const text = (value: unknown): string | null =>
  typeof value === "string" && value.trim() ? value.trim() : null;
const unitOf = (value: unknown): "g" | "ml" | null => {
  const unit = text(value)?.toLowerCase();
  return unit === "g" || unit === "ml" ? unit : null;
};

export function normalizeBarcodeProduct(json: any): NormalizedFood | null {
  const name = text(json?.product?.name);
  if (!name) return null;
  const n = json?.nutrition_per_100g ?? {};
  const servingUnit = unitOf(json?.serving?.unit);
  const servingAmount = num(json?.serving?.quantity);
  const barcode = text(json?.barcode);
  const sodiumG = num(n.sodium_g);
  return {
    id: String(json?.food_id ?? `upc-${barcode ?? name}`),
    name,
    brand: text(json?.product?.brand),
    barcode,
    basisUnit: servingUnit === "ml" ? "ml" : "g",
    per100: {
      calories: num(n.energy_kcal),
      protein: num(n.protein_g),
      carbohydrates: num(n.carbohydrates_g),
      fat: num(n.fat_g),
      fiber: num(n.fiber_g),
      sugars: num(n.sugars_g),
      saturatedFat: num(n.saturated_fat_g),
      salt: num(n.salt_g),
      sodiumMg: sodiumG === null ? null : sodiumG * 1000,
    },
    serving:
      servingUnit && servingAmount && servingAmount > 0
        ? { label: text(json?.serving?.label) ?? `${servingAmount} ${servingUnit}`, amount: servingAmount, unit: servingUnit }
        : null,
    ingredients: text(json?.product?.ingredients),
    source: "Calorie API",
  };
}

export function normalizeSearchHit(hit: any): NormalizedFood | null {
  const name = text(hit?.name);
  if (!name || hit?.id === undefined || hit?.id === null) return null;
  const portionGrams = num(hit?.default_portion?.grams);
  const brand = text(hit?.brand_name);
  return {
    id: String(hit.id),
    name,
    // "Verified" is a quality flag, not a brand.
    brand: brand && brand.toLowerCase() !== "verified" ? brand : null,
    barcode: text(hit?.upc),
    basisUnit: "g",
    per100: {
      calories: num(hit?.calories_100g),
      protein: num(hit?.protein_100g),
      carbohydrates: num(hit?.carbs_100g),
      fat: num(hit?.fat_100g),
      fiber: num(hit?.fiber_100g),
      sugars: num(hit?.sugar_100g),
      saturatedFat: null,
      salt: null,
      sodiumMg: null,
    },
    serving:
      portionGrams && portionGrams > 0
        ? { label: text(hit?.default_portion?.label) ?? `${portionGrams} g`, amount: portionGrams, unit: "g" }
        : null,
    ingredients: null,
    source: "Calorie API",
  };
}

function providerError(status: number): ApiError {
  console.error("Calorie API failed", status);
  if (status === 401 || status === 403) {
    return new ApiError(502, "food-misconfigured", "Calorie API key is invalid or lacks access");
  }
  if (status === 429) return new ApiError(429, "food-rate-limited", "Calorie API limit reached, try later");
  return unavailable("food-unavailable", "Calorie API is unavailable");
}

async function callApi(deps: FoodDeps, path: string): Promise<{ status: number; json: any }> {
  if (!deps.apiKey) throw new ApiError(500, "food-misconfigured", "CALORIE_API_KEY is not set");
  const fetcher = deps.fetcher ?? ((input, init) => fetch(input, init));
  let response: Response;
  try {
    response = await fetcher(`${CALORIE_API_BASE}${path}`, {
      headers: { "x-api-key": deps.apiKey, accept: "application/json" },
    });
  } catch {
    throw unavailable("food-unavailable", "Calorie API unreachable");
  }
  const json = await response.json().catch(() => null);
  return { status: response.status, json };
}

async function cached<T>(deps: FoodDeps, key: string, load: () => Promise<T>): Promise<T> {
  const hit = await deps.cache?.get(key).catch(() => null);
  if (hit !== null && hit !== undefined) return hit as T;
  const value = await load();
  await deps.cache?.put(key, value, CACHE_SECONDS).catch(() => {});
  return value;
}

/** POST /food/barcode */
export async function lookupBarcode(deps: FoodDeps, body: unknown) {
  const barcode = String((body as Record<string, unknown> | null)?.barcode ?? "").replace(/\D/g, "");
  if (!/^\d{8,14}$/.test(barcode)) throw invalid("invalid-barcode", "EAN/UPC barcode (8-14 digits) required");
  return cached(deps, `barcode:${barcode}`, async () => {
    const { status, json } = await callApi(deps, `/search/barcode/${barcode}`);
    if (status === 404 || status === 422) return { food: null };
    if (status !== 200) throw providerError(status);
    return { food: normalizeBarcodeProduct(json) };
  });
}

/** POST /food/search */
export async function searchFoods(deps: FoodDeps, body: unknown) {
  const input = (body ?? {}) as Record<string, unknown>;
  const query = String(input.query ?? "").trim().replace(/\s+/g, " ").slice(0, 100);
  if (query.length < 2) throw invalid("invalid-query", "Query must be at least 2 characters");
  const requested = Number(input.limit ?? 5);
  const limit = Number.isInteger(requested) ? Math.min(Math.max(requested, 1), MAX_LIMIT) : 5;
  return cached(deps, `search:${limit}:${query.toLowerCase()}`, async () => {
    const params = new URLSearchParams({ q: query, limit: String(limit) });
    const { status, json } = await callApi(deps, `/search/foods?${params}`);
    if (status !== 200) throw providerError(status);
    const hits: unknown[] = Array.isArray(json?.data) ? json.data : [];
    return { foods: hits.map(normalizeSearchHit).filter((f): f is NormalizedFood => f !== null) };
  });
}

/** Cloudflare Cache API, keyed by a synthetic URL (never the API key). */
export function edgeFoodCache(): FoodCache {
  const cache = (caches as unknown as { default: Cache }).default;
  const url = (key: string) => `https://myfit-food-cache.invalid/${encodeURIComponent(key)}`;
  return {
    async get(key) {
      const response = await cache.match(url(key));
      return response ? response.json() : null;
    },
    async put(key, value, ttlSeconds) {
      await cache.put(
        url(key),
        new Response(JSON.stringify(value), {
          headers: { "content-type": "application/json", "cache-control": `max-age=${ttlSeconds}` },
        }),
      );
    },
  };
}
