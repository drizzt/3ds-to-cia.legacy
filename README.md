# 3ds-to-cia
Simple 3DS to CIA converter for Linux (x86_64) and Windows

## Usage
Just put your unpacked (`.3ds`) roms in `roms` directory and launch the script
```
./make_cia.sh
```

or, under Windows
```
make_cia.cmd
```

The script will tell you what you need to do.
The resulting CIAs will be found in `cia` directory

## Requirements
Linux (x86_64) with python2.  
Windows (x86 and x86_64).

This should works also on Linux 32bit and Mac OS X if you put the correct binaries in `tools`
