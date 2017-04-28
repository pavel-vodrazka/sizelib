:main ::{{{1

@SETLOCAL ENABLEDELAYEDEXPANSION

@CALL test_echo.bat x_echo
@ECHO OFF

FOR /F "usebackq delims=: tokens=2" %%I IN (`CHCP`) DO SET orig_cp=%%I
CHCP 65001 >nul

SET "wrong_label="
SET "label="
SET "export_no="
SET "export_vars="
SET "errno=0"

IF /I "%1" EQU "" (
	SET "arg_1=help"
) ELSE (
	SET "arg_1=%1"
)

IF /I "%arg_1%" NEQ "getSize" IF /I "%arg_1%" NEQ "formatSize" IF /I "%arg_1%" NEQ "getFormattedSize" IF /I "%arg_1%" NEQ "help" SET "wrong_label=yes"

IF NOT DEFINED wrong_label (
	SET "label=%arg_1%"
	SET "args=%*"
	FOR /F "tokens=1*" %%I IN ("!args!") DO SET "args=%%J"
	CALL :!label! !args!
) ELSE (
	ECHO. >&2
	ECHO ERROR [1]: Tried to call a procedure not present in sizelib [“%1”]. >&2
	ECHO. >&2
	ECHO Giving you help: >&2
	ECHO. >&2
	CALL :help
	SET "errno=1"
)

SET "export_vars=%export_vars%"
SET "remaining_export_vars=%export_vars%"

:sizelib_set_exports

FOR /F %%I IN ("%remaining_export_vars%") DO (
	SET /A "export_no+=1"
	SET "remaining_export_vars=!remaining_export_vars:*%%I=!"
	SET "sizelib_exports_!export_no!=%%I=!%%I!"
	IF /I "%%I" EQU "" GOTO sizelib_exports_set
	GOTO sizelib_set_exports
)

:sizelib_exports_set

CHCP %orig_cp% >nul

(FOR /F "usebackq tokens=1,2,3 delims==" %%I IN (`SET sizelib_exports_ 2^>nul`) DO (
	IF DEFINED %%I ENDLOCAL
	SET "%%J=%%K"
)) & (
	ECHO %x_echo%
) & EXIT /B %errno%

:::main }}}1

