$script:InternalValue = 'default'

Function Get-ModuleValue {
    [OutputType([string])]
    [CmdletBinding()]
    param ()

    $script:InternalValue
}

Function Set-ModuleValue {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Value
    )

    $script:InternalValue = $Value
}

Export-ModuleMember -Function Get-ModuleValue, Set-ModuleValue
