param(
    [string]$Target = "template_debug",
    [int]$Jobs = 8
)

Push-Location "$PSScriptRoot/extension"
try {
    Write-Host "Building GDExtension with SCons ($Target, jobs: $Jobs)..." -ForegroundColor Cyan
    python -m SCons platform=windows target=$Target -j$Jobs
    if ($LASTEXITCODE -ne 0) {
        Write-Error "SCons build failed with exit code $LASTEXITCODE"
        exit $LASTEXITCODE
    }
    Write-Host "Build successful!" -ForegroundColor Green
}
finally {
    Pop-Location
}

