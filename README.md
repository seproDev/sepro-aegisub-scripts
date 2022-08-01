# Sepro's Aegisub Scripts

Most of these scripts do functions already possible with other scripts.
These scripts were developed to help subbing of variety shows which require the same effects hundreds of time per episode requiring hotkeys instead of GUIs to sub effectively.


### QuickFade
Hotkeys for fading in to or out of the current frame. Should be equivalent to FadeWorkS.

### QuickGradient
Hotkey for generating text with a vertical gradient based on `\1c` and `\2c`.
The clip width is dynamically calculated based on color difference and font size.
Requires SubInspector if no bounding clip is set and `sepro.color`.

### AdvancedStyles
Allows for saving and applying of "Advanced Styles".
If a style should always have a glow or consists of multiple lines in any other way these can be saved into an Advanced Style.
When applying that Advanced Style to a different line, the same additional lines/tags are added.
Advanced Styles are always associated to a regular style.
Requires DependencyControl.