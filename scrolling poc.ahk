; REQUIRES AHK TEST BUILD from HERE: http://ahkscript.org/boards/viewtopic.php?f=24&t=5802
; DEPENDENCIES:
; _Struct():  https://raw.githubusercontent.com/HotKeyIt/_Struct/master/_Struct.ahk - docs: http://www.autohotkey.net/~HotKeyIt/AutoHotkey/_Struct.htm
; sizeof(): https://raw.githubusercontent.com/HotKeyIt/_Struct/master/sizeof.ahk - docs: http://www.autohotkey.net/~HotKeyIt/AutoHotkey/sizeof.htm
; WinStructs: https://github.com/ahkscript/WinStructs
#SingleInstance force
#NoEnv

#include <_Struct>
#include <WinStructs>
;#include *i <SkinSharp>

;#Include Class_ScrollGUI.ahk
SetBatchLines, -1

ScrollGui := new _CScrollGui()

Esc::
Gui1Close:
Gui1Escape:
ExitApp
; ----------------------------------------------------------------------------------------------------------------------

class _CScrollGui {
	__New(){
		static WM_HSCROLL := 0x0114, WM_VSCROLL := 0x0115
		static WM_MOUSEWHEEL := 0x020A, WM_MOUSEHWHEEL := 0x020E
		
		Gui, new, hwndhwnd +Resize
		this._Scroll_H := 1
		this._Scroll_V := 1
		this._Scroll_UseShift := False

		this._hwnd := hwnd
		Loop 20 {
			x := (A_Index -1) * 20
			Gui, Add, Text, x%x%, Test %A_Index%
		}  
		Gui, Show, w200 h200
		
		this.AdjustToChild()
		
		fn := bind(this._Wheel, this)
		OnMessage(WM_MOUSEWHEEL, fn)
		
		fn := bind(this._Scroll, this)
		OnMessage(WM_VSCROLL, fn)
		OnMessage(WM_HSCROLL, fn)
		
		fn := bind(this.AdjustToParent, this)
		OnMessage(0x0005, fn)
	}
	
	AdjustToParent(){
		Static SB_HORZ := 0, SB_VERT = 1
		static SIF_PAGE := 0x2
		
		WindowRECT := this._GetClientRect()
		CanvasRECT := this._GetClientSize()
		Width := WindowRECT.Right
		Height := WindowRECT.Bottom
		If (A_EventInfo <> 1) {
			SH := SV := 0
			If This._Scroll_H {
				If (Width <> This._Scroll_Width) {
					lpsi := this._BlankScrollInfo()
					lpsi.fMask := SIF_PAGE
					lpsi.nPage := Width + 1
					This._SetScrollInfo(SB_HORZ, lpsi)

					This._Scroll_Width := Width
					This._GetScrollInfo(SB_HORZ, SI)
					PosH := SI.nPos
					SH := This._Scroll_PosH - PosH
					This._Scroll_PosH := PosH
				}
			}
			If This._Scroll_V {
				If (Height <> This._Scroll_Height) {
					lpsi := this._BlankScrollInfo()
					lpsi.fMask := SIF_PAGE
					lpsi.nPage := Height + 1
					This._SetScrollInfo(SB_VERT, lpsi)
					
					This._Scroll_Height := Height
					This._GetScrollInfo(SB_VERT, SI)
					PosV := SI.nPos
					SV := This._Scroll_PosV - PosV
					This._Scroll_PosV := PosV
				}
			}
			if (SV || SH){
				this._ScrollWindow(SH, SV)
			}
		}
	}
	
	AdjustToChild(){
		Static SB_HORZ := 0, SB_VERT = 1
		static SIF_ALL := 0x17
		
		WindowRECT := this._GetClientRect()
		CanvasRECT := this._GetClientSize()
		if (!this._Scroll_Width || !this._Scroll_Height){
			Width := WindowRECT.Right
			Height := WindowRECT.Bottom
		}
		this.MaxH := WindowRECT.Right
		this.MaxV := WindowRECT.Bottom
		this.LineH := Ceil(this.MaxH / 20)
		this.LineV := Ceil(this.MaxV / 20)
		
		lpsi := this._BlankScrollInfo()
		lpsi.fMask := SIF_ALL
		
		lpsi.nMin := 0
		lpsi.nMax := CanvasRECT.Bottom
		lpsi.nPage := WindowRECT.Bottom
		this._SetScrollInfo(SB_VERT, lpsi)
		
		lpsi.nMax := CanvasRECT.Right
		lpsi.nPage := WindowRECT.Right
		this._SetScrollInfo(SB_HORZ, lpsi)
		
		this._Scroll_Width := Width
		this._Scroll_Height := Height
	}
	
