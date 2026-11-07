$ErrorActionPreference = 'Stop'
$queries = @('milk', 'cheese', 'cream butter', 'salmon tuna carp trout', 'buckwheat', 'pasta spaghetti macaroni', 'nuts seeds', 'coffee tea beverages', 'carbonated juice', 'sugars honey jams', 'mayonnaise ketchup sauces', 'pizza burger sandwich', 'frankfurter potatoes fried', 'chocolate cookies cake ice cream', 'kefir', 'oil sunflower')
$directory = Join-Path $PSScriptRoot '../data_sources/usda'
New-Item -ItemType Directory -Path $directory -Force | Out-Null
for ($i = 0; $i -lt $queries.Count; $i++) {
  $path = Join-Path $directory "$i.json"
  if (Test-Path -LiteralPath $path) { continue }
  $query = [Uri]::EscapeDataString($queries[$i])
  $uri = "https://api.nal.usda.gov/fdc/v1/foods/search?api_key=DEMO_KEY&query=$query&dataType=SR%20Legacy&pageSize=200"
  $result = Invoke-RestMethod -Uri $uri -TimeoutSec 30
  $result.foods | ConvertTo-Json -Depth 15 | Set-Content -LiteralPath $path -Encoding UTF8
  Write-Output "$i $($queries[$i]): $($result.foods.Count) records"
}
