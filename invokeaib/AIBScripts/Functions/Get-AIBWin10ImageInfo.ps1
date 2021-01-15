function Get-AibWin10ImageInfo {
    [CmdletBinding()]

    Param (
        [Parameter(
            Position = 0,
            ValuefromPipelineByPropertyName = $true,
            ValuefromPipeline = $true,
            Mandatory = $true
        )]
        [System.String]$Location,

        [Parameter(
            ValuefromPipelineByPropertyName = $true
        )]
        [System.String]$PublisherName = 'MicrosoftWindowsDesktop',

        [Parameter(
            ValuefromPipelineByPropertyName = $true
        )]
        [System.String]$Offer = 'office-365',

        [Parameter(
            ValuefromPipelineByPropertyName = $true
        )]
        [System.String]$SkuMatchString = '*evd*'
    )

    BEGIN {
        #For Windows 10 multi session with O365 the Offer should be office-365
        #For Windows 10 multi session the Offer should be windows-10
        Set-StrictMode -Version Latest
        Write-Information 'Starting Get-AIBWin10ImageInfo Function'
    } # Begin
    PROCESS {

        $commonParams = @{
            Location      = $Location
            PublisherName = $PublisherName
        }

        # Check the offerings of a specific Microsoft Windows publisher
        $publisher = Get-AzVMImagePublisher -Location $Location

        if ($publisher.PublisherName -notcontains $publisherName) {
            Write-Error "Publisher list does not contain $publisherName"
            return
        }

        # Check the skus for a specific offer (including publisher and location)
        $offerList = Get-AzVMImageOffer @commonParams

        if ($offerList.Offer -notcontains $Offer) {
            Write-Error "Offer list does not contain $Offer"
            return
        }

        # Check the skus for a specific offer (including publisher and location)
        $sku = Get-AzVMImageSku @commonParams -Offer $Offer | Where-Object { $_.Skus -like $SkuMatchString }

        # Check the version for a specific sku (including offer, publisher and location) and select the newest one
        $newestImage = $sku | Get-AzVMImage | Sort-Object -Descending -Property Version | Select-Object -First 1

        $output = [PSCustomObject]@{
            Publisher = $publisherName
            Offer     = $Offer
            Sku       = $newestImage.Skus
            Version   = $newestImage.Version
            Id        = $newestImage.Id
        }

        Write-Output $output
        $infoOutput = 'Publisher:{0} Offer:{1} Sku:{2} Version:{3} Id:{4}' -f $output.Publisher, $output.Offer, $output.Sku, $output.Version, $output.Id
        Write-Information $infoOutput

    } #Process
    END {
        Write-Information 'Ending Get-AIBWin10ImageInfo Function'
    } #End
}  #function Get-AIBWin10ImageInfo