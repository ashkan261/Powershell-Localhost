[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$Root,
    [Parameter(Mandatory=$true)][ValidateRange(1024,65535)][int]$Port
)
$ErrorActionPreference = 'Stop'
$Root = (Resolve-Path -LiteralPath $Root).Path.TrimEnd('\','/')
$mime = @{
    '.html'='text/html; charset=utf-8'; '.htm'='text/html; charset=utf-8'; '.css'='text/css; charset=utf-8'; '.js'='application/javascript; charset=utf-8'; '.mjs'='application/javascript; charset=utf-8';
    '.json'='application/json; charset=utf-8'; '.webmanifest'='application/manifest+json'; '.svg'='image/svg+xml'; '.png'='image/png'; '.jpg'='image/jpeg'; '.jpeg'='image/jpeg'; '.gif'='image/gif'; '.webp'='image/webp'; '.ico'='image/x-icon';
    '.woff'='font/woff'; '.woff2'='font/woff2'; '.ttf'='font/ttf'; '.mp3'='audio/mpeg'; '.wav'='audio/wav'; '.mp4'='video/mp4'; '.webm'='video/webm'; '.pdf'='application/pdf'; '.txt'='text/plain; charset=utf-8'; '.xml'='application/xml; charset=utf-8'
}
function Write-Response($stream,[int]$code,[string]$reason,[string]$type,[byte[]]$body,[bool]$head=$false) {
    $header="HTTP/1.1 $code $reason`r`nContent-Type: $type`r`nContent-Length: $($body.Length)`r`nCache-Control: no-cache`r`nConnection: close`r`n`r`n"
    $hb=[Text.Encoding]::ASCII.GetBytes($header); $stream.Write($hb,0,$hb.Length)
    if (-not $head -and $body.Length -gt 0) { $stream.Write($body,0,$body.Length) }
    $stream.Flush()
}
$tcp = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, $Port)
try {
    $tcp.Start()
    $host.UI.RawUI.WindowTitle = "Ashkan Localhost - http://127.0.0.1:$Port/"
    Write-Host 'Ashkan Localhost server is running' -ForegroundColor Cyan
    Write-Host "Folder: $Root"
    Write-Host "URL:    http://127.0.0.1:$Port/" -ForegroundColor Green
    Write-Host 'Keep this PowerShell window open while using the app. Press Ctrl+C to stop.' -ForegroundColor Yellow
    while ($true) {
        $client=$tcp.AcceptTcpClient()
        try {
            $stream=$client.GetStream()
            $reader=[IO.StreamReader]::new($stream,[Text.Encoding]::ASCII,$false,1024,$true)
            $requestLine=$reader.ReadLine()
            if (-not $requestLine) { continue }
            $parts=$requestLine.Split(' ')
            if ($parts.Count -lt 2) { Write-Response $stream 400 'Bad Request' 'text/plain' ([Text.Encoding]::UTF8.GetBytes('Bad request')); continue }
            $method=$parts[0].ToUpperInvariant(); $target=$parts[1]
            while ($true) { $line=$reader.ReadLine(); if ([string]::IsNullOrEmpty($line)) { break } }
            if ($method -ne 'GET' -and $method -ne 'HEAD') { Write-Response $stream 405 'Method Not Allowed' 'text/plain' ([Text.Encoding]::UTF8.GetBytes('Method not allowed')); continue }
            try { $uri=[Uri]::new("http://127.0.0.1:$Port$target"); $path=[Uri]::UnescapeDataString($uri.AbsolutePath.TrimStart('/')) } catch { $path='' }
            if ([string]::IsNullOrWhiteSpace($path)) { $path='index.html' }
            $relative=$path.Replace('/',[IO.Path]::DirectorySeparatorChar)
            $full=[IO.Path]::GetFullPath((Join-Path $Root $relative))
            if (-not ($full.Equals($Root,[StringComparison]::OrdinalIgnoreCase) -or $full.StartsWith($Root + [IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase))) { Write-Response $stream 403 'Forbidden' 'text/plain' ([Text.Encoding]::UTF8.GetBytes('Forbidden')); continue }
            if (Test-Path -LiteralPath $full -PathType Container) { $full=Join-Path $full 'index.html' }
            if (-not (Test-Path -LiteralPath $full -PathType Leaf) -and [IO.Path]::GetExtension($full) -eq '') { $fallback=Join-Path $Root 'index.html'; if (Test-Path -LiteralPath $fallback -PathType Leaf) { $full=$fallback } }
            if (-not (Test-Path -LiteralPath $full -PathType Leaf)) { Write-Response $stream 404 'Not Found' 'text/plain; charset=utf-8' ([Text.Encoding]::UTF8.GetBytes('Not found')); continue }
            $body=[IO.File]::ReadAllBytes($full); $ext=[IO.Path]::GetExtension($full).ToLowerInvariant(); $type='application/octet-stream'; if ($mime.ContainsKey($ext)) { $type=$mime[$ext] }
            Write-Response $stream 200 'OK' $type $body ($method -eq 'HEAD')
        } catch { try { Write-Response $stream 500 'Internal Server Error' 'text/plain' ([Text.Encoding]::UTF8.GetBytes('Server error')) } catch {} }
        finally { try { if ($reader) {$reader.Dispose()} } catch {}; try {$client.Close()} catch {}; $reader=$null }
    }
} catch {
    Write-Host "Could not listen on http://127.0.0.1:$Port/" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host 'The port may already be in use. Close this window and try again.' -ForegroundColor Yellow
    Read-Host 'Press Enter to close'
} finally { if ($tcp) { try { $tcp.Stop() } catch {} } }
