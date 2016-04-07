@ECHO OFF

REM Copyright (c) 2016 Timothy Redaelli
REM Based on contents by mid-kid
REM Released under GPLv3+

DIR /B "roms\*.3ds" 2>NUL

IF %ERRORLEVEL% NEQ 0 (
	ECHO No valid files in rom directory found. >&2
	SET FAIL=1
	GOTO EXIT
)

tools\win32\ncchinfo_gen.exe roms\*.3ds

ECHO Copy ncchinfo.bin to your 3DS and make it generates the required xorpads
ECHO Then copy the generated xorpads in the 'xorpads' directory

PAUSE

REM Verify ROMs and xorpads
SETLOCAL ENABLEDELAYEDEXPANSION
SET FAIL=0
FOR /F "tokens=*" %%r IN ('DIR /S /B "roms\*.3ds"') DO (
	CALL :get_titleid "%%r" title_id

	IF "!title_id!" == "" (
		ECHO "%%r invalid." >&2
		SET FAIL=2
		GOTO EXIT
	) ELSE (
		SET xorpad=!title_id!.Main.exheader.xorpad
		IF NOT EXIST "xorpads\!xorpad!" (
			ECHO !xorpad! not found. Please put it into the 'xorpads' directory. >&2
			SET FAIL=3
			GOTO EXIT
		)
	)
)
if %FAIL% NEQ 0 GOTO EXIT
ENDLOCAL & SET xorpad=%xorpad%

SETLOCAL ENABLEDELAYEDEXPANSION
FOR /F "tokens=*" %%r IN ('DIR /B "roms\*.3ds"') DO (
	RD /Q /S _tmp 2>NUL
	MKDIR _tmp
        REM Extract cxi and cfa
        tools\win32\rom_tool.exe --extract=_tmp "roms\%%r"
        REM Remove any update data
        DEL _tmp\*_UPDATEDATA.cfa 2>NUL
	REM Fix cxi
	tools\win32\fix_cxi.exe _tmp\*_APPDATA.cxi "xorpads\%xorpad%"

	REM Generate and fix CIA file
	set /A i=0
	FOR /F "tokens=*" %%c IN ('DIR /B "_tmp\*.cxi" "_tmp\*.cfa"') DO (
		SET cmdline=!cmdline! -content ^"_tmp\%%c^":!i!:!i!
		SET /A "i += 1"
	)
	tools\win32\makerom.exe -v -f cia -o "cia\%%~nr.cia" !cmdline!
	tools\win32\fix_cia.exe "cia\%%~nr.cia" "xorpads\%xorpad%"
)
ENDLOCAL

RD /Q /S _tmp 2>NUL

SET FAIL=0
GOTO EXIT

REM Uppercase title id (as in ncchinfo.bin)
:get_titleid
	SETLOCAL ENABLEDELAYEDEXPANSION
		FOR /F "tokens=2,3,4" %%A IN ('tools\win32\rom_tool.exe -p %1') DO (
			IF "%%A %%B"=="Title ID:" IF "!var_!" == "" SET var_=%%C
		)
		CALL :hex_toupper %var_% var_
	ENDLOCAL & IF NOT "%~2"=="" SET %~2=%var_%
	GOTO :EOF

:hex_toupper
	SETLOCAL
		SET var_=%1
		SET var_=%var_:a=A%
		SET var_=%var_:b=B%
		SET var_=%var_:c=C%
		SET var_=%var_:d=D%
		SET var_=%var_:e=E%
		SET var_=%var_:f=F%
	ENDLOCAL & IF NOT "%~2" == "" SET %~2=%var_%
	GOTO :EOF

:EXIT
	PAUSE
	EXIT /B %FAIL%
