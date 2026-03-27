param(
    [string]$PythonExe = "python",
    [string]$VenvDir = ".enuv",
    [string]$LlamaCppDir = "vendor\llama.cpp",
    [ValidateSet("auto", "cpu", "cuda", "vulkan")][string]$LlamaBackend = "auto",
    [switch]$SkipPythonSetup,
    [switch]$SkipLlamaBuild
)

$ErrorActionPreference = "Stop"

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Assert-Command {
    param([string]$Name)
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Required command not found: $Name"
    }
}

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

function Invoke-Checked {
    param(
        [string]$FilePath,
        [string[]]$Arguments,
        [string]$WorkingDirectory = $PWD.Path
    )

    Push-Location $WorkingDirectory
    try {
        & $FilePath @Arguments
        if ($LASTEXITCODE -ne 0) {
            throw "Command failed: $FilePath $($Arguments -join ' ')"
        }
    }
    finally {
        Pop-Location
    }
}

function Resolve-LlamaBackend {
    param([string]$RequestedBackend)

    if ($RequestedBackend -ne "auto") {
        return $RequestedBackend
    }

    if ((Get-Command nvcc -ErrorAction SilentlyContinue) -or $env:CUDA_PATH -or $env:CUDAToolkit_ROOT) {
        return "cuda"
    }

    if ($env:VULKAN_SDK -or (Get-Command vulkaninfo -ErrorAction SilentlyContinue)) {
        return "vulkan"
    }

    return "cpu"
}

function Install-Torch {
    param([string]$PythonPath)

    $TorchArgs = @("-m", "pip", "install")
    $CanTryCudaTorch = (Get-Command nvidia-smi -ErrorAction SilentlyContinue) -or (Get-Command nvcc -ErrorAction SilentlyContinue) -or $env:CUDA_PATH

    if ($CanTryCudaTorch) {
        Write-Step "Installing GPU-first PyTorch (CUDA), fallback to CPU on failure"
        try {
            Invoke-Checked $PythonPath ($TorchArgs + @("torch", "--index-url", "https://download.pytorch.org/whl/cu124")) $RepoRoot
            return
        }
        catch {
            Write-Warning "CUDA PyTorch install failed, falling back to CPU/default torch."
        }
    }

    Write-Step "Installing CPU/default PyTorch"
    Invoke-Checked $PythonPath ($TorchArgs + @("torch")) $RepoRoot
}

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$VenvDir = Resolve-AbsolutePath -BaseDir $RepoRoot -TargetPath $VenvDir
$LlamaCppDir = Resolve-AbsolutePath -BaseDir $RepoRoot -TargetPath $LlamaCppDir

if (-not $SkipPythonSetup) {
    Write-Step "Creating Python virtual environment"
    Invoke-Checked $PythonExe @("-m", "venv", $VenvDir) $RepoRoot

    $VenvPython = Join-Path $VenvDir "Scripts\python.exe"
    if (-not (Test-Path $VenvPython)) {
        throw "Virtual environment python not found: $VenvPython"
    }

    Write-Step "Installing Cohere Transcribe dependencies"
    Invoke-Checked $VenvPython @("-m", "pip", "install", "--upgrade", "pip", "setuptools", "wheel") $RepoRoot
    Install-Torch -PythonPath $VenvPython
    Invoke-Checked $VenvPython @("-m", "pip", "install", "-r", "requirements.txt") $RepoRoot
}

if (-not $SkipLlamaBuild) {
    Assert-Command git
    Assert-Command cmake

    $ResolvedLlamaBackend = Resolve-LlamaBackend -RequestedBackend $LlamaBackend

    Write-Step "Preparing llama.cpp source"
    if (-not (Test-Path $LlamaCppDir)) {
        $ParentDir = Split-Path -Parent $LlamaCppDir
        if (-not (Test-Path $ParentDir)) {
            New-Item -ItemType Directory -Path $ParentDir | Out-Null
        }
        Invoke-Checked "git" @("clone", "--depth", "1", "https://github.com/ggml-org/llama.cpp.git", $LlamaCppDir) $RepoRoot
    }
    else {
        Invoke-Checked "git" @("-C", $LlamaCppDir, "pull", "--ff-only") $RepoRoot
    }

    $BuildDir = Join-Path $LlamaCppDir "build"
    $CmakeArgs = @("-S", $LlamaCppDir, "-B", $BuildDir)
    switch ($ResolvedLlamaBackend) {
        "cuda" { $CmakeArgs += "-DGGML_CUDA=ON" }
        "vulkan" { $CmakeArgs += "-DGGML_VULKAN=ON" }
        default { }
    }

    Write-Step "Configuring llama.cpp build ($ResolvedLlamaBackend)"
    Invoke-Checked "cmake" $CmakeArgs $RepoRoot

    Write-Step "Building llama-server"
    Invoke-Checked "cmake" @("--build", $BuildDir, "--config", "Release", "--target", "llama-server") $RepoRoot
}

Write-Step "Completed"
Write-Host "Next steps:"
Write-Host "  1. Start llama.cpp:        .\scripts\start-llama-server.ps1 ..."
Write-Host "  2. Start Cohere service:   .\scripts\start-cohere-transcribe.ps1 ..."
