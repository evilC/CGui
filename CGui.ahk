; REQUIRES AHK TEST BUILD from HERE: http://ahkscript.org/boards/viewtopic.php?f=24&t=5802

; CGui Library =================================================================================================
; Author: evilC@evilC.com
; Scrolling code by Just Me.

#include <_Struct>
#include <WinStructs>

; Gui Controls
;Class _CGuiControl extends _CGui {
Class _CGuiControl extends _CScrollGui {
	_type := "c"
	_glabel := 0
	; equivalent to Gui, Add, <params>
	; Pass parent as param 1
	__New(aParams*){
		static debug := 0
		aParams.Remove
		this._parent := aParams[1]
		this._type := aParams[2]
		if (debug) {
			OutputDebug, % "[ " this._FormatHwnd() " ] " this._FormatFuncName(A_ThisFunc) "   - Constructor adding GUIControl"
		}
		; Must use base gui commands here, as this.Gui("Add",...) points here!
		Gui, % this._parent._hwnd ":Add", % aParams[2], % "hwndhwnd " aParams[3], % aParams[4]
		this._hwnd := hwnd
	}
	
	__Get(aParam){
		if (aParam = "value"){
			; ToDo: What about other types?
			;if (this._type = "listview"){
			GuiControlGet, val, % this._parent._hwnd ":" , % this._hwnd
			return val
		}
	}
	
	__Set(aParam, aValue){
		if (aParam = "value"){
			return this._parent.GuiControl(,this,aValue)
		}
	}
	
	; Override this to hook into change events independently of g-label.
	; Use to make GuiControls persistent between runs etc (ie save in INI file)
	OnChange(){
		
	}
	
	; Called if a g-label is active OR persistence is on.
	_OnChange(){
		this.OnChange()	; Provide hook to update INI file etc
		if (this._glabel != 0){
			this._glabel.()
		}
	}
}

class _CScrollGui extends _CGui {
	__New(aParams*){
		base.__New(aParams*)
		static WM_HSCROLL := 0x0114, WM_VSCROLL := 0x0115
		static WM_MOUSEWHEEL := 0x020A, WM_MOUSEHWHEEL := 0x020E
		static WM_SIZE := 0x0005
		
		this._Scroll_H := 1
		this._Scroll_V := 1
		this._Scroll_UseShift := False

		fn := bind(this._ScrollHandler, this)
		this.OnMessage(WM_VSCROLL, fn)
		this.OnMessage(WM_HSCROLL, fn)
		
		fn := bind(this._GuiResized, this)
		this.OnMessage(WM_SIZE, fn, 999)
		;fn := bind(this._ContentsResized, this)
		;this.OnMessage(WM_SIZE, fn, 999)
	}
	
	; VARIABLE USAGE SEEMS SENSIBLE
	; This window resized - If scrollbar(s) all the way at the end and you size up, child needs to be scrolled in the direction of the size up.
	_GuiResized(WParam:= 0, lParam := 0, Msg := 0, hwnd := 0){
		static debug := 0
		Static SB_HORZ := 0, SB_VERT = 1
		static SIF_PAGE := 0x2
		
		; obj vars used:
		; this._width, this._height: GET / SET, Used By: _ScrollBarGuiSized(GET)  - SEEMS LEGIT
		
		; Ignore message if it is not for this window
		if (hwnd = 0){
			hwnd := this._hwnd
		} else if (this._hwnd != hwnd){
			; message not for this window
			if (debug){
				OutputDebug, % "[ " this._FormatHwnd() " ] " this._FormatFuncName(A_ThisFunc) "   - Ignoring message "
			}
			return
		}

		WindowRECT := this._GetClientRect()
		if (WindowRECT.Right != this._width || WindowRECT.Bottom != this._height){
			; Window changed since we were last in here, or this is first time in here.
			this._width := WindowRECT.Right
			this._height := WindowRECT.Bottom
		} else {
			if (debug) {
				OutputDebug, % "[ " this._FormatHwnd() " ] " this._FormatFuncName(A_ThisFunc) "   - Aborting as WindowRECT has not changed - " this._SerializeWH(WindowRECT)
			}
			return
		}

		if (debug) {
			OutputDebug, % "[ " this._FormatHwnd() " ] " this._FormatFuncName(A_ThisFunc) "   - Window changed size to (w,h): " this._SerializeWH(WindowRECT)
		}

		this._ScrollBarGuiSized()
	}

	; The contents of a Gui changed size (eg Controls were added to a Gui
	_ContentsResized(WParam := 0, lParam := 0, msg := 0, hwnd := 0){
		static debug := 0
		
		; obj vars used:
		; this._Scroll_Width, this._Scroll_Height - GET / SET - Used in _ScrollBarClientSized (GET), _ScrollBarGuiSized (GET/SET), 
		; this._Client_Width, this._Client_Height - GET / SET - Used in _ScrollBarClientSized (GET)
		; this._LineH, this._LineV - SET, Used in _Scroll (GET)
		
		; Determine if this message is for us
		if (hwnd = 0){
			hwnd := this._hwnd
		} else if (this._hwnd != hwnd){
			; Message not for this window
			;if (debug) {
			;	OutputDebug, % "[ " this._FormatHwnd() " ] " this._FormatFuncName(A_ThisFunc) "   - Ignoring message"
			;}
			return
		}
		
		WindowRECT := this._GetClientRect()	; remove? _GuiResized should set _width and _height.
		CanvasRECT := this._GetClientSize()
		; Use _Scroll_Width not _Width, as that that indicates the last size of WindowRECT that this function saw
		if (this._Scroll_Width == WindowRECT.Right && this._Scroll_Height == WindowRECT.Bottom && this._Client_Width == CanvasRECT.Right && this._Client_Height == CanvasRECT.Bottom){
			; Client Size did not change
			if (debug) {
				OutputDebug, % "[ " this._FormatHwnd() " ] " this._FormatFuncName(A_ThisFunc) "   - Aborting as WindowRECT and CanvasRECT have not changed - " this._SerializeWH(WindowRECT) " / " this._SerializeWH(CanvasRECT)
			}
			return
		}
		if (debug) {
			OutputDebug, % "[ " this._FormatHwnd() " ] " this._FormatFuncName(A_ThisFunc) "   - New Window / Client Sizes (w,h): " this._SerializeWH(WindowRECT) " / " this._SerializeWH(CanvasRECT)
		}
		
		; Set object vars
		this._Client_Width := CanvasRECT.Right
		this._Client_Height := CanvasRECT.Bottom
		
		this._Scroll_Width := WindowRECT.Right
		this._Scroll_Height := WindowRECT.Bottom
		
		this._LineH := Ceil(WindowRECT.Right / 20)
		this._LineV := Ceil(WindowRECT.Bottom / 20)
		this._ScrollBarClientSized()
	}
	
	; Adjust scrollbars due to change in client height.
	; Try and merge / share code with _ScrollBarGuiSized
	_ScrollBarClientSized(){
		static debug := 1
		
		; obj vars used
		; this._Client_Width / this._Client_Height (GET), Used by _ContentsResized (GET/SET), which is the parent to this call
		
		Static SB_HORZ := 0, SB_VERT = 1
		static SIF_ALL := 0x17
		static SIF_RANGE := 0x1
		
		; Alter scroll bars due to client size
		lpsi := this._BlankScrollInfo()
		;lpsi.fMask := SIF_ALL
		lpsi.fMask := SIF_RANGE
		lpsi.nMin := 0
		lpsi.nMax := this._Client_Height
		;lpsi.nPage := this._Scroll_Height
		this._SetScrollInfo(SB_VERT, lpsi)
		
		lpsi.nMax := this._Client_Width
		;lpsi.nPage := this._Scroll_Width
		this._SetScrollInfo(SB_HORZ, lpsi)
		
		if (debug) {
			OutputDebug, % "[ " this._FormatHwnd() " ] " this._FormatFuncName(A_ThisFunc) "   - CLIENT SIZED - (w,h): " this._Client_Width "," this._Client_Height
		}
	}

	; this._Client_Width / Height is a CanvasRECT
	; this._Scroll_Width / Height is a WindowRECT - same as _width?

	; Update scrollbars due to window resize and drag if needed
	; Try and merge / share code with _ScrollBarClientSized
	_ScrollBarGuiSized(){
		static debug := 1
		Static SB_HORZ := 0, SB_VERT = 1
		static SIF_PAGE := 0x2
		; obj vars used:
		; this._width, this._height - GET, Used by: _GuiResized(GET/SET) - SEEMS LEGIT
		
		; This._Scroll_Width . This._Scroll_Height (GET / SET), used by _ContentsResized (GET/SET)
		; This._Scroll_PosH / This._Scroll_PosV (GET/SET), used by _Scroll (_SET)

		; Update Scroll bars and Drag window on size up if needed.
		If (A_EventInfo <> 1) {
			; Filter SendMessage / PostMessage? Not sure what point of this conditional is
			DragH := DragV := 0
			If This._Scroll_H {
				; Horizontal scroll bars are enabled
				If (this._width <> This._Scroll_Width) {
					; Window width doesn't match client area width
					
					; Update Horizontal scroll bar SIZE
					lpsi := this._BlankScrollInfo()
					lpsi.fMask := SIF_PAGE
					lpsi.nPage := this._width + 1
					This._SetScrollInfo(SB_HORZ, lpsi)

					; Update Scroll vars
					This._Scroll_Width := this._width
					
					; Get new scroll info
					This._GetScrollInfo(SB_HORZ, SI)
					
					; Set drag amount
					DragH := This._Scroll_PosH - SI.nPos
					
					; Update scroll bar pos var
					This._Scroll_PosH := SI.nPos
				}
			}
			If This._Scroll_V {
				; Vertical scroll wheels are enabled
				If (this._height <> This._Scroll_Height) {
					; Window Height doesn't match client height
					
					; Update Vertical scroll bar SIZE
					lpsi := this._BlankScrollInfo()
					lpsi.fMask := SIF_PAGE
					lpsi.nPage := this._height + 1
					This._SetScrollInfo(SB_VERT, lpsi)
					
					; Update Scroll vars
					This._Scroll_Height := this._height
					
					; Get new scroll info
					This._GetScrollInfo(SB_VERT, SI)
					
					; Set Drag amount
					DragV := This._Scroll_PosV - SI.nPos
					
					; Update Scrollbar pos var
					This._Scroll_PosV := SI.nPos
				}
			}
			if (DragV || DragH){
				; Perform the drag if required
				this._ScrollWindow(DragH, DragV)
			}
		}
	}
	
	_GetScrollInfo(fnBar, ByRef lpsi, hwnd := 0){
		static SIF_ALL := 0x17
		if (hwnd = 0){
			; Normal use - operate on youurself. Passed hwnd = inspect another window
			hwnd := this._hwnd
		}
		; https://msdn.microsoft.com/en-us/library/windows/desktop/bb787583%28v=vs.85%29.aspx
		lpsi := this._BlankScrollInfo()
		lpsi.fMask := SIF_ALL
		r := DllCall("User32.dll\GetScrollInfo", "Ptr", hwnd, "Int", fnBar, "Ptr", lpsi[], "UInt")
		Return r
	}

	_SetScrollInfo(fnBar, ByRef lpsi, fRedraw := 1, hwnd := 0){
		if (hwnd = 0){
			; Normal use - operate on youurself. Passed hwnd = inspect another window
			hwnd := this._hwnd
		}
		; https://msdn.microsoft.com/en-us/library/windows/desktop/bb787595%28v=vs.85%29.aspx
		return DllCall("User32.dll\SetScrollInfo", "Ptr", hwnd, "Int", fnBar, "Ptr", lpsi[], "UInt", fRedraw, "UInt")
	}
	
	_ScrollWindow(XAmount, YAmount, hwnd := 0){
		if (!hwnd){
			hwnd := this._hwnd
		}
		;tooltip % "Scrolling " hwnd
		; https://msdn.microsoft.com/en-us/library/windows/desktop/bb787591%28v=vs.85%29.aspx
		return DllCall("User32.dll\ScrollWindow", "Ptr", hwnd, "Int", XAmount, "Int", YAmount, "Ptr", 0, "Ptr", 0)
	}

	; Returns a RECT describing the size of the window
	_GetClientRect(){
		lpRect := new _Struct(WinStructs.RECT)
		DllCall("User32.dll\GetClientRect", "Ptr", This._HWND, "Ptr", lpRect[])
		return lpRect
	}

	; Returns a RECT encompassing all GuiControls and GUIs that are a child of this GUI
	_GetClientSize(){
		Critical
		
		DHW := A_DetectHiddenWindows
		DetectHiddenWindows, On
		
		Width := Height := 0
		HWND := this._HWND
		L := T := R := B := LH := TH := ""
		CMD := 5 ; GW_CHILD
		While (HWND := DllCall("GetWindow", "Ptr", HWND, "UInt", CMD, "UPtr")) && (CMD := 2) {
			WinGetPos, X, Y, W, H, % "ahk_id " HWND
			W += X, H += Y
			WinGet, Styles, Style, % "ahk_id " HWND
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
		DetectHiddenWindows, % DHW
		If (LH <> "") {
			POINT := new _Struct(WinStructs.POINT)
			POINT.x := LH
			DllCall("ScreenToClient", "Ptr", this._HWND, "Ptr", POINT[])
			LH := POINT.x
		}
		If (TH <> "") {
			POINT := new _Struct(WinStructs.POINT)
			POINT.y := TH
			DllCall("ScreenToClient", "Ptr", this._HWND, "Ptr", POINT[])
			TH := POINT.y
		}
		RECT := new _Struct(WinStructs.RECT)
		RECT.Left := L
		RECT.Right := R
		RECT.Top := T
		RECT.Bottom := B
		DllCall("MapWindowPoints", "Ptr", 0, "Ptr", this._HWND, "Ptr", RECT[], "UInt", 2)
		Width := RECT.Right + (LH <> "" ? LH : RECT.Left)
		Height := RECT.Bottom + (TH <> "" ? TH : RECT.Top)

		ret := new _Struct(WinStructs.RECT)
		ret.Right := Width
		ret.Bottom := Height
		return ret
	}
	
	_GetParent(hwnd := 0){
		if (hwnd = 0){
			hwnd := this._hwnd
		}
		return DllCall("GetParent", "Uint", hwnd, "Uint")
	}
	
	; Message handlers come here when a scroll bar is dragged
	_ScrollHandler(WParam, lParam, Msg, hwnd){
		; Ignore this message if it is not for this Object.
		If ((this._hwnd) != hwnd){
			return
		}
		this._Scroll(WParam, lParam, Msg)
	}
	
	_Scroll(WP, LP, Msg, HWND := 0) {
		;ToolTip, % "wp: " WP ", lp: " LP ", msg: " msg ", h: " hwnd
		Static SB_LINEMINUS := 0, SB_LINEPLUS := 1, SB_PAGEMINUS := 2, SB_PAGEPLUS := 3, SB_THUMBTRACK := 5
		Static WM_HSCROLL := 0x0114, WM_VSCROLL := 0x0115
		Static SIF_POS := 0x4
		
		if (hwnd = 0){
			hwnd := this._hwnd
		}
		; For safety
		If ((this._hwnd) != HWND){
			return
		}
		
		If (LP <> 0) {
			Return
		}
		SB := (Msg = WM_HSCROLL ? 0 : 1) ; SB_HORZ : SB_VERT
		SC := WP & 0xFFFF
		SD := (Msg = WM_HSCROLL ? This._LineH : This._LineV)
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
			;Return 0
			return
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
		this._ScrollWindow(HS, VS)
		Return
   }
	
	_WheelHandler(wParam, lParam, Msg, hwnd) {
		; _WheelHandler only fires once rather than for each window.
		Static MK_SHIFT := 0x0004
		Static SB_LINEMINUS := 0, SB_LINEPLUS := 1
		Static WM_MOUSEWHEEL := 0x020A, WM_MOUSEHWHEEL := 0x020E
		Static WM_HSCROLL := 0x0114, WM_VSCROLL := 0x0115
		
		Static SB_HORZ := 0, SB_VERT = 1
		; Get the HWND under the mouse
		MouseGetPos,,,,hcurrent,2
		if (hcurrent = ""){
			; No Sub-item found under cursor, get which main parent gui is under the cursor.
			MouseGetPos,,,hcurrent
		}
		; Drill down through Hwnds until one is found with scrollbars showing.
		has_scrollbars := this._GetScrollInfo(SB_HORZ|SB_VERT, lpsi, hcurrent)
		while (!has_scrollbars){
			hcurrent := this._GetParent(hcurrent)
			has_scrollbars := this._GetScrollInfo(SB_HORZ|SB_VERT, lpsi, hcurrent)
			if (hcurrent = 0){
				; No parent found - end
				break
			}
		}
		if (!hcurrent){
			; No Hwnds with visible scrollbars found under mouse.
			; Add Scroll defailt GUI?
			return
		}
		; Look up CGui object for hwnd
		obj := _CGui._HwndLookup[hcurrent]
		if (!IsObject(obj)){
			; No CGui Object found for that hwnd
			return
		}
		
		If (Msg = WM_MOUSEWHEEL) && This._Scroll_UseShift && (wParam & MK_SHIFT) {
			Msg := WM_MOUSEHWHEEL
		}
		MSG := (Msg = WM_MOUSEWHEEL ? WM_VSCROLL : WM_HSCROLL)
		SB := ((wParam >> 16) > 0x7FFF) || (wParam < 0) ? SB_LINEPLUS : SB_LINEMINUS
		
		obj._Scroll(sb, 0, MSG, hcurrent)
		return 0
		;return
	}
	
	_BlankScrollInfo(){
		lpsi := new _Struct(WinStructs.SCROLLINFO)
		lpsi.cBsize := sizeof(WinStructs.SCROLLINFO)
		return lpsi
	}
}

; Wrap AHK functionality in a standardized, easy to use, syntactically similar class
Class _CGui {
	_type := "w"
	; equivalent to Gui, New, <params>
	; put parent as param 1
	__New(parent := 0, Param2 := "", Param3 := "", Param4 := ""){
		static WM_MOUSEWHEEL := 0x020A, WM_MOUSEHWHEEL := 0x020E
		static debug := 0
		
		this._parent := parent
		if (this._parent = 0){
			; Root Instance.
			; Store a lookup table of HWND to CGui object on the Class definition.
			; Not sure if this is a good place to store it or not...
			_CGui._HwndLookup := {}
			_CGui._MessageLookup := {}
			; We only need one wheel handler, as the HWND you are interested in is what is under the mouse.
			; Therefore, one handler should perform the calculations once to determine which HWND should get the wheel input, if any.
			fn := bind(this._WheelHandler, this)
			OnMessage(WM_MOUSEWHEEL, fn, 999)
		}
		if (debug){
			OutputDebug, % "[ " this._FormatHwnd() " ] " this._FormatFuncName(A_ThisFunc) "   - CONSTRUCTOR calling Gui, New: " aParams[1] ", " aParams[2] ", " aParams[3] ", " aParams[4]
		}
		this.Gui("new", Param2, Param3, Param4)
	}
	
	__Delete() {
		this.base.__Class._HwndLookup.Remove(this._hwnd)
	}
	
	OnMessage(msg, cb){
		if (!_CGui._MessageLookup[msg].MaxIndex()){
			; First time a message is subscribed to
			_CGui._MessageLookup[msg] := []
			fn := bind(this._MessageHandler, this)
			OnMessage(msg, fn)
		}
		_CGui._MessageLookup[msg].Insert(cb)
	}
	
	; Receives all all messages
	_MessageHandler(WParam, lParam, Msg, hwnd := 0){
		;_CGui._HwndLookup[hwnd]
		if (_CGui._MessageLookup[msg].MaxIndex()){
			; There are CGui objects subscribed to this message
			Loop % _CGui._MessageLookup[msg].MaxIndex() {
				; Fire message on object
				ret := (_CGui._MessageLookup[msg][A_Index]).(WParam, lParam, Msg, hwnd)
				if (ret = 0){
					; returned 0, kill message chain
					break
				}
			}
		}
	}
	
	_WheelHandler(WParam, lParam, Msg, hwnd) {
		; designed to be overridden
	}
	
	Gui(aParams*){
		static debug := 0
		if (debug){
			OutputDebug, % "[ " this._FormatHwnd() " ] " this._FormatFuncName(A_ThisFunc) "   - START: " aParams[1] ", " aParams[2] ", " aParams[3] ", " aParams[4]
		}
		; Store Guis option object
		if (aParams[1] = "add"){
			this._GuiOptions := this.ParseOptions(aParams[1],aParams[3])
		} else {
			this._GuiOptions := this.ParseOptions(aParams[1],aParams[2])
		}
		
		; Translate options - eg apply added % value for positioning
		cmd := this.ParseOptions(aParams[1])
		if (this._GuiOptions.flags.parent || cmd.flags.parent){
			MsgBox % "Parent option not supported. Use GuiOption(""+Parent"", obj, ...)"
			return
		}
		if (aParams[1] = "new"){
			aParams[1] := this._SerializeOptions()
			if (debug) {
				OutputDebug, % "[ " this._FormatHwnd() " ] " this._FormatFuncName(A_ThisFunc) "   - NEW: " aParams[2] ", " aParams[3] ", " aParams[4]
			}
			Gui, new, % "hwndhwnd " aParams[1], % aParams[3], % aParams[4]
			this._hwnd := hwnd
			; Call _GuiResized() here?
			_CGui._HwndLookup[hwnd] := this
		} else if (aParams[1] = "add") {
			if (this._GuiOptions.flags.v || this._GuiOptions.flags.g){
				; v-label or g-label passed old-school style
				MsgBox % "v-labels and g-labels are not allowed.`n`Please consult the documentation for alternate methods to use."
				return
			}
			aParams[3] := this._SerializeOptions()
			if (debug) {
				OutputDebug, % "[ " this._FormatHwnd() " ] " this._FormatFuncName(A_ThisFunc) "   - ADD: " aParams[2] " - Control Constructor: " aParams[1] ", " aParams[2] ", " aParams[3] ", " aParams[4]
			}
			r := new this.CGuiControl(this, aParams[2], aParams[3], aParams[4])
			if (debug) {
				OutputDebug, % "[ " this._FormatHwnd() " ] "  this._FormatFuncName(A_ThisFunc) "   - ADD: " aParams[2] " - RESULT: Control Hwnd " r._hwnd
				OutputDebug, % " "
			}
			; We added something to this Gui, Child size changed.
			this._ContentsResized()
			return r
		} else if (aParams[1] = "show") {
			aParams[2] := this._SerializeOptions()
			if (debug) {
				OutputDebug, % "[ " this._FormatHwnd() " ] " this._FormatFuncName(A_ThisFunc) "   - SHOW: " aParams[2] ", " aParams[3] ", " aParams[4]
			}
			Gui, % this._hwnd ":" aParams[1], % aParams[2], % aParams[3], % aParams[4]
		} else {
			aParams[2] := this._SerializeOptions()
			if (debug) {
				OutputDebug, % "[ " this._FormatHwnd() " ] " this._FormatFuncName(A_ThisFunc) "   - " aParams[1] "(Generic): " aParams[2] ", " aParams[3] ", " aParams[4]
			}
			Gui, % this._hwnd ":" aParams[1], % aParams[2], % aParams[3], % aParams[4]
		}
		if (debug){
			OutputDebug, % "[ " this._FormatHwnd() " ] " this._FormatFuncName(A_ThisFunc) "   - END"
			OutputDebug, % " "
		}
	}
	
	; Gui's child size changed.
	_ContentsResized(){
		
	}
	
	; The same as Gui, +Option - but lets you pass objects instead of hwnds
	; ToDo: Remove. Replace with this.Gui(option, value)
	GuiOption(option, value){
		debug := 0
		if (debug) {
			OutputDebug, % "[ " this._FormatHwnd() " ] " this._FormatFuncName(A_ThisFunc) "   - GUIOPTION: " option " = " value
		}
		Gui, % this._hwnd ":" option, value
		return this
	}
	
	; Wraps GuiControl to use hwnds and function binding etc
	GuiControl(aParams*){
		static debug := 0
		m := SubStr(aParams[1],1,1)
		if (m = "+" || m = "-"){
			; Options
			o := SubStr(aParams[1],2,1)
			if (o = "g"){
				; Emulate G-Labels whilst also allowing seperate OnChange event to be Extended (For Saving settings in INI etc)
				; Bind g-label to _glabel property
				fn := bind(aParams[3],this)
				aParams[2]._glabel := fn
				; Bind glabel event to _OnChange method
				fn := bind(aParams[2]._OnChange,aParams[2])
				if (debug) {
					OutputDebug, % "[ " this._FormatHwnd() " ] " this._FormatFuncName(A_ThisFunc) "   - GUICONTROL - BIND : " aParams[2]
				}
				GuiControl % aParams[1], % aParams[2]._hwnd, % fn
				return this
			}
		} else {
			if (debug) {
				OutputDebug, % "[ " this._FormatHwnd() " ] " this._FormatFuncName(A_ThisFunc) "   - GUICONTROL: " aParams[2] ", " aParams[3] ", " aParams[4]
			}
			GuiControl, % aParams[1], % aParams[2]._hwnd, % aParams[3]
			return this
		}
	}
	
	ToolTip(Text, duration){
		fn := bind(this.ToolTipTimer, this)
		this._TooltipActive := fn
		SetTimer, % fn, % "-" duration
		ToolTip % Text
	}
	
	ToolTipTimer(){
		ToolTip
	}
	
	; Parses an Option string into an object, for easy interpretation of which options it is setting
	ParseOptions(cmd, options := ""){
		static debug := 0
		static xywh_types := {x: 1, y: 1, w: 1, h: 1}
		static xywh_lookup := {x: "_Width", y: "_Height", w: "_Width", h: "_Height"}
		static wh_types := {w: 1, h: 1}
		if (debug) {
			OutputDebug, % "[ " this._FormatHwnd() " ] " this._FormatFuncName(A_ThisFunc) "   - Processing options: " options
		}
		ret := { flags: {}, options: {}, signs: {} }
		opts := StrSplit(options, A_Space)
		Loop % opts.MaxIndex() {
			opt := opts[A_Index]
			if (debug) {
				OutputDebug, % "[ " this._FormatHwnd() " ] " this._FormatFuncName(A_ThisFunc) "   - Processing option: " opt
			}
			; Strip +/- prefix if it exists
			sign := SubStr(opt,1,1)
			p := 0
			if (sign = "+" || sign = "-"){
				opt := SubStr(opt,2)
			} else {
				; default to being in + mode
				;sign := "+"
				sign := ""
			}
			vg := SubStr(opt,1,1)
			if (vg = "v" || vg = "g"){
				; v-label or g-label
				value := Substr(opt,2)
				opt := vg
			} else {
				; Take non-letters as value
				value := RegExReplace(opt, "^([a-z|A-Z]*)(.*)", "$2")
				; Take all the letters as the option
				opt := RegExReplace(opt, "^([a-z|A-Z]*)(.*)", "$1")

				percent := InStr(value,"%")
				if (percent){
					; non-Standard % value
					max := -1
					
					if (ObjHasKey(xywh_types,opt)){
						if (cmd = "show") {
							; Gui, Show, ...  - available size is that of parent (or desktop)
							max := this._parent[xywh_lookup[opt]]
							if (debug){
								OutputDebug, % "[ " this._FormatHwnd() " ] " this._FormatFuncName(A_ThisFunc) "   - OPTIONS/OPTION (" options "/" opt ") reports Parent (" this._parent._hwnd ") Width: " max
							}
						} else {
							; Gui, Add, ... - available size is that of this
							max := this[xywh_lookup[opt]]
							if (debug){
								OutputDebug, % "[ " this._FormatHwnd() " ] " this._FormatFuncName(A_ThisFunc) "   - OPTIONS/OPTION (" options "/" opt ") reports Width: " max
							}
						}
					}
					
					if (max != -1){
						value := Substr(value, 1, percent-1)
						value := round(( max / 100 ) * value)
						ret.flags._haspercent := 1
					}
				}
			}
			
			ret.flags[opt] := 1
			ret.options[opt] := value
			ret.signs[opt] := sign
		}
		return ret
	}
	
	; Turns an options object into an option string
	_SerializeOptions(opts := 0){
		static debug := 0
		if (opts = 0){
			opts := this._GuiOptions
		}

		options := ""
		Count := 0
		for key, value in opts.options {
			if (Count){
				options .= " "
			}
			options .= opts.signs[key] key value
			Count++
		}
		if (debug){
			OutputDebug, % "[ " this._FormatHwnd() " ] " this._FormatFuncName(A_ThisFunc) "   - Returning: " options
			;OutputDebug, % " "
		}

		return options
	}
	
	; RECT to CSV, mainly for debugging
	_SerializeWH(RECT){
		return RECT.Right "," RECT.Bottom
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
