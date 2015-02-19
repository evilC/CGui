; REQUIRES AHK TEST BUILD from HERE: http://ahkscript.org/boards/viewtopic.php?f=24&t=5802
; DEPENDENCIES:
; _Struct():  https://raw.githubusercontent.com/HotKeyIt/_Struct/master/_Struct.ahk - docs: http://www.autohotkey.net/~HotKeyIt/AutoHotkey/_Struct.htm
; sizeof(): https://raw.githubusercontent.com/HotKeyIt/_Struct/master/sizeof.ahk - docs: http://www.autohotkey.net/~HotKeyIt/AutoHotkey/sizeof.htm
; WinStructs: https://github.com/ahkscript/WinStructs
#SingleInstance force

#include <_Struct>
#include <WinStructs>

main := new _CGui(0,"+Resize")
main.Show("w200 h200 y0", "CGui Demo")

/*
Loop 8 {
	main.Gui("Add", "Text", "w300 Center", "Item " A_Index)
}
*/
main.Child := new _Cgui(main, "+Border +Parent" main._hwnd)
main.Child.Show("w150 h150 x0 y0")

return
Esc::
GuiClose:
	ExitApp

; Wraps All Gui commands - Guis and GuiControls
class _CGui extends _CGuiBase {
	; ScrollInfo array - Declared as associative, but consider 0-based indexed. 0-based so SB_HORZ / SB_VERT map to correct elements.
	_ScrollInfos := {0: 0, 1: 0}
	
	; ========================================== GUI COMMAND WRAPPERS =============================
	; Equivalent to Gui, New
	__New(parent := 0, options := 0, aParams*){
		this._parent := parent
		Static SB_HORZ := 0, SB_VERT = 1
		static WM_MOVE := 0x0003, WM_SIZE := 0x0005
		static WM_HSCROLL := 0x0114, WM_VSCROLL := 0x0115
		
		Gui, new, % "hwndhwnd " options
		this._hwnd := hwnd
		
		; Initialize page and range classes so that all values read 0
		this._RangeRECT := new this.RECT()
		this._PageRECT := new this.RECT()
		
		; Initialize scroll info array
		this._ScrollInfos := {0: this._DLL_GetScrollInfo(SB_HORZ), 1: this._DLL_GetScrollInfo(SB_VERT)}
		
		; Register for ReSize messages
		this._RegisterMessage(WM_SIZE,this._OnSize)
		
		; Register for scroll (drag of thumb) messages
		this._RegisterMessage(WM_HSCROLL,this._OnScroll)
		this._RegisterMessage(WM_VSCROLL,this._OnScroll)
		
		; Register for move message.
		this._RegisterMessage(WM_MOVE,this._OnMove)
	}

	__Destroy(){
		; If top touches range top, left touches page left, right touches page right, or bottom touches page bottom...
		; Removing this GuiControl should trigger a RANGE CHANGE.
		; Same for Gui, Hide?
	}
	
	; Simple patch to prefix Gui commands with HWND
	PrefixHwnd(cmd){
		return this._hwnd ":" cmd
	}

	; Equivalent to Gui, Show
	Show(options := "", title := ""){
		Gui, % this.PrefixHwnd("Show"), % options, % title
	}
 
	; Wrapper for Gui commands
	Gui(cmd, aParams*){
		if (cmd = "add"){
			; Create GuiControl
			return new this._CGuiControl(this, aParams*)
		} else if (cmd = "new"){
			obj := new _CGui(this, aParams*)
			return obj
		}
	}


	; ========================================== DIMENSIONS =======================================

	/*
	; The PAGE (Size of window) of a Gui / GuiControl changed. For GuiControls, this is the size of the control
	_GuiPageGetRect(){
		RECT := this._DLL_GetClientRect()
		return RECT
	}
	*/

