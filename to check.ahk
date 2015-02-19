#SingleInstance force

; Check activation of child gui on click in a control in the gui.
; eg if click inside an editbox of an inactive gui, the *GUI* should become active also.

; Adding +Border makes Edits in child Guis non-selectable.
Menu,File,Add,Test1,GuiClose
Menu,File,Add,Test2,GuiClose
Menu,File,Add,Test3,GuiClose
Menu,File,Add,Test4,GuiClose
Menu,File,Add,Test5,GuiClose
Menu,Test,Add,Test,:File
Gui, new, hwndhMain
Gui, % hMain ":Add",Edit,w100 h50
Gui, % hMain ":Menu",Test
Gui, % hMain ":Show", w400 h200
Gui, new, % "hwndhLeft -Resize -Border +Parent" hMain
Gui, % hLeft ":Show", w200 h200 x0 y0

Gui, new, % "hwndhLChild -Resize +Border +Parent" hLeft
Gui, % hLChild ":Show", x80 y80 w200 h50, Left
Gui,% hLChild ":Add", Edit, w50 h50 , hLChild

Gui, new, % "hwndhLChild2 -Resize +Border +Parent" hLeft
Gui, % hLChild2 ":Show", x100 y100 w200 h50, Left
Gui,% hLChild2 ":Add", Edit, w50 h50 , hLChild


Gui, new, % "hwndhRight -Resize -Border +Parent" hMain
Gui, % hRight ":Show", w200 h200 x200 y0
Gui, new, % "hwndhRChild +Resize +Parent" hRight
Gui, % hRChild ":Show", x100 y100 w200 h200, Right

return
Esc::
GuiClose:
	ExitApp
