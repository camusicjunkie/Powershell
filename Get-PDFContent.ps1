$script:dllPath = $MyInvocation.MyCommand.Path

function Get-PDFContent {
    param(
        # file name or url
        [Parameter(Mandatory=$true)]
        $Path
    )    
 
    $commandPath = Split-Path $dllPath
    Add-Type -Path "$($commandPath)/itextsharp.dll"

    $uri = $Path -as [System.URI]
    $testIsURI = $uri.AbsoluteURI -ne $null -and $uri.Scheme -match '[http|https]'

    if(!$testIsURI) {
        $Path = (Resolve-Path $Path).path
    }

    $reader = New-Object iTextSharp.text.pdf.PdfReader $Path
    $strategy = New-Object iTextSharp.text.pdf.parser.SimpleTextExtractionStrategy

    for ($i = 1; $i -lt $reader.NumberOfPages; $i++) {
        [iTextSharp.text.pdf.parser.PdfTextExtractor]::GetTextFromPage($reader, $i, $strategy)
    }

    $reader.Close()
}