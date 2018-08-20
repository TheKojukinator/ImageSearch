#include-once
#include <WinAPI.au3>       ; for _WinAPI_GetSystemMetrics
#include <WinAPIFiles.au3>  ; for _WinAPI_Wow64EnableWow64FsRedirection

; Make sure the DLL path exists, FileInstall doesn't create folders
If Not FileExists("ImageSearch\dll\") Then DirCreate("ImageSearch\dll\")

; This script's functionality depends on these DLLs being present in the script's path
#Region Required DLLs
If Not FileExists("ImageSearch\dll\ImageSearchDLLx32.dll") Then FileInstall("ImageSearch\dll\ImageSearchDLLx32.dll", "ImageSearch\dll\ImageSearchDLLx32.dll")
If Not FileExists("ImageSearch\dll\ImageSearchDLLx64.dll") Then FileInstall("ImageSearch\dll\ImageSearchDLLx64.dll", "ImageSearch\dll\ImageSearchDLLx64.dll")
; Microsoft Visual C++ Redistributable x32
If Not FileExists("ImageSearch\dll\msvcr110.dll") Then FileInstall("ImageSearch\dll\msvcr110.dll", "ImageSearch\dll\msvcr110.dll")
; Microsoft Visual C++ Redistributable x64
If Not FileExists("ImageSearch\dll\msvcr110d.dll") Then FileInstall("ImageSearch\dll\msvcr110d.dll", "ImageSearch\dll\msvcr110d.dll")
#EndRegion

; When working with multiple monitors, we need to determine absolute desktop dimensions manually, so we can escape the boundaries of the primary monitor
; Ref: https://msdn.microsoft.com/en-us/library/ms724385(v=vs.85).aspx
Global $desktopLeft     = _WinAPI_GetSystemMetrics(76)
Global $desktopTop      = _WinAPI_GetSystemMetrics(77)
Global $desktopWidth    = _WinAPI_GetSystemMetrics(78)
Global $desktopHeight   = _WinAPI_GetSystemMetrics(79)
Global $desktopRight    = $desktopLeft + $desktopWidth
Global $desktopBottom   = $desktopTop + $desktopHeight

; Will become the Handle returned by DllOpen() that will be referenced in the _ImageSearchRegion() function
Local $hImageSearchDLL = -1

#Region ImageSearch Startup/Shutdown
Func _ImageSearchStartup()
    _WinAPI_Wow64EnableWow64FsRedirection(True)
    ; Check OS and AutoIt architectures
    ; @OSArch - Returns one of the following: "X86", "IA64", "X64" - this is the architecture type of the currently running operating system
    ; @AutoItX64 - Returns 1 if the script is running under the native x64 version of AutoIt
    If @OSArch = "X86" Or @AutoItX64 = 0 Then
        cr("@OSArch=" & @OSArch & " | " & "@AutoItX64=" & @AutoItX64 & " | " & "Using x32 ImageSearch DLL")
        $hImageSearchDLL = DllOpen("ImageSearch\dll\ImageSearchDLLx32.dll")
        If $hImageSearchDLL = -1 Then Return "DllOpen Error: " & @error
    ElseIf @OSArch = "X64" And @AutoItX64 = 1 Then
        cr("@OSArch=" & @OSArch & " | " & "@AutoItX64=" & @AutoItX64 & " | " & "Using x64 ImageSearch DLL")
        $hImageSearchDLL = DllOpen("ImageSearch\dll\ImageSearchDLLx64.dll")
        If $hImageSearchDLL = -1 Then Return "DllOpen Error: " & @error
    Else
        Return "Inconsistent or incompatible Script/Windows/CPU Architecture"
    EndIf
    Return True
EndFunc ; _ImageSearchStartup

Func _ImageSearchShutdown()
    DllClose($hImageSearchDLL)
    _WinAPI_Wow64EnableWow64FsRedirection(False)
    cr("_ImageSearchShutdown() completed")
    Return True
EndFunc ; _ImageSearchShutdown
#EndRegion ImageSearch Startup/Shutdown

#Region ImageSearch UDF
;===============================================================================
; Description:      Find the position of an image in a specified area
; Syntax:           _ImageSearchArea ( findImage, resultPosition, left, top, right, bottom [, tolerance = 0 [, $transparency = 0]] )
; Parameter(s):
;                   $findImage
;                       Path to image to locate.
;                   $resultPosition
;                       Set where the returned x,y location of the image is.
;                       0 = top left of image, 1 = center of image
;                   $left, $top, $right, $bottom
;                       Bounding coordinates of the desired search area.
;                   $tolerance - [OPTIONAL], default = 0
;                       0 = no tolerance, valid range is 0-255. Needed when colors of
;                       image differ from screen. e.g GIF
;                   $transparency - [OPTIONAL], default = 0
;                       TRANSBLACK, TRANSWHITE or hex value (e.g. 0xffffff) of the color
;                       to be used as transparency.
;
; Return Value(s):  On Success - Returns [x,y] array, location of found image
;                   On Failure - Returns False
;===============================================================================
Func _ImageSearchArea($findImage, $resultPosition, $left, $top, $right, $bottom, $tolerance = 0, $transparency = 0)
    If Not FileExists($findImage) Then Return "Image File not found"
    If $tolerance < 0 Or $tolerance > 255 Then $tolerance = 0
    If $hImageSearchDLL = -1 Then _ImageSearchStartup()
    If $transparency <> 0 Then $findImage = "*Trans" & $transparency & " " & $findImage
    If $tolerance > 0 Then $findImage = "*" & $tolerance & " " & $findImage
    Local $dllResult = DllCall($hImageSearchDLL, "str", "ImageSearch", "int", $left, "int", $top, "int", $right, "int", $bottom, "str", $findImage)
    If @error Then Return "DllCall Error: " & @error
    If $dllResult = "0" Or Not IsArray($dllResult) Or $dllResult[0] = "0" Then Return False
    Local $array = StringSplit($dllResult[0], "|")
    If (UBound($array) >= 4) Then
        Local $result[2]
        ; Get the x,y location of the match
        $result[0] = Int(Number($array[2]))
        $result[1] = Int(Number($array[3]))
        If $resultPosition = 1 Then
            ; Account for the size of the image to compute the center of search
            $result[0] = $result[0] + Int(Number($array[4]) / 2)
            $result[1] = $result[1] + Int(Number($array[5]) / 2)
        EndIf
        Return $result
    EndIf
EndFunc ; _ImageSearchArea

;===============================================================================
; Description:      Find the position of an image in a specified window, or the entire screen
; Syntax:           _ImageSearch ( findImage, resultPosition [, tolerance = 0 [, $transparency = 0 [, hWindow = 0]]] )
; Parameter(s):
;                   $findImage
;                       Path to image to locate.
;                   $resultPosition
;                       Set where the returned x,y location of the image is.
;                       0 = top left of image, 1 = center of image
;                   $tolerance - [OPTIONAL], default = 0
;                       0 = no tolerance, valid range is 0-255. Needed when colors of
;                       image differ from screen. e.g GIF
;                   $transparency - [OPTIONAL], default = 0
;                       TRANSBLACK, TRANSWHITE or hex value (e.g. 0xffffff) of the color
;                       to be used as transparency.
;                   $hWindow - [OPTIONAL], default = 0
;                       Handle to the window in which we're searching.
;
; Return Value(s):  On Success - Returns [x,y] array, location of found image
;                   On Failure - Returns False
;===============================================================================
Func _ImageSearch($findImage, $resultPosition, $tolerance = 0, $transparency = 0, $hWindow = 0)
    ; Try to get the position of the window handle, success will return an array
    Local $winPos = WinGetPos($hWindow)
    ; If we have a window position array, use its boundaries for the search
    If IsArray($winPos) Then
        Return _ImageSearchArea($findImage, $resultPosition, $winPos[0], $winPos[1], $winPos[0]+$winPos[2], $winPos[1]+$winPos[3], $tolerance, $transparency)
    Else
        ; Otherwise use the entire screen
        Return _ImageSearchArea($findImage, $resultPosition, $desktopLeft, $desktopTop, $desktopWidth, $desktopHeight, $tolerance, $transparency)
    EndIf
EndFunc ; _ImageSearch

;===============================================================================
; Description:      Wait for a specified number of seconds for an image to appear
; Syntax:           _WaitForImageSearch ( findImage, resultPosition [, tolerance = 0 [, $transparency = 0 [, hWindow = 0]]] )
; Parameter(s):
;                   $waitSecs
;                       Seconds to try and find the image.
;                   $findImage
;                       Path to image to locate.
;                   $resultPosition
;                       Set where the returned x,y location of the image is.
;                       0 = top left of image, 1 = center of image
;                   $tolerance - [OPTIONAL], default = 0
;                       0 = no tolerance, valid range is 0-255. Needed when colors of
;                       image differ from screen. e.g GIF
;                   $transparency - [OPTIONAL], default = 0
;                       TRANSBLACK, TRANSWHITE or hex value (e.g. 0xffffff) of the color
;                       to be used as transparency.
;                   $hWindow - [OPTIONAL], default = 0
;                       Handle to the window in which we're searching.
;
; Return Value(s):  On Success - Returns [x,y] array, location of found image
;                   On Failure - Returns False
;===============================================================================
Func _WaitForImageSearch($findImage, $waitSecs, $resultPosition, $tolerance = 0, $transparency = 0, $hWindow = 0)
    $waitSecs = $waitSecs * 1000
    Local $startTime = TimerInit()
    While TimerDiff($startTime) < $waitSecs
        Sleep(100)
        Local $result = _ImageSearch($findImage, $resultPosition, $tolerance, $transparency, $hWindow)
        If IsArray($result) Then
            Return $result
        EndIf
    WEnd
    Return False
EndFunc ; _WaitForImageSearch

;===============================================================================
; Description:      Wait for a specified number of seconds for any of a set of images to appear
; Syntax:           _WaitForImagesSearch ( waitSecs, findImage, resultPosition [, tolerance = 0 [, $transparency = 0 [, hWindow = 0]]] )
; Parameter(s):
;                   $waitSecs
;                       Seconds to try and find the image.
;                   $findImage
;                       The ARRAY of paths to images to locate.
;                       ARRAY[0] is set to the number of images to loop through.
;                       ARRAY[1] is the first image.
;                   $resultPosition
;                       Set where the returned x,y location of the image is.
;                       0 = top left of image, 1 = center of image
;                   $tolerance - [OPTIONAL], default = 0
;                       0 = no tolerance, valid range is 0-255. Needed when colors of
;                       image differ from screen. e.g GIF
;                   $transparency - [OPTIONAL], default = 0
;                       TRANSBLACK, TRANSWHITE or hex value (e.g. 0xffffff) of the color
;                       to be used as transparency.
;                   $hWindow - [OPTIONAL], default = 0
;                       Handle to the window in which we're searching.
;
; Return Value(s):  On Success - Returns the index of the successful find, starting at 1
;                   On Failure - Returns False
;===============================================================================
Func _WaitForImagesSearch($findImage, $waitSecs, $resultPosition, $tolerance = 0, $transparency = 0, $hWindow = 0)
    $waitSecs = $waitSecs * 1000
    Local $startTime = TimerInit()
    While TimerDiff($startTime) < $waitSecs
        For $i = 1 To $findImage[0]
            Sleep(100)
            Local $result = _ImageSearch($findImage[$i], $resultPosition, $tolerance, $transparency, $hWindow)
            If IsArray($result) Then
                Return $i
            EndIf
        Next
    WEnd
    Return False
EndFunc ; _WaitForImagesSearch
#EndRegion ImageSearch UDF

#Region Custom ConsoleWrite/debug Function
Func cr($text = "", $addCR = 1, $printTime = True) ; Print to console
    Local Static $sToolTip
    If Not @Compiled Then
        If $printTime Then ConsoleWrite("+>" & @HOUR & ":" & @MIN & ":" & @SEC & " ")
        ConsoleWrite($text)
        If $addCR >= 1 Then ConsoleWrite(@CR)
        If $addCR = 2 Then ConsoleWrite(@CR)
    Else
        If $printTime Then $sToolTip &= "+>" & @HOUR & ":" & @MIN & ":" & @SEC & " "
        $sToolTip &= $text
        If $addCR >= 1 Then $sToolTip &= @CR
        If $addCR = 2 Then $sToolTip &= @CR
        ToolTip($sToolTip)
    EndIf
    Return $text
EndFunc ; cr
#EndRegion Custom ConsoleWrite/debug Function