	; Adjust this._PageRECT when Gui Size Changes (ie it was Resized)
	; Handles WM_SIZE message
	; https://msdn.microsoft.com/en-us/library/windows/desktop/ms632646%28v=vs.85%29.aspx
	_OnSize(wParam, lParam, msg, hwnd){
		; ToDo: Need to check if hwnd matches this._hwnd ?
		static SIZE_RESTORED := 0, SIZE_MINIMIZED := 1, SIZE_MAXIMIZED := 2, SIZE_MAXSHOW := 3, SIZE_MAXHIDE := 4
		
		if (wParam = SIZE_RESTORED || wParam = SIZE_MAXIMIZED){
			w := lParam & 0xffff
			h := lParam >> 16
			if (w != this._PageRECT.Right || h != this._PageRECT.Bottom){
				; Gui Size Changed - update PAGERECT
				this._PageRECT.Right := w
				this._PageRECT.Bottom := h
			}
			
			; Adjust Scrollbars if required
			this._GuiSetScrollbarSize()
		}
	}
	
	; Called when a GUI Moves.
	; If the GUI moves outside it's parent's RECT, enlarge the parent's RANGE
	_OnMove(wParam, lParam, msg, hwnd){
		;SoundBeep
		; ToDo:
		; OnMove for base class sets window position in INI
		; lParam x/y coords are relative to parent's outer rect - seem pretty useless.
		; WinGetPos gets coordinates relative to SCREEN.
		WinGetPos, X, Y, Width, Height, % "ahk_id " this._hwnd
		if (!this._parent){
			; Root window - _WindowRECT is coords relative to SCREEN.
			this._WindowRECT := new this.RECT({Left: x, Top: y, Right: x + Width, Bottom: y + height})
			;tooltip % this._WindowRECT.Top
		} else {
			; Child window - _WindowRECT is OUTER coords (including chrome) relative to PARENT.
			;tooltip % "Top: " POINT.y ", Left: " POINT.X ", Bottom: " height + POINT.y ", Right: " Width + POINT.x
			POINT := this._DLL_ScreenToClient(this._parent._hwnd,x,y)
			; Set _WindowRECT to OUTER coords, relative to the parent's INNER (client area) RECT.
			this._WindowRECT := new this.RECT({Left: POINT.x, Top: POINT.y, Right: POINT.x + Width, Bottom: POINT.y + height})
			; Enlarge Parent's RANGE if needed.
			if (!this._parent._PageRECT.contains(this._WindowRECT)){
				if (this._parent._RangeRECT.Union(this._WindowRECT)){
					; Union returns true if it enlarged the parent's RANGE
					this._parent._GuiSetScrollbarSize()
				}
			}
		}

	
	}

	; ========================================== SCROLL BARS ======================================

	; Is the scrollbar at maximum? (ie all the way at the end).
	_IsScrollBarAtMaximum(bar){
		end := this._ScrollInfos[bar].nPos + this._ScrollInfos[bar].nPage
		diff := ( this._ScrollInfos[bar].nMax - end ) * -1
		if (diff > 0){
			return diff
		} else {
			return 0
		}
	}
	
	; Set the POSITION component of a scrollbar
	_GuiSetScrollbarPos(nTrackPos, bar){
		Static SB_HORZ := 0, SB_VERT = 1
		static SIF_POS := 0x4
		
		this._ScrollInfos[bar].fMask := SIF_POS
		this._ScrollInfos[bar].nPos := nTrackPos
		this._DLL_SetScrollInfo(bar, this._ScrollInfos[bar])
	}
	
