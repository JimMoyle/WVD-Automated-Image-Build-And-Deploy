$paramInstallAIBWin10MS = @{
    subscriptionID         = $subcriptionID
    Location               = 'westeurope'
    Name                   = 'DeleteMe1'
    SharedImageGalleryName = $sharedImageGallery
    OutputType             = 'SharedImage'
}

Install-AIBWin10MS @paramInstallAIBWin10MS
