function Get-AibBuildStatus {
    [CmdletBinding()]
    Param (
        [Parameter(
            ValuefromPipelineByPropertyName = $true,
            Mandatory = $true
        )]
        [System.String]$ApiVersion,

        [Parameter(
            ValuefromPipelineByPropertyName = $true,
            Mandatory = $true
        )]
        [Microsoft.Azure.Commands.Profile.Models.Core.PSAzureContext]$AzContext,

        [Parameter(
            ValuefromPipelineByPropertyName = $true,
            Mandatory = $true
        )]
        [System.String]$ResourceGroupName,

        [Parameter(
            ValuefromPipelineByPropertyName = $true,
            Mandatory = $true
        )]
        [System.String]$ImageName
    )

    BEGIN {
        Set-StrictMode -Version Latest
        Write-Information 'Starting Get-AibBuildStatus'
        #Thanks to https://gist.github.com/brettmillerb for this code.
    }

    PROCESS {

        # Get instance profile
        $azureRmProfile = [Microsoft.Azure.Commands.Common.Authentication.Abstractions.AzureRmProfileProvider]::Instance.Profile
        $profileClient = New-Object Microsoft.Azure.Commands.ResourceManager.Common.RMProfileClient($azureRmProfile)

        # Get token
        $token = $profileClient.AcquireAccessToken($AzContext.Tenant.TenantId)
        $accessToken = $token.AccessToken

        $managementEp = $AzContext.Environment.ResourceManagerUrl

        $urlBuildStatus = [System.String]::Format("{0}subscriptions/{1}/resourceGroups/{2}/providers/Microsoft.VirtualMachineImages/imageTemplates/{3}?api-version={4}", $managementEp, $AzContext.Subscription.Id, $ResourceGroupName, $ImageName, $ApiVersion)

        $buildStatusResult = Invoke-WebRequest -Method GET  -Uri $urlBuildStatus -UseBasicParsing -Headers  @{"Authorization" = ("Bearer " + $accessToken) } -ContentType application/json
        $buildStatus = $buildStatusResult.Content | ConvertFrom-Json

        #Last runstatus holds the info we need from the API call
        Write-Output $buildStatus.properties.lastRunStatus
    }

    END {
        Remove-Variable -Name profileClient
        Write-Information 'Ending Get-AibBuildStatus'
    }
}