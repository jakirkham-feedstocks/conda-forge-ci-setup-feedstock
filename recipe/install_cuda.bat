set "CUDA_VERSION=%1"

:: We define a default subset of components to be installed for faster installation times
:: and reduced storage usage (CI is limited to 10GB). Full list of components is available at
:: https://docs.nvidia.com/cuda/archive/%CUDA_VERSION%/cuda-installation-guide-microsoft-windows/index.html
set "VAR=nvcc_%CUDA_VERSION% cuobjdump_%CUDA_VERSION% nvprune_%CUDA_VERSION% cupti_%CUDA_VERSION%"
set "VAR=%VAR% memcheck_%CUDA_VERSION% nvdisasm_%CUDA_VERSION% nvprof_%CUDA_VERSION% cublas_%CUDA_VERSION%"
set "VAR=%VAR% cublas_dev_%CUDA_VERSION% cudart_%CUDA_VERSION% cufft_%CUDA_VERSION% cufft_dev_%CUDA_VERSION%"
set "VAR=%VAR% curand_%CUDA_VERSION% curand_dev_%CUDA_VERSION% cusolver_%CUDA_VERSION% cusolver_dev_%CUDA_VERSION%"
set "VAR=%VAR% cusparse_%CUDA_VERSION% cusparse_dev_%CUDA_VERSION% npp_%CUDA_VERSION% npp_dev_%CUDA_VERSION%"
set "VAR=%VAR% nvrtc_%CUDA_VERSION% nvrtc_dev_%CUDA_VERSION% nvml_dev_%CUDA_VERSION%"
set "VAR=%VAR% visual_studio_integration_%CUDA_VERSION%"
set "CUDA_COMPONENTS=%VAR%"

if "%CUDA_VERSION%" == "11.8" goto cuda118

echo CUDA '%CUDA_VERSION%' is not supported
exit /b 1

:: Define URLs per version
:cuda118
set "CUDA_NETWORK_INSTALLER_URL=https://developer.download.nvidia.com/compute/cuda/11.8.0/network_installers/cuda_11.8.0_windows_network.exe"
set "CUDA_NETWORK_INSTALLER_CHECKSUM=600ca859835a37395277a5f3a5b6037d"
set "CUDA_INSTALLER_URL=https://developer.download.nvidia.com/compute/cuda/11.8.0/local_installers/cuda_11.8.0_522.06_windows.exe"
set "CUDA_INSTALLER_CHECKSUM=894c61ba173d26dc667e95ee734d3c5a"
set "CUDA_COMPONENTS=%CUDA_COMPONENTS% nsight_nvtx_%CUDA_VERSION% cuda_profiler_api_%CUDA_VERSION% thrust_%CUDA_VERSION%"
goto cuda_common


:: The actual installation logic
:cuda_common

::We expect this CUDA_PATH
set "CUDA_PATH=C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v%CUDA_VERSION%"

echo Downloading CUDA version %CUDA_VERSION% installer from %CUDA_INSTALLER_URL%
echo Expected MD5: %CUDA_INSTALLER_CHECKSUM%

:: Download installer
curl --retry 3 -k -L %CUDA_INSTALLER_URL% --output cuda_installer.exe
if errorlevel 1 (
    echo Problem downloading installer...
    exit /b 1
)
:: Check md5
openssl md5 cuda_installer.exe | findstr %CUDA_INSTALLER_CHECKSUM%
if errorlevel 1 (
    echo Checksum does not match!
    exit /b 1
)
:: Run installer
start /wait cuda_installer.exe -s %CUDA_COMPONENTS%
if errorlevel 1 (
    echo Problem installing CUDA toolkit...
    exit /b 1
)
del cuda_installer.exe

:: If patches are needed, download and apply
if not "%CUDA_PATCH_URL%"=="" (
    echo This version requires an additional patch
    curl --retry 3 -k -L %CUDA_PATCH_URL% --output cuda_patch.exe
    if errorlevel 1 (
        echo Problem downloading patch installer...
        exit /b 1
    )
    openssl md5 cuda_patch.exe | findstr %CUDA_PATCH_CHECKSUM%
    if errorlevel 1 (
        echo Checksum does not match!
        exit /b 1
    )
    start /wait cuda_patch.exe -s
    if errorlevel 1 (
        echo Problem running patch installer...
        exit /b 1
    )
    del cuda_patch.exe
)

:: This should exist by now!
if not exist "%CUDA_PATH%\bin\nvcc.exe" (
    echo CUDA toolkit installation failed!
    exit /b 1
)

:: Notes about nvcuda.dll
:: ----------------------
:: We should also provide the drivers (nvcuda.dll), but the installer will not
:: proceed without a physical Nvidia card attached (not the case in the CI).
:: Expanding `<installer.exe>\Display.Driver\nvcuda.64.dl_` to `C:\Windows\System32`
:: does not work anymore (.dl_ files are not PE-COFF according to Dependencies.exe).
:: Forcing this results in a DLL error 193. Basically, there's no way to provide
:: ncvuda.dll in a GPU-less machine without breaking the EULA (aka zipping nvcuda.dll
:: from a working installation).
