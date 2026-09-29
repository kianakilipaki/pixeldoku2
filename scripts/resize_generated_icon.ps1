param(
    [Parameter(Mandatory = $true)][string]$SourcePath,
    [Parameter(Mandatory = $true)][string]$DestinationPath,
    [int]$Size = 64
)

# Asset integration only: preserve generated artwork and alpha; avoid blur.
Add-Type -AssemblyName System.Drawing
$sourceImage = [System.Drawing.Image]::FromFile((Resolve-Path -LiteralPath $SourcePath))
$iconBitmap = New-Object System.Drawing.Bitmap($Size, $Size)
$iconGraphics = [System.Drawing.Graphics]::FromImage($iconBitmap)
try {
    $iconGraphics.Clear([System.Drawing.Color]::Transparent)
    $iconGraphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
    $iconGraphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
    $iconGraphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
    $iconGraphics.DrawImage($sourceImage, (New-Object System.Drawing.Rectangle(0, 0, $Size, $Size)),
        0, 0, $sourceImage.Width, $sourceImage.Height, [System.Drawing.GraphicsUnit]::Pixel)
    $iconBitmap.Save([System.IO.Path]::GetFullPath($DestinationPath), [System.Drawing.Imaging.ImageFormat]::Png)
    $transparentPixels = 0
    for ($iconY = 0; $iconY -lt $Size; $iconY++) {
        for ($iconX = 0; $iconX -lt $Size; $iconX++) {
            if ($iconBitmap.GetPixel($iconX, $iconY).A -eq 0) { $transparentPixels++ }
        }
    }
    Write-Output "$DestinationPath : ${Size}x${Size}, $transparentPixels transparent pixels"
} finally {
    $iconGraphics.Dispose()
    $iconBitmap.Dispose()
    $sourceImage.Dispose()
}
