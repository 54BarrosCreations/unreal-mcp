@echo off
echo ============================================
echo   Complete Build Fixer
echo ============================================
echo.

set "REPO=%~dp0"
set "HEADER=%REPO%MCPGameProject\Plugins\UnrealMCP\Source\UnrealMCP\Public\Commands\UnrealMCPEditorCommands.h"
set "CPP=%REPO%MCPGameProject\Plugins\UnrealMCP\Source\UnrealMCP\Private\Commands\UnrealMCPEditorCommands.cpp"
set "BIN=%REPO%MCPGameProject\Binaries"
set "INT=%REPO%MCPGameProject\Intermediate"
set "UPROJ=%REPO%MCPGameProject\MCPGameProject.uproject"

echo [1/6] Checking files exist...
if not exist "%HEADER%" (
    echo   ERROR: Header not found at %HEADER%
    pause
    exit /b 1
)
if not exist "%CPP%" (
    echo   ERROR: Cpp not found at %CPP%
    pause
    exit /b 1
)
if not exist "%UPROJ%" (
    echo   ERROR: .uproject not found at %UPROJ%
    pause
    exit /b 1
)
echo   All files found.

echo.
echo [2/6] Patching header with HandleSetActorMaterial...
powershell -ExecutionPolicy Bypass -Command ^
  "$f='%HEADER%'; $c=Get-Content $f -Raw; if($c -match 'HandleSetActorMaterial'){Write-Host '  Already in header.' -ForegroundColor Gray} else { $c=$c.Replace('static TSharedPtr<FJsonObject> HandleTakeScreenshot','static TSharedPtr<FJsonObject> HandleSetActorMaterial(const TSharedPtr<FJsonObject>& Params);'+\"`r`n`t\"+'static TSharedPtr<FJsonObject> HandleTakeScreenshot'); [System.IO.File]::WriteAllText($f,$c); Write-Host '  Patched.' -ForegroundColor Green }"

echo.
echo [3/6] Verifying header saved correctly...
powershell -ExecutionPolicy Bypass -Command ^
  "$m=Select-String 'HandleSetActorMaterial' '%HEADER%'; if($m){Write-Host '  PASS: HandleSetActorMaterial found in header' -ForegroundColor Green} else {Write-Host '  FAIL: NOT found - open header manually and add it' -ForegroundColor Red; exit 1}"
if errorlevel 1 (
    echo.
    echo   Opening header in notepad for manual edit...
    echo   Add this line above HandleTakeScreenshot:
    echo   static TSharedPtr^<FJsonObject^> HandleSetActorMaterial(const TSharedPtr^<FJsonObject^>^& Params);
    notepad "%HEADER%"
    pause
    exit /b 1
)

echo.
echo [4/6] Verifying cpp has all features...
powershell -ExecutionPolicy Bypass -Command ^
  "$c=Get-Content '%CPP%' -Raw; $ok=$true; foreach($p in @('mesh_path','material_path','HandleSetActorMaterial','TextRenderActor','ASkyLight','set_actor_material')){$found=$c -match $p; $status=if($found){'PASS'}else{'FAIL'; $script:ok=$false}; $color=if($found){'Green'}else{'Red'}; Write-Host ('  {0,-30} [{1}]' -f $p,$status) -ForegroundColor $color}"

echo.
echo [5/6] Cleaning build artifacts...
if exist "%BIN%" (
    rmdir /s /q "%BIN%"
    echo   Deleted Binaries
) else (
    echo   Binaries already clean
)
if exist "%INT%" (
    rmdir /s /q "%INT%"
    echo   Deleted Intermediate
) else (
    echo   Intermediate already clean
)

echo.
echo [6/6] Launching project (generates VS files on first open)...
echo   Opening: %UPROJ%
start "" "%UPROJ%"

echo.
echo ============================================
echo   Done. UE5 is opening.
echo   When prompted to rebuild, click YES.
echo   After it compiles, check Output Log for:
echo     MCP TCP Server started on port 55557
echo ============================================
echo.
pause
