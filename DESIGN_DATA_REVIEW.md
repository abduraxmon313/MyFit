# Design and nutrition review — 2026-09-28

Implemented a shared green Material color scheme, accessible foreground/background
pairs, rounded controls, light/dark nutrition cards, readable table spacing, source
labels and consistent gram units in food results.

Data checks: API mineral units are normalized to milligrams; explicit zero kcal is
preserved; USDA energy selection no longer depends on response order. Missing core
nutrients are shown as unavailable and cannot be added from the portion sheet.
Source and missing-value metadata survive portion scaling, storage and search cache.
Local catalog values and piece weights remain estimates, not measured quantities.

References consulted:
- https://fdc.nal.usda.gov/Foundation_Foods_Documentation/
- https://fdc.nal.usda.gov/data-documentation/
- https://openfoodfacts.github.io/documentation/docs/Product-Opener/schemas/schemas/product_nutrition/
- https://codelabs.developers.google.com/color-contrast-accessibility
- https://developer.android.com/codelabs/m3-design-theming

Validation: 86 existing tests and 4 new regression tests passed. New tests cover
USDA energy precedence and mineral conversion, OFF zero versus missing values,
light/dark text contrast, and 320 px screens with 150% text in Uzbek, Russian and
English. This does not certify every catalog entry or every physical device.

Remaining release work: independently review local recipe/portion estimates,
verify liquid nutrition bases (100 ml versus 100 g), exercise live sign-in/camera/
cloud persistence on physical devices, and configure release signing. The provided
APK is a debug build for testing; the full catalog has not been individually audited.