:procedures ::{{{1

:help ::{{{2

ECHO sizelib.bat 0.99
ECHO.
ECHO Writen by: Pavel Vodrážka
ECHO Licence:   GPLv3
ECHO.
ECHO A library of procedures for enquiring size of a set of files and for
ECHO formatting output.
ECHO.
ECHO Usage:
ECHO [call] sizelib ^<procedure^> [parameters]
ECHO.
ECHO Procedures:
ECHO.
ECHO getSize            Returns the total size of the specified input file list
ECHO                    ^(Windows-style masks^) into specified environment
ECHO                    variables ^(B, kB, MB, GB separately^). 
ECHO.
ECHO    out_B                    Output variable for total bytes.
ECHO    out_kB
ECHO    out_MB
ECHO    out_GB
ECHO    input_file_masks         One or more filenames, paths, or Windows-style
ECHO                             masks.
ECHO.
ECHO formatSize         Returns the formatted size.
ECHO.
ECHO    output_formatted_string Name of the output variable for the formatted
ECHO                            string.
ECHO                            If empty ^(""^), the string is written to the
ECHO                            console.
ECHO    input_B                 Input bytes. Can be given directly as a number
ECHO                            or as the name of a variable holding that number.
ECHO    input_kB
ECHO    input_MB
ECHO    input_GB
ECHO                    The one or more lowest inputs can be empty ^(""^), the
ECHO                    unit printed in the output formatted string is that of
ECHO                    the lowest non empty input.
ECHO                    The one or more highest inputs can also be empty or
ECHO                    not given at all.
ECHO.
ECHO getFormattedSize   Prints the formatted total size of the specified input
ECHO                    file list ^(as in getSize^) to the console.
ECHO.
ECHO    input_file_masks         One or more filenames, paths, or Windows-style
ECHO                             masks.
ECHO.
ECHO help               Prints this help.
ECHO.

EXIT /B 0

:::help }}}2

:getSize out_B out_kB out_MB out_GB input_file_masks ::{{{2

SETLOCAL ENABLEDELAYEDEXPANSION

SET /A "errno=0"
SET "arg_1=1"
SET "arg="
SET "export_vars="
SET "undefined_output_args="
SET "output_args_files="
SET "warning="
SET "pad="
SET "count_fargs="
SET "input_masks_not_found="
SET "input_masks_any_file_found="

FOR %%I IN (out_B out_kB out_MB out_GB) DO (
	SET /A "arg+=1"
	CALL SET "%%I=%%!arg_1!" & SHIFT
	IF NOT DEFINED %%I SET "errno=101" & SET "undefined_output_args=!undefined_output_args!%%~!arg! [%%I] "
	IF EXIST "!%%I!" SET "errno=102" & SET "output_args_files=!output_args_files!%%~!arg! [“!%%I!” in place of “%%I”] "
	IF DEFINED !%%I! SET "warning=!warning!Existing variable “!%%I!” will be overwritten by output.?"
)
IF /I "%errno%" GTR "0" GOTO getSize_error

SET "export_vars=%out_B% %out_kB% %out_MB% %out_GB%"

SET /A "max_farg=99, max_arg=arg + max_farg"
IF "%max_farg%" GTR "9" SET "pad=0"
IF "%max_farg%" GTR "99" SET "pad=00"
FOR /L %%I IN (%arg%,1,%max_arg%) DO (
	SET /A "arg+=1, farg+=1"
	IF DEFINED pad IF "!farg!" EQU "10" SET "pad=!pad:~1!"
	IF DEFINED pad IF "!farg!" EQU "100" SET "pad=!pad:~1!"
	SET "argname=input_mask_!pad!!farg!"
	CALL SET "!argname!=%%!arg_1!" & SHIFT
	IF DEFINED !argname! (
		SET /A "count_fargs+=1"
	) ELSE (
		GOTO getSize_no_more_args
	)
)

:getSize_no_more_args

IF NOT DEFINED count_fargs SET "errno=103" & GOTO getSize_error

FOR /F "usebackq delims== tokens=1*" %%I IN (`SET input_mask_`) DO (
	IF NOT EXIST "%%~J" SET "input_masks_not_found=!input_masks_not_found!%%J "
	IF EXIST "%%J" SET "input_masks_any_file_found=yes"
)
::TODO Add a warning for duplicate files.
IF DEFINED input_masks_not_found SET "warning=!warning!File mask argument[s] “%input_masks_not_found:~0,-1%” do [does] not exist or is [are] inaccessible.?"
IF NOT DEFINED input_masks_any_file_found SET "errno=104" & GOTO getSize_error

FOR /F "usebackq delims== tokens=1*" %%I IN (`SET input_mask_`) DO (
	FOR /F "usebackq tokens=3" %%K IN (`DIR /A:-D /-C %%J 2^>nul ^| FINDSTR /R /C:"^[^ ]"`) DO (
		SET "file_size=%%K"
		SET "file_size_B=!file_size:~-3!"
		SET "file_size_kB=!file_size:~-6,-3!"
		SET "file_size_MB=!file_size:~-9,-6!"
		SET "file_size_GB=!file_size:~-12,-9!"
		FOR %%L IN (B kB MB GB) DO (
			IF "!file_size_%%L:~-3!" NEQ "0" (
				IF "!file_size_%%L:~0,1!" EQU "0" SET "file_size_%%L=!file_size_%%L:~1!"
				IF "!file_size_%%L:~0,1!" EQU "0" SET "file_size_%%L=!file_size_%%L:~1!"
			)
			SET /A "mask_sum_%%L=mask_sum_%%L + file_size_%%L"
			SET file_size_%%L=
		)
	)
	FOR %%M IN (B kB MB GB) DO (
		SET /A "total_sum_%%M=total_sum_%%M + mask_sum_%%M
		SET mask_sum_%%M=
	)
)
SET "BtoB=%total_sum_B:~-3%"
IF "%BtoB:~-3%" NEQ "0" (
	IF "%BtoB:~0,1%" EQU "0" SET "BtoB=%BtoB:~1%"
	IF "%BtoB:~0,1%" EQU "0" SET "BtoB=%BtoB:~1%"
)
SET /A "totB=BtoB"
SET "BtokB=%total_sum_B:~-6,-3%"
SET "kBtokB=%total_sum_kB:~-3%"
IF "%kBtokB:~-3%" NEQ "0" (
	IF "%kBtokB:~0,1%" EQU "0" SET "kBtokB=%kBtokB:~1%"
	IF "%kBtokB:~0,1%" EQU "0" SET "kBtokB=%kBtokB:~1%"
)
SET /A "totkB=BtokB + kBtokB"
SET "kBtoMB=%total_sum_kB:~-6,-3%"
SET "MBtoMB=%total_sum_MB:~-3%"
IF "%MBtoMB:~-3%" NEQ "0" (
	IF "%MBtoMB:~0,1%" EQU "0" SET "MBtoMB=%MBtoMB:~1%"
	IF "%MBtoMB:~0,1%" EQU "0" SET "MBtoMB=%MBtoMB:~1%"
)
SET /A "totMB=kBtoMB + MBtoMB"
SET "MBtoGB=%total_sum_MB:~-6,-3%"
SET "GBtoGB=%total_sum_GB:~-3%"
IF "%GBtoGB:~-3%" NEQ "0" (
	IF "%GBtoGB:~0,1%" EQU "0" SET "GBtoGB=%GBtoGB:~1%"
	IF "%GBtoGB:~0,1%" EQU "0" SET "GBtoGB=%GBtoGB:~1%"
)
SET /A "totGB=MBtoGB + GBtoGB"

GOTO getSize_end

:getSize_error

IF "%errno%" EQU "101" SET errmsg=Output variable[s] %undefined_output_args:~0,-1% missing.
IF "%errno%" EQU "102" SET errmsg=Existing file name[s] in place of output variable[s]: %output_args_files:~0,-1%.
IF "%errno%" EQU "102" SET errexpl=First four arguments must specify output variables for bytes, kilobytes, megabytes, and gigabytes.
IF "%errno%" EQU "103" SET errmsg=Input file mask list [%%~5 - ?] is missing.
IF "%errno%" EQU "104" SET errmsg=None of the specified file mask list [“%input_masks_not_found:~0,-1%”] exists or is accessible.

ECHO. >&2
ECHO ERROR [%errno%]: %errmsg% >&2
IF DEFINED errexpl ECHO.             %errexpl% >&2

:getSize_end

IF DEFINED warning (
	IF "%errno%" GTR "0" ECHO. >&2
	SET "remaining_warnings=%warning%"
	GOTO getSize_output_warning
) ELSE (
	GOTO getSize_set_outputs
)

:getSize_output_warning

FOR /F "usebackq delims=? tokens=1*" %%A IN ('%remaining_warnings%') DO (
	SET "remaining_warnings=%%B"
	SET /A "warning_no+=1"
	IF /I "!warning_no!" EQU "1" (
		ECHO WARNINGS:    [!warning_no!] %%A >&2
	) ELSE (
		ECHO              [!warning_no!] %%A >&2
	)
	IF DEFINED remaining_warnings GOTO getSize_output_warning
)

:getSize_set_outputs

IF "%errno%" EQU "0" (
	ENDLOCAL & (
		SET "export_vars=%export_vars%"
		SET "%out_B%=%totB%"
		SET "%out_kB%=%totkB%"
		SET "%out_MB%=%totMB%"
		SET "%out_GB%=%totGB%"
		SET "errno=%errno%"
	)
) ELSE (
	ENDLOCAL & SET "errno=%errno%"
)

EXIT /B %errno%

:::getSize out_B out_kB out_MB out_GB input_file_masks }}}2

:formatSize output_formatted_string input_B input_kB input_MB input_GB ::{{{2

SETLOCAL ENABLEDELAYEDEXPANSION

SET "errno=0"

SET "output_var=%~1"
::IF NOT DEFINED output_var SET "errno=201" & GOTO formatSize_error
IF NOT DEFINED output_var SET text_output=yes
IF DEFINED output_var IF DEFINED !output_var! SET "warning=!warning!Existing variable “!output_var!” will be overwritten by output.?"

SET "in_B=%~2"
SET "in_kB=%~3"
SET "in_MB=%~4"
SET "in_GB=%~5"

FOR %%I IN (in_GB in_MB in_kB in_B) DO (
	SET "true_val=" & SET "true_var=" & SET "test_excess="
	IF DEFINED arg SET /A "arg-=1"
	IF NOT DEFINED arg SET "arg=5"
	IF DEFINED !%%I! SET "true_var=!%%I!"
	IF DEFINED true_var FOR /F %%J IN ("!true_var!") DO SET "true_val=!%%J!"
	IF DEFINED true_val SET "%%I=!true_val!"
	IF DEFINED %%I IF NOT DEFINED next_undefined SET "any_input=%%~!arg! [%%I: “!true_var!”=“!%%I!”]"
	IF DEFINED any_input IF DEFINED next_undefined IF DEFINED %%I SET "non_contiguous_input=%%~!arg! [%%I: “!true_var!”=“!%%I!”]"
	IF DEFINED any_input IF DEFINED next_undefined IF NOT DEFINED non_contiguous_input IF NOT DEFINED %%I SET "second_undefined= and %%~!arg! [%%I: “!true_var!”=“!%%I!”]"
	IF DEFINED any_input IF NOT DEFINED next_undefined IF NOT DEFINED %%I SET "next_undefined=%%~!arg! [%%I: “!true_var!”=“!%%I!”]"
	IF DEFINED %%I IF "!%%I!" NEQ "0" SET /A "numeric_I=!%%I!" 2>nul && (
		IF "!numeric_I!" EQU "0" SET "non_numeric_input=!non_numeric_input!%%~!arg! [%%I: “!true_var!”=“!%%I!”], "
	) || (
		SET "non_numeric_input=!non_numeric_input!%%~!arg! [%%I: “!true_var!”=“!%%I!”], "
	)
	IF DEFINED %%I SET "test_excess=!%%I:~0,-3!"
	IF DEFINED test_excess SET "excess_numerals=!excess_numerals!%%~!arg! [%%I: “!true_var!”=“!%%I!”], "
)
IF NOT DEFINED any_input SET "errno=202" & GOTO formatSize_error
IF DEFINED non_contiguous_input SET "errno=203" & GOTO formatSize_error
IF DEFINED non_numeric_input (
	FOR /F "usebackq delims=] tokens=3" %%I IN ('%non_numeric_input%') DO SET "multiple_non_numeric_inputs=%%I"
	SET "errno=204" & GOTO formatSize_error
)
IF DEFINED excess_numerals (
	FOR /F "usebackq delims=] tokens=3" %%I IN ('%excess_numerals%') DO SET "multiple_excess_numerals=%%I"
	SET "errno=205" & GOTO formatSize_error
)

FOR %%I IN (in_GB in_MB in_kB in_B) DO (
	SET "processing=%%I"
	IF "!%%I!" NEQ "" SET "unit=!processing:in_=!"
	SET "temp=000!%%I!"
	IF "!temp!" NEQ "000" SET "output=!output!!temp:~-3!"
)
FOR /F "tokens=* delims=0" %%I IN ("%output%") DO SET "output=%%I"
IF "%output%" EQU "" SET "output=0"
SET "output=%output% %unit%

GOTO formatSize_end

:formatSize_error

IF "%errno%" EQU "201" SET errmsg=No output variable [%%~1] given.
IF "%errno%" EQU "202" SET errmsg=No input size arguments [%%~2-%%~5; B-GB] given.
IF "%errno%" EQU "203" SET errmsg=Incorrect combination of input size arguments.
IF "%errno%" EQU "203" SET errexpl=Arguments %any_input% and %non_contiguous_input% given, but %next_undefined%%second_undefined% in between them empty.
IF "%errno%" EQU "204" IF NOT DEFINED multiple_non_numeric_inputs (
		SET errmsg=Input %non_numeric_input:~0,-2% is non-numeric.
	) ELSE (
		SET errmsg=Inputs %non_numeric_input:~0,-2% are non-numeric.
	)
IF "%errno%" EQU "205" IF NOT DEFINED multiple_excess_numerals (
		SET errmsg=Input %excess_numerals:~0,-2% contains excess numerals.
	) ELSE (
		SET errmsg=Inputs %excess_numerals:~0,-2% contain excess numerals.
	)

ECHO ERROR [%errno%]: %errmsg% >&2
IF DEFINED errexpl ECHO.             %errexpl% >&2

:formatSize_end

IF DEFINED warning (
	IF "%errno%" GTR "0" ECHO. >&2
	SET "remaining_warnings=%warning%"
	GOTO formatSize_output_warning
) ELSE (
	GOTO formatSize_set_outputs
)

:formatSize_output_warning

FOR /F "usebackq delims=? tokens=1*" %%A IN ('%remaining_warnings%') DO (
	SET "remaining_warnings=%%B"
	SET /A "warning_no+=1"
	IF /I "!warning_no!" EQU "1" (
		ECHO WARNINGS:    [!warning_no!] %%A >&2
	) ELSE (
		ECHO              [!warning_no!] %%A >&2
	)
	IF DEFINED remaining_warnings GOTO formatSize_output_warning
	IF DEFINED text_output ECHO.
)

:formatSize_set_outputs

IF "%errno%" EQU "0" IF NOT DEFINED text_output (
	ENDLOCAL & (
		SET "export_vars=%output_var%"
		SET "%output_var%=%output%"
		SET "errno=%errno%"
	)
) ELSE (
	ENDLOCAL & (
		SET "errno=%errno%"
		ECHO %output%
	)
)
IF "%errno%" NEQ "0" ENDLOCAL & SET "errno=%errno%"

EXIT /B	%errno%

:::formatSize output_formatted_string input_B input_kB input_MB input_GB }}}2

:getFormattedSize input_file_masks ::{{{2

SETLOCAL ENABLEDELAYEDEXPANSION

SET "errno=0"
SET "B="
SET "kB="
SET "MB="
SET "GB="

CALL :getSize B kB MB GB %*
IF "%errno%" NEQ "0" GOTO getFormattedSize_end

CALL :formatSize "" B kB MB GB

:getFormattedSize_end

ENDLOCAL & SET errno=%errno%

EXIT /B %errno%

:::getFormattedSize input_file_masks }}}2

:testEcho ::{{{2

@SETLOCAL
@PUSHD %TEMP%
@SET "file_name=%~n0%RANDOM%"
@SET "bat_file=%file_name%.bat"
@SET "out_file=%file_name%.txt"
@ECHO VER >%bat_file%
@CALL %bat_file% >%out_file%
@SET "count="
@SET "echo=OFF"
@FOR /F "usebackq tokens=*" %%I IN (%out_file%) DO @SET /A "count+=1"
@IF /I "%count%" GEQ "2" SET "echo=ON"
@DEL %bat_file% %out_file%
@POPD
@ENDLOCAL & SET "echo=%echo%"
@IF /I "%echo%" EQU "OFF" (
	EXIT /B 0
) ELSE (
	EXIT /B -1
)

:::testEcho }}}2

:::procedures }}}1

:: vim: foldmethod=marker
