[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Ticket,

    [Parameter(Position = 1)]
    [string]$OutputRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
    $OutputRoot = Join-Path -Path (Get-Location).Path -ChildPath "confluence-export"
}

. (Join-Path $PSScriptRoot "lib\Quickstart.Common.ps1")

$count = Export-ConfluenceTicketPagesToMarkdown -Ticket $Ticket -OutputRoot $OutputRoot
Write-QuickstartLog -Message "Exported $count page(s) under $(Join-Path $OutputRoot $Ticket)"
