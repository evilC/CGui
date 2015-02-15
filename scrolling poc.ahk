#SingleInstance force
#NoEnv

#include <_Struct>
#include <WinStructs>

;#Include Class_ScrollGUI.ahk
SetBatchLines, -1

mc := new MyClass()

Esc::
Gui1Close:
Gui1Escape:
ExitApp
; ----------------------------------------------------------------------------------------------------------------------

class MyClass {
	Static SB_HORZ := 0, SB_VERT = 1, SIF_ALL := 0x17, SIF_DISABLENOSCROLL := 0x08, SIF_PAGE := 0x2, SIF_POS := 0x4, SIF_RANGE := 0x1, SIF_TRACKPOS := 0x10
	Static WM_HSCROLL := 0x0114, WM_VSCROLL := 0x0115
	Static WM_MOUSEWHEEL := 0x020A, WM_MOUSEHWHEEL := 0x020E

	MaxH := 0
	MaxV := 0
	LineH := 0
	LineV := 0
	Width := 0
	Height := 0
	PosH := 0
	PosV := 0
	
	ScrollH := 1, ScrollV := 1
	UseShift := False

	__New(){
		Gui, new, hwndhwnd +Resize
		this._hwnd := hwnd
		Loop 20 {
			x := (A_Index -1) * 20
			Gui, Add, Text, x%x%, Test %A_Index%
		}  
		Gui, Show, w200 h200
		
		this.AdjustToChild()
		
		fn := bind(this.Wheel, this)
		OnMessage(this.WM_MOUSEWHEEL, fn)
		
		fn := bind(this.Scroll, this)
		OnMessage(this.WM_VSCROLL, fn)
		OnMessage(this.WM_HSCROLL, fn)
		
		;fn := bind(this.OnSize, this)
		fn := bind(this.AdjustToParent, this)
		OnMessage(0x0005, fn)
	}
	
	AdjustToParent(){
		WindowRECT := this.GetClientRect()
		CanvasRECT := this.GetClientSize()
		Width := WindowRECT.Right
		Height := WindowRECT.Bottom
		If (A_EventInfo <> 1) {
			SH := SV := 0
			If This.ScrollH {
				If (Width <> This.Width) {
					;This.SetScrollInfo(0, {Page: Width + 1})
					lpsi := new _Struct(WinStructs.SCROLLINFO)
					lpsi.cBsize := sizeof(WinStructs.SCROLLINFO)
					lpsi.fMask := this.SIF_PAGE
					lpsi.nPage := Width + 1
					This.SetScrollInfo(this.SB_HORZ, lpsi)

					This.Width := Width
					This.GetScrollInfo(this.SB_HORZ, SI)
					;PosH := NumGet(SI, 20, "Int")
					PosH := SI.nPos
					SH := This.PosH - PosH
					This.PosH := PosH
				}
			}
			If This.ScrollV {
				If (Height <> This.Height) {
					;This.SetScrollInfo(1, {Page: Height + 1})
					lpsi := new _Struct(WinStructs.SCROLLINFO)
					lpsi.cbSize := sizeof(WinStructs.SCROLLINFO)
					lpsi.fMask := this.SIF_PAGE
					lpsi.nPage := Height + 1
					This.SetScrollInfo(this.SB_VERT, lpsi)
					
					This.Height := Height
					This.GetScrollInfo(this.SB_VERT, SI)
					;PosV := NumGet(SI, 20, "Int")
					PosV := SI.nPos
					SV := This.PosV - PosV
					This.PosV := PosV
				}
			}
			if (SV || SH){
				DllCall("User32.dll\ScrollWindow", "Ptr", This._HWND, "Int", SH, "Int", SV, "Ptr", 0, "Ptr", 0)
			}
		}
	}
	
	AdjustToChild(){
		WindowRECT := this.GetClientRect()
		CanvasRECT := this.GetClientSize()
		if (!this.Width || !this.Height){
			Width := WindowRECT.Right
			Height := WindowRECT.Bottom
		}
		this.MaxH := WindowRECT.Right
		this.MaxV := WindowRECT.Bottom
		this.LineH := Ceil(this.MaxH / 20)
		this.LineV := Ceil(this.MaxV / 20)
		
		lpsi := new _Struct(WinStructs.SCROLLINFO)
		lpsi.cBsize := sizeof(WinStructs.SCROLLINFO)
		lpsi.fMask := this.SIF_ALL
		
		lpsi.nMin := 0
		lpsi.nMax := CanvasRECT.Bottom
		lpsi.nPage := WindowRECT.Bottom
		this.SetScrollInfo(this.SB_VERT, lpsi)
		
		lpsi.nMax := CanvasRECT.Right
		lpsi.nPage := WindowRECT.Right
		this.SetScrollInfo(this.SB_HORZ, lpsi)
		
		this.Width := Width
		this.Height := Height
	}
	
