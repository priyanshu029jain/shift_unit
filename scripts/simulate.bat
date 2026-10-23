@echo off
rem Compile and run a module's directed testbench, then open the waveform in GTKWave.
rem Windows version of simulate.sh.
rem
rem Usage: simulate <module> [WIDTH]
rem   simulate barrel_shifter
rem   simulate logical_shift_unit 8
rem (from PowerShell, in the repo root: .\scripts\simulate barrel_shifter)
rem
rem Set NO_WAVE=1 to run the simulation without opening GTKWave.

setlocal EnableExtensions EnableDelayedExpansion

rem The repo root is one level above scripts\
set "ROOT=%~dp0..\"
if "%~1"=="" goto usage
if not "%~3"=="" goto usage

set "MODULE=%~1"
rem allow tab-completed ".\barrel_shifter\" or "barrel_shifter/"
if "!MODULE:~0,2!"==".\" set "MODULE=!MODULE:~2!"
if "!MODULE:~0,2!"=="./" set "MODULE=!MODULE:~2!"
if "!MODULE:~-1!"=="\" set "MODULE=!MODULE:~0,-1!"
if "!MODULE:~-1!"=="/" set "MODULE=!MODULE:~0,-1!"

set "WIDTH=%~2"
set "DIR=%ROOT%%MODULE%"
set "TB=%MODULE%_directed_tb"

if not exist "%DIR%\%MODULE%.v" goto unknown
if not exist "%DIR%\%TB%.v" goto unknown

set "PARAMS="
if "%WIDTH%"=="" goto widthok
echo %WIDTH%| findstr /r "^[0-9][0-9]*$" >nul || goto badwidth
if %WIDTH% LSS 2 goto badwidth
set "PARAMS=-P %TB%.WIDTH=%WIDTH%"
:widthok

rem OSS CAD Suite tools need its lib\ folder on PATH, which its environment.bat
rem sets up. If iverilog comes from OSS CAD Suite and that hasn't been run, run it.
if defined YOSYSHQ_ROOT goto envok
for /f "delims=" %%P in ('where iverilog 2^>nul') do if not defined IVL_DIR set "IVL_DIR=%%~dpP"
if not defined IVL_DIR goto envok
if exist "%IVL_DIR%..\environment.bat" call "%IVL_DIR%..\environment.bat" >nul 2>&1
:envok

for %%T in (iverilog vvp) do (
    where %%T >nul 2>&1 || (echo Error: '%%T' not found in PATH & exit /b 1)
)

pushd "%DIR%"

if "%WIDTH%"=="" (echo ==^> Compiling %MODULE%) else (echo ==^> Compiling %MODULE% ^(WIDTH=%WIDTH%^))
iverilog %PARAMS% -o "%TB%.vvp" "%MODULE%.v" "%TB%.v" || (popd & exit /b 1)

echo ==^> Simulating
vvp "%TB%.vvp" || (popd & exit /b 1)

if "%NO_WAVE%"=="1" (
    echo ==^> Waveform written to %MODULE%\%TB%.vcd
    popd & exit /b 0
)

where gtkwave >nul 2>&1 || (
    echo ==^> GTKWave not found in PATH; waveform written to %MODULE%\%TB%.vcd
    popd & exit /b 0
)

echo ==^> Opening %MODULE%\%TB%.vcd in GTKWave
start "" gtkwave "%TB%.vcd"
popd
exit /b 0

:badwidth
echo Error: WIDTH must be a number ^>= 2 (got '%WIDTH%')
exit /b 1

:unknown
echo Error: unknown module '%MODULE%'
echo.

:usage
echo Usage: simulate ^<module^> [WIDTH]
echo.
echo Modules:
for /d %%D in ("%ROOT%*") do (
    if exist "%%D\%%~nxD_directed_tb.v" echo   %%~nxD
)
exit /b 1
