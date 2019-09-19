Function Export-PsFormatXml
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
        if(-not $PSCmdlet.ShouldProcess($DestinationFile, "Create '*.format.ps1xml' file"))
        {
            return
        }

        Write-Verbose "Processing input directory $InputDirectory"

        [System.XML.XmlWriter] $writer = [System.XML.XmlWriter]::Create($DestinationFile, `
            (New-Object 'System.Xml.XmlWriterSettings' -Property @{
                Encoding = [System.Text.Encoding]::GetEncoding($OutputEncoding)
                Indent = $true
                IndentChars = '  '
                NewLineChars = "`n"
                NewLineHandling = 'Replace'
            })
        )

        $xmlDocument = [xml] '<Configuration/>'

        foreach($formatFile in (Get-ChildItem $InputDirectory -File -Recurse))
        {
            Write-Verbose "Exporting file $formatFile"

            $yml = (Get-Content $formatFile.FullName -Encoding $InputEncoding -Raw | ConvertFrom-Yaml -Ordered)

            $fileType = $formatFile.Name.Split('.')[-2]

            if($fileType -eq $formatFile.BaseName)
            {
                $itemName = $fileType
            }
            else
            {
                $itemName = $formatFile.BaseName.Substring(0, $formatFile.BaseName.Length - $fileType.Length - 1)
            }

            _Export $xmlDocument $yml $itemName $fileType
        }

        $xmlDocument.WriteTo($writer)        
        $writer.Flush()
        $writer.Close()
    }
}

Function _Export([xml]$doc, $yml, $itemName, $itemType)
{
    $exporter = "_Export$itemType"

    if(-not (Test-Path "function:$exporter"))
    {
        Write-Warning "Unknown file type '$fileType' found while processing '$($formatFile.FullName)'. Ignoring."
        continue
    }

    $rootNodeName = _GetRootNodeName $itemType

    $rootNode = $doc.DocumentElement.SelectSingleNode($rootNodeName)

    if(-not $rootNode)
    {
        $rootNode = $doc.DocumentElement.AppendChild($doc.CreateElement($rootNodeName))
    }

    if($yml.Passthru)
    {
        $fragment = $doc.CreateDocumentFragment()
        $fragment.InnerXml = $yml.Passthru
        $itemElem = $fragment

        [void] $rootNode.AppendChild($itemElem)

        return
    }

    & $exporter $doc $yml $itemName $rootNode
}

Function _ExportView([xml]$doc, $yml, $itemName, $rootNode)
{
    $viewElem = $doc.CreateElement('View')
    $rootNode.AppendChild($viewElem).AppendChild($doc.CreateElement('Name')).InnerText = $itemName

    foreach($prop in $yml.Keys)
    {
        $exporter = "_ExportView_$prop"

        if(-not (Test-Path "function:$exporter"))
        {
            Write-Warning "Unknown YAML element '$prop' while processing '$itemName'"
            continue
        }

        & $exporter $doc $yml[$prop] $viewElem
    }
}

Function _ExportView_ViewSelectedBy([xml]$doc, $data, $rootNode)
{
    $viewSelectedByElem = $rootNode.AppendChild($doc.CreateElement('ViewSelectedBy'))

    foreach($name in $data)
    {
        $viewSelectedByElem.AppendChild($doc.CreateElement('TypeName')).InnerText = $name
    }
}

Function _ExportView_GroupBy([xml]$doc, $data, $rootNode)
{
    $groupByElem = $rootNode.AppendChild($doc.CreateElement('GroupBy'))

    foreach($item in $data.Keys)
    {
        $groupByElem.AppendChild($doc.CreateElement($item)).InnerText = $data[$item]
    }
}

Function _ExportView_TableControl([xml]$doc, $data, $rootNode)
{
    $tableControlElem = $rootNode.AppendChild($doc.CreateElement('TableControl'))
    $headersElem = $tableControlElem.AppendChild($doc.CreateElement('TableHeaders'))
    $rowsElem = $tableControlElem.AppendChild($doc.CreateElement('TableRowEntries')). `
        AppendChild($doc.CreateElement('TableRowEntry')). `
        AppendChild($doc.CreateElement('TableColumnItems'))

    foreach($col in $data.Keys)
    {
        $colData = $data[$col]
        $headerElem = $headersElem.AppendChild($doc.CreateElement('TableColumnHeader'))
        $rowElem = $rowsElem.AppendChild($doc.CreateElement('TableColumnItem'))
    
        foreach($colProp in $colData.Keys)
        {
            switch ($colProp) {
                {$_ -in 'Label', 'Width'} {
                    $headerElem.AppendChild($doc.CreateElement($colProp)).InnerText = $colData[$colProp]
                }
                Default {
                    $rowElem.AppendChild($doc.CreateElement($colProp)).InnerText = $colData[$colProp]
                }
            }
        }

        if(-not $headerElem.SelectSingleNode('Label'))
        {
            ($labelElem = $doc.CreateElement('Label')).InnerText = $col

            if($headerElem.ChildNodes -eq 0)
            {
                [void] $headerElem.AppendChild($labelElem)
            }
            else
            {
                [void] $headerElem.InsertBefore($labelElem, $headerElem.FirstChild)
            }
        }

        if($rowElem.SelectNodes('PropertyName|ScriptBlock').Count -eq 0)
        {
            $rowElem.AppendChild($doc.CreateElement('PropertyName')).InnerText = $col
        }
    }
}

Function _ExportControl([xml]$doc, $yml, $itemName, $rootNode)
{
}

Function _GetRootNodeName($itemType)
{
    switch($itemType)
    {
        'View' {
            return 'ViewDefinitions'
        }
        'Control' {
            return 'Controls'
        }
        else {
            throw "Unknown item type '$itemType'"
        }
    }
}