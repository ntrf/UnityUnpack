
# Unity Unpacker

Unpacks `.unitypackage` files as normal archives. No Unity instalation required.

## How to use it / Quick Start

It's a command line utility.

`./UnityUnpack` [`--nometa`] _source_file_ [_destination_folder_name_]

When destination is not specified, files will be extracted into a subdirectory of current working directory, with the same name as package itself, but without extension. Note, that subdirectory is created in current working directory regardless of the location of source file.

For example, when you want to unpack `~/Download/HelloWorld.unitypackage` into default directory:

`./UnityUnpack ~/Download/HelloWorld.unitypackage`

This will create subdirectory `HelloWorld` in current working directory and unpack all of the files there. `HelloWorld` directory will act as a project root and should contain `Assets` directory inside.

## Why

Because normally Unity only allows you to extract packages into existing project, without giving you any control over what is being extracted and where. There are reasons why you might want to extract Unity packages outside of your Unity project:

- Importing new assets is not fast in large projects.
- Third-party packages might contain *InitializeOnLoad* components.
- Users may want to inspect the code for incompatible API before getting compilation errors in the project.
- Only a small part of large package is needed.
- Package creates too many directories when unpacked.
- License, dependencies, images and documentation might need to be accessed by a person without Unity installed.

## Meta files

In some rare cases you might want to avoid unpacking `.meta` files. Those files contain import settings for assets, and without unpacking them, you risk getting incorrect results. If you're confident you don't need them, use `--nometa` parameter to ignore meta files.

## Warning

Unlike Unity editor, this tool provides no verification of input data. There are some minor error checks, but:

* it won't update existing files,
* it won't check for uid duplicates,
* it won't verify file integrity.

Use at your own risk. Make backups before you do.
