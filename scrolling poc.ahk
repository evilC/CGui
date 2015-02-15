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

	MaxH := 200
	MaxV := 200
	LineH := Ceil(MaxH / 20)
	LineV := Ceil(MaxV / 20)
	
	UseShift := False

	__New(){
		Gui, new, hwndhwnd
		this._hwnd := hwnd
		Loop 10 {
			Gui, Add, Text,, Test
		}  
		Gui, Show, w200 h200
		lpsi := new _Struct(WinStructs.SCROLLINFO)
		lpsi.cBsize := sizeof(WinStructs.SCROLLINFO)
		lpsi.fMask := this.SIF_RANGE
		lpsi.nMin := 0
		lpsi.nMax := 200
		
		;this.SetScrollInfo(this._hwnd, this.SB_VERT, lpsi)
		this.SetScrollInfo(this.SB_VERT, lpsi)
		
		lpsi := new _Struct(WinStructs.SCROLLINFO)
		lpsi.cBsize := sizeof(WinStructs.SCROLLINFO)
		lpsi.fMask := this.SIF_PAGE
		lpsi.nPage := 100
		;this.SetScrollInfo(this._hwnd, this.SB_VERT, lpsi)
		this.SetScrollInfo(this.SB_VERT, lpsi)
		
		;fn := bind(this.On_WM_Wheel, this)
		fn := bind(this.Wheel, this)
		OnMessage(this.WM_MOUSEWHEEL, fn)
		
		;fn := bind(this.On_WM_Scroll, this)
		fn := bind(this.Scroll, this)
		OnMessage(this.WM_VSCROLL, fn)
	}
	
	On_WM_Scroll(wParam, lParam, msg, hwnd){
		; WM_VSCROLL https://msdn.microsoft.com/en-gb/library/windows/desktop/bb787577(v=vs.85).aspx
		hw := wParam >> 16
		ToolTip % hw
		
		lpsi := new _Struct(WinStructs.SCROLLINFO)
		lpsi.cBsize := sizeof(WinStructs.SCROLLINFO)
		lpsi.fMask := this.SIF_POS
		lpsi.nPos := hw
		;this.SetScrollInfo(this._hwnd, this.SB_VERT, lpsi)
		this.SetScrollInfo(this.SB_VERT, lpsi)
		
		;this.ScrollWindow(this._hwnd,0, -1)
		return 0
	}
	
	/*
	On_WM_Wheel(wParam, lParam, msg, hwnd){
		; Fix as per http://ahkscript.org/docs/commands/OnMessage.htm
		if (A_PtrSize = 4 && wParam > 0x7FFFFFFF) {  ; Checking A_PtrSize ensures the script is 32-bit.
			wParam := -(~wParam) - 1
		}
		si := wParam >> 16
		;this.ScrollWindow(this._hwnd, 0, si)
	}
	*/

	GetScrollInfo(fnBar, ByRef lpsi){
		; https://msdn.microsoft.com/en-us/library/windows/desktop/bb787583%28v=vs.85%29.aspx
		lpsi := new _Struct(WinStructs.SCROLLINFO)
		lpsi.cBsize := sizeof(WinStructs.SCROLLINFO)
		lpsi.fMask := this.SIF_ALL
		r := DllCall("User32.dll\GetScrollInfo", "Ptr", this._hwnd, "Int", fnBar, "Ptr", lpsi[], "UInt")
		Return r
	}

	;SetScrollInfo(hwnd, fnBar, ByRef lpsi, fRedraw := 1){
	SetScrollInfo(fnBar, ByRef lpsi, fRedraw := 1){
		; https://msdn.microsoft.com/en-us/library/windows/desktop/bb787595%28v=vs.85%29.aspx
		return DllCall("User32.dll\SetScrollInfo", "Ptr", this._hwnd, "Int", fnBar, "Ptr", lpsi[], "UInt", fRedraw, "UInt")
	}
	
	;ScrollWindow(hwnd, XAmount, YAmount, lpRect, lpClipRect){
	;ScrollWindow(hwnd, XAmount, YAmount){
	ScrollWindow(XAmount, YAmount){
		; https://msdn.microsoft.com/en-us/library/windows/desktop/bb787591%28v=vs.85%29.aspx
		return DllCall("User32.dll\ScrollWindow", "Ptr", this._hwnd, "Int", XAmount, "Int", YAmount, "Ptr", 0, "Ptr", 0)
	}
	/*
   ; ===================================================================================================================
   GetScrollInfo(SB, ByRef SI) {
	  Static SI_SIZE := 28
	  Static SIF_ALL := 0x17
	  VarSetCapacity(SI, SI_SIZE, 0)
	  NumPut(SI_SIZE, SI, 0, "UInt")
	  NumPut(SIF_ALL, SI, 4, "UInt")
	  Return DllCall("User32.dll\GetScrollInfo", "Ptr", This._HWND, "Int", SB, "Ptr", &SI, "UInt")
   }
   */
	
	/*
   ; ===================================================================================================================
   SetScrollInfo(SB, Values) {
	  Static SI_SIZE := 28
	  Static SIF := {Max: 0x01, Page: 0x02, Pos: 0x04}
	  Static Off := {Max: 12, Page: 16, Pos: 20}
	  Static SIF_DISABLENOSCROLL := 0x08
	  Mask := 0
	  VarSetCapacity(SI, SI_SIZE, 0)
	  NumPut(SI_SIZE, SI, 0, "UInt")
	  For Key, Value In Values {
		 If SIF.HasKey(Key) {
			Mask |= SIF[Key]
			NumPut(Value, SI, Off[Key], "UInt")
		 }
	  }
	  If (Mask) {
		 NumPut(Mask | SIF_DISABLENOSCROLL, SI, 4, "UInt")
		 Return DllCall("User32.dll\SetScrollInfo", "Ptr", This._HWND, "Int", SB, "Ptr", &SI, "UInt", 1, "UInt")
	  }
	  Return False
   }
	*/
	
	Scroll(WP, LP, Msg, HWND) {
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
		If (SC = SB_LINEMINUS)
			PN := PA - SD
		Else If (SC = SB_LINEPLUS)
			PN := PA + SD
		Else If (SC = SB_PAGEMINUS)
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
			this.ScrollWindow(HS,VS)
		}
		Return 0
   }
   
   On_WM_Wheel(LP, Msg, H) {
	SoundBeep
      Static MK_CONTROL := 0x0008
      Static MK_SHIFT := 0x0004
      Static WM_HSCROLL := 0x0114, WM_VSCROLL := 0x0115
      Static WM_MOUSEWHEEL := 0x020A, WM_MOUSEHWHEEL := 0x020E
      HWND := WinExist("A")
	  /*
      If ScrollGUI.Instances.HasKey(HWND) {
         Instance := Object(ScrollGUI.Instances[HWND])
         If (Instance.RequireCtrl && (This & MK_CONTROL)) || (!Instance.RequireCtrl && !(This & MK_CONTROL))
            If (Instance.WheelH && (Msg = WM_MOUSEHWHEEL))
            || (Instance.WheelH && ((Msg = WM_MOUSEWHEEL) && Instance.UseShift && (This & MK_SHIFT)))
            || (Instance.WheelV && (Msg = WM_MOUSEWHEEL))
			*/
               ;Return Instance.Wheel(This, LP, Msg, HWND)
               Return this.Wheel(This, LP, Msg, HWND)
      ;}
   }
   
   Wheel(WP, LP, Msg, H) {
	  Static MK_SHIFT := 0x0004
	  Static SB_LINEMINUS := 0, SB_LINEPLUS := 1
	  Static WM_MOUSEWHEEL := 0x020A, WM_MOUSEHWHEEL := 0x020E
	  Static WM_HSCROLL := 0x0114, WM_VSCROLL := 0x0115
	  If (Msg = WM_MOUSEWHEEL) && This.UseShift && (WP & MK_SHIFT)
		 Msg := WM_MOUSEHWHEEL
	  MSG := (Msg = WM_MOUSEWHEEL ? WM_VSCROLL : WM_HSCROLL)
	  SB := ((WP >> 16) > 0x7FFF) || (WP < 0) ? SB_LINEPLUS : SB_LINEMINUS
	  ;MsgBox % "sb: " sb ", msg: " msg ", h: " h
	  Return This.Scroll(SB, 0, MSG, H)
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

