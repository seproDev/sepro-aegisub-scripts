# Sepro's Aegisub Scripts

These scripts were developed to help subbing of variety shows which require the same effects hundreds of time per episode where GUIs or multiple steps just slow you down too much.
The Quick- series of scripts takes very commonly used functions of other scripts and removes any configuration steps or GUIs.
All scripts are intended to be bound to hotkeys, since otherwise a lot of the value is lost.


### QuickFade
Hotkeys for fading in to or out of the current frame. Should be equivalent to FadeWorkS.

### QuickGradient
Hotkey for generating text with a vertical gradient based on `\1c` and `\2c`.
The clip strip height is dynamically calculated based on color difference and bounding box.
Requires `SubInspector` and `sepro.color`.

### AdvancedStyles
Allows for saving and applying of "Advanced Styles".
If a style should always have a glow or consists of multiple lines in any other way these can be saved into an Advanced Style.
When applying that Advanced Style to a different line, the same additional lines/tags are added.
Advanced Styles are always associated to a regular style.
Requires DependencyControl.
