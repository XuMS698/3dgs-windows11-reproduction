@echo off
setlocal EnableExtensions
REM ===========================================================================
REM  3DGS Windows build helper
REM  Builds the 3 CUDA submodules of gaussian-splatting:
REM    diff-gaussian-rasterization / simple-knn / fused-ssim
REM
REM  Prerequisites: conda env "gsplat" (python 3.10), VS2022 C++ tools,
REM                 CUDA Toolkit 11.8, torch cu118 installed in gsplat.
REM  Usage: double-click this file, or run it from any cmd window.
REM ===========================================================================

set "REPO=E:\gaussian-splatting"
set "CONDA_DIR=E:\miniconda3"
set "VCVARS=C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat"

if not exist "%REPO%\train.py" (
  echo [X] repo not found: %REPO%
  pause & exit /b 1
)
if not exist "%VCVARS%" (
  echo [X] MSVC not found: %VCVARS%
  pause & exit /b 1
)

echo [1/6] entering MSVC x64 environment ...
call "%VCVARS%" >nul 2>&1
where cl >nul 2>&1 || ( echo [X] cl.exe not on PATH, vcvars64.bat failed & pause & exit /b 1 )

echo [2/6] activating conda env "gsplat" ...
call "%CONDA_DIR%\condabin\conda.bat" activate gsplat
if errorlevel 1 ( echo [X] conda activate gsplat failed & pause & exit /b 1 )

REM --- build environment -----------------------------------------------------
REM DISTUTILS_USE_SDK : let setuptools use the vcvars SDK instead of scanning registry
REM TORCH_CUDA_ARCH_LIST : RTX 4060 = sm_89 -> build one arch only (much faster)
REM NVCC_PREPEND_FLAGS : tolerate MSVC 14.4x being newer than CUDA 11.8 expects
set "DISTUTILS_USE_SDK=1"
set "TORCH_CUDA_ARCH_LIST=8.9"
set "NVCC_PREPEND_FLAGS=-allow-unsupported-compiler"

cd /d "%REPO%"

if not defined CUDA_HOME (
  if exist "%ProgramFiles%\NVIDIA GPU Computing Toolkit\CUDA\v11.8\bin\nvcc.exe" set "CUDA_HOME=%ProgramFiles%\NVIDIA GPU Computing Toolkit\CUDA\v11.8"
)
if not defined CUDA_HOME (
  echo [X] CUDA Toolkit not found. Install CUDA 11.8 first, or set CUDA_HOME manually.
  pause & exit /b 1
)
echo       CUDA_HOME=%CUDA_HOME%

echo [3/6] checking torch / CUDA ...
python -c "import torch;print('  torch',torch.__version__,'| built for CUDA',torch.version.cuda,'| gpu ready:',torch.cuda.is_available())"
if errorlevel 1 ( echo [X] torch import failed & pause & exit /b 1 )

echo.
echo [4/6] building diff-gaussian-rasterization ^(slow, 3-8 min^) ...
python -m pip install --no-build-isolation --no-cache-dir "%REPO%\submodules\diff-gaussian-rasterization"
if errorlevel 1 goto fail

echo.
echo [5/6] building simple-knn and fused-ssim ...
python -m pip install --no-build-isolation --no-cache-dir "%REPO%\submodules\simple-knn"
if errorlevel 1 goto fail
python -m pip install --no-build-isolation --no-cache-dir "%REPO%\submodules\fused-ssim"
if errorlevel 1 goto fail

echo.
echo [6/6] verifying imports ...
python -c "from diff_gaussian_rasterization import GaussianRasterizer, SparseGaussianAdam; from simple_knn._C import distCUDA2; import fused_ssim; print('  ALL SUBMODULES OK')"
if errorlevel 1 goto fail

echo.
echo ================== BUILD SUCCESS ==================
echo  Next: python train.py -s data\nerf_synthetic\chair -m output\chair_7k --iterations 7000
echo ===================================================
pause & exit /b 0

:fail
echo.
echo ================== BUILD FAILED ===================
echo  Read the red error above, then:
echo  1^) "unsupported Microsoft Visual Studio version"
echo       -^> install MSVC v14.38 toolset in VS Installer, or
echo          edit each setup.py and append "-allow-unsupported-compiler" to
echo          extra_compile_args["nvcc"].
echo  2^) "cl.exe ... not found" / "command 'cl.exe' failed"
echo       -^> vcvars64.bat path is wrong for your VS install.
echo  3^) "No module named 'torch'" while building
echo       -^> you forgot --no-build-isolation, or the wrong env is active.
echo  4^) "detected CUDA version mismatches the version used to compile PyTorch"
echo       -^> torch and the CUDA Toolkit differ in major version; install
echo          torch cu118 to match CUDA 11.8.
echo  5^) "cannot open include file: 'cstdint'" (glm/MSVC)
echo       -^> set NVCC_PREPEND_FLAGS=-allow-unsupported-compiler -Xcompiler /std:c++17
echo ===================================================
pause & exit /b 1
