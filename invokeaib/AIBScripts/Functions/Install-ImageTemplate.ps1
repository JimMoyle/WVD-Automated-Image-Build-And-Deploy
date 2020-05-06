function Install-ImageTemplate {
    [CmdletBinding()]

    Param (

        [Parameter(
            ValuefromPipelineByPropertyName = $true,
            Mandatory = $true
        )]
        [System.String]$Location,

        [Parameter(
            ValuefromPipelineByPropertyName = $true,
            Mandatory = $true
        )]
        [System.String]$ResourceGroupName,

        [Parameter(
            ValuefromPipelineByPropertyName = $true
        )]
        [System.String]$ResourceType = "Microsoft.VirtualMachineImages/ImageTemplates",

        [Parameter(
            ValuefromPipelineByPropertyName = $true
        )]
        [System.String]$ResourceName = "aibWVDTemplate",

        [Parameter(
            ValuefromPipelineByPropertyName = $true,
            Mandatory = $true
        )]
        [string]$TemplateFile
    )

    BEGIN {
        Set-StrictMode -Version Latest
        Write-Information 'Starting Install-ImageTemplate'
    } # Begin
    PROCESS {

        $templateParameterObject = @{
            "imageTemplateName" = $resourceName
            "api-version"       = $ApiVersion
            "svclocation"       = $Location
        }

        $paramsRGD = @{
            ResourceGroupName       = $ResourceGroupName
            Name                    = $ResourceName
            TemplateFile            = $TemplateFile
            TemplateParameterObject = $templateParameterObject
            ErrorAction             = 'Stop'
        }

        # submit the template to the Azure Image Builder Service
        # (creates the image template artifact and stores dependent artifacts (scripts, etc) in the staging Resource Group IT_<resourcegroupname>_<temmplatename>)
        try {
            New-AzResourceGroupDeployment  @paramsRGD
        }
        catch {
            Write-Error $error[0]
            return
        }

        $paramsRA = @{
            ResourceGroupName = $ResourceGroupName
            ResourceType      = $resourceType
            ResourceName      = $resourceName
            Action            = "Run"
            ApiVersion        = $apiVersion
            Force             = $true
        }

        # Build the image, based on the template artifact
        try {
            Invoke-AzResourceAction @paramsRA
        }
        catch {
            Write-Error $error[0]
            Write-Error 'Deployment failed'
        }

    } #Process
    END {
        Write-Information 'Ending Install-ImageTemplate'
    } #End
}  #function Install-ImageTemplate