$ErrorActionPreference = "Stop"
Set-Location -LiteralPath $PSScriptRoot
python -m scripts.download_models
if ($LASTEXITCODE -ne 0) { throw "Model download failed." }
$env:HD_PRELOAD = "1"
python -m uvicorn main:app --app-dir backend --host 127.0.0.1 --port 8000
