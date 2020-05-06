using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

# Write to the Azure Functions log stream.
Write-Host "PowerShell HTTP trigger function processed a request."

#Write-Host $Request.Body

# Interact with query parameters or the body of the request.
$responder = $Request.Query.responder
if (-not $responder) {
    $responder = $Request.Body.responder
}

$submitDate = $Request.Query.submitDate
if (-not $submitDate) {
    $submitDate = $Request.Body.submitDate
}

$hostPoolName = $Request.Query.r35d86ba17ae54465a071569d4e86de52
if (-not $hostPoolName) {
    $hostPoolName = $Request.Body.r35d86ba17ae54465a071569d4e86de52
}

$numberOfVMs = $Request.Query.rc24367db747241a8ae820d6a51b7bedf
if (-not $numberOfVMs) {
    $numberOfVMs = $Request.Body.rc24367db747241a8ae820d6a51b7bedf
}

$subcriptionID = $Request.Query.r0fccb00c57724886a12770f2736fd1f3
if (-not $subcriptionID) {
    $subcriptionID = $Request.Body.r0fccb00c57724886a12770f2736fd1f3
}

$sharedImageGallery = $Request.Query.rf90a297359684f96a3b52860b1117ab5
if (-not $sharedImageGallery) {
    $sharedImageGallery = $Request.Body.rf90a297359684f96a3b52860b1117ab5
}

$language = $Request.Query.r961945759fe0414b89050dca22e41a78
if (-not $language) {
    $language = $Request.Body.r961945759fe0414b89050dca22e41a78
}

$bodyOut = "HP $hostPoolName VMs $numberOfVMs ID $subcriptionID Gallery $sharedImageGallery Lang $language Resp $responder Date $submitDate"
Write-Host $bodyOut
if (-not (Get-Module -ListAvailable -Name Az.ManagedServiceIdentity)) {
    Write-Information "Trying to install Az.ManagedServiceIdentity"
    Install-Module -Name Az.ManagedServiceIdentity -SkipPublisherCheck -Force -Scope CurrentUser
}

. invokeaib\AIBScripts\Release\Install-AIBWin10MS.ps1

$paramInstallAIBWin10MS = @{
    subscriptionID             = $subcriptionID
    Location                   = 'eastus2'
    Name                       = 'DemoResourceGroupUS'
    SharedImageGalleryName     = $sharedImageGallery
    OutputType                 = 'SharedImage'
    PathToCustomizationScripts = "invokeaib\AIBScripts\CustomizationScript\Customization.ps1"
}

Install-AIBWin10MS @paramInstallAIBWin10MS

$bodyOut = "HP $hostPoolName VMs $numberOfVMs ID $subcriptionID Gallery $sharedImageGallery Lang $language Resp $responder Date $submitDate"

Write-Host $bodyOut

# Associate values to output bindings by calling 'Push-OutputBinding'.
Push-OutputBinding -Name Response -Value (
    [HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::OK
        Body       = $bodyOut
    }
)
