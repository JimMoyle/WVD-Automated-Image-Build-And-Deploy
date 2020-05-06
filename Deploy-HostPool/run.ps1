using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

# Write to the Azure Functions log stream.
Write-Host "PowerShell HTTP trigger function processed a request."

$paramDeployHostPool = @{
    subscriptionID         = $Request.Query.subscriptionID
    HPResourceGroup        = $Request.Query.HPResourceGroup
    HPHostpoolName         = $Request.Query.HPHostpoolName
    HPLocation             = $Request.Query.HPLocation
    HPNoInstance           = $Request.Query.HPNoInstance
    SharedImageGalleryName = $Request.Query.SharedImageGalleryName
    ResourceGroupAIB       = $Request.Query.ResourceGroupAIB
    SharedImageName        = $Request.Query.SharedImageName
}

& Deploy-HostPool\HostPoolScripts\Deploy-HostPool.ps1 @paramDeployHostPool


# Interact with query parameters or the body of the request.
$name = $Request.Query.Name
if (-not $name) {
    $name = $Request.Body.Name
}

$body = "This HTTP triggered function executed successfully. Pass a name in the query string or in the request body for a personalized response."

if ($name) {
    $body = "Hello = $name. This HTTP triggered function executed successfully."
}

# Associate values to output bindings by calling 'Push-OutputBinding'.
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::OK
        Body       = $body
    })
