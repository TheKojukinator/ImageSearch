; Include the ImageSearch library
#include ".\ImageSearch\ImageSearch.au3"

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
If IsArray($result) Then MouseMove($result[0], $result[1])

; EXAMPLE 2
; Find the image across the entire desktop
$result = _ImageSearch($target, 1)
If IsArray($result) Then MouseMove($result[0], $result[1])

; Both examples accomplish the same goal, in fact _ImageSearch actually calls _ImageSearchArea with predetermined parameters
