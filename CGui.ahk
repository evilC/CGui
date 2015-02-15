; REQUIRES AHK TEST BUILD from HERE: http://ahkscript.org/boards/viewtopic.php?f=24&t=5802

; CGui Library =================================================================================================
; A library 
; Gui Controls
;Class _CGuiControl extends _CGui {
Class _CGuiControl extends _CScrollGui {
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
		
		this._Scroll_H := 1
		this._Scroll_V := 1
		this._Scroll_UseShift := False

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

; Wrap AHK functionality in a standardized, easy to use, syntactically similar class
Class _CGui {
	; equivalent to Gui, New, <params>
	; put parent as param 1
	__New(parent := 0, Param2 := "", Param3 := "", Param4 := ""){
		this._parent := parent
		if (this.parent != 0){
			; parent passed
		}
		this.Gui("new", Param2, Param3, Param4)
	}
	
	Gui(aParams*){
		c := aParams[1]
		opts := this.ParseOptions(aParams[3])
		cmd := this.ParseOptions(aParams[1])
		if (opts.flags.parent || cmd.flags.parent){
			MsgBox % "Parent option not supported. Use GuiOption(""+Parent"", obj, ...)"
			return
		}
		if (aParams[1] = "new"){
			Gui, new, % "hwndhwnd " aParams[2], % aParams[3], % aParams[4]
			this._hwnd := hwnd
		} else if (aParams[1] = "add") {
			if (opts.flags.v || opts.flags.g){
				; v-label or g-label passed old-school style
				MsgBox % "v-labels and g-labels are not allowed.`n`Please consult the documentation for alternate methods to use."
				return
			}
			return new this.CGuiControl(this, aParams[2], aParams[3], aParams[4])
		} else {
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
		ret := { flags: {}, options: {}, signs: {} }
		opts := StrSplit(options, A_Space)
		Loop % opts.MaxIndex() {
			opt := opts[A_Index]
			; Strip +/- prefix if it exists
			sign := SubStr(opt,1,1)
			p := 0
			if (sign = "+" || sign = "-"){
				opt := SubStr(opt,2)
			} else {
				; default to being in + mode
				sign := "+"
			}
			vg := SubStr(opt,1,1)
			if (vg = "v" || vg = "g"){
				; v-label or g-label
				value := Substr(opt,2)
				opt := vg
			} else {
				; Take all the letters as the option
				opt := RegExReplace(opt, "^([a-z|A-Z]*)(.*)", "$1")
				; Take numbers as value
				value := RegExReplace(opt, "^([a-z|A-Z]*)(.*)", "$2")
			}
			
			ret.flags[opt] := 1
			ret.options[opt] := value
			ret.signs[opt] := sign
		}
		return ret
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
