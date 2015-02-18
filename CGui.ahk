; DEPENDENCIES:
; _Struct():  https://raw.githubusercontent.com/HotKeyIt/_Struct/master/_Struct.ahk - docs: http://www.autohotkey.net/~HotKeyIt/AutoHotkey/_Struct.htm
; sizeof(): https://raw.githubusercontent.com/HotKeyIt/_Struct/master/sizeof.ahk - docs: http://www.autohotkey.net/~HotKeyIt/AutoHotkey/sizeof.htm
; WinStructs: https://github.com/ahkscript/WinStructs
#SingleInstance force

#include <_Struct>
#include <WinStructs>

main := new _CGui("+Resize")
main.Show("w200 h200 y0")


Loop 8 {
	main.Gui("Add", "Text",,"Item " A_Index)
}

return
Esc::
GuiClose:
	ExitApp

class _CGui extends _CGuiBase {
	; ========================================== GUI COMMAND WRAPPERS =============================
	__New(options := 0){
		Gui, new, % "hwndhwnd " options
		this._hwnd := hwnd
		this._PageRECT := this._GuiPageGetRect()
		; Set Range to size of Page for now.
		this._RangeRECT := this._GuiPageGetRect()
	}

	__Destroy(){
		; If top touches range top, left touches page left, right touches page right, or bottom touches page bottom...
		; Removing this GuiControl should trigger a RANGE CHANGE.
		; Same for Gui, Hide?
	}
	
	Show(options){
		Gui, % this._hwnd ":Show", % options
		this._PageRECT := this._GuiPageGetRect()
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
		SoundBeep
		this._GuiSetScrollbarSize()
	}
	
	; The PAGE (Size of window) of a Gui / GuiControl changed. For GuiControls, this is the size of the control
	_GuiPageGetRect(){
		RECT := this._DLL_GetClientRect()
		return RECT
	}
	
	; ========================================== SCROLL BARS ======================================

	_GuiSetScrollbarSize(PageRECT := 0, RangeRECT := 0, mode := "b"){
		Static SB_HORZ := 0, SB_VERT = 1
		static SIF_DISABLENOSCROLL := 0x8
		static SIF_RANGE := 0x1, SIF_PAGE := 0x2, SIF_POS := 0x4, SIF_ALL := 0x17
		
		if (mode = "p"){
			; Set PAGE
			mask := SIF_PAGE
		} else if (mode = "r"){
			; Set RANGE
			mask := SIF_RANGE
		} else {
			; SET PAGE + RANGE
			mask := SIF_PAGE | SIF_RANGE
		}
		;mask |= SIF_DISABLENOSCROLL	; If the scroll bar's new parameters make the scroll bar unnecessary, disable the scroll bar instead of removing it
		;mask := SIF_ALL
		
		if (PageRECT = 0){
			PageRECT := this._PageRECT
		}
		if (RangeRECT = 0){
			RangeRECT := this._RangeRECT
		}
		
		; Alter scroll bars due to client size
		Vlpsi := this._BlankScrollInfo()
		Hlpsi := this._BlankScrollInfo()
		
		Vlpsi.fMask := mask
		Hlpsi.fMask := mask
		
		if (mask & SIF_RANGE){
			Vlpsi.nMin := RangeRECT.Top
			Vlpsi.nMax := RangeRECT.Bottom
			
			Hlpsi.nMin := RangeRECT.Left
			Hlpsi.nMax := RangeRECT.Right
		}
		
		if (mask & SIF_RANGE){
			Vlpsi.nPage := PageRECT.Bottom
			Hlpsi.nPage := PageRECT.Right
		}
		
		;if (mask & SIF_POS){
		;	Vlpsi.nPos := 0
		;	Hlpsi.nPos := 0
		;}

		this._DLL_SetScrollInfo(SB_VERT, Vlpsi)
		this._DLL_SetScrollInfo(SB_HORZ, Hlpsi)
	}

	; Sets cbSize, returns blank scrollinfo
	_BlankScrollInfo(){
		lpsi := new _Struct(WinStructs.SCROLLINFO)
		lpsi.cbSize := sizeof(WinStructs.SCROLLINFO)
		return lpsi
	}


	; ========================================== DLL CALLS ========================================
	
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

	; ========================================== CLASSES ==========================================
	
	class _CGuiControl extends _CGuiBase {
		__New(parent, ctrltype, options := "", text := ""){
			this._parent := parent
			Gui, % this._parent.GuiCmd("Add"), % ctrltype, % "hwndhwnd" options, % text
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

	Guicmd(cmd){
		return this._hwnd ":" cmd
	}
}

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
	
	/*
	ToObj(){
		return {Top: this.RECT.Top, Bottom: this.RECT.Bottom, Left: this.RECT.Left, Right: this.RECT.Right}
	}
	
	ToObj(struct){
	  obj:=[]
	  for k,v in struct
	  {
		if (Asc(k)=10){
		  If IsObject(_Value_:=struct[_TYPE_:=SubStr(k,2)])
			obj[_TYPE_]:=ToObj(_Value_)
		  else obj[_TYPE_]:=_Value_
		}
	  }
	  return obj
	}
	*/
}