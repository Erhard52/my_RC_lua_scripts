@echo off
setlocal enabledelayedexpansion

:: ============================================================
:: swapswitch.bat
:: Usage: swapswitch.bat <inputfile> <outputfile> <oldswitch> <newswitch>
:: Example: swapswitch.bat design.txt out.txt SA SB
:: ============================================================

:: --- Parameter validation ---
if "%~1"=="" goto usage
if "%~2"=="" goto usage
if "%~3"=="" goto usage
if "%~4"=="" goto usage

set "INFILE=%~1"
set "OUTFILE=%~2"
set "OLDSW=%~3"
set "NEWSW=%~4"

if not exist "%INFILE%" (
    echo ERROR: Input file "%INFILE%" not found.
    exit /b 1
)

:: --- Build all pattern variants (with and without leading !) ---
:: Switch format:  [!]Sx#   where x=letter, #=0..1..2
:: We replace both "!SA0"-style and "SA0"-style occurrences.

set "CHANGED=0"

:: Wipe output file
if exist "%OUTFILE%" del "%OUTFILE%"

echo.
echo Processing: %INFILE%
echo Replacing : %OLDSW% --^> %NEWSW%
echo ============================================================

for /f "usebackq delims=" %%L in ("%INFILE%") do (
    set "ORIG=%%L"
    set "LINE=%%L"

    :: Replace every digit suffix (0, 1, 2) and both ! prefixes
    :: Order: longer/prefixed forms first to avoid partial hits

    for %%D in (0 1 2) do (
        :: With leading !
        set "LINE=!LINE:^!!OLDSW%%%D=^!!NEWSW%%%D!"
        :: Without leading !
        set "LINE=!LINE:%OLDSW%%%D=%NEWSW%%%D%!"
    )

    :: Print before/after only when a change occurred
    if "!LINE!" neq "!ORIG!" (
        echo BEFORE: !ORIG!
        echo AFTER : !LINE!
        echo ------------------------------------------------------------
        set /a CHANGED+=1
    )

    echo !LINE!>> "%OUTFILE%"
)

echo ============================================================
echo Done. !CHANGED! line(s) modified.
echo Output written to: %OUTFILE%
echo.

:: --- Ask user whether to rename output to original filename ---
set /p "ANSWER=Rename output to original input filename "%INFILE%"? (y/n): "

if /i "!ANSWER!"=="y" (
    del "%INFILE%"
    ren "%OUTFILE%" "%~nx1"
    echo File renamed: "%OUTFILE%" -> "%INFILE%"
) else (
    echo Output kept as: %OUTFILE%
)

echo.
goto :eof

:usage
echo.
echo USAGE:   swapswitch.bat ^<inputfile^> ^<outputfile^> ^<oldswitch^> ^<newswitch^>
echo.
echo   inputfile   - path to the source file
echo   outputfile  - path for the modified output file
echo   oldswitch   - switch letter pair to find   (e.g. SA, SC)
echo   newswitch   - switch letter pair to replace (e.g. SB, SD)
echo.
echo SWITCH FORMAT recognised:  [!]Sx#
echo   !  optional leading exclamation mark
echo   S  always present
echo   x  capital letter  (supplied via oldswitch / newswitch)
echo   #  digit 0, 1, or 2
echo.
echo EXAMPLE:
echo   swapswitch.bat design.txt design_out.txt SA SB
echo   Replaces SA0, SA1, SA2, ^!SA0, ^!SA1, ^!SA2
echo         with SB0, SB1, SB2, ^!SB0, ^!SB1, ^!SB2
echo.
exit /b 1