# 3ds-to-cia
Simple 3DS to CIA converter for Linux (x86_64)

## Usage
Just put your unpacked (`.3ds`) roms in `roms` directory and launch the script
```
./make_cia.sh
```
The script will tell you what you need to do.
The resulting CIAs will be found in `cia` directory

## Requirements
Linux (x86_64) with python2 and python3.  
Windows (x64) using [MSYS2](http://msys2.github.io) with python2 and python installed.

This should works also on Linux/Windows 32bit and Mac OS X if you put the correct binaries in `tools`
