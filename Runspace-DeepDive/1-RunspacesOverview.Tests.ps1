Describe "Runspace Overview" {
    It "Runs ForEach-Object sequentially" {
        1..10 | ForEach-Object {
            Write-Host "Starting $_"
            Start-Sleep -Seconds (Get-Random -Minimum 1 -Maximum 4)
            Write-Host "Finished $_"
        }
    }

    It "Runs ForEach-Object in parallel" {
        1..10 | ForEach-Object -Parallel {
            Write-Host "Starting $_"
            Start-Sleep -Seconds (Get-Random -Minimum 1 -Maximum 4)
            Write-Host "Finished $_"
        }
    }

    It "Runs Start-ThreadJob tasks in parallel" {
        1..10 | ForEach-Object {
            Start-ThreadJob -ScriptBlock {
                param($i)
                Write-Host "Starting $i"
                Start-Sleep -Seconds (Get-Random -Minimum 1 -Maximum 4)
                Write-Host "Finished $i"
            } -ArgumentList $_ -StreamingHost $host
        } | Wait-Job
    }

    It "Runs Start-Job tasks in parallel" {
        # This is like Start-ThreadJob but less efficient as each job runs as
        # a separate process.
        1..10 | ForEach-Object {
            Start-Job -ScriptBlock {
                param($i)
                "Starting $i"
                Start-Sleep -Seconds (Get-Random -Minimum 1 -Maximum 4)
                "Finished $i"
            } -ArgumentList $_
        } | Receive-Job -Wait -AutoRemoveJob
    }

    It "Runs Invoke-Command tasks in parallel" {
        $serverList = 1..10 | ForEach-Object { 'localhost' }
        Invoke-Command -HostName $serverList {
            Write-Host "Starting"
            Start-Sleep -Seconds (Get-Random -Minimum 1 -Maximum 4)
            Write-Host "Finished"
        }
    }

    It "Runs Invoke-Command tasks sequentially" {
        $serverList = 1..10 | ForEach-Object { 'localhost' }
        $serverList | ForEach-Object {
            Invoke-Command -HostName $_ {
                Write-Host "Starting"
                Start-Sleep -Seconds (Get-Random -Minimum 1 -Maximum 4)
                Write-Host "Finished"
            }
        }
    }
}
