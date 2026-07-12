param(
    [Parameter(Mandatory = $true)]
    [string] $SubscriptionId,

    [Parameter(Mandatory = $true)]
    [string] $SourceResourceGroup,

    [Parameter(Mandatory = $true)]
    [string] $SourceVmName,

    [Parameter(Mandatory = $true)]
    [string] $TargetResourceGroup,

    [Parameter(Mandatory = $false)]
    [string] $TargetRegion = "japaneast",

    [Parameter(Mandatory = $false)]
    [int] $RetentionDays = 7,

    [Parameter(Mandatory = $false)]
    [bool] $WaitForCopy = $true,

    [Parameter(Mandatory = $false)]
    [int] $CopyTimeoutMinutes = 150
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

function Connect-AutomationIdentity {
    Disable-AzContextAutosave -Scope Process | Out-Null
    $context = (Connect-AzAccount -Identity).Context
    Set-AzContext -SubscriptionId $SubscriptionId -DefaultProfile $context | Out-Null
}

function Invoke-GuestScript {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Script
    )

    Write-Output "Running command on $SourceVmName"
    $result = Invoke-AzVMRunCommand `
        -ResourceGroupName $SourceResourceGroup `
        -VMName $SourceVmName `
        -CommandId "RunShellScript" `
        -ScriptString $Script

    foreach ($message in $result.Value) {
        if ($message.Message) {
            Write-Output $message.Message
        }
    }
}

function New-IncrementalSourceSnapshot {
    param(
        [Parameter(Mandatory = $true)]
        [string] $DiskResourceId,

        [Parameter(Mandatory = $true)]
        [string] $DiskRole,

        [Parameter(Mandatory = $true)]
        [string] $RecoverySet,

        [Parameter(Mandatory = $true)]
        [string] $SourceLocation
    )

    $safeRole = $DiskRole.ToLower().Replace("_", "-")
    $name = "snap-$($SourceVmName.ToLower())-$safeRole-$RecoverySet-krc"

    $tags = @{
        ManagedBy  = "SnapshotDRDemo"
        SourceVM   = $SourceVmName
        DiskRole   = $DiskRole
        RecoverySet = $RecoverySet
        CopyStage  = "Source"
    }

    Write-Output "Creating source snapshot $name from $DiskResourceId"

    $config = New-AzSnapshotConfig `
        -SourceUri $DiskResourceId `
        -Location $SourceLocation `
        -CreateOption Copy `
        -Incremental `
        -SkuName Standard_LRS `
        -Tag $tags

    return New-AzSnapshot `
        -ResourceGroupName $SourceResourceGroup `
        -SnapshotName $name `
        -Snapshot $config
}

function New-TargetSnapshotCopy {
    param(
        [Parameter(Mandatory = $true)]
        $SourceSnapshot,

        [Parameter(Mandatory = $true)]
        [string] $DiskRole,

        [Parameter(Mandatory = $true)]
        [string] $RecoverySet
    )

    $safeRole = $DiskRole.ToLower().Replace("_", "-")
    $name = "snap-$($SourceVmName.ToLower())-$safeRole-$RecoverySet-jpe"

    $tags = @{
        ManagedBy   = "SnapshotDRDemo"
        SourceVM    = $SourceVmName
        DiskRole    = $DiskRole
        RecoverySet = $RecoverySet
        CopyStage   = "Target"
    }

    Write-Output "Starting target CopyStart snapshot $name"

    $config = New-AzSnapshotConfig `
        -Location $TargetRegion `
        -CreateOption CopyStart `
        -Incremental `
        -SourceResourceId $SourceSnapshot.Id `
        -SkuName Standard_LRS `
        -Tag $tags

    return New-AzSnapshot `
        -ResourceGroupName $TargetResourceGroup `
        -SnapshotName $name `
        -Snapshot $config
}

