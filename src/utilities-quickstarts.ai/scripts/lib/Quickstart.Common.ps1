Set-StrictMode -Version Latest

function Write-QuickstartLog {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        [ValidateSet("INFO", "WARN", "ERROR")]
        [string]$Level = "INFO"
    )

    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    Write-Host "[$timestamp][$Level] $Message"
}

function Get-QuickstartEnv {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [switch]$Required,
        [string]$DefaultValue
    )

    $value = [Environment]::GetEnvironmentVariable($Name, "Process")
    if ([string]::IsNullOrWhiteSpace($value)) {
        $value = [Environment]::GetEnvironmentVariable($Name, "User")
    }
    if ([string]::IsNullOrWhiteSpace($value)) {
        $value = [Environment]::GetEnvironmentVariable($Name, "Machine")
    }
    if ([string]::IsNullOrWhiteSpace($value)) {
        $value = $DefaultValue
    }

    if ($Required -and [string]::IsNullOrWhiteSpace($value)) {
        throw "Environment variable '$Name' is required."
    }

    return $value
}

function Get-AtlassianAuthHeaders {
    $email = Get-QuickstartEnv -Name "ATLASSIAN_EMAIL" -Required
    $token = Get-QuickstartEnv -Name "ATLASSIAN_API_TOKEN" -Required
    $basic = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("$email`:$token"))
    return @{
        Authorization = "Basic $basic"
        Accept        = "application/json"
    }
}

function Get-AtlassianBaseUrl {
    $baseUrl = Get-QuickstartEnv -Name "ATLASSIAN_BASE_URL"
    if (-not [string]::IsNullOrWhiteSpace($baseUrl)) {
        return $baseUrl.TrimEnd("/")
    }

    # Backward compatibility for existing setups.
    $jiraBase = Get-QuickstartEnv -Name "JIRA_BASE_URL"
    if (-not [string]::IsNullOrWhiteSpace($jiraBase)) {
        return $jiraBase.TrimEnd("/")
    }

    $confBase = Get-QuickstartEnv -Name "CONF_BASE_URL"
    if (-not [string]::IsNullOrWhiteSpace($confBase)) {
        return $confBase.TrimEnd("/")
    }

    throw "Environment variable 'ATLASSIAN_BASE_URL' is required."
}

function Get-JiraApiUrl {
    param(
        [Parameter(Mandatory = $true)]
        [string]$PathAndQuery
    )

    $baseUrl = Get-AtlassianBaseUrl
    return "$baseUrl/rest/api/3/$PathAndQuery"
}

function ConvertFrom-JiraAdfNode {
    param([Parameter(Mandatory = $true)]$Node)

    if ($null -eq $Node) {
        return ""
    }

    if ($Node -is [string]) {
        return $Node
    }

    $nodeType = $Node.type
    switch ($nodeType) {
        "text" {
            return [string]$Node.text
        }
        "hardBreak" {
            return "`n"
        }
        "paragraph" {
            $parts = @()
            foreach ($child in ($Node.content | Where-Object { $null -ne $_ })) {
                $parts += (ConvertFrom-JiraAdfNode -Node $child)
            }
            return (($parts -join "") + "`n")
        }
        "heading" {
            $parts = @()
            foreach ($child in ($Node.content | Where-Object { $null -ne $_ })) {
                $parts += (ConvertFrom-JiraAdfNode -Node $child)
            }
            return (($parts -join "") + "`n")
        }
        "bulletList" {
            $lines = @()
            foreach ($item in ($Node.content | Where-Object { $null -ne $_ })) {
                $itemText = ConvertFrom-JiraAdfNode -Node $item
                if (-not [string]::IsNullOrWhiteSpace($itemText)) {
                    $lines += "- $($itemText.Trim())"
                }
            }
            return (($lines -join "`n") + "`n")
        }
        "orderedList" {
            $lines = @()
            $index = 1
            foreach ($item in ($Node.content | Where-Object { $null -ne $_ })) {
                $itemText = ConvertFrom-JiraAdfNode -Node $item
                if (-not [string]::IsNullOrWhiteSpace($itemText)) {
                    $lines += "$index. $($itemText.Trim())"
                    $index++
                }
            }
            return (($lines -join "`n") + "`n")
        }
        "listItem" {
            $parts = @()
            foreach ($child in ($Node.content | Where-Object { $null -ne $_ })) {
                $parts += (ConvertFrom-JiraAdfNode -Node $child).Trim()
            }
            return ($parts -join " ")
        }
        "codeBlock" {
            $parts = @()
            foreach ($child in ($Node.content | Where-Object { $null -ne $_ })) {
                $parts += (ConvertFrom-JiraAdfNode -Node $child)
            }
            $code = ($parts -join "").TrimEnd()
            return ('```text' + "`n" + $code + "`n" + '```')
        }
        default {
            $parts = @()
            foreach ($child in ($Node.content | Where-Object { $null -ne $_ })) {
                $parts += (ConvertFrom-JiraAdfNode -Node $child)
            }
            return ($parts -join "")
        }
    }
}

