@echo off
echo ============================================
echo   Header Fix + Clean Build
echo ============================================
echo.

set "HEADER=C:\Users\barro\Desktop\Book\DigitalTwins\unreal-mcp\MCPGameProject\Plugins\UnrealMCP\Source\UnrealMCP\Public\Commands\UnrealMCPEditorCommands.h"
set "REPO=C:\Users\barro\Desktop\Book\DigitalTwins\unreal-mcp"

echo [1/4] Fixing header...
powershell -ExecutionPolicy Bypass -Command ^
 "$f='%HEADER%';$c=[System.IO.File]::ReadAllText($f);$c=$c -replace 'static TSharedPtr<FJsonObject> HandleSetActorMaterial\(const TSharedPtr<FJsonObject>\& Params\s*\r?\n','';$c=$c -replace 'static TSharedPtr<FJsonObject> HandleSetActorMaterial\(const TSharedPtr<FJsonObject>\& Params[^;]*','';$c=$c.Replace('TSharedPtr<FJsonObject> HandleFocusViewport(const TSharedPtr<FJsonObject>& Params);','TSharedPtr<FJsonObject> HandleFocusViewport(const TSharedPtr<FJsonObject>& Params);'+[Environment]::NewLine+'    TSharedPtr<FJsonObject> HandleSetActorMaterial(const TSharedPtr<FJsonObject>& Params);');if(($c -split 'HandleSetActorMaterial').Count -gt 2){$lines=$c -split [Environment]::NewLine;$seen=$false;$newlines=@();foreach($l in $lines){if($l -match 'HandleSetActorMaterial'){if($seen){continue}else{$seen=$true}};$newlines+=$l};$c=$newlines -join [Environment]::NewLine};[System.IO.File]::WriteAllText($f,$c);Write-Host '  Fixed.' -ForegroundColor Green"

echo.
echo [2/4] Verifying header...
powershell -ExecutionPolicy Bypass -Command ^
 "$c=[System.IO.File]::ReadAllText('%HEADER%');$count=([regex]::Matches($c,'HandleSetActorMaterial')).Count;Write-Host ('  HandleSetActorMaterial count: '+$count);if($count -eq 1){Write-Host '  PASS' -ForegroundColor Green}else{Write-Host '  FAIL' -ForegroundColor Red}"

echo.
echo [3/4] Showing header contents...
powershell -ExecutionPolicy Bypass -Command "Get-Content '%HEADER%'"

echo.
echo [4/4] Cleaning and launching...
if exist "%REPO%\MCPGameProject\Binaries" rmdir /s /q "%REPO%\MCPGameProject\Binaries"
if exist "%REPO%\MCPGameProject\Intermediate" rmdir /s /q "%REPO%\MCPGameProject\Intermediate"
echo   Cleaned. Launching project...
start "" "%REPO%\MCPGameProject\MCPGameProject.uproject"

echo.
echo   Click YES when UE5 asks to rebuild.
pause
