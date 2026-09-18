# 🎵 Automated Media Ingestion Pipeline (PS7)

A robust, multithreaded PowerShell 7 script designed to take a chaotic folder of downloaded media (audio and video files) and automatically transform it into a perfectly tagged, organized music library. 

Author: Ayush Rai (ɪᴏᴅᴀ)

This pipeline acts as a smart sorting facility. It separates videos from audio, losslessly extracts audio tracks from video files, hunts down duplicates using cryptographic hashes, and utilizes a multi-pass search engine against the Apple iTunes API to fetch accurate metadata and high-resolution cover art.

## 🆕 What's New (Upgrades from the Legacy Script)

* **Multi-Pass API Search Engine:** The old script gave up after one failed search. The new engine dynamically mutates the search terms in milliseconds—stripping punctuation, swapping hyphens, or isolating the track title—to guarantee a match for stubborn files.
* **The Bracket Annihilator & Pipe Chopper:** Upgraded the regex engine to aggressively delete *all* non-year bracketed text (e.g., `(360 Visualizer)`) and chop off YouTube SEO spam (e.g., `| Lirik Indonesia`). 
* **Accent & Diacritic Neutralizer:** The script now utilizes `.NET` text normalization to automatically convert foreign characters (e.g., `é` to `e`) before searching, preventing the iTunes API from crashing.
* **Bulk Duplicate Actions:** Dealing with hundreds of duplicates is no longer tedious. Added `RA` (Recycle All), `DA` (Delete All), and `SA` (Skip All) commands to process identical files instantly.
* **Smart Conditional Execution:** Pre-scans your master directory. If no video files are present, it intelligently skips video folder creation and extraction steps entirely to save time and disk space.
* **Space-Proof Architecture:** Completely rebuilt how PowerShell 7 passes variables to FFmpeg, ensuring that complex file paths with spaces (e.g., `C:\Users\Ayush Rai\...`) process perfectly without breaking the command line.
* **Strictly Online Mode:** Removed the unreliable offline mode. The script now mandates an internet connection to ensure your library is always perfectly tagged, trapping network drops in a safe Retry/Exit loop.

## ✨ Key Features

* **Smart Metadata & Cover Art Fetching:** Queries the iTunes Search API to automatically fetch Title, Artist, Album, Genre, Year, Track Number, and 600x600 high-resolution album art.
* **Lossless Tag Injection:** Utilizes FFmpeg to embed metadata and album art directly into the file's ID3 headers without re-encoding the audio, preserving 100% of the original quality.
* **Multithreaded Video Extraction:** Automatically detects your CPU core count and safely runs parallel threads to extract MP3 audio from video files (MP4, MKV, AVI, etc.) at maximum speed.
* **Intelligent Duplicate Sweeper:** Finds identical files by comparing precise file byte sizes, verified by an MD5 hash check. Features an interactive CLI to handle duplicates safely.

## 🛠️ Prerequisites

* **PowerShell 7+:** This script utilizes modern PowerShell syntax (like ternary operators and `ForEach-Object -Parallel`) and will *not* run on legacy Windows PowerShell 5.1.
* **FFmpeg:** Required for audio extraction and metadata injection. *(Note: The script features an automated pre-flight check and will offer to install FFmpeg for you via `winget` if it is not detected on your system).*
* **Active Internet Connection:** Required to query the iTunes API and download cover art.

## 🚀 How It Works (The 6-Step Pipeline)

When you point the script at a master folder, it executes the following sequence:

1. **Separation:** Scans the target directory and routes audio and video files into distinct temporary working folders.
2. **First Duplicate Sweep:** Analyzes the original audio files for exact duplicates and allows for interactive or bulk cleanup.
3. **Original Tagging:** Cleans the filenames, queries Apple iTunes, downloads the cover art, injects the ID3 metadata via FFmpeg, and moves the finished file to the final `Organized_Media_Library` folder.
4. **Video Extraction:** Strips the audio tracks from any video files found in Step 1 using parallel processing. *(Skipped if no videos exist).*
5. **Extracted Tagging:** Repeats the iTunes tagging and injection process (Step 3) on the newly extracted audio. *(Skipped if no videos exist).*
6. **Final Duplicate Sweep:** Does one last MD5 hash check across the entire finalized library to ensure no duplicate tracks exist between your original audio and the newly extracted video audio.

## ⚠️ Known Quirks & Tips

**The iTunes API is Literal:** The script's multi-pass engine is designed to fix 98% of API errors. However, if an audio file still fails to tag and ends up with "Unknown Artist" / "Unknown Album", it is usually because the original filename contained severe typos or Apple has the song cataloged strangely.
* *Fix:* Simply rename the failed file to a cleaner `Artist - Title.mp3` format (or remove the artist entirely and just use `Title.mp3`) and run the script on it again. 

## 📝 Usage

1. Clone or download the script (`pipeline.ps1`).
2. Open **PowerShell 7**.
3. Run the script: `.\pipeline.ps1`
4. Follow the interactive prompts to choose your Master Folder, select your preferred file operation mode (Move or Copy), and begin the ingestion process.
