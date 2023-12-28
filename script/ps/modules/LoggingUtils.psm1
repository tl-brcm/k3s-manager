# LoggingUtils.psm1

function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [Script] $Message" -ForegroundColor Cyan
}

Export-ModuleMember -Function Write-Log
