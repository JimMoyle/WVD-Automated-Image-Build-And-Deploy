function Add-AIBNetwork {
    [CmdletBinding()]

    Param (
        [Parameter(
            ValuefromPipelineByPropertyName = $true,
            Mandatory = $true
        )]
        [System.String]$vNet,

        [Parameter(
            ValuefromPipelineByPropertyName = $true,
            Mandatory = $true
        )]
        [System.String]$SubNet,

        [Parameter(
            ValuefromPipelineByPropertyName = $true,
            Mandatory = $true
        )]
        [System.String]$ResourceGroup,

        [Parameter(
            ValuefromPipelineByPropertyName = $true,
            Mandatory = $true
        )]
        [System.String]$NsgName
    )

    BEGIN {
        Set-StrictMode -Version Latest
    } # Begin
    PROCESS {

        $ParamGetAzNwSecGrp = @{
            Name              = $NsgName
            ResourceGroupName = $ResourceGroup
        }

        $paramAddAzNwSecRuleCfg = @{
            Name                     = 'AzureImageBuilderAccess'
            Description              = "Allow Image Builder Private Link Access to Proxy VM"
            Access                   = 'Allow'
            Protocol                 = 'Tcp'
            Direction                = 'Inbound'
            Priority                 = 400
            SourceAddressPrefix      = 'AzureLoadBalancer'
            SourcePortRange          = '*'
            DestinationAddressPrefix = 'VirtualNetwork'
            DestinationPortRange     = 60000 - 60001
        }
        Get-AzNetworkSecurityGroup @ParamGetAzNwSecGrp | Add-AzNetworkSecurityRuleConfig @paramAddAzNwSecRuleCfg | Set-AzNetworkSecurityGroup

        $virtualNetwork = Get-AzVirtualNetwork -Name $vnetName -ResourceGroupName $ResourceGroup

        ( $virtualNetwork | Select-Object -ExpandProperty subnets | Where-Object { $_.Name -eq $SubNet } ).privateLinkServiceNetworkPolicies = "Disabled"

        $virtualNetwork | Set-AzVirtualNetwork

        #Second Step 2

        $templateUrl = "https://raw.githubusercontent.com/danielsollondon/azvmimagebuilder/master/quickquickstarts/1a_Creating_a_Custom_Win_Image_on_Existing_VNET/existingVNETWindows.json"
        $templateFilePath = "existingVNETWindows.json"

        $aibRoleNetworkingUrl = "https://raw.githubusercontent.com/danielsollondon/azvmimagebuilder/master/solutions/12_Creating_AIB_Security_Roles/aibRoleNetworking.json"
        $aibRoleNetworkingPath = "aibRoleNetworking.json"

        $aibRoleImageCreationUrl = "https://raw.githubusercontent.com/danielsollondon/azvmimagebuilder/master/solutions/12_Creating_AIB_Security_Roles/aibRoleImageCreation.json"
        $aibRoleImageCreationPath = "aibRoleImageCreation.json"

        # download configs
        Invoke-WebRequest -Uri $templateUrl -OutFile $templateFilePath -UseBasicParsing

        Invoke-WebRequest -Uri $aibRoleNetworkingUrl -OutFile $aibRoleNetworkingPath -UseBasicParsing

        Invoke-WebRequest -Uri $aibRoleImageCreationUrl -OutFile $aibRoleImageCreationPath -UseBasicParsing

        # update AIB image config template
        ((Get-Content -path $templateFilePath -Raw) -replace '<subscriptionID>', $subscriptionID) | Set-Content -Path $templateFilePath
        ((Get-Content -path $templateFilePath -Raw) -replace '<rgName>', $imageResourceGroup) | Set-Content -Path $templateFilePath
        ((Get-Content -path $templateFilePath -Raw) -replace '<region>', $location) | Set-Content -Path $templateFilePath
        ((Get-Content -path $templateFilePath -Raw) -replace '<runOutputName>', $runOutputName) | Set-Content -Path $templateFilePath
        ((Get-Content -path $templateFilePath -Raw) -replace '<imageName>', $imageName) | Set-Content -Path $templateFilePath

        ((Get-Content -path $templateFilePath -Raw) -replace '<vnetName>', $vnetName) | Set-Content -Path $templateFilePath
        ((Get-Content -path $templateFilePath -Raw) -replace '<subnetName>', $subnetName) | Set-Content -Path $templateFilePath
        ((Get-Content -path $templateFilePath -Raw) -replace '<vnetRgName>', $ResourceGroup) | Set-Content -Path $templateFilePath

        #Step 3

        # setup role def names, these need to be unique
        $timeInt = $(get-date -UFormat "%s")
        $imageRoleDefName = "Azure Image Builder Image Def" + $timeInt
        $networkRoleDefName = "Azure Image Builder Network Def" + $timeInt
        $idenityName = "aibIdentity" + $timeInt

        # create user identity
        ## Add AZ PS module to support AzUserAssignedIdentity
        Install-Module -Name Az.ManagedServiceIdentity

        # create identity
        New-AzUserAssignedIdentity -ResourceGroupName $imageResourceGroup -Name $idenityName

        $idenityNameResourceId = $(Get-AzUserAssignedIdentity -ResourceGroupName $imageResourceGroup -Name $idenityName).Id
        $idenityNamePrincipalId = $(Get-AzUserAssignedIdentity -ResourceGroupName $imageResourceGroup -Name $idenityName).PrincipalId

        # update template with identity
        ((Get-Content -path $templateFilePath -Raw) -replace '<imgBuilderId>', $idenityNameResourceId) | Set-Content -Path $templateFilePath

        # update the role defintion names
        ((Get-Content -path $aibRoleImageCreationPath -Raw) -replace 'Azure Image Builder Service Image Creation Role', $imageRoleDefName) | Set-Content -Path $aibRoleImageCreationPath
        ((Get-Content -path $aibRoleNetworkingPath -Raw) -replace 'Azure Image Builder Service Networking Role', $networkRoleDefName) | Set-Content -Path $aibRoleNetworkingPath

        # update role definitions
        ((Get-Content -path $aibRoleNetworkingPath -Raw) -replace '<subscriptionID>', $subscriptionID) | Set-Content -Path $aibRoleNetworkingPath
        ((Get-Content -path $aibRoleNetworkingPath -Raw) -replace '<vnetRgName>', $ResourceGroup) | Set-Content -Path $aibRoleNetworkingPath

        ((Get-Content -path $aibRoleImageCreationPath -Raw) -replace '<subscriptionID>', $subscriptionID) | Set-Content -Path $aibRoleImageCreationPath
        ((Get-Content -path $aibRoleImageCreationPath -Raw) -replace '<rgName>', $imageResourceGroup) | Set-Content -Path $aibRoleImageCreationPath

        # create role definitions from role configurations examples, this avoids granting contributor to the SPN
        New-AzRoleDefinition -InputFile  ./aibRoleImageCreation.json
        New-AzRoleDefinition -InputFile  ./aibRoleNetworking.json

        # grant role definition to image builder user identity
        New-AzRoleAssignment -ObjectId $idenityNamePrincipalId -RoleDefinitionName $imageRoleDefName -Scope "/subscriptions/$subscriptionID/resourceGroups/$imageResourceGroup"
        New-AzRoleAssignment -ObjectId $idenityNamePrincipalId -RoleDefinitionName $networkRoleDefName -Scope "/subscriptions/$subscriptionID/resourceGroups/$ResourceGroup"




    } #Process
    END { } #End
}  #function Add-AIBNetwork