	GetScrollInfo(fnBar, ByRef lpsi){
		; https://msdn.microsoft.com/en-us/library/windows/desktop/bb787583%28v=vs.85%29.aspx
		lpsi := new _Struct(WinStructs.SCROLLINFO)
		lpsi.cBsize := sizeof(WinStructs.SCROLLINFO)
		lpsi.fMask := this.SIF_ALL
		r := DllCall("User32.dll\GetScrollInfo", "Ptr", this._hwnd, "Int", fnBar, "Ptr", lpsi[], "UInt")
		Return r
	}

	SetScrollInfo(fnBar, ByRef lpsi, fRedraw := 1){
		; https://msdn.microsoft.com/en-us/library/windows/desktop/bb787595%28v=vs.85%29.aspx
		return DllCall("User32.dll\SetScrollInfo", "Ptr", this._hwnd, "Int", fnBar, "Ptr", lpsi[], "UInt", fRedraw, "UInt")
	}
	
	ScrollWindow(XAmount, YAmount){
		; https://msdn.microsoft.com/en-us/library/windows/desktop/bb787591%28v=vs.85%29.aspx
		return DllCall("User32.dll\ScrollWindow", "Ptr", this._hwnd, "Int", XAmount, "Int", YAmount, "Ptr", 0, "Ptr", 0)
	}

	; Returns a RECT describing the size of the window
	GetClientRect(){
		lpRect := new _Struct(WinStructs.RECT)
		DllCall("User32.dll\GetClientRect", "Ptr", This._HWND, "Ptr", lpRect[])
		return lpRect
	}

	; Returns a RECT encompassing all GuiControls and GUIs that are a child of this GUI
	GetClientSize(){
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
	
	
	Scroll(WP, LP, Msg, HWND) {
		;ToolTip, % "wp: " WP ", lp: " LP ", msg: " msg ", h: " hwnd
		Static SB_LINEMINUS := 0, SB_LINEPLUS := 1, SB_PAGEMINUS := 2, SB_PAGEPLUS := 3, SB_THUMBTRACK := 5
		Static WM_HSCROLL := 0x0114, WM_VSCROLL := 0x0115
		If (LP <> 0) {
			Return
		}
		SB := (Msg = WM_HSCROLL ? 0 : 1) ; SB_HORZ : SB_VERT
		SC := WP & 0xFFFF
		SD := (Msg = WM_HSCROLL ? This.LineH : This.LineV)
		SI := 0
		If (!This.GetScrollInfo(SB, SI)){
			Return
		}
		PA := PN := SI.nPos
		;MsgBox % pa ", " sc
		If (SC = SB_LINEMINUS) {
			;MsgBox % "pn: " PN ", pa: " pa ", lineh: " This.LineH ", linev:" this.LineV
			PN := PA - SD
		
		} Else If (SC = SB_LINEPLUS) {
			;MsgBox % "pn: " PN ", pa: " pa ", lineh: " This.LineH ", linev:" this.LineV
			PN := PA + SD
		} Else If (SC = SB_PAGEMINUS)
			PN := PA - SI.nPage
		Else If (SC = SB_PAGEPLUS)
			PN := PA + SI.nPage
		Else If (SC = SB_THUMBTRACK)
			PN := SI.nTrackPos
		If (PA = PN) {
			Return 0
		}
		
		lpsi := new _Struct(WinStructs.SCROLLINFO)
		lpsi.cBsize := sizeof(WinStructs.SCROLLINFO)
		lpsi.fMask := this.SIF_POS
		lpsi.nPos := PN
		;this.SetScrollInfo(this._hwnd, SB, lpsi)
		this.SetScrollInfo(SB, lpsi)
		
		This.GetScrollInfo(SB, SI)
		PN := SI.nPos
		If (SB = 0)
			This.PosH := PN
		Else
			This.PosV := PN
		If (PA <> PN) {
			HS := VS := 0
		}
		If (Msg = WM_HSCROLL) {
			HS := PA - PN
		} Else {
			VS := PA - PN
		}
		this.ScrollWindow(HS,VS)
		Return 0
   }

	Wheel(WP, LP, Msg, H) {
		;SoundBeep
		Static MK_SHIFT := 0x0004
		Static SB_LINEMINUS := 0, SB_LINEPLUS := 1
		Static WM_MOUSEWHEEL := 0x020A, WM_MOUSEHWHEEL := 0x020E
		Static WM_HSCROLL := 0x0114, WM_VSCROLL := 0x0115
		If (Msg = WM_MOUSEWHEEL) && This.UseShift && (WP & MK_SHIFT) {
			Msg := WM_MOUSEHWHEEL
		}
		MSG := (Msg = WM_MOUSEWHEEL ? WM_VSCROLL : WM_HSCROLL)
		SB := ((WP >> 16) > 0x7FFF) || (WP < 0) ? SB_LINEPLUS : SB_LINEMINUS
		;ToolTip % "sb: " sb ", msg: " msg ", h: " h
		;Return This.Scroll(SB, 0, MSG, H)
		Return This.Scroll(sb, 0, MSG, H)
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

