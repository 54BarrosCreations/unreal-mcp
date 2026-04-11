Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Chapter 2 Feature Patch" -ForegroundColor Cyan
Write-Host "  Adds: mesh_path, material_path," -ForegroundColor Cyan
Write-Host "  Cube/Sphere/Plane shortcuts," -ForegroundColor Cyan
Write-Host "  TextRenderActor, SkyLight," -ForegroundColor Cyan
Write-Host "  set_actor_material command" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

$scriptDir = $PSScriptRoot
if (-not $scriptDir) { $scriptDir = $env:SETUP_DIR }
if (-not $scriptDir) { $scriptDir = $PWD.Path }
$scriptDir = $scriptDir.TrimEnd('\')

# Find plugin source
$plugin = $null
foreach ($candidate in @(
    (Join-Path $scriptDir "MCPGameProject\Plugins\UnrealMCP\Source\UnrealMCP\Private"),
    (Join-Path $scriptDir "Plugins\UnrealMCP\Source\UnrealMCP\Private"),
    (Join-Path $scriptDir "unreal-mcp\MCPGameProject\Plugins\UnrealMCP\Source\UnrealMCP\Private")
)) {
    if (Test-Path (Join-Path $candidate "Commands\UnrealMCPEditorCommands.cpp")) {
        $plugin = $candidate
        break
    }
}

if (-not $plugin) {
    Write-Host "ERROR: Cannot find UnrealMCPEditorCommands.cpp" -ForegroundColor Red
    Write-Host "Run this script from the unreal-mcp root folder." -ForegroundColor Red
    Read-Host "Press Enter to exit"; exit 1
}

Write-Host "Found plugin at: $plugin" -ForegroundColor Green
Write-Host ""

$editorFile = Join-Path $plugin "Commands\UnrealMCPEditorCommands.cpp"
$editorHeader = Join-Path $plugin "Commands\UnrealMCPEditorCommands.h"

# ═══════════════════════════════════════════
# PATCH 1: Add includes for new actor types
# ═══════════════════════════════════════════
Write-Host "[1/4] Adding includes..." -ForegroundColor Yellow
$content = Get-Content $editorFile -Raw

# Add TextRenderActor and SkyLight includes if not already present
if ($content -notmatch 'TextRenderActor') {
    $content = $content -replace '(#include "Camera/CameraActor.h")', "`$1`r`n#include ""Engine/TextRenderActor.h""`r`n#include ""Components/TextRenderComponent.h""`r`n#include ""Engine/SkyLight.h""`r`n#include ""EditorAssetLibrary.h"""
    Write-Host "  Added TextRenderActor, SkyLight, EditorAssetLibrary includes" -ForegroundColor Green
} else {
    Write-Host "  Includes already present" -ForegroundColor Gray
}

# ═══════════════════════════════════════════
# PATCH 2: Replace HandleSpawnActor with enhanced version
# ═══════════════════════════════════════════
Write-Host "[2/4] Enhancing spawn_actor with mesh_path, material_path, new types..." -ForegroundColor Yellow

# Find and replace the HandleSpawnActor function
# We'll replace from the function signature to the closing of "Failed to create actor" return
$spawnPattern = '(?s)(TSharedPtr<FJsonObject> FUnrealMCPEditorCommands::HandleSpawnActor\(const TSharedPtr<FJsonObject>& Params\)\s*\{.*?return FUnrealMCPCommonUtils::CreateErrorResponse\(TEXT\("Failed to create actor"\)\);\s*\})'

$spawnReplacement = @'
TSharedPtr<FJsonObject> FUnrealMCPEditorCommands::HandleSpawnActor(const TSharedPtr<FJsonObject>& Params)
{
    // Get required parameters
    FString ActorType;
    if (!Params->TryGetStringField(TEXT("type"), ActorType))
    {
        return FUnrealMCPCommonUtils::CreateErrorResponse(TEXT("Missing 'type' parameter"));
    }

    // Get actor name (required parameter)
    FString ActorName;
    if (!Params->TryGetStringField(TEXT("name"), ActorName))
    {
        return FUnrealMCPCommonUtils::CreateErrorResponse(TEXT("Missing 'name' parameter"));
    }

    // Get optional transform parameters
    FVector Location(0.0f, 0.0f, 0.0f);
    FRotator Rotation(0.0f, 0.0f, 0.0f);
    FVector Scale(1.0f, 1.0f, 1.0f);

    if (Params->HasField(TEXT("location")))
    {
        Location = FUnrealMCPCommonUtils::GetVectorFromJson(Params, TEXT("location"));
    }
    if (Params->HasField(TEXT("rotation")))
    {
        Rotation = FUnrealMCPCommonUtils::GetRotatorFromJson(Params, TEXT("rotation"));
    }
    if (Params->HasField(TEXT("scale")))
    {
        Scale = FUnrealMCPCommonUtils::GetVectorFromJson(Params, TEXT("scale"));
    }

    // Get optional mesh_path and material_path
    FString MeshPath;
    Params->TryGetStringField(TEXT("mesh_path"), MeshPath);
    FString MaterialPath;
    Params->TryGetStringField(TEXT("material_path"), MaterialPath);

    // Create the actor based on type
    AActor* NewActor = nullptr;
    UWorld* World = GEditor->GetEditorWorldContext().World();

    if (!World)
    {
        return FUnrealMCPCommonUtils::CreateErrorResponse(TEXT("Failed to get editor world"));
    }

    // Check if an actor with this name already exists
    TArray<AActor*> AllActors;
    UGameplayStatics::GetAllActorsOfClass(World, AActor::StaticClass(), AllActors);
    for (AActor* Actor : AllActors)
    {
        if (Actor && Actor->GetName() == ActorName)
        {
            return FUnrealMCPCommonUtils::CreateErrorResponse(FString::Printf(TEXT("Actor with name '%s' already exists"), *ActorName));
        }
    }

    FActorSpawnParameters SpawnParams;
    SpawnParams.Name = *ActorName;

    // Basic shape shortcuts - auto-assign mesh_path
    if (ActorType == TEXT("Cube") || ActorType == TEXT("cube"))
    {
        ActorType = TEXT("StaticMeshActor");
        if (MeshPath.IsEmpty()) MeshPath = TEXT("/Engine/BasicShapes/Cube.Cube");
    }
    else if (ActorType == TEXT("Sphere") || ActorType == TEXT("sphere"))
    {
        ActorType = TEXT("StaticMeshActor");
        if (MeshPath.IsEmpty()) MeshPath = TEXT("/Engine/BasicShapes/Sphere.Sphere");
    }
    else if (ActorType == TEXT("Cylinder") || ActorType == TEXT("cylinder"))
    {
        ActorType = TEXT("StaticMeshActor");
        if (MeshPath.IsEmpty()) MeshPath = TEXT("/Engine/BasicShapes/Cylinder.Cylinder");
    }
    else if (ActorType == TEXT("Plane") || ActorType == TEXT("plane"))
    {
        ActorType = TEXT("StaticMeshActor");
        if (MeshPath.IsEmpty()) MeshPath = TEXT("/Engine/BasicShapes/Plane.Plane");
    }
    else if (ActorType == TEXT("Cone") || ActorType == TEXT("cone"))
    {
        ActorType = TEXT("StaticMeshActor");
        if (MeshPath.IsEmpty()) MeshPath = TEXT("/Engine/BasicShapes/Cone.Cone");
    }

    if (ActorType == TEXT("StaticMeshActor"))
    {
        NewActor = World->SpawnActor<AStaticMeshActor>(AStaticMeshActor::StaticClass(), Location, Rotation, SpawnParams);
        
        // Set mesh if mesh_path provided
        if (NewActor && !MeshPath.IsEmpty())
        {
            AStaticMeshActor* MeshActor = Cast<AStaticMeshActor>(NewActor);
            if (MeshActor && MeshActor->GetStaticMeshComponent())
            {
                UStaticMesh* Mesh = Cast<UStaticMesh>(UEditorAssetLibrary::LoadAsset(MeshPath));
                if (Mesh)
                {
                    MeshActor->GetStaticMeshComponent()->SetStaticMesh(Mesh);
                }
                else
                {
                    UE_LOG(LogTemp, Warning, TEXT("Failed to load mesh: %s"), *MeshPath);
                }
            }
        }
        
        // Set material if material_path provided
        if (NewActor && !MaterialPath.IsEmpty())
        {
            AStaticMeshActor* MeshActor = Cast<AStaticMeshActor>(NewActor);
            if (MeshActor && MeshActor->GetStaticMeshComponent())
            {
                UMaterialInterface* Material = Cast<UMaterialInterface>(UEditorAssetLibrary::LoadAsset(MaterialPath));
                if (Material)
                {
                    MeshActor->GetStaticMeshComponent()->SetMaterial(0, Material);
                }
                else
                {
                    UE_LOG(LogTemp, Warning, TEXT("Failed to load material: %s"), *MaterialPath);
                }
            }
        }
    }
    else if (ActorType == TEXT("PointLight"))
    {
        NewActor = World->SpawnActor<APointLight>(APointLight::StaticClass(), Location, Rotation, SpawnParams);
    }
    else if (ActorType == TEXT("SpotLight"))
    {
        NewActor = World->SpawnActor<ASpotLight>(ASpotLight::StaticClass(), Location, Rotation, SpawnParams);
    }
    else if (ActorType == TEXT("DirectionalLight"))
    {
        NewActor = World->SpawnActor<ADirectionalLight>(ADirectionalLight::StaticClass(), Location, Rotation, SpawnParams);
    }
    else if (ActorType == TEXT("CameraActor"))
    {
        NewActor = World->SpawnActor<ACameraActor>(ACameraActor::StaticClass(), Location, Rotation, SpawnParams);
    }
    else if (ActorType == TEXT("SkyLight"))
    {
        NewActor = World->SpawnActor<ASkyLight>(ASkyLight::StaticClass(), Location, Rotation, SpawnParams);
    }
    else if (ActorType == TEXT("TextRenderActor"))
    {
        ATextRenderActor* TextActor = World->SpawnActor<ATextRenderActor>(ATextRenderActor::StaticClass(), Location, Rotation, SpawnParams);
        if (TextActor)
        {
            // Set text if provided
            FString TextContent;
            if (Params->TryGetStringField(TEXT("text"), TextContent))
            {
                TextActor->GetTextRender()->SetText(FText::FromString(TextContent));
            }
            // Set text size if provided
            double TextSize = 0;
            if (Params->TryGetNumberField(TEXT("text_size"), TextSize))
            {
                TextActor->GetTextRender()->SetWorldSize(TextSize);
            }
            NewActor = TextActor;
        }
    }
    else
    {
        return FUnrealMCPCommonUtils::CreateErrorResponse(FString::Printf(TEXT("Unknown actor type: %s. Supported types: StaticMeshActor, Cube, Sphere, Cylinder, Plane, Cone, PointLight, SpotLight, DirectionalLight, SkyLight, CameraActor, TextRenderActor"), *ActorType));
    }

    if (NewActor)
    {
        // Set scale (since SpawnActor only takes location and rotation)
        FTransform Transform = NewActor->GetTransform();
        Transform.SetScale3D(Scale);
        NewActor->SetActorTransform(Transform);

        // Return the created actor's details
        return FUnrealMCPCommonUtils::ActorToJsonObject(NewActor, true);
    }

    return FUnrealMCPCommonUtils::CreateErrorResponse(TEXT("Failed to create actor"));
}
'@

if ($content -match $spawnPattern) {
    $content = [regex]::Replace($content, $spawnPattern, $spawnReplacement)
    Write-Host "  HandleSpawnActor replaced with enhanced version" -ForegroundColor Green
} else {
    Write-Host "  WARNING: Could not find HandleSpawnActor pattern. Manual edit may be needed." -ForegroundColor Red
}

# ═══════════════════════════════════════════
# PATCH 3: Add set_actor_material command routing
# ═══════════════════════════════════════════
Write-Host "[3/4] Adding set_actor_material command..." -ForegroundColor Yellow

if ($content -notmatch 'set_actor_material') {
    # Add routing in the command dispatcher (after take_screenshot)
    $content = $content -replace '(else if \(CommandType == TEXT\("take_screenshot"\)\)\s*\{[^}]+\})', "`$1`r`n    else if (CommandType == TEXT(""set_actor_material""))`r`n    {`r`n        return HandleSetActorMaterial(Params);`r`n    }"

    # Add the handler function before HandleDeleteActor
    $materialHandler = @'

TSharedPtr<FJsonObject> FUnrealMCPEditorCommands::HandleSetActorMaterial(const TSharedPtr<FJsonObject>& Params)
{
    FString ActorName;
    if (!Params->TryGetStringField(TEXT("name"), ActorName))
    {
        return FUnrealMCPCommonUtils::CreateErrorResponse(TEXT("Missing 'name' parameter"));
    }

    FString MaterialPathStr;
    if (!Params->TryGetStringField(TEXT("material_path"), MaterialPathStr))
    {
        return FUnrealMCPCommonUtils::CreateErrorResponse(TEXT("Missing 'material_path' parameter"));
    }

    int32 SlotIndex = 0;
    Params->TryGetNumberField(TEXT("slot_index"), SlotIndex);

    // Find the actor
    AActor* TargetActor = nullptr;
    TArray<AActor*> AllActors;
    UGameplayStatics::GetAllActorsOfClass(GWorld, AActor::StaticClass(), AllActors);
    for (AActor* Actor : AllActors)
    {
        if (Actor && Actor->GetName() == ActorName)
        {
            TargetActor = Actor;
            break;
        }
    }

    if (!TargetActor)
    {
        return FUnrealMCPCommonUtils::CreateErrorResponse(FString::Printf(TEXT("Actor not found: %s"), *ActorName));
    }

    // Load the material
    UMaterialInterface* Material = Cast<UMaterialInterface>(UEditorAssetLibrary::LoadAsset(MaterialPathStr));
    if (!Material)
    {
        return FUnrealMCPCommonUtils::CreateErrorResponse(FString::Printf(TEXT("Material not found: %s"), *MaterialPathStr));
    }

    // Apply to StaticMeshComponent if available
    AStaticMeshActor* MeshActor = Cast<AStaticMeshActor>(TargetActor);
    if (MeshActor && MeshActor->GetStaticMeshComponent())
    {
        MeshActor->GetStaticMeshComponent()->SetMaterial(SlotIndex, Material);

        TSharedPtr<FJsonObject> ResultObj = MakeShared<FJsonObject>();
        ResultObj->SetStringField(TEXT("actor"), ActorName);
        ResultObj->SetStringField(TEXT("material"), MaterialPathStr);
        ResultObj->SetNumberField(TEXT("slot"), SlotIndex);
        ResultObj->SetBoolField(TEXT("success"), true);
        return ResultObj;
    }

    return FUnrealMCPCommonUtils::CreateErrorResponse(TEXT("Actor does not have a StaticMeshComponent"));
}

'@

    $content = $content -replace '(TSharedPtr<FJsonObject> FUnrealMCPEditorCommands::HandleDeleteActor)', "$materialHandler`$1"
    Write-Host "  Added set_actor_material command and handler" -ForegroundColor Green
} else {
    Write-Host "  set_actor_material already exists" -ForegroundColor Gray
}

# Save the file
Set-Content $editorFile $content -NoNewline
Write-Host "  Saved: $editorFile" -ForegroundColor Green

# ═══════════════════════════════════════════
# PATCH 4: Add HandleSetActorMaterial declaration to header
# ═══════════════════════════════════════════
Write-Host "[4/4] Updating header file..." -ForegroundColor Yellow

if (Test-Path $editorHeader) {
    $headerContent = Get-Content $editorHeader -Raw
    if ($headerContent -notmatch 'HandleSetActorMaterial') {
        $headerContent = $headerContent -replace '(static TSharedPtr<FJsonObject> HandleTakeScreenshot)', "static TSharedPtr<FJsonObject> HandleSetActorMaterial(const TSharedPtr<FJsonObject>& Params);`r`n`t`$1"
        Set-Content $editorHeader $headerContent -NoNewline
        Write-Host "  Added HandleSetActorMaterial declaration" -ForegroundColor Green
    } else {
        Write-Host "  Header already updated" -ForegroundColor Gray
    }
} else {
    Write-Host "  WARNING: Header file not found at $editorHeader" -ForegroundColor Red
}

# ═══════════════════════════════════════════
# VERIFY
# ═══════════════════════════════════════════
Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Verification" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan

$final = Get-Content $editorFile -Raw

$checks = @(
    @("mesh_path support",        ($final -match 'mesh_path')),
    @("material_path support",    ($final -match 'material_path')),
    @("Cube shortcut",            ($final -match '"Cube"')),
    @("Sphere shortcut",          ($final -match '"Sphere"')),
    @("Plane shortcut",           ($final -match '"Plane"')),
    @("TextRenderActor",          ($final -match 'TextRenderActor')),
    @("SkyLight",                 ($final -match 'ASkyLight')),
    @("set_actor_material cmd",   ($final -match 'set_actor_material')),
    @("HandleSetActorMaterial",   ($final -match 'HandleSetActorMaterial')),
    @("EditorAssetLibrary",       ($final -match 'EditorAssetLibrary'))
)

$allGood = $true
foreach ($check in $checks) {
    $status = if ($check[1]) { "PASS" } else { "FAIL"; $allGood = $false }
    $color = if ($check[1]) { "Green" } else { "Red" }
    Write-Host ("  {0,-28} [{1}]" -f $check[0], $status) -ForegroundColor $color
}

Write-Host ""
if ($allGood) {
    Write-Host "  ALL CHECKS PASSED" -ForegroundColor Green
    Write-Host ""
    Write-Host "  What was added:" -ForegroundColor White
    Write-Host "  - spawn_actor now accepts mesh_path and material_path params" -ForegroundColor Gray
    Write-Host "  - Type shortcuts: Cube, Sphere, Cylinder, Plane, Cone" -ForegroundColor Gray
    Write-Host "  - New types: TextRenderActor (with text, text_size), SkyLight" -ForegroundColor Gray
    Write-Host "  - New command: set_actor_material (name, material_path, slot_index)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  Next: Clean build in Visual Studio" -ForegroundColor White
    Write-Host "  1. Delete Binaries/ and Intermediate/" -ForegroundColor Gray
    Write-Host "  2. Regenerate VS project files" -ForegroundColor Gray
    Write-Host "  3. Build (Development Editor, Win64)" -ForegroundColor Gray
    Write-Host "  4. Push to GitHub" -ForegroundColor Gray
} else {
    Write-Host "  SOME CHECKS FAILED - review the output above" -ForegroundColor Red
}

Write-Host ""
Read-Host "Press Enter to exit"
