Function Import-PsTypesXml
{
    [CmdletBinding(SupportsShouldProcess=$true)]
    Param
    (
        # Input types.ps1xml file
        [Parameter(Position=0,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
        [Alias('Path')]
        [string]
        $InputFile,

        # Encoding of the input file
        [Parameter()]
        [string]
        $InputEncoding = 'UTF8',

        # Destination directory
        [Parameter()]
        [string]
        $DestinationDirectory,

        # Encoding of the input file
        [Parameter()]
        [string]
        $OutputEncoding = 'UTF8',

        # Overwrite existing files
        [Parameter()]
        [switch]
        $Force
    )

    Process
    {
        if(-not (Test-Path $DestinationDirectory) -and $PSCmdlet.ShouldProcess("Create output directory $DestinationDirectory?"))
        {
            Write-Verbose "Creating directory $DestinationDirectory"

            New-Item -Path $DestinationDirectory -ItemType Directory | Write-Verbose
        }

        Write-Verbose "Loading input file $InputFile"

        $xml = [xml] (Get-Content $InputFile -Raw -Encoding $InputEncoding)

        foreach($type in $xml.Types.Type)
        {
            $typeName = $type.Name.Trim()
            $fileName = (Join-Path $DestinationDirectory "$typeName.yml")

            if(Test-Path $fileName)
            {
                $op = 'Overwrite'
            }
            else
            {
                $op = 'Create'
            }

            if(-not $PSCmdlet.ShouldProcess($DestinationDirectory, "$op file $fileName"))
            {
                continue
            }

            if($op -eq 'Overwrite' -and (-not $Force.IsPresent))
            {
                throw "File $fileName exists and -Force was not specified. To overwrite existing files, use -Force.`n"
            }

            Write-Verbose $fileName

            Clear-Content $fileName -Force

            foreach($m in $type.Members.ChildNodes)
            {
                "- $($m.LocalName):" | Add-Content $fileName -Encoding $OutputEncoding
                "- $($m.LocalName):" | Write-Verbose

                foreach($elem in $m.ChildNodes)
                {
                    $elemName = $elem.LocalName
                    $elemValue = $elem.'#text'.Trim()

                    if($elemValue.Contains("`n"))
                    {
                        $cont = ">-`n      "
                    }
                    else
                    {
                        $cont = ''    
                    }

                    "    ${elemName}: ${cont}${elemValue}" | Add-Content $fileName -Encoding $OutputEncoding
                    "    ${elemName}: ${cont}${elemValue}" | Write-Verbose
                }
            }
        }
    }
}