### Quick comparison of tools and scripts
| **Tool / Script** | **Primary use** | **Pros** | **When to use** |
|---|---:|---|---|
| **ImageMagick CLI (magick / mogrify)** | Batch image processing, resize, crop, convert | Fast, cross‑platform, many operators; suitable for large batches.  | Production pipelines, experiments that need many variants |
| **PowerShell wrappers** | Windows automation around `magick` | Easy integration with Windows tasks and folder logic | Windows users, scheduled jobs |
| **Bash scripts** | Unix automation around `magick` or `mogrify` | Portable on Linux/macOS; easy to combine with GNU Parallel | High‑throughput batch processing |
| **Python (Pillow / Wand / subprocess magick)** | Research experiments, custom metrics, ML preprocessing | Programmatic control, integrate with analysis and ML code | Research, reproducibility, custom pipelines |

---

### 1. Project overview
**Goal**: a reproducible, extensible ImageMagick research project for image processing experiments: resizing, stretching, crop modes, format conversion, quality tradeoffs, and performance benchmarking. Use the ImageMagick CLI as the core engine and provide multiple script types for different environments and workflows. ImageMagick supports a wide range of operations and scripting modes. 

---

### 2. Recommended project structure
```
image-research-project/
├─ data/
│  ├─ raw/                     # original images (keep immutable)
│  ├─ samples/                 # small subset for quick tests
│  └─ README.md
├─ outputs/
│  ├─ qf_resized/              # outputs from resize-images.ps1
│  ├─ qf_resized1/             # outputs from resize-stretch.ps1
│  └─ qf_resized2/             # outputs from resize-crop.ps1
├─ scripts/
│  ├─ windows/
│  │  ├─ resize-images.ps1
│  │  ├─ resize-stretch.ps1
│  │  └─ resize-crop.ps1
│  ├─ unix/
│  │  ├─ resize-batch.sh
│  │  └─ resize-parallel.sh
│  └─ python/
│     ├─ preprocess.py
│     └─ metrics.py
├─ notebooks/
│  ├─ analysis.ipynb
│  └─ experiments.ipynb
├─ benchmarks/
│  ├─ perf_results.csv
│  └─ run_benchmarks.sh
├─ docs/
│  ├─ README.md
│  └─ USAGE.md
└─ .gitignore
```

---

### 3. Core scripts (ready to use)
#### PowerShell Windows scripts
**resize-images.ps1** (quality controlled, recursive)
```powershell
param(
  [string]$SourceFolder = ".\data/raw",
  [string]$OutputFolder = ".\outputs/qf_resized",
  [int]$Width = 800,
  [int]$Height = 600,
  [int]$Quality = 90,
  [switch]$Recursive
)
if (!(Test-Path $OutputFolder)) { New-Item -ItemType Directory -Path $OutputFolder | Out-Null }
$files = Get-ChildItem -Path $SourceFolder -Include *.jpg,*.jpeg,*.png -File -Recurse:($Recursive.IsPresent)
foreach ($f in $files) {
  $rel = $f.FullName.Substring((Resolve-Path $SourceFolder).Path.Length).TrimStart('\','/')
  $outDir = Join-Path $OutputFolder ([System.IO.Path]::GetDirectoryName($rel))
  if (!(Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir -Force | Out-Null }
  $outFile = Join-Path $outDir $f.Name
  magick $f.FullName -resize ${Width}x${Height}^ -gravity center -extent ${Width}x${Height} -quality $Quality $outFile
  Write-Host "Resized: $($f.Name) -> $outFile"
}
```

**resize-stretch.ps1** (force stretch)
```powershell
param($SourceFolder=".\data/raw",$OutputFolder=".\outputs/qf_resized1",$Width=800,$Height=600,$Recursive)
if (!(Test-Path $OutputFolder)) { New-Item -ItemType Directory -Path $OutputFolder | Out-Null }
Get-ChildItem -Path $SourceFolder -Include *.jpg,*.jpeg,*.png -File -Recurse:($Recursive.IsPresent) | ForEach-Object {
  $rel = $_.FullName.Substring((Resolve-Path $SourceFolder).Path.Length).TrimStart('\','/')
  $outFile = Join-Path $OutputFolder $rel; New-Item -ItemType Directory -Path (Split-Path $outFile) -Force | Out-Null
  magick $_.FullName -resize "${Width}x${Height}!" $outFile
  Write-Host "Stretched: $($_.Name)"
}
```

