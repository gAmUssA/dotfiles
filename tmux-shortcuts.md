# Tmux Shortcuts Reference

This document contains the key shortcuts for your tmux configuration.

## 🎛️ **Prefix Key**
Your tmux prefix is: **`Ctrl-Space`**

Press the prefix key before any of the shortcuts listed below.

## 🏷️ **Renaming Shortcuts**

### **Rename Pane**
- **`<prefix> + t`** - Opens prompt to rename the current pane
- Example: `Ctrl-Space` then `t`, then type new name

### **Rename Window**
- **`<prefix> + ,`** - Rename current window (tmux default)
- Example: `Ctrl-Space` then `,`, then type new name

### **Toggle Pane Title Display**
- **`<prefix> + T`** (capital T) - Shows/hides pane titles
- This toggles the pane border status on/off so you can see the pane names

## 📝 **How to Use**
1. **Rename a pane**: Press `Ctrl-Space` then `t`, type the new name, press Enter
2. **Rename a window**: Press `Ctrl-Space` then `,`, type the new name, press Enter  
3. **Show pane names**: Press `Ctrl-Space` then `T` to toggle pane title display

## 🪟 **Window & Pane Management**

### **Creating Windows/Panes**
- **`<prefix> + N`** - New session
- **`<prefix> + |`** - Split window horizontally
- **`<prefix> + _`** - Split window vertically

### **Pane Navigation**
- **`Alt + Arrow Keys`** - Navigate between panes (no prefix needed)
- **`<prefix> + Ctrl-A`** - Cycle through panes

### **Pane Resizing**
- **`<prefix> + Ctrl-h`** - Resize pane left
- **`<prefix> + Ctrl-j`** - Resize pane down
- **`<prefix> + Ctrl-l`** - Resize pane right
- **`<prefix> + Ctrl-u`** - Resize pane up
- **`<prefix> + *`** - Resize pane to 80 columns wide

### **Pane Management**
- **`<prefix> + x`** - Zoom/maximize current pane
- **`<prefix> + )`** - Swap pane down
- **`<prefix> + (`** - Swap pane up
- **`<prefix> + =`** - Synchronize panes (type in all panes at once)

### **Layout Management**
- **`<prefix> + @`** - Even horizontal layout
- **`<prefix> + !`** - Even vertical layout
- **`<prefix> + l`** - Next layout
- **`<prefix> + L`** - Previous layout

## 🧹 **Utility**
- **`<prefix> + r`** - Reload tmux configuration
- **`Ctrl-Alt-k`** - Clear pane history (no prefix needed)

## 🎨 **Theme & Plugins**
Your configuration uses:
- **Dracula theme** with powerline
- **CPU/RAM usage** and **time** display
- **tmux-resurrect** and **tmux-continuum** for session persistence

---

💡 **Remember**: Your prefix key is `Ctrl-Space`, not the default `Ctrl-b`!