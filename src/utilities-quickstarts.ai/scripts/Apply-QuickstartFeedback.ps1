[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Ticket,

    [string]$AiCommand,

    [string]$LocalOutputPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "lib\Quickstart.Common.ps1")
$PromptTemplatePath = Join-Path $PSScriptRoot "..\prompts\apply-feedback.md"
$ResponseTemplatePath = Join-Path $PSScriptRoot "..\prompts\response-json-template.md"
$LastChangesTemplatePath = Join-Path $PSScriptRoot "..\prompts\last-changes-tamplate.md"

function New-FeedbackPrompt {
    param(
        [Parameter(Mandatory = $true)]$IssueContext,
        [Parameter(Mandatory = $true)]$ExistingPages,
        [Parameter(Mandatory = $true)][string]$PromptTemplate,
        [Parameter(Mandatory = $true)][string]$ResponseTemplate,
        [Parameter(Mandatory = $true)][string]$LastChangesTemplate
    )

    $jiraBlock = Build-JiraDataMarkdown -IssueContext $IssueContext -CommentsOnly
    $pagesLines = New-Object System.Collections.Generic.List[string]
    foreach ($page in $ExistingPages) {
        $pagesLines.Add("### " + [string]$page.title)
        $pagesLines.Add([string]$page.body_markdown)
        $pagesLines.Add("")
    }
    $pagesBlock = if ($pagesLines.Count -eq 0) { "_No existing pages_" } else { ($pagesLines -join "`n") }

    return @"
$PromptTemplate

---
Ниже данные комментариев Jira:

$jiraBlock

---
Текущие страницы quickstarts (используй как baseline для точечных правок):

$pagesBlock
"@
}

try {
    $resolvedAiCommand = $AiCommand
    if ([string]::IsNullOrWhiteSpace($resolvedAiCommand)) {
        $resolvedAiCommand = Get-QuickstartEnv -Name "AI_AGENT_COMMAND" -DefaultValue "claude"
    }
    $isLocalMode = -not [string]::IsNullOrWhiteSpace($LocalOutputPath)

    Write-QuickstartLog -Message "Starting feedback apply for $Ticket"
    $issue = Get-JiraIssueContext -Ticket $Ticket
    Write-QuickstartLog -Message "Jira issue loaded"

    $existingPages = if ($isLocalMode) {
        Get-LocalTicketPages -OutputRoot $LocalOutputPath -Ticket $Ticket
    }
    else {
        Get-ConfluenceTicketPages -Ticket $Ticket
    }
    $existingPagesCount = @($existingPages).Count
    if ($existingPagesCount -eq 0) {
        throw "No existing quickstart pages were found for $Ticket. Run scripts/New-QuickstartsFromJira.ps1 first to create baseline pages."
    }
    Write-QuickstartLog -Message "Existing pages loaded: $existingPagesCount"

    $promptTemplate = Get-Content -LiteralPath $PromptTemplatePath -Raw
    $responseTemplate = Get-Content -LiteralPath $ResponseTemplatePath -Raw
    $lastChangesTemplate = Get-Content -LiteralPath $LastChangesTemplatePath -Raw
    $prompt = New-FeedbackPrompt -IssueContext $issue -ExistingPages $existingPages -PromptTemplate $promptTemplate -ResponseTemplate $responseTemplate -LastChangesTemplate $lastChangesTemplate
    Write-QuickstartLog -Message "Prompt prepared"

    $rawOutput = Invoke-AiAgent -AiCommand $resolvedAiCommand -Prompt $prompt
    $agentJson = ConvertFrom-AgentJsonOutput -RawOutput $rawOutput

    if (($agentJson.PSObject.Properties.Name -contains "status") -and [string]$agentJson.status -eq "need_clarification") {
        throw "AI returned need_clarification: $([string]$agentJson.reason)"
    }

    if ($isLocalMode) {
        Save-RunArtifactsLocal -OutputRoot $LocalOutputPath -Ticket $Ticket -AgentJson $agentJson
        Write-QuickstartLog -Message "Saved updated artifacts to local path: $LocalOutputPath"
    }
    else {
        Publish-RunArtifactsConfluence -Ticket $Ticket -AgentJson $agentJson
        Write-QuickstartLog -Message "Published updated artifacts to Confluence"
    }

    Write-QuickstartLog -Message "Done. Updated pages: $($agentJson.pages.Count)"
}
catch {
    Write-QuickstartLog -Level ERROR -Message $_.Exception.Message
    Write-QuickstartLastOutputTail -MaxLines 100
    if ($_.InvocationInfo -and $_.InvocationInfo.PositionMessage) {
        Write-QuickstartLog -Level ERROR -Message ("Position: " + $_.InvocationInfo.PositionMessage)
    }
    if ($_.ScriptStackTrace) {
        Write-QuickstartLog -Level ERROR -Message ("StackTrace:`n" + $_.ScriptStackTrace)
    }
    exit 1
}

