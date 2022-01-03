@echo off
:: brew.bat
::
:: This is a simple script to invoke the `brew` tool from a Windows command
:: prompt without having to explicitly compile the project.
::
:: As a user of the script, you should be able to invoke it *as if* it were
:: the `brew.exe` executable, and not care about the details of how an
:: executable gets created. Any arguments passed to the script file will
:: be passed along to the executable.
::

:: The basic setup is that we have a single file with our source code,
:: called `brew.cpp` that sits next to this script. The first time
:: the script is invoked, we want to compile that source file to produce
:: a `brew.exe` executable, and then invoke it.
::
:: On subsequent invocations of the script we want to detect if the
:: executable or the source file is newer. If the executable is newer,
:: then we want to invoke it directly without any build step. if the
:: source file is newer, we want to re-run the build.
::
:: Any errors during the build process should cause this script to
:: exit with an error (rather than run a stale executable).

:: We want to execute any build actions from within the directory where
:: this script (and the source code) reside, so we will switch into
:: that directory to make our lives easier.
::
set ROOT=%~dp0

:: In order to decide what to do, we need to detect whether the `brew.exe`
:: file exists *and* whether it is newer than the source file.
::
:: We will handle this by enumerating those two files (and just those files
:: with `dir` and setting it so that it lists them from oldest to newest).
:: We will update a single variable with each file that gets enumerated.
::
pushd "%ROOT%"
set SRCFILE=brew.cpp
set EXEFILE=brew.exe
set NEWFILE=
for /F %%F in ('dir /B /O:D %SRCFILE% %EXEFILE% 2^>nul') do set NEWFILE=%%F
popd

:: If the source file is newer than the executable (which also covers
:: the case where the executable didn't exist *at all* we want to jump
:: to our logic that will build things from source).
::
:: On the other side, if the executable file is the newer one, we can
:: just go and invoke it, which is the easiest case of all.
::
:: Finally, if we couldn't detect *either* file, somthing is wrong in
:: how things are currently set up, and we need to report that to
:: the user.
::
if "%NEWFILE%"=="%SRCFILE%" (
	goto Build
) else if "%NEWFILE%"=="%EXEFILE%" (
	goto Run
) else (
	echo brew.bat: error: couldn't find %EXEFILE% or %SRCFILE%
	goto Error
)

:Build
:: Since we are on Windows, try to build Mangle using Visual Studio

:: If `cl.exe` (the C/C++ compiler) is already available in our
:: current path, then we will go ahead and invoke it directly.
::
cl >nul 2>nul
if %errorlevel% NEQ 0 (
	goto AFTERCHECKCL
) else (
	goto Compile
)
:AFTERCHECKCL

:: Start by attempting to use `vswhere` to locate things.
set VSWHERE="C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe"
if exist "%VSWHERE%" (
	set VSPATH=
	for /F "delims=" %%F in ('%VSWHERE% -latest -property installationPath') do set VSPATH=%%F

	if exist "%VSPATH%" (
		call "%VSPATH%\VC\Auxiliary\Build\vcvarsall.bat" x86
		goto Compile
	)
)

:: If we cannot find a Visual Studio installation via the most
:: recent mechanism(s), we will fall back to manually checking
:: certain paths supported by older versions.

:: TODO: Check for multiple VS versions
if exist "%VS140COMNTOOLS%VSVARS32.bat" (
	call "%VS140COMNTOOLS%VSVARS32.bat"
	goto Compile
)

if exist "%VS120COMNTOOLS%VSVARS32.bat" (
	call "%VS120COMNTOOLS%VSVARS32.bat"
	goto Compile
)

:: If none of our ad-hoc attempts succeeded in finding a Visual
:: Studio installation, we will fail with an error message.
::
echo "brew.bat: error: failed to find a Visual Studio compiler installation"
goto Error

:: If we found a compiler that we can try to use, we will invoke
:: it to try to turn `brew.cpp` into `brew.exe`. If that attempt
:: fails (e.g., due to compile errors) then we will fail this script.
::
:: We will make sure to link in the `setargv.obj` file provided by
:: the compiler, since that is needed on Windows to get things like
:: typical wildcard handling in command-line argument lists.
::
:Compile
pushd "%ROOT%"
echo brew.bat: compiling %SRCFILE% into %EXEFILE%...
cl /nologo %SRCFILE% /link /out:%EXEFILE% setargv.obj
popd
if %errorlevel% NEQ 0 (
	echo brew.bat: compilation failed
	goto Exit
)
echo brew.bat: compilation succeeded

:: We will do our best to be tidy and get rid of the intermediate object
:: files that will be created during compilation.
::
pushd "%ROOT%"
del brew.obj
popd

:: If we either found a usable compiler and built things successfully,
:: *or* we had an up-to-date executable already sitting around, we
:: will run it and forward all the arguments from our script on to the
:: executable.
::
:Run
"%ROOT%/brew.exe" %*
goto Exit

:: We bottleneck all the error cases in our script to one case so that
:: we can conveniently set the error level on exit so that our script
:: is usable in other batch files.
::
:Error
set errorlevel=1

:Exit