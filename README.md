# CGui
A wrapper for AHK's GUI functionality, Experimental!

Inspired by Fincs' AFC.  
Made possible by the recent test builds of AHK.  

Please ensure you have a test build of AHK from [this thread](http://ahkscript.org/boards/viewtopic.php?f=24&t=5802).  
To make swapping between builds of ahk, you can use [AHK-EXE-Swapper](https://github.com/ahkscript/AHK-EXE-Swapper).  

##What?
#####Does it do?
A Class that you extend to allow you to turn a Gui or GuiControl into an object (Class).  
#####Are the objectives?
* To simplify the syntax of AHK, whilst maintining it's functionality.
* To provide extra Gui-Related features on top of what AHK normally offers. 

#####Are the current features?
* Add, Edit Guis and GuiControls as objects
* Pass objects as parameters, instead of HWNDs etc.
* Persistent settings systems catered for, sample basic IniRead/Write based system included.
* Example script demonstrating features

##How?
#####Do I use it?
* Include the script.
* Derive any classes you wish to alter them.
* instantiate your first window class `MyClass := new MyClass()`
* Put `base.__New()` at the start of the `__New()` constructor for your class.
* Access Gui functions through `this.GUI()`, using the same syntax.  
eg `Gui, Add, Edit, x0 y0 w100, Text`
would become `this.Gui("Add", "Edit", "x0 y0 w100", "Text")`  
* When adding a Gui item that you will wish to interrogate later, store a reference, like so:  
`this.myedit := this.Gui("Add", "Edit", "x0 y0 w100", "Text")`  
* Do not pass *vLabels* or *gLabels* in Option strings  
Set *gLabels* with `this.GuiContol("+g", <control>, <method>)`  
eg `this.GuiContol("+g", this.myedit, this.EditChanged)`  
* *vLabels* are not required - Get / Set Control properties with <control>.value, eg `myedit.value`.  
* Use `GuiOption` to set gui options, pass objects instead of HWNDs, eg:  
```
this.ChildWindow := new CWindow(this, "-Border")
this.ChildWindow.GuiOption("+Parent", this)
```
* Functions can sometimes be chained, like so:  
`this.ChildWindow := new CWindow(this, "-Border").GuiOption("+Parent", this)`
* An object's *HWND* is always available via it's `_hwnd` property.
* An object's parent is available via it's `_parent` property.


