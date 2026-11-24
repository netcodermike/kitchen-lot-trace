param([Parameter(Mandatory=$true, Position=0)][string] $InputPath)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
function Invoke-Analysis($data) {
    $start = $data['start']
    if ($start -isnot [string] -or [string]::IsNullOrWhiteSpace($start) -or $data['uses'] -isnot [array]) {
        throw 'Supply a starting lot and a list of input/output lot pairs'
    }
    $edges = [Collections.Generic.Dictionary[string,object]]::new([StringComparer]::Ordinal)
    foreach ($pair in $data['uses']) {
        if ($pair -isnot [array] -or $pair.Count -ne 2) { throw 'Expected a pair of lot identifiers' }
        foreach ($lot in $pair) {
            if ($lot -isnot [string] -or [string]::IsNullOrWhiteSpace($lot)) { throw 'Invalid lot identifier' }
        }
        if (-not $edges.ContainsKey($pair[0])) { $edges[$pair[0]] = [Collections.Generic.List[string]]::new() }
        $edges[$pair[0]].Add($pair[1])
    }
    $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    $queue = [Collections.Generic.Queue[object]]::new()
    $affected = [Collections.Generic.List[object]]::new()
    $null = $seen.Add($start)
    $queue.Enqueue(@{lot=$start; steps=0})
    while ($queue.Count) {
        $node = $queue.Dequeue()
        if (-not $edges.ContainsKey($node.lot)) { continue }
        foreach ($child in $edges[$node.lot]) {
            if ($seen.Add($child)) {
                $row = [ordered]@{lot=$child; steps=$node.steps+1}
                $affected.Add($row)
                $queue.Enqueue($row)
            }
        }
    }
    return @{affected=$affected}
}

try {
    $payload = Get-Content -LiteralPath $InputPath -Raw | ConvertFrom-Json -AsHashtable
    if ($payload -isnot [System.Collections.IDictionary]) { throw 'Input must be a JSON object' }
    Invoke-Analysis $payload | ConvertTo-Json -Depth 30 -Compress
} catch {
    [Console]::Error.WriteLine($_.Exception.Message)
    exit 2
}