function Wait-TargetSnapshot {
    param(
        [Parameter(Mandatory = $true)]
        [string] $SnapshotName
    )

    $deadline = (Get-Date).AddMinutes($CopyTimeoutMinutes)

    while ((Get-Date) -lt $deadline) {
        $snapshot = Get-AzSnapshot `
            -ResourceGroupName $TargetResourceGroup `
            -SnapshotName $SnapshotName

        $completion = $snapshot.CompletionPercent
        $state = $snapshot.ProvisioningState

        Write-Output "$SnapshotName state=$state completion=$completion"

        if ($completion -eq 100 -and $state -eq "Succeeded") {
            return
        }

        if ($state -eq "Failed") {
            throw "Snapshot copy failed: $SnapshotName"
        }

        Start-Sleep -Seconds 30
    }

    throw "Snapshot copy timed out after $CopyTimeoutMinutes minutes: $SnapshotName"
}


function Assert-NoTargetCopyInProgress {
    $inProgress = Get-AzSnapshot -ResourceGroupName $TargetResourceGroup |
        Where-Object {
            $_.Tags["ManagedBy"] -eq "SnapshotDRDemo" -and
            $_.Tags["SourceVM"] -eq $SourceVmName -and
            $_.Tags["CopyStage"] -eq "Target" -and
            ($_.ProvisioningState -ne "Succeeded" -or
             ($null -ne $_.CompletionPercent -and $_.CompletionPercent -lt 100))
        }

    if ($inProgress) {
        $names = ($inProgress | Select-Object -ExpandProperty Name) -join ", "
        throw "A previous target snapshot copy is still in progress: $names"
    }
}

function Remove-ExpiredSnapshots {
    $cutoff = (Get-Date).ToUniversalTime().AddDays(-1 * $RetentionDays)

    foreach ($resourceGroup in @($SourceResourceGroup, $TargetResourceGroup)) {
        $snapshots = Get-AzSnapshot -ResourceGroupName $resourceGroup |
            Where-Object {
                $_.Tags["ManagedBy"] -eq "SnapshotDRDemo" -and
                $_.Tags["SourceVM"] -eq $SourceVmName
            }

        foreach ($snapshot in $snapshots) {
            $created = $snapshot.TimeCreated.ToUniversalTime()

            if ($created -lt $cutoff) {
                Write-Output "Deleting expired snapshot $($snapshot.Name) created $created"
                Remove-AzSnapshot `
                    -ResourceGroupName $resourceGroup `
                    -SnapshotName $snapshot.Name `
                    -Force
            }
        }
    }
}

Connect-AutomationIdentity
Assert-NoTargetCopyInProgress

$vm = Get-AzVM -ResourceGroupName $SourceResourceGroup -Name $SourceVmName
$recoverySet = (Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmssZ")

$diskItems = @(
    [pscustomobject]@{
        ResourceId = $vm.StorageProfile.OsDisk.ManagedDisk.Id
        Role       = "OS"
    }
)

foreach ($dataDisk in ($vm.StorageProfile.DataDisks | Sort-Object Lun)) {
    $diskItems += [pscustomobject]@{
        ResourceId = $dataDisk.ManagedDisk.Id
        Role       = "DATA-LUN-$($dataDisk.Lun)"
    }
}

$sourceSnapshots = @()

try {
    Invoke-GuestScript -Script "sudo /usr/local/sbin/dr-stop-services.sh"

    foreach ($diskItem in $diskItems) {
        $sourceSnapshots += [pscustomobject]@{
            Role = $diskItem.Role
            Snapshot = New-IncrementalSourceSnapshot `
                -DiskResourceId $diskItem.ResourceId `
                -DiskRole $diskItem.Role `
                -RecoverySet $recoverySet `
                -SourceLocation $vm.Location
        }
    }
}
finally {
    try {
        Invoke-GuestScript -Script "sudo /usr/local/sbin/dr-start-services.sh"
    }
    catch {
        Write-Warning "Source service restart failed. Manual action is required: $($_.Exception.Message)"
    }
}

$targetSnapshots = @()

foreach ($item in $sourceSnapshots) {
    $targetSnapshots += New-TargetSnapshotCopy `
        -SourceSnapshot $item.Snapshot `
        -DiskRole $item.Role `
        -RecoverySet $recoverySet
}

if ($WaitForCopy) {
    foreach ($targetSnapshot in $targetSnapshots) {
        Wait-TargetSnapshot -SnapshotName $targetSnapshot.Name
    }
}

Remove-ExpiredSnapshots

Write-Output "RecoverySet=$recoverySet"
Write-Output "Target snapshots:"
$targetSnapshots | ForEach-Object {
    Write-Output " - $($_.Name)"
}
