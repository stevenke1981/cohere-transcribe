param(
    [string]$LlamaCppDir = "vendor\llama.cpp",
    [string]$ModelPath,
    [string]$HfRepo,
    [string]$Host = "0.0.0.0",
    [int]$Port = 8080,
    [int]$ContextSize = 8192,
    [int]$Parallel = 1,
    [string]$GpuLayers = "auto"
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

function Resolve-LlamaServerExe {
    param([string]$BaseDir)

    $Candidates = @(
        (Join-Path $BaseDir "build\bin\Release\llama-server.exe"),
        (Join-Path $BaseDir "build\bin\llama-server.exe"),
        (Join-Path $BaseDir "bin\Release\llama-server.exe"),
        (Join-Path $BaseDir "bin\llama-server.exe")
    )

    foreach ($Candidate in $Candidates) {
        if (Test-Path $Candidate) {
            return (Resolve-Path $Candidate).Path
        }
    }

    throw "Could not find llama-server.exe under $BaseDir. Run scripts\deploy-stack.ps1 first."
}

function Get-LlamaBackendFromBuild {
    param([string]$BaseDir)

    $CacheFile = Join-Path $BaseDir "build\CMakeCache.txt"
    if (-not (Test-Path $CacheFile)) {
        return "cpu"
    }

    $CacheContent = Get-Content $CacheFile -Raw
    if ($CacheContent -match "GGML_CUDA:BOOL=ON") {
        return "cuda"
    }
    if ($CacheContent -match "GGML_VULKAN:BOOL=ON") {
        return "vulkan"
    }
    return "cpu"
}

if (-not $ModelPath -and -not $HfRepo) {
    throw "Provide either -ModelPath <gguf-path> or -HfRepo <huggingface-repo>."
}

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$LlamaCppDir = Resolve-AbsolutePath -BaseDir $RepoRoot -TargetPath $LlamaCppDir
$LlamaServerExe = Resolve-LlamaServerExe -BaseDir $LlamaCppDir
$ResolvedBackend = Get-LlamaBackendFromBuild -BaseDir $LlamaCppDir

$Args = @("--host", $Host, "--port", "$Port", "-c", "$ContextSize", "-np", "$Parallel")

if ($GpuLayers -eq "auto") {
    if ($ResolvedBackend -ne "cpu") {
        $Args += @("-ngl", "999")
    }
}
elseif ([int]$GpuLayers -gt 0) {
    $Args += @("-ngl", "$GpuLayers")
}

if ($ModelPath) {
    $ResolvedModelPath = (Resolve-Path $ModelPath).Path
    $Args = @("-m", $ResolvedModelPath) + $Args
}
else {
    $Args = @("-hf", $HfRepo) + $Args
}

Write-Host "Starting llama-server with arguments:" -ForegroundColor Cyan
Write-Host "Detected backend: $ResolvedBackend"
Write-Host ($Args -join " ")

& $LlamaServerExe @Args
