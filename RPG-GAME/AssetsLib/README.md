# Asset documentation

## Assets in Assets.cs

This is a class for simplifying the process of finding asset files.

attributes:
- `string Path` : holds the base path of the asset folder

methods: 
- `string[] ReadFileLines(string relative_path)` : a function that gets the
lines of a file relative to the `Path`
- `void WriteFileLines(string relative_path, string[] lines)` : a function 
that writes the lines of a file relative to the `Path`