	; Set the SIZE component(s) of a scrollbar - PAGE and RANGE
	; bars = 0 = SB_HORZ
	; bars = 1 = SB_VERT
	; bars = 2 (or omit bars) = both bars
	_GuiSetScrollbarSize(bars := 2, PageRECT := 0, RangeRECT := 0, mode := "b"){
		Static SB_HORZ := 0, SB_VERT = 1
		static SIF_DISABLENOSCROLL := 0x8
		static SIF_RANGE := 0x1, SIF_PAGE := 0x2, SIF_POS := 0x4, SIF_ALL := 0x17
		; Index Min / Max property names of a RECT by SB_HORZ = 0, SB_VERT = 1
		static RECTProperties := { 0: {min: "Left", max: "Right"}, 1: {min: "Top", max: "Bottom"} }
		
		; Determine what part of the scrollbars we wish to set.
		if (mode = "p"){
			; Set PAGE
			mask := SIF_PAGE
		} else if (mode = "r"){
			; Set RANGE
			mask := SIF_RANGE
		} else {
			; Default to SET PAGE + RANGE
			mask := SIF_PAGE | SIF_RANGE
		}
		;mask |= SIF_DISABLENOSCROLL	; If the scroll bar's new parameters make the scroll bar unnecessary, disable the scroll bar instead of removing it
		;mask := SIF_ALL

		; If no RECTs passed, use class properties
		if (PageRECT = 0){
			PageRECT := this._PageRECT
		}
		if (RangeRECT = 0){
			RangeRECT := this._RangeRECT
		}
		
		; Alter scroll bars due to client size
		Loop 2 {
			bar := A_Index - 1 ; SB_HORZ = 0, SB_VERT = 1
			if ( ( bar=0 && (bars = 0 || bars = 2) )   ||  ( bar=1 && bars > 0 ) ){
				; If this scroll bar was specified ...
				; ... Adjust this window's ScrollBar Struct as appropriate, ...
				this._ScrollInfos[bar].fMask := mask
				if (mask & SIF_RANGE){
					; Range bits set
					this._ScrollInfos[bar].nMin := RangeRECT[RECTProperties[bar].min]
					this._ScrollInfos[bar].nMax := RangeRECT[RECTProperties[bar].max]
				}
				
				if (mask & SIF_PAGE){
					; Page bits set
					this._ScrollInfos[bar].nPage := PageRECT[RECTProperties[bar].max]
				}
				; ... Then update the Scrollbar.
				this._DLL_SetScrollInfo(bar, this._ScrollInfos[bar])
			}
			
			; If a vertical scrollbar is showing, and you are scrolled all the way to the bottom of the page...
			; ... If you grab the bottom edge of the window and size up, the contents must scroll downwards.
			; I call this a Size-Scroll.
			if (this._ScrollInfos[bar].nPage <= this._ScrollInfos[bar].nMax){
				; Page (Size of window) is less than Max (Size of contents) - scrollbars will be showing.
				diff := this._IsScrollBarAtMaximum(bar)
				
				if (diff > 0){
					; diff is positive, Size-Scroll required
					; Set up vars for call
					if (bar) {
						h := 0
						v := diff
					} else {
						h := diff
						v := 0
					}
					; Size-Scroll the contents.
					this._DLL_ScrollWindow(h,v)
					if (bar){
						this._ScrollInfos[bar].nPos -= v
					} else {
						this._ScrollInfos[bar].nPos	-= h
					}
				}
			}
		}
	}

	; Sets cbSize, returns blank scrollinfo
	_BlankScrollInfo(){
		lpsi := new _Struct(WinStructs.SCROLLINFO)
		lpsi.cbSize := sizeof(WinStructs.SCROLLINFO)
		return lpsi
	}

