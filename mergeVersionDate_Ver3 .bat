@echo off
setlocal enabledelayedexpansion
goto :main

:main
setlocal
	copy NUL New.config
	for /f "tokens=*" %%g in (.config) do (	
	
		set var=%%g	
		set Ignore=false
	    if "!var:~0,4!" == "INFO" set Ignore=true
		if "!var:~0,2!" == "FW" set Ignore=true
		
		 if !Ignore!==false echo		%%g>> new.config
		 
	    for /f "tokens=1-3 eol=#" %%g in ("!var!") do (
			set temp=%%g
			set temp_h=%%h
		
			if "!temp:~15,8!" == "HP_S340C" set filename=AOC_HP_DEMO.h 
			if "!temp:~15,8!" == "HP_S240t" set filename=AOC_HP_S240t.h
			if "!temp:~15,9!" == "HP_OMEN32" set filename=AOC_HP_OMEN32.h
			if "!temp:~15,9!" == "HP_HPDEMO" set filename=AOC_HP_DEMO.h
			if "!temp:~15,9!" == "HP_HPZ32s" set filename=AOC_HP_HPZ32s.h
			if "!temp:~15,9!" == "HP_HPZ24s" set filename=AOC_HP_HPZ24s.h
			if "!temp:~15,9!" == "HP_S240uw" set filename=AOC_HP_S240uw.h
			if "!temp:~15,9!" == "HP_Envy27" set filename=AOC_HP_ENVY27.h
			if "!temp:~15,10!" == "HP_Envy27s" set filename=AOC_HP_ENVY27s.h
			if "!temp:~15,12!" == "HP_SPECTRE32" set filename=AOC_HP_SPECTRE32.h
			if "!temp:~15,10!" == "HP_Envy32g" set filename=AOC_HP_ENVY32.h
			if "!temp:~15,13!" == "HP_Pavilion32" set filename=AOC_HP_PAVILION32.h
					
			if "!temp_h!" == "HP_S340C" set filename=AOC_HP_DEMO.h
			if "!temp_h!" == "HP_S240t" set filename=AOC_HP_S240t.h
			if "!temp_h!" == "HP_OMEN32" set filename=AOC_HP_OmenByHP32.h
			if "!temp_h!" == "HP_HPDEMO" set filename=AOC_HP_DEMO.h
			if "!temp_h!" == "HP_HPZ32s" set filename=AOC_HP_HPZ32s.h
			if "!temp_h!" == "HP_HPZ24s" set filename=AOC_HP_HPZ24s.h
			if "!temp_h!" == "HP_S240uw" set filename=AOC_HP_S240uw.h
			if "!temp_h!" == "HP_Envy27" set filename=AOC_HP_ENVY27.h
			if "!temp_h!" == "HP_Envy27s" set filename=AOC_HP_ENVY27s.h
			if "!temp_h!" == "HP_SPECTRE32" set filename=AOC_HP_SPECTRE32.h
			if "!temp_h!" == "HP_Envy32g" set filename=AOC_HP_ENVY32.h
			if "!temp_h!" == "HP_Pavilion32" set filename=AOC_HP_PAVILION32.h	
		)			 
	)
	
del .config
rename "new.config" ".config"
	
cd .\monitor_ap\CUSTOM\HP\MODEL
title Modify FW_VERSION
	  
	for /f "tokens=*" %%g in (!filename!) do (
		set filename_str=%%g
		
	    for /f "tokens=1-3" %%g in ("!filename_str!") do (
		set keyword=%%h
		if "!keyword!" == "INFO_VERSION" set real_ver=%%i goto :printVersion
		if "!keyword!" == "FW_DATE" set real_date=%%i goto :printDate
	    )
	)
	
cd ..\..\..\..\
:printVersion
echo;>> .config
echo 	INFO_VERSION?=!real_ver:~1,6!>> .config
:printDate
echo;>> .config
echo 	FW_DATE?=!real_date:~1,8!>> .config

set BUILDPATH=%~dp0
set BUILDPATH=!BUILDPATH:\=/!

rem //==預設cygwin路徑 d:\A_WORK\cygwin=========================================================================
set FOUND=false
cd D:\
for /d /r "D:\A_WORK\cygwin" %%a in (*) do if /i "%%~nxa"=="cygdrive" set "MINTTYPATH=%%a"
	if "!MINTTYPATH!"=="D:\A_WORK\cygwin\cygdrive" (set FOUND=true)	


rem //==如果有找到路徑，呼叫cygwin load autobuild.sh執行make指令===================================
if !FOUND!==true ( cd "%MINTTYPATH%"	
	cd ..\bin\
	del autobuild.sh
	copy NUL autobuild.sh
	echo cd %BUILDPATH%	>>autobuild.sh
	echo Make realclean >>autobuild.sh
	echo sh rmlink.sh	>>autobuild.sh
	echo sh drivergenlink.sh	>>autobuild.sh
	echo Make ; Make >>autobuild.sh
rem	echo read -s -n 1 -p "Press any key to continue . . ." >>autobuild.sh
	start mintty.exe %MINTTYPATH%\..\bin\bash --login -i -c 'sh %AUTOBUILDPATH%/../bin/autobuild.sh'
)
endlocal 

goto :eof






