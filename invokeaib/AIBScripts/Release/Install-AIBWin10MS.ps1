function Install-AibWin10MS {

    [CmdletBinding(DefaultParametersetname = "None")]

    Param (

        [Parameter(
            ValuefromPipelineByPropertyName = $true,
            ValuefromPipeline = $true,
            Mandatory = $true
        )]
        [string]$Name,

        [Parameter(
            ValuefromPipelineByPropertyName = $true,
            Mandatory = $true
        )]
        [string]$Location,

        [Parameter(
            ValuefromPipelineByPropertyName = $true
        )]
        [ValidateSet('ManagedImage', 'SharedImage')]
        [string]$OutputType = 'SharedImage',

        [Parameter(
            ValuefromPipelineByPropertyName = $true,
            Mandatory = $true
        )]
        [Alias('Id')]
        [string]$SubscriptionID,

        [Parameter(
            ValuefromPipelineByPropertyName = $true
        )]
        [string]$PathToCustomizationScripts,

        [Parameter(
            ParameterSetName = "Network",
            ValuefromPipelineByPropertyName = $true,
            Mandatory = $true
        )]
        [string]$vNet,

        [Parameter(
            ParameterSetName = "Network",
            ValuefromPipelineByPropertyName = $true,
            Mandatory = $true
        )]
        [string]$Subnet,

        [Parameter(
            ParameterSetName = "Network",
            ValuefromPipelineByPropertyName = $true,
            Mandatory = $true
        )]
        [System.String]$NsgName,

        [Parameter(
            ValuefromPipelineByPropertyName = $true
        )]
        [string]$SharedImageGalleryName

    )

    BEGIN {
        Write-Information 'Starting Install-AIBWin10MS function'
        Set-StrictMode -Version Latest

        #Requires -Modules 'Az.Compute', 'Az.Resources', 'Az.Accounts', 'Az.ManagedServiceIdentity'

        #region get functions
        $Private = @( Get-ChildItem -Path $PSScriptRoot\..\functions\*.ps1 -ErrorAction SilentlyContinue )

        #Dot source the functions
        Foreach ($import in $Private) {
            Try {
                Write-Verbose "Importing $($Import.FullName)"
                . $import.fullname
            }
            Catch {
                Write-Error "Failed to import function $($import.fullname): $_"
            }
        }
        #endregion
        Write-Information 'Finished Begin block for Install-AIBWin10MS'
    } # Begin
    PROCESS {
        #Wait-Debugger
        #Api Version will change once we are in GA, hopefully just to use the latest version
        $apiVersion = "2019-05-01-preview"

        $date = Get-Date -Format yyMMdd
        $timeInt = $(get-date -UFormat "%s")

        $sharedImageDefName = $date + 'Win10MS' + $timeInt.ToString().Substring(4)

        if ($SharedImageGalleryName -and $OutputType -eq 'ManagedImage') {
            Write-Error "Managed Images cannot be used with shared galleries, set OutputType to SharedImage to use a gallery"
            return
        }

        #if ($env:FUNCTIONS_WORKER_RUNTIME -ne 'powershell') {}
        Write-Information 'Getting Az-Context'
        try {
            $azContext = Get-AzContext
            Write-Information "Context is $($azContext.Name)"
        }
        catch {
            Write-Error $error[0].ToString()
            Write-Information'Failed to get Az Context'
        }

        if ($azContext.Subscription.Id -ne $SubscriptionID) {
            Write-Error "Can not find Subscription ID $SubscriptionID in current Azure context, Use Connect-AzAccout or Select-AzContext to correct this."
            return
        }

        $tenantID = $azContext.Subscription.TenantId
        if ((Get-AzSubscription -TenantId $TenantID).SubscriptionId -notcontains $subscriptionID ) {
            Write-Error "Cannot find subscrioption Id $subscriptionID in tenant"
            return
        }
        Write-Information "tenantID is $tenantID"

        $imageInfo = Get-AIBWin10ImageInfo -Location $Location

        $aibProvider = Get-AzProviderFeature -ProviderNamespace Microsoft.VirtualMachineImages -FeatureName VirtualMachineTemplatePreview

        if ($aibProvider.RegistrationState -ne 'Registered') {
            Write-Error "pre-reqs not met for Azure Image Builder. Check https://docs.microsoft.com/en-us/azure/virtual-machines/windows/image-builder for all pre-requisite steps"
            return
        }
        else {
            Write-Information "Azure Image Builder is $($aibProvider.RegistrationState)"
        }

        $paramNewAIBResourceGroup = @{
            Name           = $Name
            Location       = $Location
            SubscriptionID = $subscriptionID
            TenantID       = $tenantID
        }
        $assignedIdentityId = $null
        $assignedIdentityId = New-AIBResourceGroup @paramNewAIBResourceGroup

        #Add-AIBNetwork -vNet $vNet -Subnet $Subnet -ResourceGroup $Name

        if ($OutputType -eq 'SharedImage') {
            try {
                $paramUpdateSharedImageGallery = @{
                    #ErrorAction        = 'Stop'
                    SharedImageGalName = $SharedImageGalleryName
                    ResourceGroupName  = $Name
                    Location           = $Location
                    ImageDefName       = $sharedImageDefName
                    Publisher          = $imageInfo.Publisher
                    Offer              = $imageInfo.Offer
                    Sku                = $imageInfo.Sku
                }
                Update-SharedImageGallery @paramUpdateSharedImageGallery
            }
            catch {
                Write-Error "Could not validate or create Gallery $SharedImageGalleryName"
                return
            }
        }

        $paramsUpdateAibTemplate = @{
            TemplateUrl                = "https://raw.githubusercontent.com/JimMoyle/CloudImageBuilder/master/Templates/GenericTemplate.json"
            ApiVersion                 = $apiVersion
            SubscriptionID             = $subscriptionID
            ResourceGroupName          = $Name
            Location                   = $Location
            ImageName                  = $Name + "MasterImage"
            RunOutputName              = $Name + "WindowsRun"
            PublisherName              = $imageInfo.Publisher
            Offer                      = $imageInfo.Offer
            ImageVersion               = $imageInfo.Version
            Type                       = $OutputType
            Sku                        = $imageInfo.Sku
            PathToCustomizationScripts = $PathToCustomizationScripts
            SharedImageGalName         = $SharedImageGalleryName
            ImageDefName               = $sharedImageDefName
            AssignedIdentityId         = $assignedIdentityId
        }
        $template = Update-AibTemplate @paramsUpdateAibTemplate #| Out-Null

        $tempFile = New-TemporaryFile

        $template | Set-Content $tempfile

        $resourceName = $Name + "WVDTemplate"

        $paramsInstallImageTemplate = @{
            ErrorAction       = 'Stop'
            Location          = $Location
            ResourceGroupName = $Name
            ResourceName      = $resourceName
            ResourceType      = "Microsoft.VirtualMachineImages/ImageTemplates"
            TemplateFile      = $tempFile
        }
        try {
            Install-ImageTemplate @paramsInstallImageTemplate
        }
        catch {
            Write-Error $error[0].exception.message
            Write-Error "Could Not install Image Template"
            return
        }

        Remove-Item $tempFile

        if (-not ($env:FUNCTIONS_WORKER_RUNTIME)) {

            $runState = 'Running'

            while ($runState -eq 'Running' ) {
                Start-Sleep 5
                $status = Get-AibBuildStatus -ApiVersion $apiVersion -AzContext $azContext -ResourceGroupName $Name -ImageName $resourceName
                if ($null -eq $status.runState) {
                    $runState = 'Fail'
                }
                else {
                    $runState = $status.runState
                }
            }

            if ($runState -ne 'Succeeded') {
                Write-Error "Template deployment failed.  Please manually clean up resources"
                return
            }

            $paramGetAzResource = @{
                ResourceName      = $resourceName
                ResourceGroupName = $Name
                ResourceType      = 'Microsoft.VirtualMachineImages/imageTemplates'
                ApiVersion        = $apiVersion
            }

            $resTemplateId = Get-AzResource @paramGetAzResource

            Remove-AzResource -ResourceId $resTemplateId.ResourceId -Force | Out-Null

        }

        $output = [PSCustomObject]@{
            Name = $sharedImageDefName
        }

        Write-Output $output

    } #Process
    END {
        Write-Information 'Ending Install-AIBWin10MS function'
    } #End
}  #function Install-AIBWin10MS