	; A scrollbar was dragged
	_OnScroll(wParam, lParam, msg, hwnd){
		; Handles:
		; WM_VSCROLL https://msdn.microsoft.com/en-gb/library/windows/desktop/bb787577(v=vs.85).aspx
		; WM_HSCROLL https://msdn.microsoft.com/en-gb/library/windows/desktop/bb787575(v=vs.85).aspx
		Critical
		static WM_HSCROLL := 0x0114, WM_VSCROLL := 0x0115
		Static SB_HORZ := 0, SB_VERT = 1
		static SB_LINEUP := 0x0, SB_LINEDOWN := 0x1, SB_PAGEUP := 0x2, SB_PAGEDOWN := 0x3, SB_THUMBPOSITION := 0x4, SB_THUMBTRACK := 0x5, SB_TOP := 0x6, SB_BOTTOM := 0x7, SB_ENDSCROLL := 0x8 
		
		if (msg = WM_HSCROLL || msg = WM_VSCROLL){
			bar := msg - 0x114
		} else {
			;SoundBeep
			return
		}
		ScrollInfo := this._DLL_GetScrollInfo(bar)
		;OutputDebug, % "SI: " ScrollInfo.nTrackPos ", Bar: " bar

		if (wParam = SB_LINEUP || wParam = SB_LINEDOWN){
			; "Scrolls one line up / Scrolls one line down"
			; Is an unimplemented flag
			SoundBeep, 100, 100
		} else if (wParam = SB_PAGEUP || wParam = SB_PAGEDOWN){
			; "Scrolls one page up / Scrolls one page down"
			; Is an unimplemented flag
			SoundBeep, 100, 100
		/*
		} else if (wParam = SB_THUMBTRACK){
			; "The user is dragging the scroll box. This message is sent repeatedly until the user releases the mouse button"
			; This is bundled in with the drags, as same code seems good.
		} else if (wParam = SB_THUMBPOSITION || wParam = SB_ENDSCROLL){
			; This is bundled in with the drags, as same code seems good.
			this._GuiSetScrollbarPos(ScrollInfo.nTrackPos, bar)
		} else if (wParam = SB_TOP || wParam = SB_BOTTOM) {
			; "Scrolls to the upper left" / "Scrolls to the lower right"
			; Not entirely sure what these are for, disable for now
			SoundBeep, 100, 100
		*/
		} else {
			; Drag of scrollbar
			; Handles SB_THUMBTRACK, SB_THUMBPOSITION, SB_ENDSCROLL Flags (Indicated by wParam has set LOWORD, Highest value is 0x8 which is SB_ENDSCROLL) ...
			; These Flags generally only get set once each per drag.
			; ... Also handles drag of scrollbar (wParam has set HIWORD = "current position of the scroll box"), so wParam will be very big.
			; This HIWORD "Flag" gets set lots of times per drag.
			if (bar){
				; Vertical Bar
				h := 0
				v := (ScrollInfo.nTrackPos - this._ScrollInfos[bar].nPos) * -1
			} else {
				; Horiz Bar
				h := (ScrollInfo.nTrackPos - this._ScrollInfos[bar].nPos) * -1
				v := 0
			}
			;OutputDebug, % "[ " this._FormatHwnd() " ] " this._SetStrLen(A_ThisFunc) "   Scrolling window by (x,y) " h ", " v " - new Pos: " this._ScrollInfos[bar].nPos
			this._DLL_ScrollWindow(h, v)
			this._ScrollInfos[bar].nPos := ScrollInfo.nTrackPos
			this._GuiSetScrollbarPos(ScrollInfo.nTrackPos, bar)
		}
	}

	; ========================================== DLL CALLS ========================================

	; ACCEPTS x, y
	; Returns a POINT
	_DLL_ScreenToClient(hwnd, x, y){
		; https://msdn.microsoft.com/en-gb/library/windows/desktop/dd162952(v=vs.85).aspx
		lpPoint := new _Struct(WinStructs.POINT, {x: x, y: y})
		r := DllCall("User32.dll\ScreenToClient", "Ptr", hwnd, "Ptr", lpPoint[], "Uint")
		return lpPoint
	}
	
	/*
	_DLL_MapWindowPoints(hwndFrom, hwndTo, ByRef lpPoints, cPoints := 2){
		; https://msdn.microsoft.com/en-gb/library/windows/desktop/dd145046(v=vs.85).aspx
		lpPoints := new _Struct(WinStructs.RECT)
		r := DllCall("User32.dll\MapWindowPoints", "Ptr", hwndFrom, "Ptr", hwndTo, "Ptr", lpPoints[], "Uint", cPoints, "Uint")
		return lpPoints
	}
	*/
	
