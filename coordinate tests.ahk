;#include <_Struct>
;#include <WinStructs>
; ToDo: Scroll window hotkeys so we can check that values are still correct when window scrolled
; Known Bug: Dragging Child to top / left causes crazy numbers (65536...) Singed / Unsigned / 2's comppliment issue?
WM_MOVE := 0x0003, WM_SIZE := 0x0005
OnMessage(WM_MOVE, "OnMove")

Gui, New, +Resize hwndhMain
Gui, % hMain ":Show", w200 h200
Gui, New, % "+Border hwndhChild +Parent" hMain
Gui, % hChild ":Show", % "w200 h200 x0 y0"

;MsgBox % sizeof(WinStructs.POINT)
return

Esc::
GuiClose:
	ExitApp
	
F12::
	;POINT := new _Struct(WinStructs.POINT)
	;POINT.x := 0
	;POINT.y := 0
	; Find 0,0 of Child Page relative to Parent's Range
	CreatePoint(0,0, POINT)
	_DLL_MapWindowPoints(hChild, hMain, POINT)
	POINT := GetPoints(POINT)
	; Subtract size of top and left borders
	POINT := ConvertCoords(POINT, hChild)
	ToolTip % "x: " POINT.x "`ny: " POINT.y
	return

OnMove(wParam, lParam, msg, hwnd){
	global hChild
	; Filter messages only for child window.
	if (hwnd = hChild){
		; x and y are coords of Child Page relative to Parent's Range
		x := lParam & 0xffff
		y := lParam >> 16
		; Convert coords
		POINT := ConvertCoords({x: x, y: y}, hwnd)
		ToolTip % "x: " POINT.x "`ny: " POINT.y
	}
}

BoolToSgn(bool){
	if (bool){
		return "+"
	} else {
		return "-"
	}
}

CreatePoint(x,y, ByRef POINT){
	VarSetCapacity(POINT, 8)
	NumPut(x, POINT, 0, "Uint")
	NumPut(y, POINT, 4, "Uint")
	return POINT
}

GetPoints(ByRef POINT){
	px := NumGet(POINT,0)
	py := NumGet(POINT,4)
	return {x: px, y: py}
}

_DLL_MapWindowPoints(hwndFrom, hwndTo, ByRef lpPoints, cPoints := 1){
	; https://msdn.microsoft.com/en-gb/library/windows/desktop/dd145046(v=vs.85).aspx
	;r := DllCall("User32.dll\MapWindowPoints", "Ptr", hwndFrom, "Ptr", hwndTo, "Ptr", lpPoints[], "Uint", cPoints, "Uint")
	r := DllCall("User32.dll\MapWindowPoints", "Ptr", hwndFrom, "Ptr", hwndTo, "Ptr", &lpPoints, "Uint", cPoints, "Uint")
	return lpPoints
}

ConvertCoords(coords,hwnd){
	static WS_BORDER := 0x00800000, SM_CYCAPTION := 4
	VarSetCapacity(wi,60)
	DllCall("GetWindowInfo","PTR",hwnd,"PTR",&wi)
	; Find size of frame (sizing handles - usually 3px)
	Frame := NumGet(&wi,48,"UInt")
	; Does this window have a "caption" (Title)
	Caption := NumGet(&wi,36,"UInt")
	Caption := Caption & WS_BORDER
	if (Caption = WS_BORDER){
		; Yes - get size of caption
		TitleBar := DllCall("GetSystemMetrics","Int", SM_CYCAPTION)
	} else {
		; No, window is -Border
		TitleBar := 0
	}
	; Adjust coords
	coords.x -= Frame
	coords.y -= TitleBar + Frame
	return coords
}