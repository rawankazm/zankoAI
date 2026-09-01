try {
    $ppt = New-Object -ComObject PowerPoint.Application
    Write-Host "PowerPoint Application version: $($ppt.Version)"
    $pres = $ppt.Presentations.Open("C:\dev\zankoAI\scratch\test_presentation.pptx", $false, $false, $false)
    Write-Host "SUCCESS! Slides count: $($pres.Slides.Count)"
    $pres.Close()
    $ppt.Quit()
    [System.Runtime.InteropServices.Marshal]::ReleaseComObject($ppt) | Out-Null
} catch {
    Write-Host "ERROR OPENING PPTX:"
    Write-Host $_.Exception.Message
    Write-Host $_.Exception.ToString()
}
