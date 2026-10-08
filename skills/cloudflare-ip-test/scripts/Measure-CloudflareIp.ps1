#requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidatePattern('^[a-zA-Z0-9.-]+$')][string]$Domain,
    [Parameter(Mandatory)][string[]]$IPs,
    [ValidateRange(20, 10000)][int]$Samples = 20,
    [ValidateRange(1, 60)][int]$TimeoutSeconds = 5,
    [string[]]$ExpectedColos = @(),
    [string]$OutputDirectory = $env:TEMP
)

$ErrorActionPreference = 'Stop'
# Handle native failures through LASTEXITCODE, independently of the caller's
# preference. Script scope keeps the caller's setting intact (including on 7.0).
$PSNativeCommandUseErrorActionPreference = $false
if (-not (Test-Path -LiteralPath $OutputDirectory -PathType Container)) {
    throw "Output directory must already exist: $OutputDirectory"
}
$null = Get-Command curl.exe -ErrorAction Stop
$candidateIPs = @(@(foreach ($inputIP in $IPs) {
    $candidateIP = if ($null -eq $inputIP) { '' } else { $inputIP.Trim() }
    # Parse four decimal octets explicitly: IPAddress.TryParse also accepts
    # abbreviated, hexadecimal and octal forms that can change the target.
    if ($candidateIP -notmatch '^\d{1,3}(\.\d{1,3}){3}$' -or $candidateIP -match '[^0-9.]') {
        throw "Provide a four-octet decimal IPv4 address: $inputIP"
    }
    $octets = @($candidateIP.Split('.') | ForEach-Object { [int]::Parse($_, [System.Globalization.CultureInfo]::InvariantCulture) })
    if (@($octets | Where-Object { $_ -gt 255 }).Count -gt 0) {
        throw "Invalid IPv4 address: $inputIP"
    }
    $octets -join '.'
}) | Select-Object -Unique)
if ($candidateIPs.Count -eq 0) { throw 'Provide at least one IP.' }
$runStamp = Get-Date -Format 'yyyyMMdd-HHmmss-fff'
$rawPath = Join-Path $OutputDirectory "cf-ip-$Domain-$runStamp-raw.csv"
$summaryPath = Join-Path $OutputDirectory "cf-ip-$Domain-$runStamp-summary.csv"
$culture = [System.Globalization.CultureInfo]::InvariantCulture
$records = [System.Collections.Generic.List[object]]::new()
$progressWatch = [System.Diagnostics.Stopwatch]::StartNew()
$url = "https://$Domain/cdn-cgi/trace"

for ($round = 1; $round -le $Samples; $round++) {
    for ($offset = 0; $offset -lt $candidateIPs.Count; $offset++) {
        $candidateIP = $candidateIPs[($offset + $round - 1) % $candidateIPs.Count]
        $curlArgs = @('-4', '--noproxy', '*', '--resolve', "${Domain}:443:$candidateIP",
            '-sS', '--max-time', "$TimeoutSeconds", '-w',
            '\nBENCHMARK code=%{http_code} remote=%{remote_ip} tcp=%{time_connect} tls=%{time_appconnect} total=%{time_total}', $url)
        $startedAt = [DateTimeOffset]::Now.ToString('o')
        $reply = (& curl.exe @curlArgs 2>&1 | ForEach-Object { "$_" }) -join "`n"
        $exitCode = $LASTEXITCODE
        $metrics = [regex]::Match($reply,
            'BENCHMARK code=(\d+) remote=(\S*) tcp=([\d.]+) tls=([\d.]+) total=([\d.]+)')
        $colo = [regex]::Match($reply, '(?m)^colo=(\w+)\r?$').Groups[1].Value
        $status = if ($metrics.Success) { [int]$metrics.Groups[1].Value } else { 0 }
        $isSuccess = $exitCode -eq 0 -and $status -eq 200 -and $colo -ne ''
        $row = [pscustomobject]@{
            Timestamp = $startedAt
            IP = $candidateIP
            Round = $round
            ExitCode = $exitCode
            Status = $status
            Colo = $colo
            RemoteIP = $metrics.Groups[2].Value
            Success = $isSuccess
            ColoMismatch = $isSuccess -and $ExpectedColos.Count -gt 0 -and $colo -notin $ExpectedColos
            TcpMs = if ($metrics.Success) { 1000 * [double]::Parse($metrics.Groups[3].Value, $culture) } else { $null }
            TlsMs = if ($metrics.Success) { 1000 * [double]::Parse($metrics.Groups[4].Value, $culture) } else { $null }
            TotalMs = if ($metrics.Success) { 1000 * [double]::Parse($metrics.Groups[5].Value, $culture) } else { $null }
            # Do not persist trace response bodies: they can contain the client's public IP.
            Error = if ($isSuccess) { '' } else { "curl_exit=$exitCode; http_status=$status; colo_present=$($colo -ne '')" }
        }
        $records.Add($row)
        $row | Export-Csv -LiteralPath $rawPath -NoTypeInformation -Encoding utf8 -Append
        if ($progressWatch.Elapsed.TotalSeconds -ge 30) {
            Write-Host "Completed $($records.Count)/$($Samples * $candidateIPs.Count) requests; raw data: $rawPath"
            $progressWatch.Restart()
        }
    }
}

$summaries = foreach ($candidateIP in $candidateIPs) {
    $ipRecords = @($records | Where-Object IP -EQ $candidateIP)
    $successful = @($ipRecords | Where-Object Success)
    $times = @($successful.TotalMs | Sort-Object)
    $mean = $median = $p95 = $minimum = $maximum = $null
    if ($times.Count -gt 0) {
        $stats = $times | Measure-Object -Average -Minimum -Maximum
        $mean = [math]::Round($stats.Average, 1)
        $middle = [int][math]::Floor($times.Count / 2)
        $medianValue = if ($times.Count % 2) { $times[$middle] } else { ($times[$middle - 1] + $times[$middle]) / 2 }
        $median = [math]::Round($medianValue, 1)
        $p95 = [math]::Round($times[[int][math]::Ceiling(0.95 * $times.Count) - 1], 1)
        $minimum = [math]::Round($stats.Minimum, 1)
        $maximum = [math]::Round($stats.Maximum, 1)
    }
    [pscustomobject]@{
        IP = $candidateIP
        Attempts = $ipRecords.Count
        Successes = $successful.Count
        Failures = $ipRecords.Count - $successful.Count
        Timeouts = @($ipRecords | Where-Object ExitCode -EQ 28).Count
        ColoMismatches = @($ipRecords | Where-Object ColoMismatch).Count
        Colos = (@($successful.Colo | Sort-Object -Unique) -join ',')
        MeanMs = $mean
        MedianMs = $median
        P95Ms = $p95
        MinMs = $minimum
        MaxMs = $maximum
    }
}
$latencySort = foreach ($property in @('P95Ms', 'MedianMs', 'MeanMs')) {
    @{ Expression = { if ($null -eq $_.$property) { [double]::PositiveInfinity } else { $_.$property } }.GetNewClosure() }
}
$orderedSummaries = @($summaries | Sort-Object -Property (@('Failures', 'ColoMismatches') + @($latencySort)))
$orderedSummaries | Export-Csv -LiteralPath $summaryPath -NoTypeInformation -Encoding utf8
$orderedSummaries | Format-Table -AutoSize
Write-Host "Raw CSV: $rawPath"
Write-Host "Summary CSV: $summaryPath"
