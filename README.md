# Automated-Music-Pipeline
<br>
A robust, multithreaded PowerShell 7 script designed to take a chaotic folder of downloaded media (audio and video files) and automatically transform it into a perfectly tagged, organized music library.
<br>
Author: Ayush Rai
(ɪᴏᴅᴀ)
Pro Automated Media Ingestion Pipeline (PS7)
A robust, multithreaded PowerShell 7 script designed to take a chaotic folder of downloaded media (audio and video files) and automatically transform it into a perfectly tagged, organized music library.

This pipeline acts as a smart sorting facility. It separates videos from audio, extracts audio tracks from video files losslessly, hunts down duplicates using cryptographic hashes, and uses the Apple iTunes API to fetch accurate metadata and high-resolution cover art.

✨ Key Features
Smart Metadata & Cover Art Fetching: Queries the iTunes Search API to automatically fetch Title, Artist, Album, Genre, Year, Track Number, and 600x600 high-resolution album art.

Lossless Tag Injection: Utilizes FFmpeg to embed metadata and album art directly into the file's ID3 headers without re-encoding the audio, preserving 100% of the original quality.

Multithreaded Video Extraction: Automatically detects your CPU core count and safely runs parallel threads to extract MP3 audio from video files (MP4, MKV, AVI, etc.) at maximum speed.

Intelligent Duplicate Sweeper: Finds identical files by comparing precise file byte sizes, verified by an MD5 hash check. Features an interactive CLI to Recycle, Delete, or Skip duplicates (including bulk actions like Recycle All).

Regex Filename Scrubbing: Automatically cleans messy downloaded filenames (e.g., removing [Official Music Video], (Lyrics), etc.) to ensure accurate database searching.

Space-Proof Architecture: Fully supports complex file and folder paths with spaces and special characters.

🛠️ Prerequisites
PowerShell 7+: This script utilizes modern PowerShell syntax (like ternary operators and ForEach-Object -Parallel) and will not run on Windows PowerShell 5.1.

FFmpeg: Required for audio extraction and metadata injection. (Note: The script features an automated pre-flight check and will offer to install FFmpeg for you via winget if it is not detected on your system).

Active Internet Connection: Required to query the iTunes API and download cover art.

🚀 How It Works (The 6-Step Pipeline)
When you point the script at a master folder, it executes the following sequence:

Separation: Scans the target directory and routes audio and video files into distinct temporary working folders.

First Duplicate Sweep: Analyzes the original audio files for exact duplicates and allows for interactive cleanup.

Original Tagging: Cleans the filenames, queries Apple iTunes, downloads the cover art, injects the ID3 metadata via FFmpeg, and moves the finished file to the final Organized_Media_Library folder.

Video Extraction: Strips the audio tracks from any video files found in Step 1 using parallel processing.

Extracted Tagging: Repeats the iTunes tagging and injection process (Step 3) on the newly extracted audio.

Final Duplicate Sweep: Does one last MD5 hash check across the entire finalized library to ensure no duplicate tracks exist between your original audio and the newly extracted video audio.

⚠️ Known Quirks & Tips
The iTunes API is Literal: The script relies on the Apple iTunes Search API. If an audio file fails to tag and ends up with "Unknown Artist" / "Unknown Album", it is usually because the original filename contained weird punctuation (like stray hyphens) or obscure text that confused the search engine.

Fix: Simply rename the failed file to a cleaner Artist - Title.mp3 format and run the script on it again.

📝 Usage
Clone or download the script.

Open PowerShell 7.

Run .\pipeline.ps1

Follow the interactive prompts to choose your Master Folder, choose between Move/Copy mode, and begin the ingestion process.