**resize-crop.ps1** (cover + center crop)
```powershell
param($SourceFolder=".\data/raw",$OutputFolder=".\outputs/qf_resized2",$Width=800,$Height=600,$Recursive)
if (!(Test-Path $OutputFolder)) { New-Item -ItemType Directory -Path $OutputFolder | Out-Null }
Get-ChildItem -Path $SourceFolder -Include *.jpg,*.jpeg,*.png -File -Recurse:($Recursive.IsPresent) | ForEach-Object {
  $rel = $_.FullName.Substring((Resolve-Path $SourceFolder).Path.Length).TrimStart('\','/')
  $outFile = Join-Path $OutputFolder $rel; New-Item -ItemType Directory -Path (Split-Path $outFile) -Force | Out-Null
  magick $_.FullName -resize "${Width}x${Height}^" -gravity center -extent "${Width}x${Height}" $outFile
  Write-Host "Cropped: $($_.Name)"
}
```

#### Unix Bash scripts
**resize-batch.sh** (single-threaded)
```bash
#!/usr/bin/env bash
SRC="data/raw"
DST="outputs/qf_resized"
W=800; H=600
find "$SRC" -type f \( -iname '*.jpg' -o -iname '*.png' \) | while read -r f; do
  rel="${f#$SRC/}"
  out="$DST/$rel"
  mkdir -p "$(dirname "$out")"
  magick "$f" -resize "${W}x${H}^" -gravity center -extent "${W}x${H}" "$out"
  echo "Processed $rel"
done
```

**resize-parallel.sh** (parallel using GNU Parallel)
```bash
#!/usr/bin/env bash
SRC="data/raw"; DST="outputs/qf_resized"; W=800; H=600
export DST W H
find "$SRC" -type f \( -iname '*.jpg' -o -iname '*.png' \) | parallel --bar '
  rel={/}
  out="$DST/{/}"
  mkdir -p "$(dirname "$out")"
  magick "{}" -resize "${W}x${H}^" -gravity center -extent "${W}x${H}" "$out"
'
```

#### Python utilities
**preprocess.py** (Pillow fallback and metadata)
```python
from PIL import Image, ImageOps
from pathlib import Path
def stretch(in_path, out_path, size):
    img = Image.open(in_path).convert("RGB")
    img = img.resize(size, Image.LANCZOS)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    img.save(out_path, quality=90)
def cover_crop(in_path, out_path, size):
    img = Image.open(in_path).convert("RGB")
    img = ImageOps.fit(img, size, Image.LANCZOS, centering=(0.5,0.5))
    out_path.parent.mkdir(parents=True, exist_ok=True)
    img.save(out_path, quality=90)
# usage example in __main__ omitted for brevity
```

---

### 4. Experiments, metrics, and reproducibility
**Suggested experiments**
- **Visual fidelity**: compare stretched vs cropped vs aspect‑preserved resized images using SSIM and PSNR metrics.
- **Compression tradeoffs**: generate JPEGs at multiple quality levels and measure file size vs SSIM.
- **Performance**: measure throughput (images/sec) for single‑threaded `magick`, `mogrify`, and GNU Parallel runs. Batch processing at scale is common and can be parallelized. 

**Metrics to collect**
- **SSIM**, **PSNR**, **MSE** for image quality.
- **File size** in bytes.
- **Processing time** per image and total.
- **Memory and CPU usage** during runs.

**Reproducibility**
- Keep `data/raw` immutable and record script versions and ImageMagick version (`magick -version`) in `benchmarks/perf_results.csv`.
- Use notebooks in `notebooks/` to load metrics and produce plots.
- Store exact command lines in `docs/USAGE.md`.

---

### 5. Best practices and tips
- Use `magick -version` to record the exact build for reproducibility.   
- For very large datasets, use `mogrify` for in‑place bulk operations or combine `find` + `parallel` to utilize all CPU cores.   
- Prefer `-resize WxH^ -gravity center -extent WxH` for consistent gallery thumbnails without distortion.  
- For ML pipelines, generate multiple sizes and store them in separate folders for `srcset` and training augmentation.  
- Keep a small `data/samples` set for quick iteration.

---

### 6. Getting started checklist
1. **Install ImageMagick** and verify: `magick -version`.   
2. **Clone project tree** and place originals in `data/raw`.  
3. **Run quick test** on a single image using the one‑line `magick` command.  
4. **Run scripts**:
   - Windows: `.\scripts\windows\resize-images.ps1 -SourceFolder ".\data/raw" -OutputFolder ".\outputs/qf_resized" -Width 800 -Height 600 -Quality 90 -Recursive`
   - Unix: `bash scripts/unix/resize-batch.sh`
5. **Collect metrics** with `python scripts/python/metrics.py` and record results in `benchmarks/`.  
6. **Iterate**: adjust modes, quality, and parallelism; document findings in `notebooks/analysis.ipynb`.

---

If you want, I will:
- generate the full `README.md` file content ready to drop into the repo,
- produce the `metrics.py` script to compute SSIM/PSNR and a sample Jupyter notebook skeleton for experiments,
- or create a `Makefile` to run common tasks. Which of these should I provide next?
