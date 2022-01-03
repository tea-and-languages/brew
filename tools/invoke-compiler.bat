@echo off
set ROOT=%~dp0

:: If `cl.exe` (the C/C++ compiler) is already available in our
:: current path, then we will go ahead and invoke it directly.
::
cl >nul 2>nul
if %errorlevel% NEQ 0 (
	goto SearchForCompiler
) else (
	goto Compile
)
:SearchForCompiler

:: Start by attempting to use `vswhere` to locate things.
set VSWHERE="C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe"
if exist "%VSWHERE%" (
	set VSPATH=
	for /F "delims=" %%F in ('%VSWHERE% -latest -property installationPath') do set VSPATH=%%F

	if exist "%VSPATH%" (
		call "%VSPATH%\VC\Auxiliary\Build\vcvarsall.bat" x86 >nul 2>nul
		goto Compile
	)
)

:: If we cannot find a Visual Studio installation via the most
:: recent mechanism(s), we will fall back to manually checking
:: certain paths supported by older versions.

:: TODO: Check for multiple VS versions
if exist "%VS140COMNTOOLS%VSVARS32.bat" (
	call "%VS140COMNTOOLS%VSVARS32.bat" >nul 2>nul
	goto Compile
)

if exist "%VS120COMNTOOLS%VSVARS32.bat" (
	call "%VS120COMNTOOLS%VSVARS32.bat" >nul 2>nul
	goto Compile
)

:: If none of our ad-hoc attempts succeeded in finding a Visual
:: Studio installation, we will fail with an error message.
::
echo "error: failed to find a Visual Studio compiler installation"
goto Error

:Compile
cl %*
goto Exit

:: We bottleneck all the error cases in our script to one case so that
:: we can conveniently set the error level on exit so that our script
:: is usable in other batch files.
::
:Error
set errorlevel=1

:Exit