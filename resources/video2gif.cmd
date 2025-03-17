@echo off
rem Delete previous frame images and output GIF if they exist
del frame*.png 2>nul
if exist output.gif del output.gif

REM winget install ImageMagick.Q16-HDRI
REM winget install "FFmpeg (Shared)"

ffmpeg -i "20250308_0532_Digital Grid Symphony_remix_01jnt0d7d7fzfs7ph05vx47ewz.mp4" -vf "fps=10,scale=480x480:force_original_aspect_ratio=decrease" -compression_level 9 frame%%03d.png
magick -delay 10 -loop 0 frame*.png -colors 256 -layers Optimize output.gif

pause

REM ffmpeg -i "20250308_0532_Digital Grid Symphony_remix_01jnt0d7d7fzfs7ph05vx47ewz.mp4" -vf "fps=24,scale=480x480:force_original_aspect_ratio=decrease" frame%%03d.png
REM magick -delay 4 -loop 0 frame*.png output.gif

