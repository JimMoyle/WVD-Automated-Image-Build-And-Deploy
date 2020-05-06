function Update-AibTemplate {
    [CmdletBinding()]

    Param (
        [Parameter(
            ValuefromPipelineByPropertyName = $true,
            ValuefromPipeline = $true,
            Mandatory = $true
        )]
        [System.String]$TemplateUrl,

        [Parameter(
            ValuefromPipelineByPropertyName = $true,
            Mandatory = $true
        )]
        [System.String]$ApiVersion,

        [Parameter(
            ValuefromPipelineByPropertyName = $true,
            Mandatory = $true
        )]
        [System.String]$SubscriptionID,

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
        [System.String]$ImageName,

        [Parameter(
            ValuefromPipelineByPropertyName = $true,
            Mandatory = $true
        )]
        [System.String]$RunOutputName,

        [Parameter(
            ValuefromPipelineByPropertyName = $true,
            Mandatory = $true
        )]
        [System.String]$PublisherName,

        [Parameter(
            ValuefromPipelineByPropertyName = $true,
            Mandatory = $true
        )]
        [System.String]$Offer,

        [Parameter(
            ValuefromPipelineByPropertyName = $true,
            Mandatory = $true
        )]
        [System.String]$ImageVersion,

        [Parameter(
            ValuefromPipelineByPropertyName = $true,
            Mandatory = $true
        )]
        [System.String]$Sku,

        [Parameter(
            ValuefromPipelineByPropertyName = $true,
            Mandatory = $true
        )]
        [System.String]$Type,

        [Parameter(
            ValuefromPipelineByPropertyName = $true
        )]
        [int]$BuildTimeoutInMinutes = 100,

        [Parameter(
            ValuefromPipelineByPropertyName = $true
        )]
        [System.String]$ImageDefName,

        [Parameter(
            ValuefromPipelineByPropertyName = $true
        )]
        [System.String]$SharedImageGalName,

        [Parameter(
            ValuefromPipelineByPropertyName = $true
        )]
        [System.String]$PathToCustomizationScripts,

        [Parameter(
            ValuefromPipelineByPropertyName = $true
        )]
        [System.String]$AssignedIdentityId

    )

    BEGIN {
        Set-StrictMode -Version Latest
        Write-Information 'Starting Update-AibTemplate'
    } # Begin
    PROCESS {

        #Grab json template, needs to be accessable, could change to unc path if you wanted
        try {
            $jsonTemplate = Invoke-WebRequest -Uri $TemplateUrl -UseBasicParsing -ErrorAction Stop
        }
        catch {
            Write-Error "Cannot connect to $TemplateUrl to download json template"
            return
        }


        #You can create as many tags as you like here
        $tags = @{
            Source    = 'azVmImageBuilder'
            BaseOsImg = $Offer
            Sku       = $Sku
            Version   = $ImageVersion
        }

        #grab json file content getting rid of http stuff and convert to object
        $template = $jsonTemplate.Content | ConvertFrom-Json

        #Set template values
        $template.resources.properties.buildTimeoutInMinutes = $BuildTimeoutInMinutes
        $template.resources.properties.source.publisher = $PublisherName
        $template.resources.properties.source.offer = $Offer
        $template.resources.properties.source.sku = $Sku
        $template.resources.properties.source.version = $ImageVersion
        $template.resources.identity.userAssignedIdentities = [pscustomobject]@{ $AssignedIdentityId = @{ } }


        switch ($Type) {
            'ManagedImage' {

                #image id needed for builder
                $imageId = "/subscriptions/$SubscriptionID/resourceGroups/$ResourceGroupName/providers/Microsoft.Compute/images/$ImageName"

                #Add each Managed Disk Image target to Location
                foreach ($loc in $Location) {

                    $distrib = @{
                        type          = $Type
                        imageId       = $imageId
                        location      = $loc
                        runOutputName = $RunOutputName
                        artifactTags  = $tags
                    }

                    $template.resources.properties.distribute += $distrib

                }
            }
            'SharedImage' {

                #Gallery id needed for builder
                $galleryImageId = "/subscriptions/$SubscriptionID/resourceGroups/$ResourceGroupName/providers/Microsoft.Compute/galleries/$sharedImageGalName/images/$imageDefName"

                $distrib = [ordered]@{
                    type               = $Type
                    galleryImageId     = $galleryImageId
                    runOutputName      = $RunOutputName
                    artifactTags       = $tags
                    replicationRegions = @($Location)
                }

                $template.resources.properties.distribute += $distrib

            }
            Default { }
        }

        if ($PathToCustomizationScripts) {

            $files = Get-ChildItem -Path $PathToCustomizationScripts -File

            foreach ($file in $files) {
                #Make sure it's a powershell file
                if ($file.Extension -ne '.ps1') {
                    Write-Warning 'Only PowerShell Scripts are currently supported in this script'
                    break
                }

                #Create customisation object with inline powershell script
                $customization = [PSCustomObject]@{
                    type   = 'PowerShell'
                    name   = $file.BaseName
                    inline = Get-Content -Path $file.FullName | ForEach-Object { $_.ToString() }
                }

                #Add customisation to template
                $template.resources.properties.customize += $customization
            }
        }

        $output = ConvertTo-Json -InputObject $template -Depth 6

        Write-Output $output

    } #Process
    END {
        Write-Information 'Ending Update-AibTemplate'
    } #End
}  #function Update-AibTemplate