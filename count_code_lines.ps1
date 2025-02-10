$files = Get-ChildItem -Recurse -Filter *.dart | Where-Object { $_.Name -notmatch '\.g\.dart$|\.freezed\.dart$|\.gr\.dart$|\.gen\.dart$' }
$totalLines = 0
foreach ($file in $files) {
    $lines = (Get-Content $file.FullName | Measure-Object -Line).Lines
    $totalLines += $lines
    Write-Output "$($file.FullName): $lines lines"
}
Write-Output "Total lines: $totalLines" 