-- SpektraDroplet: renders each TIFF or PNG it's given through SpektraMac's engine, in place,
-- with the preset in ~/Library/Application Support/SpektraDroplet/preset.json (the default
-- settings, Kodak Portra 400 printed on Portra Endura, if there's none).
--
-- Drop files on it, or choose it as the Open With app of a Capture One process recipe.
-- Open it on its own to choose the preset (one saved with SpektraMac's Preset > Save Preset…)
-- and an exposure in stops.

property supportFolder : "Library/Application Support/SpektraDroplet/"

on run
	set presetFile to choose file with prompt "Choose a SpektraMac preset for SpektraDroplet:" of type {"public.json"}
	set evAnswer to text returned of (display dialog "Exposure, in stops over the photo as shot:" default answer my currentEV())
	try
		set evAnswer to (evAnswer as real) as text
	on error
		display alert "“" & evAnswer & "” isn't a number of stops." as warning
		return
	end try
	set folderPath to my supportPath()
	do shell script "mkdir -p " & quoted form of folderPath & " && cp " & quoted form of POSIX path of presetFile & " " & quoted form of (folderPath & "preset.json") & " && printf %s " & quoted form of evAnswer & " > " & quoted form of (folderPath & "ev")
	display notification "Preset " & (name of (info for presetFile)) & ", " & evAnswer & " EV" with title "SpektraDroplet"
end run

on open droppedItems
	set cli to POSIX path of (path to resource "spektra-cli" in directory "spektra")
	set folderPath to my supportPath()
	set options to ""
	if my fileExists(folderPath & "preset.json") then set options to " --preset " & quoted form of (folderPath & "preset.json")
	set options to options & " --ev " & quoted form of my currentEV()
	set rendered to 0
	set failures to {}
	repeat with anItem in droppedItems
		set filePath to POSIX path of anItem
		set lowerPath to do shell script "printf %s " & quoted form of filePath & " | tr '[:upper:]' '[:lower:]'"
		if lowerPath ends with ".tif" or lowerPath ends with ".tiff" or lowerPath ends with ".png" then
			try
				do shell script quoted form of cli & " save " & quoted form of filePath & " " & quoted form of filePath & options
				set rendered to rendered + 1
			on error message
				set end of failures to (name of (info for anItem)) & ": " & message
			end try
		else
			set end of failures to (name of (info for anItem)) & ": not a TIFF or PNG"
		end if
	end repeat
	if failures is {} then
		display notification "Rendered " & rendered & " photo(s)" with title "SpektraDroplet"
	else
		set AppleScript's text item delimiters to return
		display alert "SpektraDroplet rendered " & rendered & " photo(s); " & (count of failures) & " failed" message (failures as text) as warning
	end if
end open

on supportPath()
	return (POSIX path of (path to home folder)) & supportFolder
end supportPath

on fileExists(posixPath)
	try
		do shell script "test -e " & quoted form of posixPath
		return true
	on error
		return false
	end try
end fileExists

on currentEV()
	set evFile to my supportPath() & "ev"
	if my fileExists(evFile) then return do shell script "cat " & quoted form of evFile
	return "0"
end currentEV
