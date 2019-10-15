#NoEnv
#KeyHistory 0
#SingleInstance force
ListLines Off
Process, Priority, , H
SetBatchLines, -1

windowTitle := "A" ; active window = "A", entire screen = ""
, scanPosX = 0 ; left edge of the scan area
, scanPosY = 0 ; top edge of the scan area
, scanWidth = 1000 ; width of the scan area
, scanHeight = 1000 ; height of the scan area

, scanRowSkip = 1.0 ; how often to skip rows, must use skipping loop
, scanColumnSkip = 1.0 ; how often to skip columns, must use skipping loop

; Boilerplate
WinGet, winId, ID, %windowTitle%
hDcWnd := DllCall("GetDC", "UInt", winId)
, hDcBuffer := DllCall("CreateCompatibleDC", "UPtr", hDcWnd)
, hBmBuffer := DllCall("CreateCompatibleBitmap", "UPtr", hDcWnd, "Int", scanWidth, "Int", scanHeight)
, DllCall("SelectObject", "UPtr", hDcBuffer, "UPtr", hBmBuffer)

; Init gdiplus
, VarSetCapacity(startInput, 16, 0)
, startInput := Chr(1)
, hModuleGdip := DllCall("LoadLibrary", "Str", "gdiplus")
, DllCall("gdiplus\GdiplusStartup", "UPtr*", pToken, "UPtr", &startInput, "UPtr", 0)

; Get proc address for max performance
, procBitBlt := DllCall("GetProcAddress", "UPtr", DllCall("GetModuleHandle", "Str", "gdi32"), "AStr", "BitBlt")
, procCreateBitmap := DllCall("GetProcAddress", "UPtr", hModuleGdip, "AStr", "GdipCreateBitmapFromHBITMAP")
, procBitmapLock := DllCall("GetProcAddress", "UPtr", hModuleGdip, "AStr", "GdipBitmapLockBits")
, procBitmapUnlock := DllCall("GetProcAddress", "UPtr", hModuleGdip, "AStr", "GdipBitmapUnlockBits")

loop 1000 {
	; Get bitmap
	DllCall(procBitBlt, "UPtr", hDcBuffer, "Int", 0, "Int", 0, "Int", scanWidth, "Int", scanHeight, "UPtr", hDcWnd, "Int", scanPosX, "Int", scanPosY, "UInt", 0xCC0020)
	, DllCall(procCreateBitmap, "UPtr", hBmBuffer, "UPtr", 0, "UPtr*", pBitmap)

	; Lock bitmap and get byte iteration data
	, VarSetCapacity(bitmapRect, 16, 0)
	, NumPut(scanWidth, bitmapRect, 8, "Int")
	, NumPut(scanHeight, bitmapRect, 12, "Int")
	, VarSetCapacity(bitmapData, 24, 0)
	, DllCall(procBitmapLock, "UPtr", pBitmap, "UPtr", &bitmapRect, "UInt", 3, "Int", 0x26200a, "UPtr", &bitmapData)
	, stride := NumGet(bitmapData, 8, "Int")
	, scan0 := NumGet(bitmapData, 16)

	; Iterate through pixels, ~3,964,000px/s
	Loop %scanHeight% {
		y := A_Index - 1
		Loop %scanWidth%
			col := NumGet(scan0 + 0, (A_Index - 1) * 4 + y * stride, "UInt")
	}
	
	; Uncomment to use skipping, ~3,191,000px/s
	;Loop % Floor(scanHeight / scanRowSkip) {
	;	y := Floor((A_Index - 1) * scanRowSkip)
	;	Loop % Floor(scanWidth / scanColumnSkip)
	;		col := NumGet(scan0 + 0, Floor((A_Index - 1) * scanColumnSkip) * 4 + y * stride, "UInt")
	;		;col := Format("{:p}", NumGet(scan0 + 0, Floor((A_Index - 1) * scanColumnSkip) * 4 + y * stride, "UInt"))
	;}

	; Unlock bitmap
	DllCall(procBitmapUnlock, "UPtr", pBitmap, "UPtr", &bitmapData)
}

; Clean up
DllCall("gdiplus\GdipDisposeImage", "UPtr", pBitmap)
, DllCall("gdiplus\GdiplusShutdown", "UPtr", pToken)
, DllCall("FreeLibrary", "UPtr", hModuleGdip)
, DllCall("DeleteObject", "UPtr", hBmBuffer)
, DllCall("DeleteDC", "UPtr", hDcBuffer)
, DllCall("DeleteDC", "UPtr", hDcWnd)