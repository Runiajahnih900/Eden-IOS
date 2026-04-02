param(
    [int]$Port = 8787,
    [string]$Path = "/log/",
    [string]$HostToken = "+"
)

$ErrorActionPreference = "Stop"

if (-not $Path.StartsWith("/")) {
    $Path = "/$Path"
}
if (-not $Path.EndsWith("/")) {
    $Path = "$Path/"
}

$prefix = "http://$HostToken`:$Port$Path"
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add($prefix)

try {
    $listener.Start()
} catch {
    Write-Host "Failed to start HttpListener on $prefix" -ForegroundColor Red
    Write-Host "If you see Access is denied, run PowerShell as Administrator and execute:" -ForegroundColor Yellow
    Write-Host "  netsh http add urlacl url=$prefix user=$env:USERNAME" -ForegroundColor Yellow
    throw
}

Write-Host "Live iOS log server listening on $prefix" -ForegroundColor Green
Write-Host "Press Ctrl+C to stop." -ForegroundColor DarkGray

while ($listener.IsListening) {
    $context = $listener.GetContext()
    $request = $context.Request
    $response = $context.Response

    try {
        $body = ""
        if ($request.HasEntityBody) {
            $encoding = if ($request.ContentEncoding) { $request.ContentEncoding } else { [System.Text.Encoding]::UTF8 }
            $reader = New-Object System.IO.StreamReader($request.InputStream, $encoding)
            $body = $reader.ReadToEnd()
            $reader.Dispose()
        }

        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
        $remote = $request.RemoteEndPoint

        if ([string]::IsNullOrWhiteSpace($body)) {
            Write-Host "[$timestamp] $remote empty payload" -ForegroundColor DarkYellow
        } else {
            try {
                $json = $body | ConvertFrom-Json
                $event = $json.event
                $session = $json.sessionID
                $tick = $json.tickCount
                $running = $json.running
                $report = $json.report
                Write-Host "[$timestamp] $remote event=$event session=$session tick=$tick running=$running" -ForegroundColor Cyan
                if (-not [string]::IsNullOrWhiteSpace($report)) {
                    Write-Host "  report: $report"
                }
            } catch {
                Write-Host "[$timestamp] $remote raw: $body" -ForegroundColor Gray
            }
        }

        $payload = @{ ok = $true } | ConvertTo-Json -Compress
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($payload)
        $response.StatusCode = 200
        $response.ContentType = "application/json"
        $response.ContentLength64 = $bytes.Length
        $response.OutputStream.Write($bytes, 0, $bytes.Length)
    } catch {
        $message = $_.Exception.Message
        $errorPayload = @{ ok = $false; error = $message } | ConvertTo-Json -Compress
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($errorPayload)
        $response.StatusCode = 500
        $response.ContentType = "application/json"
        $response.ContentLength64 = $bytes.Length
        $response.OutputStream.Write($bytes, 0, $bytes.Length)
    } finally {
        $response.OutputStream.Close()
    }
}
