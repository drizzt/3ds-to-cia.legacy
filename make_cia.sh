#!/usr/bin/env bash

# Copyright (c) 2016 Timothy Redaelli
# Based on contents by mid-kid
# Released under GPLv3+

set -e
set -o pipefail
shopt -s nullglob

roms=( roms/*.3[dD][sS] )

if [ ${#roms[@]} -eq 0 ]; then
	echo "No valid files in rom directory found." >&2
	exit 1
fi

# FIXME Build 32 bit versions
case "$OS" in
Windows*)
	ncchinfo_gen=./tools/win32/ncchinfo_gen.exe
	fix_cxi=./tools/win32/fix_cxi.exe
	fix_cia=./tools/win32/fix_cia.exe
	rom_tool=./tools/win32/rom_tool.exe
	makerom=./tools/win32/makerom.exe
	;;

*)
	ncchinfo_gen=./tools/ncchinfo_gen.py
	fix_cxi=./tools/fix_cxi.py
	fix_cia=./tools/fix_cia.py
	case "$(uname -sm)" in
	"Linux x86_64")
		rom_tool=./tools/linux64/rom_tool
		makerom=./tools/linux64/makerom
		;;
	esac
	;;
esac

"$ncchinfo_gen" "${roms[@]}" >/dev/null

echo "Copy ncchinfo.bin to your 3DS and make it generates the required xorpads"
echo "Then copy the generated xorpads in the 'xorpads' directory"

echo "Press any key to continue..."
read -sn 1 || true

fail=0
for rom in "${roms[@]}"; do
	rom_base="${rom#roms/}"

	# Uppercase title id (as in ncchinfo.bin)
	title_id=$("$rom_tool" -p "$rom" | awk '/^ > Title ID:/{print toupper($4); exit}') || {
		echo "$rom is corrupted" >&2
		fail=1
		continue
	}
	xorpad="$title_id.Main.exheader.xorpad"

	# Verify xorpads
	if ! [[ -f "xorpads/$xorpad" ]]; then
		echo "$xorpad not found. Please put it into the 'xorpads' directory." >&2
		fail=2
		continue
	fi
	if (( $(stat -c "%s" "xorpads/$xorpad") != 1048576 )); then
		echo "$xorpad must be 1MiB size." >&2
		fail=3
		continue
	fi

	rm -rf _tmp
	mkdir -p _tmp

	# Extract cxi and cfa
	"$rom_tool" --extract=_tmp "$rom"
	# Remove any update data
	rm -f _tmp/*_UPDATEDATA.cfa

	# Fix cxi
	"$fix_cxi" _tmp/*_APPDATA.cxi "xorpads/$xorpad"

	# Generate CIA file
	i=0
	for content in _tmp/*.cxi _tmp/*.cfa; do
		cmdline+=(-content "$content":$i:$i)
		i=$((i + 1))
	done
	"$makerom" -v -f cia -o "cia/${rom_base%.3[dD][sS]}.cia" "${cmdline[@]}"

	"$fix_cia" "cia/${rom_base%.3[dD][sS]}.cia" "xorpads/$xorpad"
done

rm -rf _tmp
