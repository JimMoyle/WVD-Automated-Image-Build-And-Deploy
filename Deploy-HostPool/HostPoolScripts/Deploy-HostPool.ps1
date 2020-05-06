param ($subscriptionID, $HPResourceGroup, $HPHostpoolName, $HPLocation, $HPNoInstance, $SharedImageGalleryName, $ResourceGroupAIB, $SharedImageName )

$azContext = Get-AzContext
Write-Information "Context is $($azContext.Name)"

$templatepath = "Deploy-HostPool\ARMTemplates"

$SRParametersTemplateFile = Join-Path $templatepath "SPRINGRELEASE_PARAMETERS_TEMPLATE.json"
$SRParametersFile = Join-Path $templatepath "SPRINGRELEASE_PARAMETERS.json"
$SRTemplateFile = Join-Path $templatepath "SPRINGRELEASE_TEMPLATE.json"

$SRWorkSpaceName = 'SRWorkSpace'
$SRWorkSpaceLocation = 'eastus2'
$SRWorkSpaceResourceGroup = $HPResourceGroup
$SRMaxSessionLimit = '10'
$SRLoadBalanceType = 'BreadthFirst'

$AKVObjectID = '/subscriptions/4705c1d9-fec5-487f-a3e4-436f90c58c0c/resourceGroups/WvdInfrastructure/providers/Microsoft.KeyVault/vaults/JimKeyVault'
$AKVDomainJoinPassword = 'JimAdmin'
$HPDomainJoinAccount = 'domainjoin@jimmoyle.net'
$HPVMSize = "Standard_B2s"
$HPDiskType = "StandardSSD_LRS"
$HPVNETName = "WvdInfrastructureUS"
$HPSubnetName = 'Default'
$HPVNETResourceGroup = $HPResourceGroup
$HPDomaintoJoin = "jimmoyle.net"
$HPPrefix = "Win10"
$HPDomainJoinOU = ''
$HPDefaultUsers = 'user1@jimmoyle.net', 'user2@jimmoyle.net'

$SIGVersions = (Get-AzGalleryImageVersion -ResourceGroupName $ResourceGroupAIB -GalleryName $SharedImageGalleryName -GalleryImageDefinitionName $SharedImageName)
$SIGLatestVersion = "0.0.0"
foreach ($SIGVersion in $SIGVersions) {
    if ([version]$SIGVersion.Name -gt [version]$SIGLatestVersion) { $SIGLatestVersion = $SIGVersion.Name }
}

#Get vCPUs and Memory of Virtual Machine Size

$VMSize = Get-AzVMSize -Location $HPLocation | Where-Object { $_.Name -eq $HPVMSize }

#Create a new Deployment GUID
$DeploymentGUID = (New-Guid).Guid

#SetToken Expiration Time (24 Hours)
$TokenExpirationTime = Get-Date ((Get-Date) + (New-TimeSpan -days 1)) -format yyyy-MM-ddTHH:mm:ss.ffZ

#Create New Spring Release Parameters File for Hostpool Image Deployment
Copy-Item $SRParametersTemplateFile -Destination $SRParametersFile
$content = Get-Content -Path $SRParametersFile -ReadCount 0
$content = $content -Replace ('<SUBSCRIPTIONID>', $subscriptionID)
$content = $content -Replace ('<HPRESOURCEGROUP>', $HPResourceGroup)
$content = $content -Replace ('<HPHOSTPOOLNAME>', $HPHostpoolName)
$content = $content -Replace ('<HPLOCATION>', $HPLocation)
$content = $content -Replace ('<SRWORKSPACENAME>', $SRWorkSpaceName)
$content = $content -Replace ('<SRWORKSPACELOCATION>', $SRWorkSpaceLocation)
$content = $content -Replace ('<SRWORKSPACERESOURCEGROUP>', $SRWorkSpaceResourceGroup)
$content = $content -Replace ('<HPDOMAINJOINACCOUNT>', $HPDomainJoinAccount)
$content = $content -Replace ('<AKVOBJECTID>', $AKVObjectID)
$content = $content -Replace ('<AKVDOMAINJOINPASSWORD>', $AKVDomainJoinPassword)
$content = $content -Replace ('<HPVMSIZE>', $HPVMSize)
$content = $content -Replace ('<HPNOINSTANCE>', $HPNoInstance)
$content = $content -Replace ('<RESOURCEGROUPAIB>', $ResourceGroupAIB)
$content = $content -Replace ('<SHAREDIMAGEGALLERYNAME>', $SharedImageGalleryName)
$content = $content -Replace ('<SHAREDIMAGENAME>', $SharedImageName)
$content = $content -Replace ('<SHAREDIMAGEVERSION>', $SIGLatestVersion)
$content = $content -Replace ('<HPDISKTYPE>', $HPDiskType)
$content = $content -Replace ('<HPVNETNAME>', $HPVNETName)
$content = $content -Replace ('<HPSUBNETNAME>', $HPSubnetName)
$content = $content -Replace ('<HPVNETRESOURCEGROUP>', $HPVNETResourceGroup)
$content = $content -Replace ('<SRMAXSESSIONLIMIT>', $SRMaxSessionLimit)
$content = $content -Replace ('<SRLOADBALANCETYPE>', $SRLoadBalanceType)
$content = $content -Replace ('<HPDOMAINTOJOIN>', $HPDomaintoJoin)
$content = $content -Replace ('<HPPREFIX>', $HPPrefix)
$content = $content -Replace ('<HPDOMAINJOINOU>', $HPDomainJoinOU)
$content = $content -Replace ('<HPVMSIZECORES>', $VMSize.NumberOfCores)
$content = $content -Replace ('<HPVMSIZEMEM>', ($VMSize.MemoryInMB / 1024))
$content = $content -Replace ('<DEPLOYMENTGUID>', $DeploymentGUID)
$content = $content -Replace ('<TOKENEXPIRATIONTIME>', $TokenExpirationTime)



Set-Content -Path $SRParametersFile -Value $content -Encoding Unicode

#Check for ResourceGroup to create Hostpool. If it doesn't exist create it.
If (!(Get-AzResourceGroup -Name $HPResourceGroup -ErrorAction SilentlyContinue)) {
    New-AzResourceGroup -Name $HPResourceGroup -Location $HPLocation
    Write-Information "Created Resource Group $HPResourceGroup in $HPLocation"

}
Wait-Debugger
#Create Hostpool - General Availability
$Hostpool = New-AzResourceGroupDeployment -ResourceGroupName $HPResourceGroup -TemplateFile $SRTemplateFile -TemplateParameterFile $SRParametersFile
If ($Hostpool.provisioningState = "Succeeded") { Write-Host $HPHostpoolName "has been succesfully deployed." } else { Write-Host $HPHostpoolName "failed to deploy" }

#Add Default Users to DAG
New-AzRoleAssignment -SignInName $HPDefaultUsers -ResourceGroupName $HPResourceGroup -RoleDefinitionName "Desktop Virtualization User"