function ConvertFrom-JiraAdfToText {
    param($Adf)

    if ($null -eq $Adf) {
        return ""
    }

    if ($Adf -is [string]) {
        return $Adf
    }

    $result = ConvertFrom-JiraAdfNode -Node $Adf
    return ($result -replace "(\r?\n){3,}", "`n`n").Trim()
}

function Get-JiraIssueContext {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Ticket
    )

    $headers = Get-AtlassianAuthHeaders
    $query = "issue/${Ticket}?fields=summary,description,comment"
    $url = Get-JiraApiUrl -PathAndQuery $query
    Write-QuickstartLog -Message "Fetching Jira issue $Ticket"

    try {
        $issue = Invoke-RestMethod -Uri $url -Headers $headers -Method Get -TimeoutSec 120
    }
    catch {
        throw "Failed to fetch Jira issue '$Ticket': $($_.Exception.Message)"
    }

    $comments = @()
    foreach ($comment in ($issue.fields.comment.comments | Where-Object { $null -ne $_ })) {
        $comments += [pscustomobject]@{
            author  = [string]$comment.author.displayName
            created = [string]$comment.created
            body    = ConvertFrom-JiraAdfToText -Adf $comment.body
        }
    }

    return [pscustomobject]@{
        key         = [string]$issue.key
        summary     = [string]$issue.fields.summary
        description = ConvertFrom-JiraAdfToText -Adf $issue.fields.description
        comments    = $comments
    }
}

function Get-ConfluenceV2ApiUrl {
    param(
        [Parameter(Mandatory = $true)]
        [string]$PathAndQuery
    )

    $baseUrl = Get-AtlassianBaseUrl
    return "$baseUrl/wiki/api/v2/$PathAndQuery"
}

function Invoke-ConfluenceRequest {
    param(
        [Parameter(Mandatory = $true)][ValidateSet("GET", "POST", "PUT", "DELETE")][string]$Method,
        [Parameter(Mandatory = $true)][string]$PathAndQuery,
        [object]$Body
    )

    $headers = Get-AtlassianAuthHeaders
    $url = Get-ConfluenceV2ApiUrl -PathAndQuery $PathAndQuery

    try {
        if ($null -eq $Body) {
            return Invoke-RestMethod -Uri $url -Headers $headers -Method $Method -TimeoutSec 120
        }

        $jsonBody = $Body | ConvertTo-Json -Depth 20
        return Invoke-RestMethod -Uri $url -Headers $headers -Method $Method -Body $jsonBody -ContentType "application/json" -TimeoutSec 120
    }
    catch {
        throw "Confluence API request failed ($Method $PathAndQuery): $($_.Exception.Message)"
    }
}

function ConvertTo-ConfluenceStorageBody {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Markdown
    )

    $safe = [System.Security.SecurityElement]::Escape($Markdown)
    return "<pre>$safe</pre>"
}

function Get-ConfluenceRootContainer {
    $id = Get-QuickstartEnv -Name "CONF_ROOT_PARENT_ID"
    if ([string]::IsNullOrWhiteSpace($id)) {
        # Backward compatibility with previous config name.
        $id = Get-QuickstartEnv -Name "CONF_ROOT_PARENT_PAGE_ID"
    }
    if ([string]::IsNullOrWhiteSpace($id)) {
        throw "Environment variable 'CONF_ROOT_PARENT_ID' is required."
    }

    $type = (Get-QuickstartEnv -Name "CONF_ROOT_PARENT_TYPE" -DefaultValue "folder").ToLowerInvariant()
    if ($type -ne "folder" -and $type -ne "page") {
        throw "CONF_ROOT_PARENT_TYPE must be 'folder' or 'page'."
    }

    $spaceId = Get-QuickstartEnv -Name "CONF_SPACE_ID"
    if ([string]::IsNullOrWhiteSpace($spaceId)) {
        if ($type -eq "folder") {
            $folder = Invoke-ConfluenceRequest -Method GET -PathAndQuery "folders/$id"
            $spaceId = [string]$folder.spaceId
        }
        else {
            $page = Invoke-ConfluenceRequest -Method GET -PathAndQuery "pages/$id"
            $spaceId = [string]$page.spaceId
        }
    }

    return [pscustomobject]@{
        id      = [string]$id
        type    = [string]$type
        spaceId = [string]$spaceId
    }
}