	_GetScrollInfo(fnBar, ByRef lpsi){
		static SIF_ALL := 0x17
		; https://msdn.microsoft.com/en-us/library/windows/desktop/bb787583%28v=vs.85%29.aspx
		lpsi := this._BlankScrollInfo()
		lpsi.fMask := SIF_ALL
		r := DllCall("User32.dll\GetScrollInfo", "Ptr", this._hwnd, "Int", fnBar, "Ptr", lpsi[], "UInt")
		Return r
	}

	_SetScrollInfo(fnBar, ByRef lpsi, fRedraw := 1){
		; https://msdn.microsoft.com/en-us/library/windows/desktop/bb787595%28v=vs.85%29.aspx
		return DllCall("User32.dll\SetScrollInfo", "Ptr", this._hwnd, "Int", fnBar, "Ptr", lpsi[], "UInt", fRedraw, "UInt")
	}
	
	_ScrollWindow(XAmount, YAmount){
		; https://msdn.microsoft.com/en-us/library/windows/desktop/bb787591%28v=vs.85%29.aspx
		return DllCall("User32.dll\ScrollWindow", "Ptr", this._hwnd, "Int", XAmount, "Int", YAmount, "Ptr", 0, "Ptr", 0)
	}

	; Returns a RECT describing the size of the window
	_GetClientRect(){
		lpRect := new _Struct(WinStructs.RECT)
		DllCall("User32.dll\GetClientRect", "Ptr", This._HWND, "Ptr", lpRect[])
		return lpRect
	}

