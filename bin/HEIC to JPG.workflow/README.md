# HEIC to JPG.workflow

This Automator workflow can be used as a macOS Folder Action so files dropped into a watched folder are converted automatically.

For example, you can attach it to `~/Downloads` to watch for incoming `.heic` images and convert them to `.jpg` files as they appear.

After conversion, the workflow deletes the original `.heic` file.

Suggested setup:

1. In Finder, right-click the folder you want to watch, such as `Downloads`.
2. Choose `Services` -> `Folder Actions Setup...`.
3. Enable Folder Actions if needed.
4. Attach `HEIC to JPG.workflow` to that folder.

Once attached, macOS will run the workflow whenever new files are added to the folder.