function Get-ConfluenceDirectChildren {
    param(
        [Parameter(Mandatory = $true)][string]$ParentId,
        [Parameter(Mandatory = $true)][ValidateSet("folder", "page")][string]$ParentType
    )

    $endpointPrefix = if ($ParentType -eq "folder") { "folders" } else { "pages" }
    $cursor = $null
    $all = @()
    do {
        $path = "$endpointPrefix/$ParentId/direct-children?limit=250"
        if (-not [string]::IsNullOrWhiteSpace($cursor)) {
            $path += "&cursor=$([System.Uri]::EscapeDataString($cursor))"
        }

        $chunk = Invoke-ConfluenceRequest -Method GET -PathAndQuery $path
        if ($null -ne $chunk.results) {
            $all += $chunk.results
        }

        $cursor = $null
        $linksProp = $chunk.PSObject.Properties.Match("_links")
        if ($linksProp.Count -gt 0 -and $null -ne $linksProp[0].Value) {
            $links = $linksProp[0].Value
            $nextProp = $links.PSObject.Properties.Match("next")
            if ($nextProp.Count -gt 0 -and -not [string]::IsNullOrWhiteSpace([string]$nextProp[0].Value)) {
                $nextUrl = [string]$nextProp[0].Value
                if ($nextUrl -match "cursor=([^&]+)") {
                    $cursor = [System.Uri]::UnescapeDataString($matches[1])
                }
            }
        }
    } while (-not [string]::IsNullOrWhiteSpace($cursor))

    return $all
}

function Get-ConfluenceChildByTitle {
    param(
        [Parameter(Mandatory = $true)][string]$ParentId,
        [Parameter(Mandatory = $true)][ValidateSet("folder", "page")][string]$ParentType,
        [Parameter(Mandatory = $true)][ValidateSet("folder", "page")][string]$ChildType,
        [Parameter(Mandatory = $true)][string]$Title
    )

    $children = Get-ConfluenceDirectChildren -ParentId $ParentId -ParentType $ParentType
    foreach ($child in $children) {
        if (([string]$child.type).ToLowerInvariant() -eq $ChildType -and [string]$child.title -eq $Title) {
            return $child
        }
    }
    return $null
}

function Get-ConfluencePageById {
    param(
        [Parameter(Mandatory = $true)][string]$PageId
    )

    return Invoke-ConfluenceRequest -Method GET -PathAndQuery "pages/${PageId}?body-format=storage"
}

function New-ConfluenceFolder {
    param(
        [Parameter(Mandatory = $true)][string]$Title,
        [Parameter(Mandatory = $true)][string]$ParentId,
        [Parameter(Mandatory = $true)][string]$SpaceId
    )

    $body = @{
        spaceId  = $SpaceId
        title    = $Title
        parentId = $ParentId
    }

    return Invoke-ConfluenceRequest -Method POST -PathAndQuery "folders" -Body $body
}

function New-ConfluencePage {
    param(
        [Parameter(Mandatory = $true)][string]$Title,
        [Parameter(Mandatory = $true)][string]$ParentId,
        [Parameter(Mandatory = $true)][string]$SpaceId,
        [Parameter(Mandatory = $true)][string]$Markdown
    )

    $storage = ConvertTo-ConfluenceStorageBody -Markdown $Markdown
    $body = @{
        spaceId  = $SpaceId
        status   = "current"
        title    = $Title
        parentId = $ParentId
        body = @{
            representation = "storage"
            value          = $storage
        }
    }

    return Invoke-ConfluenceRequest -Method POST -PathAndQuery "pages" -Body $body
}