	; Returns a RECT encompassing all GuiControls and GUIs that are a child of this GUI
	_GetClientSize(){
		DHW := A_DetectHiddenWindows
		DetectHiddenWindows, On
		VarSetCapacity(RECT, 16, 0)
		Width := Height := 0
		HWND := this._HWND
		CMD := 5 ; GW_CHILD
		L := T := R := B := LH := TH := ""
		While (HWND := DllCall("GetWindow", "Ptr", HWND, "UInt", CMD, "UPtr")) && (CMD := 2) {
		WinGetPos, X, Y, W, H, ahk_id %HWND%
		W += X, H += Y
		WinGet, Styles, Style, ahk_id %HWND%
		If (Styles & 0x10000000) { ; WS_VISIBLE
		If (L = "") || (X < L)
			L := X
		If (T = "") || (Y < T)
			T := Y
		If (R = "") || (W > R)
			R := W
		If (B = "") || (H > B)
			B := H
		}
		Else {
			If (LH = "") || (X < LH)
			LH := X
			If (TH = "") || (Y < TH)
				TH := Y
			}
		}
		DetectHiddenWindows, %DHW%
		If (LH <> "") {
			VarSetCapacity(POINT, 8, 0)
			NumPut(LH, POINT, 0, "Int")
			DllCall("ScreenToClient", "Ptr", this._HWND, "Ptr", &POINT)
			LH := NumGet(POINT, 0, "Int")
		}
		If (TH <> "") {
			VarSetCapacity(POINT, 8, 0)
			NumPut(TH, POINT, 4, "Int")
			DllCall("ScreenToClient", "Ptr", this._HWND, "Ptr", &POINT)
			TH := NumGet(POINT, 4, "Int")
		}
		NumPut(L, RECT, 0, "Int"), NumPut(T, RECT,  4, "Int")
		NumPut(R, RECT, 8, "Int"), NumPut(B, RECT, 12, "Int")
		DllCall("MapWindowPoints", "Ptr", 0, "Ptr", this._HWND, "Ptr", &RECT, "UInt", 2)
		Width := NumGet(RECT, 8, "Int") + (LH <> "" ? LH : NumGet(RECT, 0, "Int"))
		Height := NumGet(RECT, 12, "Int") + (TH <> "" ? TH : NumGet(RECT,  4, "Int"))

		ret := new _Struct(WinStructs.RECT)
		ret.Right := Width
		ret.Bottom := Height
		return ret
	}
	
	
	_Scroll(WP, LP, Msg, HWND) {
		;ToolTip, % "wp: " WP ", lp: " LP ", msg: " msg ", h: " hwnd
		Static SB_LINEMINUS := 0, SB_LINEPLUS := 1, SB_PAGEMINUS := 2, SB_PAGEPLUS := 3, SB_THUMBTRACK := 5
		Static WM_HSCROLL := 0x0114, WM_VSCROLL := 0x0115
		Static SIF_POS := 0x4
		
		If (LP <> 0) {
			Return
		}
		SB := (Msg = WM_HSCROLL ? 0 : 1) ; SB_HORZ : SB_VERT
		SC := WP & 0xFFFF
		SD := (Msg = WM_HSCROLL ? This.LineH : This.LineV)
		SI := 0
		If (!This._GetScrollInfo(SB, SI)){
			Return
		}
		PA := PN := SI.nPos
		If (SC = SB_LINEMINUS) {
			PN := PA - SD
		} Else If (SC = SB_LINEPLUS) {
			PN := PA + SD
		} Else If (SC = SB_PAGEMINUS) {
			PN := PA - SI.nPage
		} Else If (SC = SB_PAGEPLUS) {
			PN := PA + SI.nPage
		} Else If (SC = SB_THUMBTRACK) {
			PN := SI.nTrackPos
		} 
		If (PA = PN) {
			Return 0
		}
		
		lpsi := this._BlankScrollInfo()
		lpsi.fMask := SIF_POS
		lpsi.nPos := PN
		this._SetScrollInfo(SB, lpsi)
		
		This._GetScrollInfo(SB, SI)
		PN := SI.nPos
		If (SB = 0) {
			This._Scroll_PosH := PN
		} Else {
			This._Scroll_PosV := PN
		}
		If (PA <> PN) {
			HS := VS := 0
		}
		If (Msg = WM_HSCROLL) {
			HS := PA - PN
		} Else {
			VS := PA - PN
		}
		this._ScrollWindow(HS,VS)
		Return 0
   }

	_Wheel(WP, LP, Msg, H) {
		Static MK_SHIFT := 0x0004
		Static SB_LINEMINUS := 0, SB_LINEPLUS := 1
		Static WM_MOUSEWHEEL := 0x020A, WM_MOUSEHWHEEL := 0x020E
		Static WM_HSCROLL := 0x0114, WM_VSCROLL := 0x0115
		If (Msg = WM_MOUSEWHEEL) && This._Scroll_UseShift && (WP & MK_SHIFT) {
			Msg := WM_MOUSEHWHEEL
		}
		MSG := (Msg = WM_MOUSEWHEEL ? WM_VSCROLL : WM_HSCROLL)
		SB := ((WP >> 16) > 0x7FFF) || (WP < 0) ? SB_LINEPLUS : SB_LINEMINUS
		Return this._Scroll(sb, 0, MSG, H)
	}
	
	_BlankScrollInfo(){
		lpsi := new _Struct(WinStructs.SCROLLINFO)
		lpsi.cBsize := sizeof(WinStructs.SCROLLINFO)
		return lpsi
	}
}

bind(fn, args*) {  ; bind v1.2
	 try bound := fn.bind(args*)  ; Func.Bind() not yet implemented.
	 return bound ? bound : new BoundFunc(fn, args*)
}

class BoundFunc {
	 __New(fn, args*) {
		  this.fn := IsObject(fn) ? fn : Func(fn)
		  this.args := args
	 }
	 __Call(callee, args*) {
		  if (callee = "" || callee = "call" || IsObject(callee)) {  ; IsObject allows use as a method.
				fn := this.fn, args.Insert(1, this.args*)
				return %fn%(args*)
		  }
	 }
}

