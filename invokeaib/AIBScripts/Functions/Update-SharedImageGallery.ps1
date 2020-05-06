function Update-SharedImageGallery {
    [CmdletBinding()]

    Param (
        [Parameter(
            ValuefromPipelineByPropertyName = $true,
            Mandatory = $true
        )]
        [System.String]$SharedImageGalName,

        [Parameter(
            ValuefromPipelineByPropertyName = $true,
            Mandatory = $true
        )]
        [System.String]$ResourceGroupName,

        [Parameter(
            ValuefromPipelineByPropertyName = $true,
            Mandatory = $true
        )]
        [System.String]$Location,

        [Parameter(
            ValuefromPipelineByPropertyName = $true,
            Mandatory = $true
        )]
        [System.String]$ImageDefName,

        [Parameter(
            ValuefromPipelineByPropertyName = $true,
            Mandatory = $true
        )]
        [System.String]$Publisher,

        [Parameter(
            ValuefromPipelineByPropertyName = $true,
            Mandatory = $true
        )]
        [System.String]$Offer,

        [Parameter(
            ValuefromPipelineByPropertyName = $true,
            Mandatory = $true
        )]
        [System.String]$Sku


    )

    BEGIN {
        Set-StrictMode -Version Latest
        Write-Information 'Starting Update-SharedImageGallery'
    } # Begin
    PROCESS {

        $gallery = Get-AzGallery

        if (-not $gallery -or $gallery.Name -notcontains $SharedImageGalName) {

            New-AzGallery -GalleryName $SharedImageGalName -ResourceGroupName $ResourceGroupName -Location $Location

        }

        if (-not (Get-AzGalleryImageDefinition -GalleryName $SharedImageGalName -ResourceGroupName $ResourceGroupName)) {

            $ParamNewAzGalleryImageDefinition = @{
                GalleryName       = $SharedImageGalName
                ResourceGroupName = $ResourceGroupName
                Location          = $Location
                Name              = $ImageDefName
                OsState           = 'generalized'
                OsType            = 'Windows'
                Publisher         = $Publisher
                Offer             = $Offer
                Sku               = $Sku
            }

            New-AzGalleryImageDefinition @ParamNewAzGalleryImageDefinition

        }


    } #Process
    END {
        Write-Information 'Ending Update-SharedImageGallery'
    } #End
}  #function Update-SharedImageGallery