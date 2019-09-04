Function Export-Xml
{
    [CmdletBinding(SupportsShouldProcess=$true)]
    Param
    (
        # Input types.ps1xml file
        [Parameter(Position=0,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
        [Alias('Path')]
        [string]
        $InputDirectory,

        # Encoding of the input file
        [Parameter()]
        [string]
        $InputEncoding = 'UTF8',

        # Destination directory
        [Parameter()]
        [string]
        $DestinationFile,

        # Encoding of the output XML file
        [Parameter()]
        [string]
        $OutputEncoding = 'utf-8',

        # Overwrite existing file
        [Parameter()]
        [switch]
        $Force
    )

    Process
    {
        if(-not $PSCmdlet.ShouldProcess($DestinationFile, "Create '*.types.ps1xml' file"))
        {
            return
        }

        Write-Verbose "Processing input directory $InputDirectory"

        [System.XML.XmlWriter] $writer = [System.XML.XmlWriter]::Create($DestinationFile, `
            (New-Object 'System.Xml.XmlWriterSettings' -Property @{
                Encoding = [System.Text.Encoding]::GetEncoding($OutputEncoding)
                Indent = $true
                IndentChars = '  '
            })
        )

        $writer.WriteStartDocument()
        $writer.WriteStartElement('Types')

        foreach($typeFile in (Get-ChildItem $InputDirectory -File))
        {
            Write-Verbose "Exporting file $typeFile"
            $yml = (Get-Content $typeFile.FullName -Encoding $InputEncoding -Raw | ConvertFrom-Yaml)

            $writer.WriteStartElement('Type')

                $writer.WriteElementString('Name', $typeFile.BaseName.ToString())

                $writer.WriteStartElement('Members')

                foreach($member in $yml)
                {
                    $memberName = (([PSCustomObject]$member) | Get-Member -MemberType NoteProperty).Name

                    $writer.WriteStartElement($memberName)

                    foreach($property in $member.$memberName)
                    {
                        $writer.WriteElementString('Name', $property.Name)

                        foreach($settingName in (([PSCustomObject]$property) | Get-Member -MemberType NoteProperty | Where-Object Name -ne Name).Name)
                        {
                            $settingValue = $property.$settingName

                            if($settingValue.IndexOf("`n") -gt 0)
                            {
                                $writer.WriteStartElement($settingName)
                                $writer.WriteCData($settingValue)
                                $writer.WriteEndElement()
                            }
                            else
                            {
                                $writer.WriteElementString($settingName, $settingValue)
                            }
                        }
                    }

                    $writer.WriteEndElement()
                }

                $writer.WriteEndElement()

            $writer.WriteEndElement()
        }

        $writer.WriteEndElement()
        $writer.WriteEndDocument()
        $writer.Flush()
        $writer.Close()
    }
}