# ============================================================================
# Automated Media Sorting, Extraction, and Organization Pipeline (PS7)
# ============================================================================

# --- Prerequisite Checks ---
if (-not (Get-Command ffmpeg -ErrorAction SilentlyContinue)) {
    Write-Host "`n[!] Error: FFmpeg is not installed but is required for extraction and metadata tagging." -ForegroundColor Red
    $installChoice = Read-Host "Do you want to install it now via winget? (Y/N)"
    
    if ($installChoice -match "^[Yy]") {
        Write-Host "`nStarting FFmpeg installation..." -ForegroundColor Cyan
        winget install ffmpeg --source winget --accept-package-agreements --accept-source-agreements
        Write-Host "`n[+] Installation complete! Please restart your PowerShell window and run this script again." -ForegroundColor Green
        exit
    } else {
        Write-Host "`nExiting pipeline. FFmpeg must be installed to continue." -ForegroundColor Yellow
        exit
    }
}

# Load VisualBasic for Recycle Bin functionality
Add-Type -AssemblyName Microsoft.VisualBasic

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

Function Search-OnlineMetadata {
    param ([string]$SearchTerm)
    $safeQuery = [uri]::EscapeDataString($SearchTerm)
    $url = "https://itunes.apple.com/search?term=$safeQuery&entity=song&limit=1"
    
    try {
        $response = Invoke-RestMethod -Uri $url -Method Get -ErrorAction Stop
        if ($response.resultCount -gt 0) {
            $track = $response.results[0]
            
            # iTunes returns 100x100 thumbnails by default. Replace with 600x600 for high quality.
            $artUrl = $track.artworkUrl100 -replace '100x100bb', '600x600bb'
            
            # Parse Release Year safely
            $releaseYear = ""
            if ($track.releaseDate) { $releaseYear = ([datetime]$track.releaseDate).Year }

            return @{
                Title       = $track.trackName
                Artist      = $track.artistName
                Album       = $track.collectionName
                TrackNumber = $track.trackNumber
                Genre       = $track.primaryGenreName
                Year        = $releaseYear
                Copyright   = $track.copyright
                ArtworkUrl  = $artUrl
            }
        }
    } catch { return $null }
    return $null
}

