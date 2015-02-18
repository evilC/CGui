#SingleInstance force

#include <_Struct>
#include <WinStructs>

main := new _CGui("+Resize")
main.Show("w200 h200 y0")

;main._GuiRangeChanged()

Loop 9 {
	main.Gui("Add", "Text",,"Item " A_Index)
}

main._GuiRangeChanged()

return
Esc::
GuiClose:
	ExitApp

class _CGui {
	__New(options := 0){
		Gui, new, % "hwndhwnd " options
		this._hwnd := hwnd
		this._PageRECT := new this.RECT()
		this._RangeRECT := new this.RECT()
	}
	
	Show(options){
		Gui, % this._hwnd ":Show", % options
		this._PageRECT := this._GuiPageGetRect()
		ToolTip % "Width :" this._PageRECT.Bottom ", Height: " _PageRECT.Right
	}
 
	; The RANGE (Size of contents) of a GUI / GuiControl changed (Most GuiControls would not have a Range, just a page)
	_GuiRangeChanged(){
		RangeRECT := this._GuiRangeGetRect()
		if (!this._RangeRECT.Contains(RangeRECT)){
			; Range Grew
			this._RangeRECT := this._GuiRangeGetRect()
			;ToolTip % "PageH :" this._PageRECT.Bottom ", RangeH: " this._RangeRECT.Bottom
			if (!this._PageRECT.Contains(this._RangeRECT)){
				MsgBox RANGE GREW
				SoundBeep
			}
		}
	}
	
	; The PAGE (Size of window) of a Gui / GuiControl changed. For GuiControls, this is the size of the control
	_GuiPageGetRect(){
		RECTClass := new this.RECT()
		DllCall("User32.dll\GetClientRect", "Ptr", This._hwnd, "Ptr", RECTClass[])
		return RECTClass
	}

	; ToDo: Do not calculate client RECTs. Let the child classes calculate their own RECTs on an as-needed basis.
	_GuiRangeGetRect(){
		Critical
		
		DHW := A_DetectHiddenWindows
		DetectHiddenWindows, On
		
		Width := Height := 0
		hwnd := this._hwnd
		L := T := R := B := LH := TH := ""
		cmd := 5 ; GW_CHILD
		While (hwnd := DllCall("GetWindow", "Ptr", hwnd, "UInt", cmd, "UPtr")) && (cmd := 2) {
			WinGetPos, X, Y, W, H, % "ahk_id " hwnd
			W += X, H += Y
			WinGet, Styles, Style, % "ahk_id " hwnd
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
			DllCall("ScreenToClient", "Ptr", this._hwnd, "Ptr", POINT[])
			LH := POINT.x
		}
		If (TH <> "") {
			POINT := new _Struct(WinStructs.POINT)
			POINT.y := TH
			DllCall("ScreenToClient", "Ptr", this._hwnd, "Ptr", POINT[])
			TH := POINT.y
		}
		RECT := new _Struct(WinStructs.RECT)
		RECT.Left := L
		RECT.Right := R
		RECT.Top := T
		RECT.Bottom := B
		DllCall("MapWindowPoints", "Ptr", 0, "Ptr", this._hwnd, "Ptr", RECT[], "UInt", 2)
		
		return new this.RECT({Right: RECT.Right + (LH <> "" ? LH : RECT.Left), Bottom: RECT.Bottom + (TH <> "" ? TH : RECT.Top)})
	}
	
	Gui(cmd, aParams*){
		if (cmd = "add"){
			; Create GuiControl
			obj := new this._CGuiControl(this, aParams*)
			
			return obj
		}
	}

	; ==================================== CLASSES ===============================================================
	
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
			return (this.RECT.Bottom >= RECT.Bottom && this.RECT.Right >= RECT.Right)
		}
		
		; Is this RECT equal to the passed RECT?
		Equals(RECT){
			return (this.RECT.Bottom = RECT.Bottom && this.RECT.Right = RECT.Right)
		}
		
		; Expands the current RECT to include the new RECT
		; Returns TRUE if it the RECT grew.
		Union(RECT){
			Expanded := 0
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

	class _CGuiControl {
		__New(parent, ctrltype, options := "", text := ""){
			this._parent := parent
			Gui, % this._parent.GuiCmd("Add"), % ctrltype, % "hwndhwnd" options, % text
			this._hwnd := hwnd
			this._parent._GuiRangeChanged()
		}
	}

	Guicmd(cmd){
		return this._hwnd ":" cmd
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