	; Wraps ScrollWindow() DLL Call.
	_DLL_ScrollWindow(XAmount, YAmount, hwnd := 0){
		; https://msdn.microsoft.com/en-us/library/windows/desktop/bb787591%28v=vs.85%29.aspx
		if (!hwnd){
			hwnd := this._hwnd
		}
		;tooltip % "Scrolling " hwnd
		return DllCall("User32.dll\ScrollWindow", "Ptr", hwnd, "Int", XAmount, "Int", YAmount, "Ptr", 0, "Ptr", 0)
	}

	/*
	; Wraps GetClientRect() Dll call, returns RECT class (Not Structure! Class!)
	_DLL_GetClientRect(hwnd := 0){
		if (hwnd = 0){
			hwnd := this._hwnd
		}
		RECT := new this.RECT()
		DllCall("User32.dll\GetClientRect", "Ptr", hwnd, "Ptr", RECT[])
		return RECT
	}
	*/
	
	; Wraps SetScrollInfo() Dll call.
	; Returns Dll Call return value
	_DLL_SetScrollInfo(fnBar, ByRef lpsi, fRedraw := 1, hwnd := 0){
		; https://msdn.microsoft.com/en-us/library/windows/desktop/bb787595%28v=vs.85%29.aspx
		if (hwnd = 0){
			; Normal use - operate on youurself. Passed hwnd = inspect another window
			hwnd := this._hwnd
		}
		return DllCall("User32.dll\SetScrollInfo", "Ptr", hwnd, "Int", fnBar, "Ptr", lpsi[], "UInt", fRedraw, "UInt")
	}

	;_DLL_GetScrollInfo(fnBar, ByRef lpsi, hwnd := 0){
	; returns a SCROLLINFO structure
	_DLL_GetScrollInfo(fnBar, hwnd := 0){
		; https://msdn.microsoft.com/en-us/library/windows/desktop/bb787583%28v=vs.85%29.aspx
		static SIF_ALL := 0x17
		if (hwnd = 0){
			; Normal use - operate on youurself. Passed hwnd = inspect another window
			hwnd := this._hwnd
		}
		lpsi := this._BlankScrollInfo()
		lpsi.fMask := SIF_ALL
		r := DllCall("User32.dll\GetScrollInfo", "Ptr", hwnd, "Int", fnBar, "Ptr", lpsi[], "UInt")
		return lpsi
		;Return r
	}

	; ========================================== MESSAGES =========================================
	
	; All messages route through here. Only one message of each kind will be registered, to avoid noise and make debugging easier.
	_MessageHandler(wParam, lParam, msg, hwnd){
		; Call the callback associated with this Message and HWND
		(_CGui._MessageArray[msg][hwnd]).(wParam, lParam, msg, hwnd)
	}
	
	; Register a message with the Message handler.
	_RegisterMessage(msg, callback){
		newmessage := 0
		if (!ObjHasKey(_CGui, "_MessageArray")){
			_Cgui._MessageArray := {}
		}
		if (!ObjHasKey(_CGui._MessageArray, msg)){
			_CGui._MessageArray[msg] := {}
			newmessage := 1
		}
		
		; Add the callback to _MessageArray, so that _MessageHandler can look it up and route to it.
		; Store Array on _CGui, so any class can call it's own .RegisterMessage property.
		fn := Bind(callback, this)
		_CGui._MessageArray[msg][this._hwnd] := fn
		
		; Only subscribe to message if this message has not already been subscribed to.
		if (newmessage){
			fn := bind(this._MessageHandler, this)
			OnMessage(msg, fn)
		}
	}
	; ========================================== CLASSES ==========================================
	
	; Wraps GuiControls into an Object
	class _CGuiControl extends _CGuiBase {
		; Equivalent to Gui, Add
		__New(parent, ctrltype, options := "", text := ""){
			this._parent := parent
			Gui, % this._parent.PrefixHwnd("Add"), % ctrltype, % "hwndhwnd " options, % text
			this._hwnd := hwnd
			GuiControlGet, Pos, % this._parent._hwnd ":Pos", % this._hwnd
			this._PageRECT := new this.RECT({Top: PosY, Left: PosX, Bottom: PosY + PosH, Right: PosX + PosW})
			if (!this._parent._PageRECT.contains(this._PageRECT)){
				this._parent._RangeRECT.Union(this._PageRECT)
				this._parent._GuiSetScrollbarSize()
			}
		}
		
		__Destroy(){
			; If top touches range top, left touches page left, right touches page right, or bottom touches page bottom...
			; Removing this GuiControl should trigger a RANGE CHANGE.
			; Same for Hiding a GuiControl?
		}
	}

}

; A base class, purely for inheriting.
class _CGuiBase {
	; ========================================== CLASSES ==========================================
	
