param(
    [Parameter(Mandatory)]
    [ValidateSet('Web', 'App', 'Schema', 'Verify')]
    [string] $Check,

    [string] $FeedbackMarker,
    [string] $Profile = 'guvi-project01',
    [string] $Region = 'ap-south-1'
)

$ErrorActionPreference = 'Stop'
$awsOptions = @('--profile', $Profile, '--region', $Region, '--no-cli-pager')
$tier = if ($Check -eq 'Web') { 'web' } else { 'app' }
$instances = @(aws ec2 describe-instances @awsOptions --filters 'Name=tag:Project,Values=guvi-project01' "Name=tag:Tier,Values=$tier" 'Name=instance-state-name,Values=running' --query 'Reservations[].Instances[].InstanceId' --output json | ConvertFrom-Json)
if ($LASTEXITCODE -ne 0 -or $instances.Count -eq 0) {
    throw "No running $tier project instance was found."
}

$commands = @('set -eu', 'cloud-init status --wait')
switch ($Check) {
    Web {
        $commands += @(
            'nginx -t 2>&1',
            'systemctl is-active nginx',
            'grep -E "location /api/|proxy_pass" /etc/nginx/nginx.conf',
            'curl -fsS http://localhost/api/; printf "\n"'
        )
    }
    App {
        $commands += @(
            'python3 --version',
            'systemctl is-active feedback',
            'curl -fsS http://localhost:5000/; printf "\n"'
        )
    }
    Schema {
        $commands += @(
            'set -a; . /opt/feedback/feedback.env',
            '/opt/feedback/venv/bin/python /opt/feedback/database.py initialize'
        )
    }
    Verify {
        if ($FeedbackMarker -notmatch '^[a-zA-Z0-9-]{1,80}$') {
            throw 'Specify a feedback marker containing letters, digits or hyphens.'
        }
        $commands += @(
            'set -a; . /opt/feedback/feedback.env',
            "/opt/feedback/venv/bin/python /opt/feedback/database.py verify '$FeedbackMarker'"
        )
    }
}

$instance = $null
foreach ($candidate in $instances) {
    $online = aws ssm describe-instance-information @awsOptions --filters "Key=InstanceIds,Values=$candidate" --query 'InstanceInformationList[0].PingStatus' --output text
    if ($LASTEXITCODE -ne 0) {
        throw 'Could not query Systems Manager instance status.'
    }
    if ($online -eq 'Online') {
        $instance = $candidate
        break
    }
}
if (-not $instance) {
    throw "Systems Manager has not registered a running $tier instance yet."
}

$inputPath = [IO.Path]::GetTempFileName()
try {
    @{
        DocumentName = 'AWS-RunShellScript'
        InstanceIds = @($instance)
        Comment = "Project 01 $Check evidence"
        Parameters = @{ commands = $commands }
    } | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $inputPath -Encoding utf8NoBOM
    $commandId = aws ssm send-command @awsOptions --cli-input-json "file://$inputPath" --query 'Command.CommandId' --output text
    if ($LASTEXITCODE -ne 0) {
        throw 'Could not send the Systems Manager command.'
    }
} finally {
    Remove-Item -LiteralPath $inputPath
}

Write-Host "Systems Manager command $commandId on $instance"
aws ssm wait command-executed @awsOptions --command-id $commandId --instance-id $instance 2>$null
$invocation = aws ssm get-command-invocation @awsOptions --command-id $commandId --instance-id $instance --output json | ConvertFrom-Json
if ($LASTEXITCODE -ne 0) {
    throw 'Could not retrieve the Systems Manager command result.'
}
$invocation | Select-Object CommandId, InstanceId, Status, StandardOutputContent, StandardErrorContent | ConvertTo-Json
if ($invocation.Status -ne 'Success') {
    throw "The $Check check ended with status $($invocation.Status)."
}
