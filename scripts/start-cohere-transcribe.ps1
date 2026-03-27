param(
    [string]$PythonExe = ".enuv\Scripts\python.exe",
    [string]$Host = "0.0.0.0",
    [int]$Port = 9000,
    [string]$ModelId = "CohereLabs/cohere-transcribe-03-2026",
    [string]$ModelPath = "",
    [string]$Language = "en",
    [string]$Device = "auto",
    [int]$BatchSize = 8,
    [ValidateSet("true", "false")][string]$LocalFilesOnly = "true",
    [switch]$AllowRemoteFallback,
    [switch]$CompileEncoder,
    [switch]$PipelineDetokenization
)

$ErrorActionPreference = "Stop"

function Resolve-AbsolutePath {
    param(
        [string]$BaseDir,
        [string]$TargetPath
    )

    if ([System.IO.Path]::IsPathRooted($TargetPath)) {
        return [System.IO.Path]::GetFullPath($TargetPath)
    }

    return [System.IO.Path]::GetFullPath((Join-Path $BaseDir $TargetPath))
}

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$PythonExe = Resolve-AbsolutePath -BaseDir $RepoRoot -TargetPath $PythonExe

if ([string]::IsNullOrWhiteSpace($ModelPath)) {
    $ModelPath = Join-Path $RepoRoot ("models\" + ($ModelId -replace "/", "--"))
}
else {
    $ModelPath = Resolve-AbsolutePath -BaseDir $RepoRoot -TargetPath $ModelPath
}

if (-not (Test-Path $PythonExe)) {
    throw "Python executable not found: $PythonExe. Run scripts\deploy-stack.ps1 first."
}

$env:PYTHONPATH = $RepoRoot
$env:COHERE_MODEL_ID = $ModelId
$env:COHERE_MODEL_PATH = $ModelPath
$env:COHERE_DEFAULT_LANGUAGE = $Language
$env:COHERE_DEVICE = $Device
$env:COHERE_BATCH_SIZE = "$BatchSize"
$env:COHERE_LOCAL_FILES_ONLY = $LocalFilesOnly
$env:COHERE_ALLOW_REMOTE_FALLBACK = if ($AllowRemoteFallback) { "true" } else { "false" }
$env:COHERE_COMPILE = if ($CompileEncoder) { "true" } else { "false" }
$env:COHERE_PIPELINE_DETOKENIZATION = if ($PipelineDetokenization) { "true" } else { "false" }

Write-Host "Starting Cohere Transcribe service on $Host`:$Port" -ForegroundColor Cyan
Write-Host "Model ID: $ModelId"
Write-Host "Model path: $ModelPath"
Write-Host "Language: $Language"
Write-Host "Device: $Device"
Write-Host "Local files only: $LocalFilesOnly"
Write-Host "Allow remote fallback: $($AllowRemoteFallback.IsPresent)"

& $PythonExe -m uvicorn app.cohere_server:app --host $Host --port $Port