	; RECT class. Wraps _Struct to provide functionality similar to C
	; https://msdn.microsoft.com/en-us/library/system.windows.rect(v=vs.110).aspx
	class RECT {
		__New(RECT := 0){
			; Initialize RECT
			if (RECT = 0){
				RECT := {Top: 0, Bottom: 0, Left: 0, Right: 0}
			}
			; Create Structure
			this.RECT := new _Struct(WinStructs.RECT, RECT)
		}
		
		__Get(aParam := ""){
			static keys := {Top: 1, Left: 1, Bottom: 1, Right: 1}
			if (aParam = ""){
				; Blank param passed via [] or [""] - pass back RECT Structure
				return this.RECT[""]
			}
			if (ObjHasKey(keys, aParam)){
				; Top / Left / Bottom / Right property requested - return property from Structure
				return this.RECT[aParam]
			}
		}
		
		__Set(aParam = "", aValue := ""){
			static keys := {Top: 1, Left: 1, Bottom: 1, Right: 1}
			
			if (aParam = ""){
				; Blank param passed via [""] - pass back RECT Structure
				return this.RECT[] := aValue
			}
			
			if (ObjHasKey(keys, aParam)){
				; Top / Left / Bottom / Right property specified - Set property of Structure
				this.RECT[aParam] := aValue
			}
		}
		; Syntax Sugar
		
		; Does this RECT contain the passed rect ?
		Contains(RECT){
			return (this.RECT.Top <= RECT.Top && this.RECT.Left <= RECT.Left && this.RECT.Bottom >= RECT.Bottom && this.RECT.Right >= RECT.Right)
		}
		
		; Is this RECT equal to the passed RECT?
		Equals(RECT){
			return (this.RECT.Bottom = RECT.Bottom && this.RECT.Right = RECT.Right)
		}
		
		; Expands the current RECT to include the new RECT
		; Returns TRUE if it the RECT grew.
		Union(RECT){
			Expanded := 0
			if (RECT.Top < this.RECT.Top){
				this.RECT.Top := RECT.Top
				Expanded := 1
			}
			if (RECT.Left < this.RECT.Left){
				this.RECT.Left := RECT.Left
				Expanded := 1
			}
			if (RECT.Right > this.RECT.Right){
				this.RECT.Right := RECT.Right
				Expanded := 1
			}
			if (RECT.Bottom > this.RECT.Bottom){
				this.RECT.Bottom := RECT.Bottom
				Expanded := 1
			}
			return Expanded
		}
	}

	; Shorthand way of formatting something as 0x0 format Hex
	FormatHex(val){
		return Format("{:#x}", val+0)
	}
	
	; Human readable hwnd, or padded number if not set
	_FormatHwnd(hwnd := -1){
		if (hwnd = -1){
			hwnd := this._hwnd
		}
		if (!hwnd){
			return 0x000000
		} else {
			return hwnd
		}
	}
	
	; Formats a String to a given length.
	_SetStrLen(func, max := 25){
		if (StrLen(func) > max){
			func := Substr(func, 1, max)
		}
		return Format("{:-" max "s}",func)
	}

}

; Functions that will be part of AHK at some point ================================================================================================
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
