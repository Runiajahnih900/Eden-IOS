param(
    [int]$Port = 8787,
    [string]$Path = "/log/"
)

$ErrorActionPreference = "Stop"

if (-not $Path.StartsWith("/")) {
    $Path = "/$Path"
}
if (-not $Path.EndsWith("/")) {
    $Path = "$Path/"
}

function Write-HttpResponse {
    param(
        [System.IO.Stream]$Stream,
        [int]$StatusCode,
        [string]$StatusText,
        [string]$JsonBody
    )

    $bytes = [System.Text.Encoding]::UTF8.GetBytes($JsonBody)
    $headers = @(
        "HTTP/1.1 $StatusCode $StatusText",
        "Content-Type: application/json",
        "Content-Length: $($bytes.Length)",
        "Connection: close",
        "",
        ""
    ) -join "`r`n"

    $headerBytes = [System.Text.Encoding]::ASCII.GetBytes($headers)
    $Stream.Write($headerBytes, 0, $headerBytes.Length)
    $Stream.Write($bytes, 0, $bytes.Length)
}

$listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Any, $Port)
$listener.Start()

Write-Host "Live iOS log server listening on 0.0.0.0:$Port$Path" -ForegroundColor Green
Write-Host "Press Ctrl+C to stop." -ForegroundColor DarkGray

while ($true) {
    $client = $listener.AcceptTcpClient()
    $stream = $client.GetStream()

    try {
        $reader = New-Object System.IO.StreamReader($stream, [System.Text.Encoding]::ASCII, $false, 4096, $true)
        $requestLine = $reader.ReadLine()
        if ([string]::IsNullOrWhiteSpace($requestLine)) {
            Write-HttpResponse -Stream $stream -StatusCode 400 -StatusText "Bad Request" -JsonBody (@{ ok = $false; error = "empty request" } | ConvertTo-Json -Compress)
            continue
        }

        $parts = $requestLine.Split(' ')
        $method = if ($parts.Length -ge 1) { $parts[0] } else { "" }
        $requestPath = if ($parts.Length -ge 2) { $parts[1] } else { "" }

        $contentLength = 0
        while ($true) {
            $line = $reader.ReadLine()
            if ($null -eq $line -or $line -eq "") {
                break
            }

            if ($line -match "^Content-Length:\s*(\d+)$") {
                $contentLength = [int]$Matches[1]
            }
        }

        $body = ""
        if ($contentLength -gt 0) {
            $charBuffer = New-Object char[] $contentLength
            $offset = 0
            while ($offset -lt $contentLength) {
                $read = $reader.Read($charBuffer, $offset, $contentLength - $offset)
                if ($read -le 0) {
                    break
                }
                $offset += $read
            }

            if ($offset -gt 0) {
                $body = -join $charBuffer[0..($offset - 1)]
            }
        }

        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
        $remote = $client.Client.RemoteEndPoint

        if ($method -ne "POST" -or $requestPath -ne $Path) {
            Write-HttpResponse -Stream $stream -StatusCode 404 -StatusText "Not Found" -JsonBody (@{ ok = $false; error = "not found" } | ConvertTo-Json -Compress)
            continue
        }

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

        Write-HttpResponse -Stream $stream -StatusCode 200 -StatusText "OK" -JsonBody (@{ ok = $true } | ConvertTo-Json -Compress)
    } catch {
        $message = $_.Exception.Message
        Write-Host "Request handling error: $message" -ForegroundColor Red
        Write-HttpResponse -Stream $stream -StatusCode 500 -StatusText "Internal Server Error" -JsonBody (@{ ok = $false; error = $message } | ConvertTo-Json -Compress)
    } finally {
        if ($stream) {
            $stream.Close()
        }
        if ($client) {
            $client.Close()
        }
    }
}
