; REQUIRES AHK TEST BUILD from HERE: http://ahkscript.org/boards/viewtopic.php?f=24&t=5802
; DEPENDENCIES:
; _Struct():  https://raw.githubusercontent.com/HotKeyIt/_Struct/master/_Struct.ahk - docs: http://www.autohotkey.net/~HotKeyIt/AutoHotkey/_Struct.htm
; sizeof(): https://raw.githubusercontent.com/HotKeyIt/_Struct/master/sizeof.ahk - docs: http://www.autohotkey.net/~HotKeyIt/AutoHotkey/sizeof.htm
; WinStructs: https://github.com/ahkscript/WinStructs
#SingleInstance force

#include <_Struct>
#include <WinStructs>

main := new _CGui("+Resize")
main.Show("w200 h100 y0")


Loop 8 {
	main.Gui("Add", "Text", "w500", "Item " A_Index)
}

return
Esc::
GuiClose:
	ExitApp

class _CGui extends _CGuiBase {
	; ScrollInfo array - Declared as associative, but consider 0-based indexed. 0-based so SB_HORZ / SB_VERT map to correct elements.
	_ScrollInfos := {0: 0, 1: 0}
	; ========================================== GUI COMMAND WRAPPERS =============================
	__New(options := 0){
		Static SB_HORZ := 0, SB_VERT = 1
		static WM_SIZE := 0x0005
		static WM_HSCROLL := 0x0114, WM_VSCROLL := 0x0115
		
		Gui, new, % "hwndhwnd " options
		this._hwnd := hwnd
		
		; Set Range to size of Page to start off with.
		this._RangeRECT := this._GuiPageGetRect()
		
		; Initialize scroll info array
		this._ScrollInfos := {0: this._GetScrollInfo(SB_HORZ), 1: this._GetScrollInfo(SB_VERT)}
		
		; Register for ReSize messages
		this._RegisterMessage(WM_SIZE,this._OnSize)
		this._RegisterMessage(WM_HSCROLL,this._OnScroll)
		this._RegisterMessage(WM_VSCROLL,this._OnScroll)

	}

	__Destroy(){
		; If top touches range top, left touches page left, right touches page right, or bottom touches page bottom...
		; Removing this GuiControl should trigger a RANGE CHANGE.
		; Same for Gui, Hide?
	}
	
	Show(options){
		Gui, % this._hwnd ":Show", % options
	}
 
	; Wrapper for Gui commands
	Gui(cmd, aParams*){
		if (cmd = "add"){
			; Create GuiControl
			obj := new this._CGuiControl(this, aParams*)
			
			return obj
		}
	}


	; ========================================== DIMENSIONS =======================================

	; The RANGE (Size of contents) of a GUI / GuiControl changed (Most GuiControls would not have a Range, just a page)
	_GuiRangeChanged(){
		;SoundBeep
		this._GuiSetScrollbarSize()
	}
	
	; The PAGE (Size of window) of a Gui / GuiControl changed. For GuiControls, this is the size of the control
	_GuiPageGetRect(){
		RECT := this._DLL_GetClientRect()
		return RECT
	}

	; Adjust this._PageRECT when Gui Size Changes (ie it was Resized)
	_OnSize(wParam, lParam, msg, hwnd){
		; ToDo: Need to check if hwnd matches this._hwnd ?
		this._PageRECT := this._GuiPageGetRect()
		this._GuiSetScrollbarSize()
	}

	; ========================================== SCROLL BARS ======================================

	_GuiSetScrollbarPos(nTrackPos, bar){
		Static SB_HORZ := 0, SB_VERT = 1
		static SIF_POS := 0x4
		
		this._ScrollInfos[bar].fMask := SIF_POS
		this._ScrollInfos[bar].nPos := nTrackPos
		this._DLL_SetScrollInfo(bar, this._ScrollInfos[bar])
	}
	
