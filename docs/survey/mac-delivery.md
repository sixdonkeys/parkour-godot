# Survey: mac-delivery

## Exporting for macOS — https://raw.githubusercontent.com/godotengine/godot-docs/master/tutorials/export/exporting_for_macos.rst

> Projects exported without code signing and notarization will be blocked by Gatekeeper if they are downloaded from unknown sources, see the :ref:`Running Godot apps on macOS <doc_running_on_macos>` page for more information.

> To notarize an app, you **must** have a valid `Apple Developer ID Certificate <https://developer.apple.com/>`__.

> If you do not have an Apple Developer ID Certificate
> ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
>
> - Select ``Built-in (ad-hoc only)`` in the ``Code Signing > Codesign`` option.
> - Select ``Disabled`` in the ``Notarization > Notarization`` option.
>
> In this case Godot will use an ad-hoc signature, which will make running an exported app easier for the end users,

> Due to file system limitations, ``.app`` bundles exported from Windows lack the
> ``executable`` flag and won't run on macOS. Projects exported as ``.zip`` are not
> affected by this issue.

## Running Godot apps on macOS — https://raw.githubusercontent.com/godotengine/godot-docs/master/tutorials/export/running_on_macos.rst

> App is signed (including ad-hoc signatures) but not notarized

> * Or, right-click (Control-click) on the app icon in the Finder window and select ``Open`` from the menu.

> * Run the command ``xattr -dr com.apple.quarantine "Unsigned Game.app"`` (including quotation marks and ``.app`` extension).
