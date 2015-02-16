; REQUIRES AHK TEST BUILD from HERE: http://ahkscript.org/boards/viewtopic.php?f=24&t=5802

; CGui Library =================================================================================================
; Author: evilC@evilC.com
; Scrolling code by Just Me.
; Gui Controls
;Class _CGuiControl extends _CGui {
Class _CGuiControl extends _CScrollGui {
	_type := "c"
	_glabel := 0
	; equivalent to Gui, Add, <params>
	; Pass parent as param 1
	__New(aParams*){
		aParams.Remove
		this._parent := aParams[1]
		this._type := aParams[2]
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

		this.AdjustToChild()
		
		;fn := bind(this._Scroll, this)
		fn := bind(this._ScrollHandler, this)
		OnMessage(WM_VSCROLL, fn, 999)
		OnMessage(WM_HSCROLL, fn, 999)
		
		fn := bind(this.AdjustToParent, this)
		OnMessage(WM_SIZE, fn, 999)
		fn := bind(this.AdjustToChild, this)
		OnMessage(WM_SIZE, fn, 999)
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
		this._width := WindowRECT.Right
		this._height := WindowRECT.Bottom
		CanvasRECT := this._GetClientSize()
		if (!this._Scroll_Width || !this._Scroll_Height){
			Width := WindowRECT.Right
			Height := WindowRECT.Bottom
		}
		this._MaxH := WindowRECT.Right
		this._MaxV := WindowRECT.Bottom
		this._LineH := Ceil(this._MaxH / 20)
		this._LineV := Ceil(this._MaxV / 20)
		
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
		
		this._parent := parent
		if (this._parent = 0){
			; Root Instance.
			; Store a lookup table of HWND to CGui object on the Class definition.
			; Not sure if this is a good place to store it or not...
			_CGui._HwndLookup := {}

			; We only need one wheel handler, as the HWND you are interested in is what is under the mouse.
			; Therefore, one handler should perform the calculations once to determine which HWND should get the wheel input, if any.
			fn := bind(this._WheelHandler, this)
			OnMessage(WM_MOUSEWHEEL, fn, 999)
		}
		this.Gui("new", Param2, Param3, Param4)

		/*
		if (!IsObject(_CGui._HwndLookup)){
			_CGui._HwndLookup := {}
		}
		*/
		

	}
	
	__Delete() {
		this.base.__Class._HwndLookup.Remove(this._hwnd)
	}
	
	_WheelHandler(WParam, lParam, Msg, hwnd) {
		; designed to be overridden
	}
	
	Gui(aParams*){
		; Store Guis option object
		if (aParams[1] = "add"){
			;OutputDebug, % "[" A_ThisFunc "] Calling Parse Add: " aParams[3]
			this._GuiOptions := this.ParseOptions(aParams[3])
		} else {
			;OutputDebug, % "[" A_ThisFunc "] Calling Regular Parse: " aParams[2]
			this._GuiOptions := this.ParseOptions(aParams[2])
		}
		
		; Translate options - eg apply added % value for positioning
		;MsgBox % aParams[3]
		;OutputDebug, % "[" A_ThisFunc "] Calling Command Parse: " aParams[1]
		cmd := this.ParseOptions(aParams[1])
		if (this._GuiOptions.flags.parent || cmd.flags.parent){
			MsgBox % "Parent option not supported. Use GuiOption(""+Parent"", obj, ...)"
			return
		}
		if (aParams[1] = "new"){
			aParams[1] := this.SerializeOptions()
			OutputDebug, % "[" A_ThisFunc "] Executing Gui Cmd (New): " aParams[1] ", " aParams[2] ", " aParams[3] ", " aParams[4]
			Gui, new, % "hwndhwnd " aParams[1], % aParams[3], % aParams[4]
			this._hwnd := hwnd
			_CGui._HwndLookup[hwnd] := this
		} else if (aParams[1] = "add") {
			if (this._GuiOptions.flags.v || this._GuiOptions.flags.g){
				; v-label or g-label passed old-school style
				MsgBox % "v-labels and g-labels are not allowed.`n`Please consult the documentation for alternate methods to use."
				return
			}
			aParams[3] := this.SerializeOptions()
			OutputDebug, % "[" A_ThisFunc "] Executing Gui Cmd (Add): " aParams[1] ", " aParams[2] ", " aParams[3] ", " aParams[4]
			return new this.CGuiControl(this, aParams[2], aParams[3], aParams[4])
		} else {
			aParams[2] := this.SerializeOptions()
			OutputDebug, % "[" A_ThisFunc "] Executing Gui Cmd (Default): " aParams[1] ", " aParams[2] ", " aParams[3] ", " aParams[4]
			Gui, % this._hwnd ":" aParams[1], % aParams[2], % aParams[3], % aParams[4]
		}
	}
	
	; The same as Gui, +Option - but lets you pass objects instead of hwnds
	GuiOption(option, value){
		Gui, % this._hwnd ":" option, value
		return this
	}
	
	; Wraps GuiControl to use hwnds and function binding etc
	GuiControl(aParams*){
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
				GuiControl % aParams[1], % aParams[2]._hwnd, % fn
				return this
			}
		} else {
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
	ParseOptions(options){
		OutputDebug, % "[" A_ThisFunc "] Processing options: " options
		ret := { flags: {}, options: {}, signs: {} }
		opts := StrSplit(options, A_Space)
		Loop % opts.MaxIndex() {
			opt := opts[A_Index]
			OutputDebug, % "[" A_ThisFunc "] Processing option: " opt
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
					
					if(opt = "w" || opt = "x"){
						max := this._width
						OutputDebug, % "[" A_ThisFunc "] Width: " max
						if (max = 0){
							max := this._parent._Width
							OutputDebug, % "[" A_ThisFunc "] Parent Width: " max
						}
					} else if (opt = "h" || opt = "y") {
						max := this._height
						if (max = 0){
							max := this._parent.Width
						}
					}
					
					if (max != -1){
						value := Substr(value, 1, percent-1)
						value := round(( max / 100 ) * value)
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
	SerializeOptions(opts := 0){
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
		OutputDebug, % "[" A_ThisFunc "] Returning: " options
		OutputDebug, % " "

		return options
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