function Set-ConfluencePageMarkdown {
    param(
        [Parameter(Mandatory = $true)][string]$PageId,
        [Parameter(Mandatory = $true)][string]$Title,
        [Parameter(Mandatory = $true)][string]$SpaceId,
        [Parameter(Mandatory = $true)][int]$CurrentVersion,
        [Parameter(Mandatory = $true)][string]$Markdown
    )

    $storage = ConvertTo-ConfluenceStorageBody -Markdown $Markdown
    $body = @{
        id      = $PageId
        status  = "current"
        title   = $Title
        spaceId = $SpaceId
        body    = @{
            representation = "storage"
            value          = $storage
        }
        version = @{
            number = ($CurrentVersion + 1)
        }
    }

    return Invoke-ConfluenceRequest -Method PUT -PathAndQuery "pages/$PageId" -Body $body
}

function Ensure-ConfluenceChildPage {
    param(
        [Parameter(Mandatory = $true)][string]$Title,
        [Parameter(Mandatory = $true)][string]$ParentId,
        [Parameter(Mandatory = $true)][ValidateSet("folder", "page")][string]$ParentType,
        [Parameter(Mandatory = $true)][string]$SpaceId,
        [Parameter(Mandatory = $true)][string]$Markdown
    )

    $existing = Get-ConfluenceChildByTitle -ParentId $ParentId -ParentType $ParentType -ChildType "page" -Title $Title
    if ($null -eq $existing) {
        Write-QuickstartLog -Message "Creating Confluence page '$Title'"
        return New-ConfluencePage -Title $Title -ParentId $ParentId -SpaceId $SpaceId -Markdown $Markdown
    }

    Write-QuickstartLog -Message "Updating Confluence page '$Title'"
    $page = Get-ConfluencePageById -PageId ([string]$existing.id)
    return Set-ConfluencePageMarkdown -PageId ([string]$page.id) -Title $Title -SpaceId ([string]$page.spaceId) -CurrentVersion ([int]$page.version.number) -Markdown $Markdown
}

function Get-OrCreateTicketFolderPage {
    param(
        [Parameter(Mandatory = $true)][string]$Ticket,
        [Parameter(Mandatory = $true)]$RootContainer
    )

    $ticketFolder = Get-ConfluenceChildByTitle -ParentId $RootContainer.id -ParentType $RootContainer.type -ChildType "folder" -Title $Ticket
    if ($null -eq $ticketFolder) {
        Write-QuickstartLog -Message "Creating ticket folder '$Ticket'"
        $ticketFolder = New-ConfluenceFolder -Title $Ticket -ParentId $RootContainer.id -SpaceId $RootContainer.spaceId
    }

    return [pscustomobject]@{
        id      = [string]$ticketFolder.id
        type    = "folder"
        spaceId = [string]$RootContainer.spaceId
    }
}

function Get-OrCreateLastChangesPage {
    param(
        [Parameter(Mandatory = $true)]$RootContainer
    )

    $title = Get-QuickstartEnv -Name "CONF_LAST_CHANGES_PAGE_TITLE" -DefaultValue "last changes"
    $page = Get-ConfluenceChildByTitle -ParentId $RootContainer.id -ParentType $RootContainer.type -ChildType "page" -Title $title
    if ($null -eq $page) {
        Write-QuickstartLog -Message "Creating last changes page '$title'"
        $page = New-ConfluencePage -Title $title -ParentId $RootContainer.id -SpaceId $RootContainer.spaceId -Markdown "Auto-generated changelog page."
    }

    return [string]$page.id
}

