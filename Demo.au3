; Include the ImageSearch library
#include "ImageSearch\ImageSearch.au3"

; Force declaration of variables, helps develop good coding habits
AutoItSetOption("MustDeclareVars", 1)

; This will be the target image file to search for
; Currently the gear icon from VS Code, feel free to replace with whatever
Local $target = "DemoTarget.png"

; Declare an init a variable to hold the search result
Local $result = False

; EXAMPLE 1
; Find the image in a specified area, and move the mouse to its location
$result = _ImageSearchArea($target, 1, $desktopLeft, $desktopTop, $desktopWidth, $desktopHeight, 0)
If IsArray($result) Then
    cr("_ImageSearchArea: " & $result[0] & "," & $result[1])
    MouseMove($result[0], $result[1])
Else
    cr("_ImageSearchArea: " & $result)
EndIf

; Reset the mouse position so it doesn't obscure the search target for EXAMPLE 2
MouseMove(0,0)

; EXAMPLE 2
; Find the image across the entire desktop
$result = _ImageSearch($target, 1)
If IsArray($result) Then
    cr("_ImageSearch: " & $result[0] & "," & $result[1])
    MouseMove($result[0], $result[1])
Else
    cr("_ImageSearch: " & $result)
EndIf

; EXAMPLE 3
; Find the image across the entire desktop, and give it 5 seconds before giving up
; NOTE: This will probably fail because the mouse will be obscuring the search target, but you have 5 seconds to move the mouse away, so it may work
$result = _WaitForImageSearch($target, 5, 1)
If IsArray($result) Then
    cr("_WaitForImageSearch: " & $result[0] & "," & $result[1])
    MouseMove($result[0], $result[1])
Else
    cr("_WaitForImageSearch: " & $result)
EndIf

; Both examples accomplish the same goal, in fact _ImageSearch actually calls _ImageSearchArea with predetermined parameters