	; Set the SIZE component(s) of a scrollbar - PAGE and RANGE
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
		}
	}

	; Sets cbSize, returns blank scrollinfo
	_BlankScrollInfo(){
		lpsi := new _Struct(WinStructs.SCROLLINFO)
		lpsi.cbSize := sizeof(WinStructs.SCROLLINFO)
		return lpsi
	}

	_GetScrollInfo(fnBar, hwnd := 0){
		static SIF_ALL := 0x17
		if (hwnd = 0){
			; Normal use - operate on youurself. Passed hwnd = inspect another window
			hwnd := this._hwnd
		}
		; https://msdn.microsoft.com/en-us/library/windows/desktop/bb787583%28v=vs.85%29.aspx
		lpsi := this._BlankScrollInfo()
		lpsi.fMask := SIF_ALL
		r := DllCall("User32.dll\GetScrollInfo", "Ptr", hwnd, "Int", fnBar, "Ptr", lpsi[], "UInt")
		return lpsi
		;Return r
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
		ScrollInfo := this._GetScrollInfo(bar)
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
			;OutputDebug, % "[ " this._FormatHwnd() " ] " this._FormatFuncName(A_ThisFunc) "   Scrolling window by (x,y) " h ", " v " - new Pos: " this._ScrollInfos[bar].nPos
			this._DLL_ScrollWindow(h, v)
			this._ScrollInfos[bar].nPos := ScrollInfo.nTrackPos
			this._GuiSetScrollbarPos(ScrollInfo.nTrackPos, bar)
		}
	}

	; ========================================== DLL CALLS ========================================

	_DLL_ScrollWindow(XAmount, YAmount, hwnd := 0){
		; https://msdn.microsoft.com/en-us/library/windows/desktop/bb787591%28v=vs.85%29.aspx
		if (!hwnd){
			hwnd := this._hwnd
		}
		;tooltip % "Scrolling " hwnd
		return DllCall("User32.dll\ScrollWindow", "Ptr", hwnd, "Int", XAmount, "Int", YAmount, "Ptr", 0, "Ptr", 0)
	}

	; Wraps GetClientRect() Dll call, returns RECT class (Not Structure! Class!)
	_DLL_GetClientRect(hwnd := 0){
		if (hwnd = 0){
			hwnd := this._hwnd
		}
		RECT := new this.RECT()
		DllCall("User32.dll\GetClientRect", "Ptr", hwnd, "Ptr", RECT[])
		return RECT
	}

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
		if (!IsObject(_CGui._MessageArray)){
			_Cgui._MessageArray := {}
		}
		if (!IsObject(_Gui._MessageArray[msg])){
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
		__New(parent, ctrltype, options := "", text := ""){
			this._parent := parent
			Gui, % this._parent.GuiCmd("Add"), % ctrltype, % "hwndhwnd " options, % text
			this._hwnd := hwnd
			GuiControlGet, Pos, % this._parent._hwnd ":Pos", % this._hwnd
			this._PageRECT := new this.RECT({Top: PosY, Left: PosX, Bottom: PosY + PosH, Right: PosX + PosW})
			if (!this._parent._PageRECT.contains(this._PageRECT)){
				this._parent._RangeRECT.Union(this._PageRECT)
				this._parent._GuiRangeChanged()
			}
		}
		
		__Destroy(){
			; If top touches range top, left touches page left, right touches page right, or bottom touches page bottom...
			; Removing this GuiControl should trigger a RANGE CHANGE.
			; Same for Hiding a GuiControl?
		}
	}

	; Simple patch to prefix Gui commands with HWND
	Guicmd(cmd){
		return this._hwnd ":" cmd
	}
}

; A base class, purely for inheriting.
class _CGuiBase {
	; ========================================== CLASSES ==========================================
	
	; RECT class. Wraps _Struct to provide functionality similar to C
	; https://msdn.microsoft.com/en-us/library/system.windows.rect(v=vs.110).aspx
	class RECT {
		__New(RECT := 0){
			if (RECT = 0){
				RECT := {Top: 0, Bottom: 0, Left: 0, Right: 0}
			}
			this.RECT := new _Struct(WinStructs.RECT, RECT)
		}
		
		__Get(aParam := ""){
			static keys := {Top: 1, Left: 1, Bottom: 1, Right: 1}
			if (aParam = ""){
				; Blank param passed via [""] - pass back RECT Structure
				return this.RECT[""]
			}
			if (ObjHasKey(keys, aParam)){
				return this.RECT[aParam]
			}
		}
		
		__Set(aParam = "", aValue := ""){
			static keys := {Top: 1, Left: 1, Bottom: 1, Right: 1}
			
			if (aParam = ""){
				; Blank param passed via [""] - pass back RECT Structure
				return this.RECT
			}
			if (ObjHasKey(keys, aParam)){
				this.RECT[aParam] := aValue
			}
		}
		
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
	
	_FormatFuncName(func){
		static max := 25
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
