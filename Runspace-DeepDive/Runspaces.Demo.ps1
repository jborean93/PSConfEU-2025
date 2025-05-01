# Slide 1 - ForEach-Object vs ForEach-Object -Parallel vs Start-ThreadJob
# Find a potential way to split this into multiple panes and start at the same time
# May not be possible without a dedicated extension.

Measure-Command {
    1..10 | ForEach-Object {
        Write-Host "Starting $_"
        Start-Sleep -Seconds (Get-Random -Minimum 1 -Maximum 4)
        Write-Host "Finished $_"
    }
} | Select-Object -ExpandProperty TotalSeconds

Measure-Command {
    1..10 | ForEach-Object -Parallel {
        Write-Host "Starting $_"
        Start-Sleep -Seconds (Get-Random -Minimum 1 -Maximum 4)
        Write-Host "Finished $_"
    }
} | Select-Object -ExpandProperty TotalSeconds

Measure-Command {
    1..10 | ForEach-Object {
        Start-ThreadJob -ScriptBlock {
            param($i)
            Write-Host "Starting $i"
            Start-Sleep -Seconds (Get-Random -Minimum 1 -Maximum 4)
            Write-Host "Finished $i"
        } -ArgumentList $_ -StreamingHost $host
    } | Wait-Job
} | Select-Object -ExpandProperty TotalSeconds

# Slide 2 - Remote Runspaces - Start-Job/Invoke-Command
1..10 | ForEach-Object {
    Start-Job -ScriptBlock {
        param($i)
        "Starting $i"
        Start-Sleep -Seconds (Get-Random -Minimum 1 -Maximum 4)
        "Finished $i"
    } -ArgumentList $_
} | Receive-Job -Wait -AutoRemoveJob

$serverList = 1..10 | ForEach-Object { 'localhost' }
Invoke-Command -HostName $serverList {
    Write-Host "Starting"
    Start-Sleep -Seconds (Get-Random -Minimum 1 -Maximum 4)
    Write-Host "Finished"
}

$serverList | ForEach-Object {
    Invoke-Command -HostName $_ {
        Write-Host "Starting"
        Start-Sleep -Seconds (Get-Random -Minimum 1 -Maximum 4)
        Write-Host "Finished"
    }
}

# Slide 3* - Runspace Dos and Don'ts
# Is it worth the runspace overhead - can I illustrate CPU vs IO bound activities easily?
Measure-Command {
    1..50 | ForEach-Object { $_ }
} | Select-Object -ExpandProperty TotalSeconds

Measure-Command {
    1..50 | ForEach-Object -Parallel { $_ }
} | Select-Object -ExpandProperty TotalSeconds

# The order is non-deterministic - run multiple times and the output order will change
1..5 | ForEach-Object -Parallel {
    Start-Sleep -Seconds (Get-Random -Minimum 1 -Maximum 4)
    $_
}

# No shared module state - some modules won't work in parallel
# Is there something builtin to test this locally?

# Lack of trouble shooting - no easy debugging
# Move to separate file and add breakpoint to $res
1..5 | ForEach-Object {
    $res = '1' + $_

    $res
}

1..5 | ForEach-Object -Parallel {
    $res = '1' + $_

    $res
}

# If you integrate using you need to rewrite it so it works normally outside of -Parallel
# Works
$var = 'test'
1 | ForEach-Object -Parallel {
    $a = $using:var

    "$a - $_"
}

# Fails as $using: is not valid in normal circumstances
$var = 'test'
1 | ForEach-Object {
    $a = $using:var

    "$a - $_"
}

# Race conditions
# Run this enough times and you will see missing or empty lines
Remove-Item test.txt -ErrorAction Ignore
1..10 | ForEach-Object -Parallel {
    Add-Content "Testing value $_" -Path test.txt
}
Get-Content test.txt

$state = @{}
1..10 | ForEach-Object -Parallel {
    $state = $using:state
    $state[$_] = 'value'
}
$state

# .NET Tasks as an alternative - no runspace overhead
$http = [System.Net.Http.HttpClient]::new()

# Single task run synchronously
$getTask = $http.GetStringAsync('https://httpbin.org/base64/dGVzdCByZXN1bHQ=')
while (-not $getTask.AsyncWaitHandle.WaitOne(200)) {}
$getTask.GetAwaiter().GetResult()

# New feature in pwsh 7.6 makes this easier to use - $PSCmdlet.PipelineStopToken
# Removes the need for the AsyncWaitHandle.WaitOne loop
& {
    [CmdletBinding()]
    param ()

    $http = [System.Net.Http.HttpClient]::new()
    $http.GetStringAsync(
        'https://httpbin.org/delay/5',
        $PSCmdlet.PipelineStopToken).GetAwaiter().GetResult()
}

# Can run multiple tasks in parallel and wait for them to complete
$tasks = [System.Threading.Tasks.Task[]]@(
    $http.GetStringAsync('https://httpbin.org/base64/UmVzdWx0IDE=')
    $http.GetStringAsync('https://httpbin.org/base64/UmVzdWx0IDI=')
    $http.GetStringAsync('https://httpbin.org/base64/UmVzdWx0IDM=')
)
$waitTask = [System.Threading.Tasks.Task]::WhenAll($tasks)
while (-not $waitTask.AsyncWaitHandle.WaitOne(200)) {}
$null = $waitTask.GetAwaiter().GetResult()

$tasks[0].GetAwaiter().GetResult()
$tasks[1].GetAwaiter().GetResult()
$tasks[2].GetAwaiter().GetResult()

# Can also job-ify the tasks using 3rd party module TaskJob
Import-Module -Name TaskJob
@(
    $http.GetStringAsync('https://httpbin.org/base64/UmVzdWx0IDE=')
    $http.GetStringAsync('https://httpbin.org/base64/UmVzdWx0IDI=')
    $http.GetStringAsync('https://httpbin.org/base64/UmVzdWx0IDM=')
) | ConvertTo-TaskJob | Receive-Job -Wait
