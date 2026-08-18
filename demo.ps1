# Demo script for Smart Warehouse prototype
# Run after backend is started (http://localhost:4000)

$base = 'http://localhost:4000/api'

function safePost($uri, $body){
  Write-Host "POST $uri" -ForegroundColor Cyan
  $json = $body | ConvertTo-Json
  try { return Invoke-RestMethod -Uri $uri -Method Post -ContentType 'application/json' -Body $json } catch { Write-Host $_ -ForegroundColor Red; return $null }
}

function safeGet($uri){
  Write-Host "GET $uri" -ForegroundColor Cyan
  try { return Invoke-RestMethod -Uri $uri } catch { Write-Host $_ -ForegroundColor Red; return $null }
}

Write-Host "1) Check initial state"
$s = safeGet "$base/state"
$s | ConvertTo-Json -Depth 5 | Write-Host

Write-Host "\n2) Run allocation"
$alloc = safePost "$base/allocate" @{}
$alloc | ConvertTo-Json -Depth 5 | Write-Host

Write-Host "\n3) Pick some items (simulate scan)"
# pick 3 units of p1 from order o1
safePost "$base/pick-item/o1" @{ productId = 'p1'; qty = 3 } | ConvertTo-Json -Depth 5 | Write-Host
# scan items one by one for o1,p1
1..2 | ForEach-Object { safePost "$base/pick-item/o1" @{ productId='p1'; qty=1 } }

Write-Host "\n4) Pack order o1"
safePost "$base/pack/o1" @{} | ConvertTo-Json -Depth 5 | Write-Host

Write-Host "\n5) Dispatch order o1"
safePost "$base/dispatch/o1" @{} | ConvertTo-Json -Depth 5 | Write-Host

Write-Host "\n6) Report analytics"
$s = safeGet "$base/analytics"
$s | ConvertTo-Json -Depth 5 | Write-Host

Write-Host "\n7) Introduce damage to o3,p2 qty=2 and auto-resolve"
safePost "$base/damage" @{ orderId='o3'; productId='p2'; qty=2; autoResolve=$true } | ConvertTo-Json -Depth 5 | Write-Host

Write-Host "\n8) View backorders and resolve one if present"
$b = safeGet "$base/backorders"
$b | ConvertTo-Json -Depth 5 | Write-Host
if ($b -and $b.Count -gt 0) {
  $id = $b[0].id
  Write-Host "Resolving backorder $id by receiving 5 units"
  safePost "$base/resolve-backorder" @{ backorderId = $id; qty=5 } | ConvertTo-Json -Depth 5 | Write-Host
}

Write-Host "\nDemo complete. Final state:"
safeGet "$base/state" | ConvertTo-Json -Depth 5 | Write-Host
