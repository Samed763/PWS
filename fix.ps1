$ws = [System.Net.WebSockets.ClientWebSocket]::new()

function Send-PageNavigateCommand {
    param (
        [string]$webSocketDebuggerUrl,
        [string]$newUrl
    )
    
    try {
        $webSocketUri = "ws://$($webSocketDebuggerUrl.TrimStart('ws://'))"

        if ($ws.State -ne [System.Net.WebSockets.WebSocketState]::Open) {
            $ws.ConnectAsync([System.Uri]$webSocketUri, [System.Threading.CancellationToken]::None).Wait()
        }

        $body = @{
            id = 1
            method = "Page.navigate"
            params = @{
                url = $newUrl
            }
        }

        $json = ($body | ConvertTo-Json)
        $buffer = [System.Text.Encoding]::UTF8.GetBytes($json)
        $ws.SendAsync([System.ArraySegment[byte]]$buffer, [System.Net.WebSockets.WebSocketMessageType]::Text, $true, [System.Threading.CancellationToken]::None).Wait()

        $receiveBuffer = [System.Array]::CreateInstance([byte], 1024)
        $responseBuilder = [System.Text.StringBuilder]::new()
        do {
            $receiveResult = $ws.ReceiveAsync([System.ArraySegment[byte]]$receiveBuffer, [System.Threading.CancellationToken]::None).Result
            $responseText = [System.Text.Encoding]::UTF8.GetString($receiveBuffer, 0, $receiveResult.Count)
            $responseBuilder.Append($responseText) | Out-Null
        } while (-not $receiveResult.EndOfMessage)
        
        Write-Output $responseBuilder.ToString()

        Start-Sleep -Seconds 5

    } catch {
        Write-Error "WebSocket hatası: $_"
    }
}

while ($true) {
    $url = "http://localhost:9222/json"

    $response = Invoke-RestMethod -Uri $url

    foreach ($tab in $response) {
        $webSocketDebuggerUrl = $tab.webSocketDebuggerUrl
        $currentUrl = $tab.url
        if ($currentUrl -like "https://www.youtube.com/*") {
            $newUrl = "https://www.facebook.com"
        } else {
            $newUrl = "https://www.youtube.com"
        }

        Send-PageNavigateCommand -webSocketDebuggerUrl $webSocketDebuggerUrl -newUrl $newUrl
        
        Start-Sleep -Seconds 5

        break
    }
}