Function Organize-AudioFiles {
    param ([string]$SourcePath, [string]$DestinationPath, [string]$StepName)
    
    $audioExtensions = @('.mp3', '.m4a', '.flac', '.wav', '.wma', '.ogg')
    $files = Get-ChildItem -LiteralPath $SourcePath -File | Where-Object { $_.Extension -in $audioExtensions }
    
    $totalFiles = $files.Count
    if ($totalFiles -eq 0) { Write-Host "  No audio files to organize in this pass." -ForegroundColor Gray; return }

    Write-Host "  Tagging and processing $totalFiles audio files..." -ForegroundColor Cyan
    $counter = 0

    foreach ($file in $files) {
        $counter++
        $percent = [math]::Round(($counter / $totalFiles) * 100)
        Write-Progress -Activity $StepName -Status "Processing: $($file.Name)" -PercentComplete $percent -Id 1

        # Smart Filename Cleaning to use as the search base
        $cleanBaseName = $file.BaseName -replace '(?i)\[(?![^\]]*\b(?:19|20)\d{2}\b).*?\]', '' `
                                        -replace '(?i)\((?![^\)]*\b(?:19|20)\d{2}\b).*?(?:official|lyric|video).*?\)', '' `
                                        -replace '(?i)official( music)? video', '' `
                                        -replace '(?i)(official )?lyrics?', ''
        $cleanBaseName = ($cleanBaseName -replace '\s+', ' ').Trim(" -_")
        
        # Always fetch metadata online
        $onlineData = Search-OnlineMetadata -SearchTerm $cleanBaseName 

        # Null-safe PS7 Ternary Operators
        $mTitle  = ($null -ne $onlineData -and $onlineData.Title) ? $onlineData.Title : $cleanBaseName
        $mArtist = ($null -ne $onlineData -and $onlineData.Artist) ? $onlineData.Artist : "Unknown Artist"
        $mAlbum  = ($null -ne $onlineData -and $onlineData.Album) ? $onlineData.Album : "Unknown Album"
        $mTrack  = ($null -ne $onlineData -and $onlineData.TrackNumber) ? $onlineData.TrackNumber : ""
        $mGenre  = ($null -ne $onlineData -and $onlineData.Genre) ? $onlineData.Genre : ""
        $mYear   = ($null -ne $onlineData -and $onlineData.Year) ? $onlineData.Year : ""
        $mCopy   = ($null -ne $onlineData -and $onlineData.Copyright) ? $onlineData.Copyright : ""

        # Sanitize filename for Windows
        $invalidChars = '[<>:"/\\|?*⧸∕]'
        $safeFileName = ($mTitle -replace $invalidChars, '').Trim() + $file.Extension
        $targetPath = Join-Path -Path $DestinationPath -ChildPath $safeFileName

        # Build FFmpeg Arguments list with exact quotes around paths
        $argsList = @()
        $argsList += "-y"
        $argsList += "-i `"$($file.FullName)`""
        
        $isMp3 = ($file.Extension -match '(?i)\.mp3')
        $coverPath = ""

        # Handle Album Art download and injection
        if ($null -ne $onlineData -and $onlineData.ArtworkUrl) {
            $coverPath = Join-Path $env:TEMP "$([guid]::NewGuid()).jpg"
            try {
                Invoke-WebRequest -Uri $onlineData.ArtworkUrl -OutFile $coverPath -ErrorAction SilentlyContinue | Out-Null
                $argsList += "-i `"$coverPath`""
                $argsList += "-map 0:a"
                $argsList += "-map 1:v"
                $argsList += "-c:a copy"
                $argsList += "-c:v mjpeg"
                $argsList += "-disposition:v attached_pic"
                
                # ONLY apply id3v2_version 3 to MP3 files to prevent FLAC/M4A corruption
                if ($isMp3) { $argsList += "-id3v2_version 3" }
            } catch {
                $argsList += "-c copy"
            }
        } else {
            $argsList += "-c copy"
        }

        # Append string metadata (Safely escaping internal quotes)
        $argsList += "-metadata title=`"$($mTitle -replace '"', '\"')`""
        $argsList += "-metadata artist=`"$($mArtist -replace '"', '\"')`""
        $argsList += "-metadata album=`"$($mAlbum -replace '"', '\"')`""
        if ($mTrack) { $argsList += "-metadata track=`"$($mTrack -replace '"', '\"')`"" }
        if ($mGenre) { $argsList += "-metadata genre=`"$($mGenre -replace '"', '\"')`"" }
        if ($mYear)  { $argsList += "-metadata date=`"$($mYear -replace '"', '\"')`"" }
        if ($mCopy)  { $argsList += "-metadata copyright=`"$($mCopy -replace '"', '\"')`"" }

        $argsList += "`"$targetPath`""
        $argsList += "-loglevel error"

        # Join the array into a single perfectly spaced and quoted string for PS7
        $ffmpegArgs = $argsList -join " "

        # Execute injection
        try {
            $process = Start-Process -FilePath "ffmpeg" -ArgumentList $ffmpegArgs -Wait -NoNewWindow -PassThru
            
            if ($process.ExitCode -eq 0) {
                Remove-Item -LiteralPath $file.FullName -Force -ErrorAction SilentlyContinue
            } else {
                Move-Item -LiteralPath $file.FullName -Destination $targetPath -Force -ErrorAction SilentlyContinue
            }
        } catch {
            Move-Item -LiteralPath $file.FullName -Destination $targetPath -Force -ErrorAction SilentlyContinue
        }

        # Cleanup Temp Cover Image
        if (Test-Path $coverPath) { Remove-Item -Path $coverPath -Force -ErrorAction SilentlyContinue }
    }
    Write-Progress -Activity $StepName -Completed -Id 1
}

Function Remove-DuplicatesInteractive {
    param ([string]$ScanPath)
    
    if (-not (Test-Path $ScanPath)) { return }
    
    $files = Get-ChildItem -Path $ScanPath -File -Recurse
    if ($files.Count -eq 0) { Write-Host "  No files found to scan." -ForegroundColor Gray; return }

    $dupes = $files | Group-Object -Property Length | Where-Object { $_.Count -gt 1 } | ForEach-Object { $_.Group } | 
             Get-FileHash -Algorithm MD5 | Group-Object -Property Hash | Where-Object { $_.Count -gt 1 }

    if ($dupes.Count -gt 0) {
        Write-Host "  Found $($dupes.Count) duplicate groups. Starting interactive cleanup..." -ForegroundColor Yellow
        
        # Track if the user has selected an "Apply to All" action
        $globalAction = $null 

        foreach ($group in $dupes) {
            $sorted = $group.Group | Sort-Object -Property Path
            $originalFile = $sorted[0].Path
            
            # Only print the original file name if we are still in interactive mode
            if ($null -eq $globalAction) {
                Write-Host "`n  [ORIGINAL] (Keeping): $originalFile" -ForegroundColor Green
            }
            
            for ($i = 1; $i -lt $sorted.Count; $i++) {
                $dupFile = $sorted[$i].Path
                
                # Use the global action if set, otherwise prompt the user
                $choice = $globalAction
                
                if ($null -eq $choice) {
                    Write-Host "  [DUPLICATE]: $dupFile" -ForegroundColor Yellow
                    $promptMsg = "  Action -> [R]ecycle, [D]elete, [S]kip | OR [RA] Recycle All, [DA] Delete All, [SA] Skip All"
                    $choice = Read-Host $promptMsg
                }
                
                # Check for bulk actions first and lock them in
                if ($choice -match "^[Rr][Aa]$") {
                    $globalAction = "R"; $choice = "R"
                } elseif ($choice -match "^[Dd][Aa]$") {
                    $globalAction = "D"; $choice = "D"
                } elseif ($choice -match "^[Ss][Aa]$") {
                    $globalAction = "S"; $choice = "S"
                }

                # Execute the chosen action
                if ($choice -match "^[Rr]$") {
                    try {
                        [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile($dupFile, 'OnlyErrorDialogs', 'SendToRecycleBin')
                        Write-Host "  -> Recycled: $($dupFile | Split-Path -Leaf)" -ForegroundColor Magenta
                    } catch { Write-Host "  -> Failed to recycle." -ForegroundColor Red }
                } elseif ($choice -match "^[Dd]$") {
                    try {
                        Remove-Item -LiteralPath $dupFile -Force -ErrorAction Stop
                        Write-Host "  -> Deleted: $($dupFile | Split-Path -Leaf)" -ForegroundColor DarkRed
                    } catch { Write-Host "  -> Failed to delete." -ForegroundColor Red }
                } else {
                    if ($null -eq $globalAction) { Write-Host "  -> Skipped" -ForegroundColor Gray }
                }
            }
        }
        if ($null -ne $globalAction) { Write-Host "  Bulk duplicate cleanup finished." -ForegroundColor Green }
    } else { Write-Host "  No duplicates found. Area is clean!" -ForegroundColor Green }
}

# ============================================================================
# MAIN PIPELINE EXECUTION
# ============================================================================
Clear-Host

$asciiWatermark = @"
  ██╗  ██████╗ ██████╗  █████╗  ██╗ ███████╗
  ██║ ██╔═══██╗██╔══██╗██╔══██╗ ██║ ██╔════╝
  ██║ ██║   ██║██║  ██║███████║ ╚═╝ ███████╗
  ██║ ██║   ██║██║  ██║██╔══██║     ╚════██║
  ██║ ╚██████╔╝██████╔╝██║  ██║     ███████╗
  ╚═╝  ╚═════╝ ╚═════╝ ╚═╝  ╚═╝     ╚══════╝
"@

Write-Host $asciiWatermark -ForegroundColor Cyan
Write-Host "`n==================================================" -ForegroundColor Magenta
Write-Host "    AUTOMATED MEDIA INGESTION PIPELINE        " -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Magenta
Write-Host "--------------------------------------------------" -ForegroundColor DarkGray

$inputPath = Read-Host "`nEnter the master folder path to process"
$masterPath = $inputPath.Trim('"').Trim("'")

if (-not (Test-Path -LiteralPath $masterPath -PathType Container)) {
    Write-Host "Invalid folder path! Exiting." -ForegroundColor Red; exit
}

Write-Host "`nFile Operation Mode:" -ForegroundColor Cyan
Write-Host "[M] Move files (Cleans up your original folder as it organizes)" -ForegroundColor Gray
Write-Host "[C] Copy files (Leaves your original files completely untouched)" -ForegroundColor Gray
$actionChoice = Read-Host "Choice (M/C)"
$isCopyMode = ($actionChoice -match '^c')

# Mandatory Internet Verification
Write-Host "`nVerifying internet connection for iTunes metadata synchronization..." -ForegroundColor Cyan
$connected = $false
while (-not $connected) {
    try {
        $null = Invoke-WebRequest -Uri "https://itunes.apple.com" -TimeoutSec 3 -ErrorAction Stop
        $connected = $true
        Write-Host "Connection successful!`n" -ForegroundColor Green
    } catch {
        Write-Host "[!] Internet unavailable or iTunes is down. An active connection is required to run this script." -ForegroundColor Red
        $retryChoice = Read-Host "Press [R] Retry or [E] Exit (R/E)"
        if ($retryChoice -match '^e') { exit }
    }
}

# Pre-Scan for File Types
$audioExt = @(".mp3", ".wav", ".m4a", ".flac", ".aac", ".wma", ".ogg")
$videoExt = @(".mp4", ".mkv", ".avi", ".mov", ".wmv", ".flv", ".webm", ".m4v", ".mts", ".ts", ".3gp")
$allFiles = Get-ChildItem -LiteralPath $masterPath -File

$hasVideos = $false
foreach ($file in $allFiles) {
    if ($videoExt -contains $file.Extension.ToLower()) {
        $hasVideos = $true
        break
    }
}

# Set up Core Working Directories
$audioDir = Join-Path $masterPath "Audio_Originals"
$finalLibraryDir = Join-Path $masterPath "Organized_Media_Library"

New-Item -ItemType Directory -Path $audioDir -Force | Out-Null
New-Item -ItemType Directory -Path $finalLibraryDir -Force | Out-Null

# Conditionally Setup Video Directories
if ($hasVideos) {
    $videoDir = Join-Path $masterPath "Video_Originals"
    $extractedAudioDir = Join-Path $masterPath "Audio_Extracted"
    New-Item -ItemType Directory -Path $videoDir -Force | Out-Null
    New-Item -ItemType Directory -Path $extractedAudioDir -Force | Out-Null
}

# ----------------------------------------------------------------------------
Write-Host "`n[Step 1/6] Separating files..." -ForegroundColor Magenta
# ----------------------------------------------------------------------------
$totalSep = $allFiles.Count
$sepCount = 0

foreach ($file in $allFiles) {
    $sepCount++
    $percent = [math]::Round(($sepCount / $totalSep) * 100)
    Write-Progress -Activity "Step 1: Separating Media" -Status "Checking: $($file.Name)" -PercentComplete $percent -Id 1

    $ext = $file.Extension.ToLower()
    if ($audioExt -contains $ext) { 
        if ($isCopyMode) { Copy-Item -LiteralPath $file.FullName -Destination $audioDir -Force }
        else { Move-Item -LiteralPath $file.FullName -Destination $audioDir -Force }
    }
    elseif ($hasVideos -and ($videoExt -contains $ext)) { 
        if ($isCopyMode) { Copy-Item -LiteralPath $file.FullName -Destination $videoDir -Force }
        else { Move-Item -LiteralPath $file.FullName -Destination $videoDir -Force }
    }
}
Write-Progress -Activity "Step 1: Separating Media" -Completed -Id 1
Write-Host "  Separation complete." -ForegroundColor Green

# ----------------------------------------------------------------------------
Write-Host "`n[Step 2/6] Sweeping Original Audio for Duplicates..." -ForegroundColor Magenta
# ----------------------------------------------------------------------------
Remove-DuplicatesInteractive -ScanPath $audioDir

# ----------------------------------------------------------------------------
Write-Host "`n[Step 3/6] Tagging and Organizing Original Audio Files..." -ForegroundColor Magenta
# ----------------------------------------------------------------------------
Organize-AudioFiles -SourcePath $audioDir -DestinationPath $finalLibraryDir -StepName "Step 3: Tagging Originals"
Write-Host "  Original audio organized." -ForegroundColor Green

# ----------------------------------------------------------------------------
if ($hasVideos) {
    Write-Host "`n[Step 4/6] Extracting Audio from Videos (Multithreaded)..." -ForegroundColor Magenta
    # ----------------------------------------------------------------------------
    $videos = Get-ChildItem -LiteralPath $videoDir -File | Where-Object { $videoExt -contains $_.Extension.ToLower() }
    if ($videos.Count -gt 0) {
        $cores = [System.Environment]::ProcessorCount
        $throttle = if ($cores -gt 2) { $cores - 1 } else { 1 }
        Write-Host "  Using $throttle threads for processing $($videos.Count) videos." -ForegroundColor Cyan

        $videos | ForEach-Object -Parallel {
            $vid = $_; $outDir = $using:extractedAudioDir
            $outFile = Join-Path $outDir "$($vid.BaseName) [Extracted].mp3"
            Write-Host "  -> Extracting: $($vid.Name)" -ForegroundColor DarkGray
            
            $args = "-y -i `"$($vid.FullName)`" -vn -acodec libmp3lame -q:a 2 `"$outFile`" -loglevel error"
            Start-Process -FilePath "ffmpeg" -ArgumentList $args -Wait -NoNewWindow
        } -ThrottleLimit $throttle
        Write-Host "  Extraction complete." -ForegroundColor Green
    } else { 
        Write-Host "  No videos found to extract." -ForegroundColor Gray 
    }

    # ----------------------------------------------------------------------------
    Write-Host "`n[Step 5/6] Tagging and Organizing Extracted Audio..." -ForegroundColor Magenta
    # ----------------------------------------------------------------------------
    Organize-AudioFiles -SourcePath $extractedAudioDir -DestinationPath $finalLibraryDir -StepName "Step 5: Tagging Extracted"
    Write-Host "  Extracted audio organized." -ForegroundColor Green

} else {
    Write-Host "`n[Step 4 & 5] Skipped (No video files found in source folder)..." -ForegroundColor Gray
}

# ----------------------------------------------------------------------------
Write-Host "`n[Step 6/6] Final Library Duplicate Sweep..." -ForegroundColor Magenta
# ----------------------------------------------------------------------------
Remove-DuplicatesInteractive -ScanPath $finalLibraryDir

# --- Cleanup & Finish ---
if (Test-Path $audioDir) {
    if ((Get-ChildItem -Path $audioDir -Force).Count -eq 0) { Remove-Item -Path $audioDir -Force -Recurse }
}
if ($hasVideos) {
    if (Test-Path $extractedAudioDir) {
        if ((Get-ChildItem -Path $extractedAudioDir -Force).Count -eq 0) { Remove-Item -Path $extractedAudioDir -Force -Recurse }
    }
    if ($isCopyMode -and (Test-Path $videoDir)) {
        Remove-Item -Path $videoDir -Force -Recurse
    }
}

Write-Host "`n==================================================" -ForegroundColor Magenta
Write-Host "Pipeline Complete!" -ForegroundColor Green
Write-Host "All beautifully tagged media is located in: " -NoNewline
Write-Host $finalLibraryDir -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Magenta
Write-Host $asciiWatermark -ForegroundColor DarkGray