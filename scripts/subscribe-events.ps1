# Скрипт к сценарию docs/quickstarts/subscribe-events.md — WebSocket JSON-RPC (PowerShell 7+).
param(
    [string] $RestBase = $(if ($env:UMEC_BASE) { $env:UMEC_BASE } else { "https://api.rumecdev.deviot.cloud" }),
    [string] $WsUrl = $(if ($env:UMEC_WS_URL) { $env:UMEC_WS_URL } else { "wss://ws.umecdev.deviot.cloud/ws" }),
    [Parameter(Mandatory)]
    [string] $AccessToken,
    [string] $CompoundUnitId = $env:UMEC_COMPOUND_UNIT_ID,
    [long] $UnitId = 0,
    [int] $MaxEvents = 1
)

$ErrorActionPreference = "Stop"
$RestBase = $RestBase.TrimEnd("/")

# Шаг 1 — подготовить deviceId/unitCode (параметр или GET /units/{id}).
if (-not $CompoundUnitId) {
    if ($UnitId -eq 0) {
        if ($env:UMEC_UNIT_ID) { $UnitId = [long]$env:UMEC_UNIT_ID }
    }
    if ($UnitId -eq 0) {
        throw "Укажите -CompoundUnitId или -UnitId (или переменные UMEC_COMPOUND_UNIT_ID / UMEC_UNIT_ID)."
    }
    $hdr = @{ Authorization = "Bearer $AccessToken" }
    $u = Invoke-RestMethod -Method Get -Uri "$RestBase/api/customer/v1/units/$UnitId" -Headers $hdr
    if (-not $u.deviceId -or -not $u.unitCode) {
        throw "В ответе API нет deviceId/unitCode; задайте -CompoundUnitId вручную."
    }
    $CompoundUnitId = "$($u.deviceId)/$($u.unitCode)"
}

# Шаг 2 — WebSocket: connect-customer.
$ws = [System.Net.WebSockets.ClientWebSocket]::new()
$ws.ConnectAsync([Uri]$WsUrl, [Threading.CancellationToken]::None).GetAwaiter().GetResult()

function Send-JsonRpc {
    param([int]$Id, [string]$Method, [hashtable]$Params)
    $payload = @{ jsonrpc = "2.0"; id = $Id; method = $Method; params = $Params } | ConvertTo-Json -Compress -Depth 8
    $buf = [Text.Encoding]::UTF8.GetBytes($payload)
    $seg = [System.ArraySegment[byte]]::new($buf)
    $ws.SendAsync($seg, [System.Net.WebSockets.WebSocketMessageType]::Text, $true, [Threading.CancellationToken]::None).GetAwaiter().GetResult()
}

function Receive-JsonRpc {
    $ms = [IO.MemoryStream]::new()
    $buf = [byte[]]::new(65536)
    do {
        $seg = [System.ArraySegment[byte]]::new($buf)
        $r = $ws.ReceiveAsync($seg, [Threading.CancellationToken]::None).GetAwaiter().GetResult()
        if ($r.MessageType -ne [System.Net.WebSockets.WebSocketMessageType]::Text) { continue }
        $ms.Write($buf, 0, $r.Count)
    } while (-not $r.EndOfMessage)
    $txt = [Text.Encoding]::UTF8.GetString($ms.ToArray())
    $txt | ConvertFrom-Json
}

try {
    Send-JsonRpc -Id 1 -Method "connect-customer" -Params @{ authToken = $AccessToken }
    $hello = Receive-JsonRpc
    if ($null -ne $hello.error) {
        $hello | ConvertTo-Json -Depth 10
        exit 1
    }
    $connectionKey = $hello.result.connectionKey
    Write-Host "connectionKey: $connectionKey"

    # Шаг 3 — subscribe-units.
    Send-JsonRpc -Id 2 -Method "subscribe-units" -Params @{ connectionKey = $connectionKey; unitIds = @($CompoundUnitId) }
    $sub = Receive-JsonRpc
    if ($null -ne $sub.error) {
        $sub | ConvertTo-Json -Depth 10
        exit 1
    }
    Write-Host "subscribe:"
    $sub.result | ConvertTo-Json -Depth 10

    # Шаг 4 — ждать unit-event.
    $seen = 0
    while ($MaxEvents -eq 0 -or $seen -lt $MaxEvents) {
        $msg = Receive-JsonRpc
        if ($msg.method -eq "unit-event") {
            $seen++
            $p = $msg.params
            if ($p -is [System.Array] -and $p.Count -eq 1) { $p = $p[0] }
            $p | ConvertTo-Json -Depth 12
        }
        else {
            $msg | ConvertTo-Json -Depth 10
        }
    }
}
finally {
    if ($ws.State -eq [System.Net.WebSockets.WebSocketState]::Open) {
        $ws.CloseAsync([System.Net.WebSockets.WebSocketCloseStatus]::NormalClosure, "", [Threading.CancellationToken]::None).GetAwaiter().GetResult() | Out-Null
    }
    $ws.Dispose()
}