function ConvertFrom-AgentJsonOutput {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RawOutput
    )

    $candidate = $RawOutput.Trim()
    $preview = (($RawOutput -split "`r?`n") | Select-Object -First 100) -join "`n"
    if ($candidate -match "(?m)^\{""type"":""result""") {
        $lines = $candidate -split "`r?`n"
        $resultPayload = $null
        $assistantPayload = $null
        $streamTextBuilder = New-Object System.Text.StringBuilder
        foreach ($line in $lines) {
            $trim = $line.Trim()
            if ([string]::IsNullOrWhiteSpace($trim)) { continue }
            if (-not $trim.StartsWith("{")) { continue }
            try {
                $eventObj = $trim | ConvertFrom-Json
                if ($eventObj.type -eq "result" -and -not [string]::IsNullOrWhiteSpace([string]$eventObj.result)) {
                    $resultPayload = [string]$eventObj.result
                }
                elseif ($eventObj.type -eq "assistant" -and $null -ne $eventObj.message -and $null -ne $eventObj.message.content) {
                    $parts = @()
                    foreach ($part in $eventObj.message.content) {
                        if ($null -ne $part -and -not [string]::IsNullOrWhiteSpace([string]$part.text)) {
                            $parts += [string]$part.text
                        }
                    }
                    if (($parts | Measure-Object).Count -gt 0) {
                        $assistantPayload = ($parts -join "")
                    }
                }
                elseif ($eventObj.type -eq "stream_event" -and $null -ne $eventObj.event -and $eventObj.event.delta.type -eq "text_delta") {
                    [void]$streamTextBuilder.Append([string]$eventObj.event.delta.text)
                }
            }
            catch {
                # ignore non-json line
            }
        }
        if (-not [string]::IsNullOrWhiteSpace($resultPayload)) {
            $candidate = $resultPayload.Trim()
        }
        elseif (-not [string]::IsNullOrWhiteSpace($assistantPayload)) {
            $candidate = $assistantPayload.Trim()
        }
        elseif ($streamTextBuilder.Length -gt 0) {
            $candidate = $streamTextBuilder.ToString().Trim()
        }
    }
    if ($candidate.StartsWith('```')) {
        $candidate = [regex]::Replace($candidate, '^```[a-zA-Z]*\s*', '', [System.Text.RegularExpressions.RegexOptions]::Singleline)
        $candidate = [regex]::Replace($candidate, '\s*```$', '', [System.Text.RegularExpressions.RegexOptions]::Singleline)
    }

    $obj = $null
    try {
        $obj = $candidate | ConvertFrom-Json
    }
    catch {
        $first = $candidate.IndexOf("{")
        $last = $candidate.LastIndexOf("}")
        if ($first -lt 0 -or $last -lt 0 -or $last -le $first) {
            throw "Agent output does not contain valid JSON object. Output preview (first 100 lines):`n$preview"
        }

        $jsonSlice = $candidate.Substring($first, $last - $first + 1)
        try {
            $obj = $jsonSlice | ConvertFrom-Json
        }
        catch {
            throw "Failed to parse agent JSON output: $($_.Exception.Message)`nOutput preview (first 100 lines):`n$preview"
        }
    }

    if ($null -eq $obj.pages) {
        throw "Agent JSON misses 'pages' property."
    }
    if ($null -eq $obj.last_changes_markdown) {
        throw "Agent JSON misses 'last_changes_markdown' property."
    }

    return $obj
}

function Normalize-AiCommand {
    param([Parameter(Mandatory = $true)][string]$AiCommand)

    $trimmed = $AiCommand.Trim()
    $commandName = $trimmed.Trim('"').ToLowerInvariant()
    if ($commandName -eq "cursor-agent") {
        return "$trimmed -p --output-format stream-json --stream-partial-output --trust"
    }
    if ($commandName -eq "claude") {
        return "$trimmed -p --output-format stream-json --include-partial-messages --verbose"
    }

    return $trimmed
}

function ConvertTo-WindowsCommandLineArgument {
    param([Parameter(Mandatory = $true)][string]$Value)
    $escaped = $Value -replace '(\\*)"', '$1$1\"'
    $escaped = $escaped -replace '(\\+)$', '$1$1'
    return '"' + $escaped + '"'
}

function Parse-CommandExecutableAndArgs {
    param([Parameter(Mandatory = $true)][string]$CommandLine)
    $trimmed = $CommandLine.Trim()
    if ($trimmed -match '^(?:"([^"]+)"|(\S+))(?:\s+(.*))?$') {
        return [pscustomobject]@{
            exe  = if ($matches[1]) { $matches[1] } else { $matches[2] }
            args = if ($matches[3]) { $matches[3] } else { "" }
        }
    }
    throw "Cannot parse AI command: $CommandLine"
}

function Resolve-ExecutablePath {
    param([Parameter(Mandatory = $true)][string]$ExecutableName)

    $cmd = Get-Command $ExecutableName -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($null -ne $cmd) {
        if (-not [string]::IsNullOrWhiteSpace([string]$cmd.Source)) {
            return [string]$cmd.Source
        }
        if (-not [string]::IsNullOrWhiteSpace([string]$cmd.Path)) {
            return [string]$cmd.Path
        }
        return [string]$cmd.Name
    }

    return $ExecutableName
}

