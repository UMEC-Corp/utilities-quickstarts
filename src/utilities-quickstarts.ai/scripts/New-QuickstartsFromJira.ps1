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
$PromptTemplatePath = Join-Path $PSScriptRoot "..\prompts\create-quickstart.md"
$ResponseTemplatePath = Join-Path $PSScriptRoot "..\prompts\response-json-template.md"
$LastChangesTemplatePath = Join-Path $PSScriptRoot "..\prompts\last-changes-tamplate.md"

function New-GeneratePrompt {
    param(
        [Parameter(Mandatory = $true)]$IssueContext,
        [Parameter(Mandatory = $true)][string]$PromptTemplate,
        [Parameter(Mandatory = $true)][string]$ResponseTemplate,
        [Parameter(Mandatory = $true)][string]$LastChangesTemplate
    )

    $jiraBlock = Build-JiraDataMarkdown -IssueContext $IssueContext
    return @"
$PromptTemplate

---
Ниже фактические данные Jira для обработки:

$jiraBlock
"@
}

try {
    $resolvedAiCommand = $AiCommand
    if ([string]::IsNullOrWhiteSpace($resolvedAiCommand)) {
        $resolvedAiCommand = Get-QuickstartEnv -Name "AI_AGENT_COMMAND" -DefaultValue "claude"
    }
    $isLocalMode = -not [string]::IsNullOrWhiteSpace($LocalOutputPath)

    Write-QuickstartLog -Message "Starting generation for $Ticket"
    $issue = Get-JiraIssueContext -Ticket $Ticket

    $promptTemplate = Get-Content -LiteralPath $PromptTemplatePath -Raw
    $responseTemplate = Get-Content -LiteralPath $ResponseTemplatePath -Raw
    $lastChangesTemplate = Get-Content -LiteralPath $LastChangesTemplatePath -Raw
    $prompt = New-GeneratePrompt -IssueContext $issue -PromptTemplate $promptTemplate -ResponseTemplate $responseTemplate -LastChangesTemplate $lastChangesTemplate

    $rawOutput = Invoke-AiAgent -AiCommand $resolvedAiCommand -Prompt $prompt
    $agentJson = ConvertFrom-AgentJsonOutput -RawOutput $rawOutput

    if (($agentJson.PSObject.Properties.Name -contains "status") -and [string]$agentJson.status -eq "need_clarification") {
        throw "AI returned need_clarification: $([string]$agentJson.reason)"
    }

    if ($isLocalMode) {
        Save-RunArtifactsLocal -OutputRoot $LocalOutputPath -Ticket $Ticket -AgentJson $agentJson
        Write-QuickstartLog -Message "Saved artifacts to local path: $LocalOutputPath"
    }
    else {
        Publish-RunArtifactsConfluence -Ticket $Ticket -AgentJson $agentJson
        Write-QuickstartLog -Message "Published artifacts to Confluence"
    }

    Write-QuickstartLog -Message "Done. Pages: $($agentJson.pages.Count)"
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

