foreach($func in (Get-ChildItem (Join-Path $PSScriptRoot 'Functions')))
{
    . $func.FullName
}