function Invoke-AiAgent {
    param(
        [Parameter(Mandatory = $true)][string]$AiCommand,
        [Parameter(Mandatory = $true)][string]$Prompt
    )

    if ([string]::IsNullOrWhiteSpace($AiCommand)) {
        throw "AI command is empty. Pass -AiCommand or set AI_AGENT_COMMAND."
    }

    $resolvedCommand = Normalize-AiCommand -AiCommand $AiCommand
    Write-QuickstartLog -Message "Running AI command: $resolvedCommand"
    $parsed = Parse-CommandExecutableAndArgs -CommandLine $resolvedCommand

    $resolvedExe = Resolve-ExecutablePath -ExecutableName $parsed.exe
    $exeExt = ([IO.Path]::GetExtension($resolvedExe)).ToLowerInvariant()

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    if ($exeExt -eq ".ps1") {
        $psi.FileName = "powershell.exe"
    }
    else {
        $psi.FileName = $resolvedExe
    }
    $psi.UseShellExecute = $false
    $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
    $psi.StandardErrorEncoding = [System.Text.Encoding]::UTF8
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true

    $exeNameLower = ([IO.Path]::GetFileNameWithoutExtension($parsed.exe)).ToLowerInvariant()
    $isCursorAgent = $exeNameLower -eq "cursor-agent"
    $isClaudeAgent = $exeNameLower -eq "claude"
    $isStreamingAgent = $isCursorAgent -or $isClaudeAgent
    $baseArgs = $parsed.args
    if ($exeExt -eq ".ps1") {
        $quotedScript = ConvertTo-WindowsCommandLineArgument -Value $resolvedExe
        $baseArgs = if ([string]::IsNullOrWhiteSpace($baseArgs)) { "-NoProfile -ExecutionPolicy Bypass -File $quotedScript" } else { "-NoProfile -ExecutionPolicy Bypass -File $quotedScript $baseArgs" }
    }

    if ($isStreamingAgent) {
        $promptArg = ConvertTo-WindowsCommandLineArgument -Value $Prompt
        $psi.Arguments = if ([string]::IsNullOrWhiteSpace($baseArgs)) { $promptArg } else { "$baseArgs $promptArg" }
        $psi.RedirectStandardInput = $false
    }
    else {
        $psi.Arguments = $baseArgs
        $psi.RedirectStandardInput = $true
    }

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $psi
    [void]$process.Start()

    $stdErrTask = $process.StandardError.ReadToEndAsync()
    $stdOut = ""

    if ($isStreamingAgent) {
        $outLines = New-Object System.Collections.Generic.List[string]
        $progressEvents = 0
        $lastProgressAt = Get-Date

        while (-not $process.StandardOutput.EndOfStream) {
            $line = $process.StandardOutput.ReadLine()
            if ($null -eq $line) { continue }
            $outLines.Add($line)

            if ($line -match '"type":"assistant"' -or $line -match '"type":"stream_event"' -or $line -match '"type":"result"') {
                $progressEvents++
            }

            $now = Get-Date
            if (($now - $lastProgressAt).TotalSeconds -ge 10) {
                Write-QuickstartLog -Message "AI progress: stream lines=$($outLines.Count), events=$progressEvents"
                $lastProgressAt = $now
            }
        }

        $process.WaitForExit()
        $stdOut = ($outLines -join "`n")
    }
    else {
        $process.StandardInput.WriteLine($Prompt)
        $process.StandardInput.Close()

        while (-not $process.WaitForExit(10000)) {
            Write-QuickstartLog -Message "AI progress: command is still running..."
        }
        $stdOut = $process.StandardOutput.ReadToEnd()
    }

    $stdErr = $stdErrTask.Result

    if ($process.ExitCode -ne 0) {
        throw "AI command failed with exit code $($process.ExitCode): $stdErr"
    }

    if (-not [string]::IsNullOrWhiteSpace($stdErr)) {
        Write-QuickstartLog -Message "AI command stderr: $stdErr" -Level WARN
    }

    return $stdOut
}

function Build-JiraDataMarkdown {
    param(
        [Parameter(Mandatory = $true)]$IssueContext,
        [switch]$CommentsOnly
    )

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add("## Jira data")
    $lines.Add("")
    $lines.Add("- Ticket: $($IssueContext.key)")

    if (-not $CommentsOnly) {
        $lines.Add("- Summary: $($IssueContext.summary)")
        $lines.Add("")
        $lines.Add("### Description")
        $lines.Add($IssueContext.description)
        $lines.Add("")
    }

    $lines.Add("### Comments")
    if (($IssueContext.comments | Measure-Object).Count -eq 0) {
        $lines.Add("_No comments_")
    }
    else {
        foreach ($comment in $IssueContext.comments) {
            $lines.Add("- [$($comment.created)] $($comment.author):")
            $lines.Add("  $($comment.body -replace "`n", "`n  ")")
        }
    }

    return ($lines -join "`n")
}

