$ppt = New-Object -ComObject PowerPoint.Application
$pres = $ppt.Presentations.Add(1)
$slide = $pres.Slides.Add(1, 1)
$pres.SaveAs('C:\dev\zankoAI\scratch\native_ppt.pptx')
$pres.Close()
$ppt.Quit()
[System.Runtime.InteropServices.Marshal]::ReleaseComObject($ppt) | Out-Null
Write-Host "Native PPTX generated successfully!"
