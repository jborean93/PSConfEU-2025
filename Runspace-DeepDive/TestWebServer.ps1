using namespace System.Net

[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [int]
    $Port
)

$http = [HttpListener]::new()
$http.Prefixes.Add("http://localhost:$Port/")
$http.Start()

while ($http.IsListening) {
    try {
        $context = $http.GetContext()
    }
    catch [HttpListenerException] {
        if (-not $http.IsListening) {
            break
        }

        throw
    }

    Start-ThreadJob -ScriptBlock {
        param ($http, $context)

        if ($context.Request.HttpMethod -ne 'GET') {
            $context.Response.StatusCode = 405
            $context.Response.OutputStream.Close()
            continue
        }

        if ($context.Request.RawUrl -eq '/shutdown') {
            $context.Response.StatusCode = 200
            $context.Response.OutputStream.Close()
            $http.Stop()
        }
        elseif ($context.Request.RawUrl -eq '/') {
            $context.Response.StatusCode = 200
            $context.Response.OutputStream.Close()
        }
        elseif ($context.Request.RawUrl -match '\/delay=(\d+)') {
            $delay = [int]$matches[1]
            Start-Sleep -Seconds $delay

            $respJson = @{
                delay = $delay
            } | ConvertTo-Json -Compress
            $resp = [System.Text.Encoding]::UTF8.GetBytes($respJson)
            $context.Response.ContextLength64 = $resp.Length
            $context.Response.OutputStream.Write($resp, 0, $resp.Length)
            $context.Response.OutputStream.Close()
        }
        else {
            $context.Response.StatusCode = 404
            $context.Response.OutputStream.Close()
        }
    } -ArgumentList $http, $context | Out-Null
}