function Save-RunArtifactsLocal {
    param(
        [Parameter(Mandatory = $true)][string]$OutputRoot,
        [Parameter(Mandatory = $true)][string]$Ticket,
        [Parameter(Mandatory = $true)]$AgentJson
    )

    $ticketPath = Join-Path $OutputRoot $Ticket
    if (-not (Test-Path -LiteralPath $ticketPath)) {
        New-Item -Path $ticketPath -ItemType Directory -Force | Out-Null
    }

    foreach ($page in $AgentJson.pages) {
        $safeName = ($page.title -replace '[\\/:*?"<>|]', "_")
        $path = Join-Path $ticketPath "$safeName.md"
        Set-Content -LiteralPath $path -Value $page.body_markdown -Encoding UTF8
    }

    Set-Content -LiteralPath (Join-Path $OutputRoot "last-changes.md") -Value $AgentJson.last_changes_markdown -Encoding UTF8
    Set-Content -LiteralPath (Join-Path $ticketPath "agent-response.json") -Value ($AgentJson | ConvertTo-Json -Depth 50) -Encoding UTF8
}

function Publish-RunArtifactsConfluence {
    param(
        [Parameter(Mandatory = $true)][string]$Ticket,
        [Parameter(Mandatory = $true)]$AgentJson
    )

    $root = Get-ConfluenceRootContainer
    $ticketFolder = Get-OrCreateTicketFolderPage -Ticket $Ticket -RootContainer $root
    foreach ($page in $AgentJson.pages) {
        Ensure-ConfluenceChildPage -Title ([string]$page.title) -ParentId $ticketFolder.id -ParentType $ticketFolder.type -SpaceId $ticketFolder.spaceId -Markdown ([string]$page.body_markdown) | Out-Null
    }

    $lastChangesId = Get-OrCreateLastChangesPage -RootContainer $root
    $lastChangesPage = Get-ConfluencePageById -PageId $lastChangesId
    Set-ConfluencePageMarkdown -PageId $lastChangesId -Title ([string]$lastChangesPage.title) -SpaceId ([string]$lastChangesPage.spaceId) -CurrentVersion ([int]$lastChangesPage.version.number) -Markdown ([string]$AgentJson.last_changes_markdown) | Out-Null
}

function Get-ConfluenceTicketPages {
    param(
        [Parameter(Mandatory = $true)][string]$Ticket
    )

    $root = Get-ConfluenceRootContainer
    $ticketFolder = Get-OrCreateTicketFolderPage -Ticket $Ticket -RootContainer $root
    $result = Get-ConfluenceDirectChildren -ParentId $ticketFolder.id -ParentType $ticketFolder.type
    $pages = @()

    foreach ($item in ($result | Where-Object { $null -ne $_ -and [string]$_.type -eq "page" })) {
        $full = Get-ConfluencePageById -PageId ([string]$item.id)
        $body = [string]$full.body.storage.value
        $plain = [regex]::Replace($body, "<[^>]+>", "")
        $decoded = [System.Net.WebUtility]::HtmlDecode($plain)
        $pages += [pscustomobject]@{
            title         = [string]$full.title
            body_markdown = $decoded.Trim()
        }
    }

    return $pages
}

function Get-LocalTicketPages {
    param(
        [Parameter(Mandatory = $true)][string]$OutputRoot,
        [Parameter(Mandatory = $true)][string]$Ticket
    )

    $ticketPath = Join-Path $OutputRoot $Ticket
    if (-not (Test-Path -LiteralPath $ticketPath)) {
        return @()
    }

    $pages = @()
    foreach ($file in Get-ChildItem -LiteralPath $ticketPath -Filter "*.md" -File) {
        if ($file.Name -eq "last-changes.md") {
            continue
        }

        $pages += [pscustomobject]@{
            title         = [IO.Path]::GetFileNameWithoutExtension($file.Name)
            body_markdown = (Get-Content -LiteralPath $file.FullName -Raw)
        }
    }

    return $pages
}

