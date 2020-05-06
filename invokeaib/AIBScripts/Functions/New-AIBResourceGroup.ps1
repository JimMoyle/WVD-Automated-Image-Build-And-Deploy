function New-AIBResourceGroup {
    [CmdletBinding()]

    Param (

        [Parameter(
            Position = 0,
            ValuefromPipelineByPropertyName = $true,
            ValuefromPipeline = $true,
            Mandatory = $true
        )]
        [System.String]$Name,

        [Parameter(
            Position = 1,
            ValuefromPipelineByPropertyName = $true,
            ValuefromPipeline = $true,
            Mandatory = $true
        )]
        [System.String]$Location,

        [Parameter(
            ValuefromPipelineByPropertyName = $true
        )]
        [System.String]$AzureImageBuilderAppID = "cf32a0cc-373c-47c9-9156-0db11f6a6dfc",

        [Parameter(
            ValuefromPipelineByPropertyName = $true
        )]
        [System.String]$TenantID,

        [Parameter(
            ValuefromPipelineByPropertyName = $true
        )]
        [System.String]$SubscriptionID,

        [Parameter(
            ValuefromPipelineByPropertyName = $true
        )]
        [System.String]$identityNamePrefix = "aibIdentity"


    )

    BEGIN {
        Set-StrictMode -Version Latest
        Write-Information 'Starting New-AIBReesourceGroup'
    } # Begin
    PROCESS {

        if (-not (Get-AzResourceGroup -Name $Name -ErrorAction SilentlyContinue)) {
            # Create a resource group to store the image configuration template artifact and the image
            try {
                New-AzResourceGroup -Name $Name -Location $Location -Force -ErrorAction Stop | Out-Null
                Write-Information "Created Resource Group $Name"
            }
            catch {
                Write-Error "Failed to create Resource Group $Name"
            }
        }
        else {
            Write-Information "Resource Group $Name already present, skipping creation"
        }

        $userIdentity = Get-AzUserAssignedIdentity -ResourceGroupName $Name -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name
        $userCount = $userIdentity -like "$identityNamePrefix*" | Measure-Object | Select-Object -ExpandProperty Count

        if ($userCount -eq 0) {
            $timeInt = $(get-date -UFormat "%s")
            $identityName = $identityNamePrefix + $timeInt
            New-AzUserAssignedIdentity -ResourceGroupName $Name -Name $identityName | Out-Null

            $assignedIdentity = Get-AzUserAssignedIdentity -ResourceGroupName $Name -Name $identityName

        }
        else {
            $assignedIdentity = Get-AzUserAssignedIdentity -ResourceGroupName $Name -Name $userIdentity
            Write-Information "User Identity $Name already present, skipping creation"
        }

        $roleAssign = Get-AzRoleAssignment -ResourceGroupName $Name -ErrorAction SilentlyContinue | Select-Object -ExpandProperty DisplayName
        Write-Information "Role Assign is $roleAssign"
        $roleCount = $roleAssign -like "$identityNamePrefix*" | Measure-Object | Select-Object -ExpandProperty Count

        Write-Information "Role Count is $roleCount"

        if ($roleCount -lt 1) {

            Write-Information "Principle ID is $($assignedIdentity.PrincipalId)"

            $paramNewAzRoleAssignment = @{
                ErrorAction        = 'Stop'
                ObjectId           = $assignedIdentity.PrincipalId
                Scope              = "/subscriptions/$subscriptionID/resourceGroups/$Name"
                RoleDefinitionName = 'Contributor'
            }

            #Wait for Role to be ready
            $i = 0
            $status = $false
            while ($i -le 12 -and $status -eq $false) {
                Start-Sleep 5
                try {
                    New-AzRoleAssignment @paramNewAzRoleAssignment | Out-Null
                    $status = $true
                }
                catch {
                    $status = $false
                }
                $i++
            }

            if ($status -eq $false) {
                Write-Warning "Failed to maybe assign Contributor role to Resource Group"
            }
            else {
                $timeElapsed = "Role assigned after {0} seconds" -f ($i * 5)
                Write-Information $timeElapsed
            }
        }
        else {
            Write-Information "Role already assigned, Skipping assignment"
        }

        $out = $assignedIdentity.Id
        Write-Output $out

    } #Process
    END {
        Write-Information 'Ending New-AIBResourceGroup'
    } #End
}  #function New-AIBResourceGroup