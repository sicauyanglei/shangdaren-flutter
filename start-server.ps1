$process = Start-Process -FilePath "python" -ArgumentList "-m", "http.server", "8080" -WorkingDirectory "E:\AI-PRJ\shangdaren-game\web" -PassThru -WindowStyle Hidden
Start-Sleep -Seconds 2
Start-Process "http://localhost:8080"
Write-Host "Server started on http://localhost:8080"
Write-Host "Process ID: $($process.Id)"
