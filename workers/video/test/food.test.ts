import { describe, expect, it } from "vitest";
import { handle, type Env } from "../src/index";
import { unauthenticated } from "../src/errors";
import { normalizeBarcodeProduct, normalizeSearchHit, type FoodCache, type FoodDeps } from "../src/food";

const env = { FIREBASE_PROJECT_ID: "myfit-d6275", ALLOWED_ORIGINS: "" } as Env;

const BARCODE_JSON = {
  barcode: "5449000000996",
  food_id: null,
  product: { name: "Coca-Cola", brand: "Coca-Cola", ingredients: "Water, sugar" },
  serving: { label: "1 can (330 ml)", quantity: 330, unit: "ml" },
  nutrition_per_100g: {
    energy_kcal: 42,
    protein_g: 0,
    carbohydrates_g: 10.6,
    fat_g: 0,
    sugars_g: 10.6,
    salt_g: 0,
    sodium_g: 0.01,
    fiber_g: null,
  },
};

// Shape returned live by /api/v1/public/search/foods?q=egg (trimmed).
const SEARCH_JSON = {
  data: [
    {
      id: 8153861,
      name: "Egg",
      brand_name: "Verified",
      default_portion: { grams: 48.0, label: "1 Small Egg" },
      upc: null,
      calories_100g: 120.0,
      protein_100g: 12.0,
      carbs_100g: 0.0,
      fat_100g: 8.0,
      fiber_100g: 0.0,
      sugar_100g: 0.0,
    },
  ],
  total: 1,
};

class MemoryCache implements FoodCache {
  map = new Map<string, unknown>();
  async get(key: string) {
    return this.map.get(key) ?? null;
  }
  async put(key: string, value: unknown) {
    this.map.set(key, value);
  }
}

function harness(responder: (url: string) => Response) {
  const calls: { url: string; headers: Record<string, string> }[] = [];
  const cache = new MemoryCache();
  const food: FoodDeps = {
    apiKey: "sk_test",
    cache,
    fetcher: (async (url: RequestInfo | URL, init: RequestInit = {}) => {
      calls.push({ url: String(url), headers: init.headers as Record<string, string> });
      return responder(String(url));
    }) as typeof fetch,
  };
  const verify = async (header: string | null) => {
    if (header === "Bearer user") return { uid: "u1" };
    throw unauthenticated("sign-in-required", "Missing bearer token");
  };
  const call = async (path: string, body: unknown, token: string | null = "user") => {
    const headers: Record<string, string> = { "content-type": "application/json" };
    if (token) headers.authorization = `Bearer ${token}`;
    const response = await handle(
      new Request(`https://w.example${path}`, { method: "POST", headers, body: JSON.stringify(body) }),
      env,
      { verify, food },
    );
    const json = (await response.json()) as any;
    return { status: response.status, reason: json.error?.reason, json };
  };
  return { calls, call, cache };
}

describe("Calorie API proxy", () => {
  it("requires a Firebase sign-in", async () => {
    const h = harness(() => Response.json(BARCODE_JSON));
    expect(await h.call("/food/barcode", { barcode: "5449000000996" }, null)).toMatchObject({ status: 401 });
    expect(await h.call("/food/search", { query: "egg" }, null)).toMatchObject({ status: 401 });
    expect(h.calls).toHaveLength(0);
  });

  it("looks up a barcode with the key header and normalizes per 100 g/ml", async () => {
    const h = harness(() => Response.json(BARCODE_JSON));
    const r = await h.call("/food/barcode", { barcode: "5449 0000 00996" });
    expect(r.status).toBe(200);
    expect(h.calls[0]!.url).toBe("https://calorieapiadmin.com/api/v1/search/barcode/5449000000996");
    expect(h.calls[0]!.headers["x-api-key"]).toBe("sk_test");
    expect(r.json.food).toMatchObject({
      name: "Coca-Cola",
      brand: "Coca-Cola",
      barcode: "5449000000996",
      basisUnit: "ml",
      per100: { calories: 42, protein: 0, carbohydrates: 10.6, fat: 0, fiber: null, sodiumMg: 10 },
      serving: { label: "1 can (330 ml)", amount: 330, unit: "ml" },
      source: "Calorie API",
    });
    // Key never reaches the app.
    expect(JSON.stringify(r.json)).not.toContain("sk_test");
  });

  it("caches results to save the quota", async () => {
    const h = harness(() => Response.json(BARCODE_JSON));
    await h.call("/food/barcode", { barcode: "5449000000996" });
    await h.call("/food/barcode", { barcode: "5449000000996" });
    expect(h.calls).toHaveLength(1);
  });

  it("returns null for unknown barcodes and validates input", async () => {
    const h = harness(() => Response.json({ detail: "Not found" }, { status: 404 }));
    expect((await h.call("/food/barcode", { barcode: "4006381333931" })).json).toEqual({ food: null });
    expect(await h.call("/food/barcode", { barcode: "12" })).toMatchObject({ status: 400, reason: "invalid-barcode" });
    expect(await h.call("/food/search", { query: "a" })).toMatchObject({ status: 400, reason: "invalid-query" });
  });

  it("searches foods for photo labels", async () => {
    const h = harness(() => Response.json(SEARCH_JSON));
    const r = await h.call("/food/search", { query: "  egg  ", limit: 50 });
    expect(h.calls[0]!.url).toBe("https://calorieapiadmin.com/api/v1/search/foods?q=egg&limit=10");
    expect(r.json.foods).toEqual([
      {
        id: "8153861",
        name: "Egg",
        brand: null,
        barcode: null,
        basisUnit: "g",
        per100: {
          calories: 120,
          protein: 12,
          carbohydrates: 0,
          fat: 8,
          fiber: 0,
          sugars: 0,
          saturatedFat: null,
          salt: null,
          sodiumMg: null,
        },
        serving: { label: "1 Small Egg", amount: 48, unit: "g" },
        ingredients: null,
        source: "Calorie API",
      },
    ]);
  });

  it("maps provider errors", async () => {
    for (const [status, reason, ours] of [
      [401, "food-misconfigured", 502],
      [403, "food-misconfigured", 502],
      [429, "food-rate-limited", 429],
      [500, "food-unavailable", 503],
    ] as const) {
      const h = harness(() => Response.json({ detail: "x" }, { status }));
      expect(await h.call("/food/search", { query: "egg" })).toMatchObject({ status: ours, reason });
    }
    const missingKey = harness(() => Response.json(SEARCH_JSON));
    const result = await handle(
      new Request("https://w.example/food/search", {
        method: "POST",
        headers: { "content-type": "application/json", authorization: "Bearer user" },
        body: JSON.stringify({ query: "egg" }),
      }),
      env,
      { verify: async () => ({ uid: "u1" }), food: { apiKey: "" } },
    );
    expect(result.status).toBe(500);
    expect(((await result.json()) as any).error.reason).toBe("food-misconfigured");
    expect(missingKey.calls).toHaveLength(0);
  });

  it("drops records without a name", () => {
    expect(normalizeBarcodeProduct({ product: {} })).toBeNull();
    expect(normalizeSearchHit({ id: 1 })).toBeNull();
  });
});
