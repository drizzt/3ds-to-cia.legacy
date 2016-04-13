#!/bin/sh

# Copyright (c) 2016 Timothy Redaelli
# Based on contents by mid-kid
# Released under GPLv2

set -e

IFS='
'

is_empty() {
	! [ -f "$1" ]
}

# Extract the (uppercase) title id from the rom
# get_title_id rom_filename
get_title_id() {
	local title_id=$("$rom_tool" -p "$1" | awk '/^ > Title ID:/{print toupper($4); exit}')
	if [ -z "$title_id" ]; then
		echo "$1 is corrupted" >&2
		return 1
	fi
	printf '%s' "$title_id"
}

# Find and check the xorpad file (both standard and custom format)
# find_check_xorpad rom_filename rom_crc32 [check]
find_check_xorpad() {
	local rom="$1" rom_crc32="$2" xorpad= title_id= x tmp
	title_id=$(get_title_id "$rom") || return 1

	if [ -f "_tmp/$title_id.$rom_crc32.Main.exheader.xorpad" ]; then
		echo "_tmp/$title_id.$rom_crc32.Main.exheader.xorpad"
		return 0
	fi

	for x in xorpads/*.zip; do
		[ -f "$x" ] || continue
		xorpad="$title_id.$rom_crc32.Main.exheader.xorpad"
		if unzip -d _tmp "$x" "$title_id.$rom_crc32.Main.exheader.xorpad" >/dev/null && \
			[ -f "_tmp/$xorpad" ]; then

			echo "_tmp/$xorpad"
			return 0
		else
			tmp=$(unzip -lqq "$x" | grep "$title_id\.$rom_crc32\.Main\.exheader\.xorpad$" | awk '{for(i=4;i<=NF;++i)print $i}')
			if [ -n "$tmp" ]; then
				unzip -p "$x" "$tmp" > "_tmp/$xorpad" || true
				if [ -f "_tmp/$xorpad" ]; then
					echo "_tmp/$xorpad"
					return 0
				fi
			fi
		fi
	done

	if [ -f "xorpads/$title_id.Main.exheader.xorpad" ]; then
		xorpad="xorpads/$title_id.Main.exheader.xorpad"
	else
		xorpad="xorpads/$title_id.$rom_crc32.Main.exheader.xorpad"
	fi

	if ! [ -f "$xorpad" ]; then
		echo "$(basename "$xorpad") not found. Please put it into the 'xorpads' directory." >&2
		return 2
	fi

	if [ $(stat -c "%s" "$xorpad") -lt 1024 ]; then
		echo "$(basename "$xorpad") must be bigger than 1KiB." >&2
		return 3
	fi

	echo "$xorpad"
	return 0
}

if is_empty roms/*.3[dD][sS]; then
	echo "No valid files in rom directory found." >&2
	exit 1
fi

case "$OS" in
Windows_NT)
	crc32=./tools/win32/crc32.exe
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
		crc32=./tools/linux64/crc32
		rom_tool=./tools/linux64/rom_tool
		makerom=./tools/linux64/makerom
		;;
	esac
	;;
esac

rm -rf _tmp
mkdir -p _tmp

roms_crc32=
for rom in roms/*.3[dD][sS]; do
	rom_crc32="$("$crc32" "$rom")"
	roms_crc32="$roms_crc32
$rom_crc32"
	find_check_xorpad "$rom" "$rom_crc32" >/dev/null || to_generate="$to_generate
$rom"
done
if [ -n "$to_generate" ]; then
	"$ncchinfo_gen" $to_generate >/dev/null

	echo "Copy ncchinfo.bin to your 3DS and make it generates the required xorpads"
	echo "Then copy the generated xorpads in the 'xorpads' directory"

	echo "Press enter to continue..."
	read _ || true
fi

trap 'rm -rf "_tmp" ; exit' EXIT

fail=0
n=0
set -f
set -- $roms_crc32
set +f
for rom in roms/*.3[dD][sS]; do
	rom_base="${rom#roms/}"
	rom_base="${rom_base%.3[dD][sS]}"
	n=$((n + 1))

	# Uppercase title id (as in ncchinfo.bin)
	if ! title_id=$(get_title_id "$rom"); then
		fail=1
		continue
	fi

	eval rom_crc32=\$${n}

	# Verify xorpads (both "standard" an "custom format")
	if ! xorpad=$(find_check_xorpad "$rom" "$rom_crc32"); then
		fail=$?
		continue
	fi

	rm -f _tmp/*.cxi _tmp/*.cfa

	# Extract cxi and cfa
	"$rom_tool" --extract=_tmp "$rom"

	# Remove any update data
	rm -f _tmp/*_UPDATEDATA.cfa

	# Fix cxi
	"$fix_cxi" _tmp/*_APPDATA.cxi "$xorpad"

	# Generate CIA file
	i=0
	cmdline=
	for content in _tmp/*.cxi _tmp/*.cfa; do
		cmdline="$cmdline
-content
$content:$i:$i"
		i=$((i + 1))
	done
	"$makerom" -v -f cia -o "cia/$rom_base.cia" $cmdline

	"$fix_cia" "cia/$rom_base.cia" "$xorpad"
done
