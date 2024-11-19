-- Original Program:
-- MineExplorer by Reimar
-- License can be viewed here:
-- https://github.com/ReimarPB/MineExplorer/blob/master/LICENSE
--                     GNU GENERAL PUBLIC LICENSE

-- MineExplorerPlus by Missooni
-- All original Minex files have been condensed into a single file.
-- Added file extensions for images, web files, system files, archives, and more.
-- Program now shows file sizes.
-- Stores settings api files in 'usr/minexp/' and deleted files in 'temp/minexp/' Configurable. 
-- 		(Original settings API code had a typo in it.)
-- Colors used in the file explorer are customizable now.
--      (All minexp.colors.* settings use decimal values. 1 = white, 32768 = black)
-- A lot of new hotkeys have been added, some have been edited.
-- Spacebar is now the dedicated key for deselecting files and exiting the context window. 
--       (Pressing any button that isn't a hotkey will do this as well.)
-- There is now an X on the top right you can use to exit the program in conjunction to the original hotkey,'q'.
-- File list will now re-sort automatically after renaming files. 
-- Pasting a folder that already exists in a directory will combine the contents of both into a new 'foldername-merged'
-- The folder you are copying from will overwrite any matching files when merging.
-- If you try to paste a single file that already exists in a directory it will paste a duplicate with a number added to the end.

-- Mouse-only context menu will appear when right-clicking. Program contains the following operations and hotkeys.
-- Copy file/folder (1 or c)
-- Paste file/folder (2 or v)
-- Rename file/folder (f1 or f2)
-- Delete file/folder (x or Delete)
-- Edit file (leftCtrl)
-- Undo Delete (z or Backspace)
-- Run program in shell (Enter)
-- Run program in a new tab (Tab Key)
-- Create new file (Insert)
-- Deselect file or exit context menu (Spacebar)

-- Creates a directory for temporarily storing deleted files and user configurations.
-- You can change these variables to use different directories / use an existing directory if necessary.

-- MineExplorerPlus can delete and remake the directory that stores deleted files. It is off by default.
-- If you have limited space on your computer, enable this setting or routinely delete your recycling folder.
-- Do not keep anything important in the recycling folder!
-- Use 'Undo' if you accidentally delete an important file.

recycleDir = "/temp/minexp/"
cfgDir = "usr/minexp/"

--
	settings.clear()
if not fs.exists(cfgDir.."explorer.cfg") then
	settings.set("minexp.disable_hotkeys", false)
	settings.set("minexp.recycle_directory", recycleDir)
	settings.set("minexp.recycle_on_leave", false)
	settings.save("usr/minexp/explorer.cfg")
	settings.clear()
end
if not fs.exists(cfgDir.."colors.cfg") then
	settings.set("minexp.colors.bg", colors.black)
	settings.set("minexp.colors.fg", colors.white)
	settings.set("minexp.colors.select", colors.blue)
	settings.set("minexp.colors.active", colors.gray)
	settings.save("usr/minexp/colors.cfg")
	settings.clear()
end
if not fs.exists(cfgDir.."programs.cfg") then
	settings.set("minexp.default_program", "edit")
	settings.set("minexp.programs.nft", "paint")
	settings.set("minexp.programs.nfp", "paint")
	settings.save("usr/minexp/programs.cfg")
	settings.clear()
end
settings.load(cfgDir.."explorer.cfg")
settings.load(cfgDir.."colors.cfg")
settings.load(cfgDir.."programs.cfg")
if not fs.exists(recycleDir) then fs.makeDir(recycleDir) end
if not fs.exists(cfgDir) then fs.makeDir(cfgDir) end

-- Create Context Window
local ogTerm = term.current()
local contextWindow = window.create(term.current(), 1, 1, 16, 8)
contextWindow.setVisible(false)
function drawContextWindow()
contextWindow.setTextColor(colors.white)
contextWindow.setBackgroundColor(colors.gray)
contextWindow.clear()
term.redirect(contextWindow)
term.setCursorPos(1,1)
print(" Context Menu>")
term.blit("  Copy  ", "77777777", "88888888") term.blit("  Paste  ", "777777777", "000000000") write("\n")
term.blit(" Rename ", "77777777", "00000000") term.blit(" Delete  ", "000000000", "eeeeeeeee") write("\n")
term.blit("  Edit  ", "77777777", "88888888") term.blit("  Undo   ", "eeeeeeeee", "000000000") write("\n")
write(" Run Program> \n")
term.blit("  Shell ", "77777777", "88888888") term.blit(" NewTab  ", "777777777", "000000000") write("\n")
write(" Create New> \n")
term.blit("  File  ", "77777777", "00000000") term.blit(" Folder  ", "777777777", "888888888")
term.redirect(ogTerm)
end

local listeners = {}
local currentFocus = nil;

Focus = {
	FILES = 0,
	INPUT = 1,
}

function addListener(event, focus, callback)
	if not listeners[event] then listeners[event] = {} end
	table.insert(listeners[event], {
		focus = focus,
		callback = callback,
	})
end

function listen()
	while true do
		local event, p1, p2, p3 = os.pullEvent()

		if listeners[event] then
			for _, listener in ipairs(listeners[event]) do
				if listener.focus == currentFocus then
					if listener.callback(p1, p2, p3) then return end -- Exit when callback returns true
					if currentFocus ~= listener.focus then break end -- Break out if focus changed
				end
			end
		end
	end
end

function setFocus(focus)
	currentFocus = focus
end

local scrollY = 0
local CONTENT_OFFSET_Y = 1

local bgColor = settings.get("minexp.colors.bg")
local txtColor = settings.get("minexp.colors.fg")
local selectColor = settings.get("minexp.colors.select")
local activeColor = settings.get("minexp.colors.active")

function showPath()
	local path = getCurrentPath()

	term.setCursorPos(1, 1)
	term.setBackgroundColor(colors.gray)
	term.setTextColor(colors.white)
	term.write(path)

	-- Fill remaining space
	local width, _ = term.getSize()
	term.write(string.rep(" ", width - #path + 1 - 3))
	term.blit(" X ", "000", "eee")
end

function showFiles()
	for i, file in ipairs(files) do
		showFile(i)
	end

	-- Fill remaining space
	local width, height = term.getSize()
	if #files < height then
		term.setBackgroundColor(bgColor)
		for i = #files + 1 + CONTENT_OFFSET_Y, height do
			term.setCursorPos(1, i)
			term.write(string.rep(" ", width))
		end
	end
end

function showFile(index)
	local width, height = term.getSize()
	local y = index - scrollY + CONTENT_OFFSET_Y

	if y < 1 + CONTENT_OFFSET_Y or y > height then return end

	local file = files[index]

	term.setBackgroundColor(bgColor)
	term.setTextColor(txtColor)
	term.setCursorPos(1, y)

	term.write(string.rep(" ", file.depth - 1))

	-- Arrow + Icon
	local color1, color2
	if file.type ~= FileType.FILE then
		if file.expanded then
			term.write("-")
		else
			term.write("+")
		end

		if file.readonly then
			color1 = colors.orange
			color2 = colors.orange
		elseif file.type == FileType.DIRECTORY then
			color1 = colors.yellow
			color2 = colors.yellow
		else
			color1 = colors.gray
			color2 = colors.gray
		end
	else
		term.write(" ")
		color1 = colors.lightGray
		color2 = colors.lightGray
	end

	if file.name:match("%.lua$") or file.name:match("%.sh$") then color2 = colors.blue
    elseif file.name:match("%.tmp$") or file.name:match("%.temp$")  or file.name:match("%.txt$") then color2 = colors.white
    elseif file.name:match("%.ls$") or file.name:match("%.db$") or file.name:match("%.cfg") then color2 = colors.lime
	elseif file.name:match("%.man$") or file.name:match("%.d$") then color2 = colors.yellow
	elseif file.name:match("%.v$") or file.name:match("%.al$") then color2 = colors.gray
    elseif file.name:match("%.dep$") then color2 = colors.purple
	elseif file.name:match("%.pal$") then color2 = colors.red
    elseif file.name:match("%.nft$") or file.name:match("%.nfp$") then
        color1 = colors.red
        color2 = colors.red
    elseif file.name:match("%.sys$") then
        color1 = colors.lightBlue
        color2 = colors.lightBlue
    elseif file.name:match("%.html$") then
        color1 = colors.white
        color2 = colors.white
	elseif file.name:match("%.css$") then
		color1 = colors.white
		color2 = colors.lightBlue
	elseif file.name:match("%.js$") then
		color1 = colors.white
		color2 = colors.yellow
    elseif file.name:match("%.tar$") or file.name:match("%.a$") or file.name:match("%.pdr$") then
        color1 = colors.yellow
        color2 = colors.orange
    end

	term.setTextColor(color1)
	term.write("\138")
	term.setTextColor(color2)
	term.write("\133")

	-- Name
	if file.selected then
		term.setBackgroundColor(selectColor)
	else
		term.setBackgroundColor(bgColor)
	end

	if not file.selected and file.name:find("^%.") then
		term.setTextColor(colors.lightGray)
	else
		term.setTextColor(txtColor)
	end
	term.write(file.name)

	-- File Size
	term.setBackgroundColor(bgColor)
	term.setTextColor(colors.lightGray)
	local suffix = "B"
	local fileSize = fs.getSize(file.path)
	if fileSize > 1024 then
	fileSize = fileSize / 1024
	fileSize = math.floor(fileSize + .5)
	suffix = "kB"
	end
	if file.type == FileType.FILE then 
	term.write(" "..fileSize) 
	term.setTextColor(colors.gray)
	term.write(suffix) 
	end

	-- Fill remaining space
	local x, _ = term.getCursorPos()
	term.setBackgroundColor(bgColor)
	term.write(string.rep(" ", width - x + 1))
end

function showEverything()
	showPath()
	showFiles()
end

function showContextWindow(x,y)
	local width, height = term.getSize()
	if y > height - 8 then y = height - 7 end
	if x > width - 16 then x = width - 15 end
	contextWindow.reposition(x, y)
	contextWindow.setVisible(true)
	waitForContext(x,y)
end

undoBuffer = {}
clipboard = {}
deleteIndex = nil

function waitForContext(ogx,ogy)
	local selection = getSelectedIndex()
	local file = files[selection]
	repeat
    event, button, x, y = os.pullEvent()
    until event == "mouse_click" or button == keys.space or button == keys.insert
	if button == keys.space then
		hideContextWindow()
		return
	elseif button == keys.insert then
		fileFromContext("file", file, ogx, ogy)
	elseif button == 2 then
		showEverything()
		showContextWindow(x,y)
	elseif (x < ogx or x > ogx+15) or (y < ogy or y > ogy+7) then
		hideContextWindow()
		return
	elseif (y == ogy+1 and x >= ogx and x <= ogx+7) then
		if file then 
		copyFile(file)
		hideContextWindow()
		else
		contextWhenClicked(1,2,"8","e"," NoFile ")
		waitForContext(ogx,ogy)
		end
	elseif (y == ogy+1 and x >= ogx+8 and x <= ogx+15) then
		local pasteFile = pasteFile(file)
		if pasteFile then
			hideContextWindow()
			redrawFromContext()
		else
			contextWhenClicked(9,2,"0","e"," NoClip ")
			waitForContext(ogx,ogy)
		end
	elseif (y == ogy+2 and x >= ogx and x <= ogx+7) then
	if file then 
		hideContextWindow()
		renameFile(selection)
	else
		contextWhenClicked(1,3,"0","e"," NoFile ")
		waitForContext(ogx,ogy)
	end
	elseif (y == ogy+2 and x >= ogx+8 and x <= ogx+15) then
		if file and not file.readonly then
		deleteFile(file)
		redrawFromContext("delete")
		hideContextWindow()
		else
		contextWhenClicked(9,3,"e","0"," NoFile ")
		waitForContext(ogx,ogy)
		end
	elseif (y == ogy+3 and x >= ogx and x <= ogx+7) then
	if file then doPrimaryAction(file) else
		contextWhenClicked(1,4,"8","e"," NoFile ")
		waitForContext(ogx,ogy)
	end
	elseif (y == ogy+3 and x >= ogx+8 and x <= ogx+15) then
		if #undoBuffer ~= 0 then
			undoDelete()
			hideContextWindow()
			redrawFromContext()
		else
			contextWhenClicked(9,4,"0","e","  N/A   ")
			waitForContext(ogx,ogy)
		end
	elseif (y == ogy+5 and x >= ogx and x <= ogx+7) then
	if file and file.type == FileType.FILE then doSecondaryAction(file) else
		contextWhenClicked(1,6,"8","e"," NoFile ")
		waitForContext(ogx,ogy)
	end
	elseif (y == ogy+5 and x >= ogx+8 and x <= ogx+15) then
		if file and file.type == FileType.FILE then doSecondaryAction(file, true) else
			contextWhenClicked(9,6,"0","e"," NoFile ")
			waitForContext(ogx,ogy)
		end
	elseif (y == ogy+7 and x >= ogx and x <= ogx+7) then
		fileFromContext("file", file, ogx, ogy)
	elseif (y == ogy+7 and x >= ogx+8 and x <= ogx+15) then
		fileFromContext("folder", file, ogx, ogy)
	else
		waitForContext(ogx,ogy)
	end
end

function hideContextWindow()
	contextWindow.setVisible(false)
	drawContextWindow()
	showEverything()
end

function fileFromContext(param, file, ogx, ogy)
	local madeFile = makeNewFile(param, file)
	local x = 1
	local col = "0"
	if param == "folder" then
		x = 9
		col = "8"
	end
	if madeFile == true then
	hideContextWindow()
	redrawFromContext()
	else
	drawContextWindow()
	contextWhenClicked(x,8,col,"e"," Voided ")
	waitForContext(ogx,ogy)
	end
end

function redrawFromContext(operation)
	if getSelectedIndex() and files[getSelectedIndex()].depth > 1 then
	local targetDepth = files[getSelectedIndex()].depth - 1
	if files[getSelectedIndex()].type == FileType.FOLDER then targetDepth = targetDepth - 2 end
	repeat
	index = getSelectedIndex()
	if deleteIndex ~= nil then 
	index = deleteIndex
	deleteIndex = nil
	end
	if not (files[index].depth == targetDepth and files[index].type ~= FileType.FILE) then
	setSelection(index-1) end
	until files[index].depth == targetDepth and files[index].type ~= FileType.FILE
		updateSelection(index, index+1)
		collapse()
		expand()
		showFiles()
	elseif operation ~= "delete" and getSelectedIndex() and (files[getSelectedIndex()].type == FileType.DIRECTORY or files[getSelectedIndex()].type == FileType.DISK) then
		collapse()
		expand()
		showFiles()
	else
		local index = getSelectedIndex()
	if not index then index = 1 end
		files = {}
		loadAllFiles()
		setSelection(index)
	if getSelectedIndex() then files[index].selected = false end
	fixScreen()
	end
end

function contextWhenClicked(x,y,bg,fg,string)
	term.redirect(contextWindow)
	term.setCursorPos(x,y)
	term.blit(string, string.rep(fg,#string), string.rep(bg,#string))
	os.sleep(0.4)
	drawContextWindow()
end

function fixScreen()
	local width, height = term.getSize()
	repeat
	local newScrollY = scrollY - 1
	scrollY = newScrollY
	local index = getSelectedIndex()
	if not index then index = #files end
	until newScrollY < 1 or scrollTo(index)
	if scrollY < 0 then scrollY = 0 end
	showFiles()
end

-- Returns whether it actually scrolled
function scrollTo(index)
	local _, height = term.getSize()
	height = height - CONTENT_OFFSET_Y

	if index <= scrollY + 1 then
		scrollY = index - 1
		return true
	end

	if index > scrollY + height - 1 then
		scrollY = index - height
		return true
	end

	return false
end

-- Scrolls to new selection if necessary and draws changes
function updateSelection(oldIndex, newIndex)
	if scrollTo(newIndex) then
		showFiles()
	else
		if oldIndex and files[oldIndex] then showFile(oldIndex) end
		showFile(newIndex)
	end
	showPath()
end

function getFileIndexFromY(y)
	return y + scrollY - CONTENT_OFFSET_Y
end

function getYFromFileIndex(index)
	return index - scrollY + CONTENT_OFFSET_Y
end

function drawInput(input, cursorPos)
	local width, _ = term.getSize()

	term.setCursorPos(input.x, input.y)
	term.setTextColor(input.color)

	term.setBackgroundColor(input.highlightColor)
	term.write(input.text)

	term.setBackgroundColor(input.backgroundColor)
	term.write(string.rep(" ", width - input.x - #input.text))

	term.setCursorBlink(true)
	term.setCursorPos(input.x + cursorPos - 1, input.y)
end

addListener("term_resize", Focus.FILES, function()
	showEverything()
end)

addListener("mouse_scroll", Focus.FILES, function(direction)
	local width, height = term.getSize()
	local newScrollY = scrollY + direction

	if newScrollY < 0 or newScrollY > #files - height + 1 then return end

	scrollY = newScrollY

	showFiles()
end)

function deleteFile(file)
	deleteIndex = getSelectedIndex() - 1
	if file and not file.readonly and file.type ~= FileType.DISK then
		table.insert(undoBuffer, {
			ogPath = file.path,
			recyclePath = recycleDir..file.name,
		})
		if fs.exists(recycleDir..file.name) then fs.delete(recycleDir..file.name) end
		fs.move(file.path, recycleDir..file.name) 
	
	end
end

function undoDelete()
	local index = #undoBuffer
	if index ~= 0 then
		local recycledFile = undoBuffer[index]
		fs.move(recycledFile.recyclePath, recycledFile.ogPath)
		table.remove(undoBuffer, index)
	end
end

function pasteFile(file)
	local clippedFile = clipboard[1]
	local pastePath = "/"
	if file and file.type ~= FileType.FILE then pastePath = file.path.."/" end
	if clippedFile ~= nil and fs.exists(pastePath..clippedFile.name) and fs.exists(clippedFile.path) and fs.isDir(clippedFile.path) and fs.getDrive(clippedFile.path) ~= "hdd" then
		mergeFolders(pastePath, clippedFile) 
	elseif clippedFile ~= nil and fs.exists(pastePath..clippedFile.name) and fs.exists(clippedFile.path) then 
		local clippedName = clippedFile.name
		local clippedNum = tonumber(string.match(clippedName, "-(%d*)"))
		local clippedExt = string.match(clippedName, "%.(.*)")
		if clippedExt == nil then clippedExt = "" else clippedExt = "."..clippedExt end
		local justName = string.match(clippedName,"(.*)"..clippedExt)
		if string.find(justName, "%-") then
			justName = string.match(justName,"(.+)-")
		elseif string.find(justName, "%.") then
			justName = string.sub(justName, "%.", "")
		end
		if clippedNum == nil then clippedNum = 1 end
		repeat
			clippedNum = clippedNum + 1
		until not fs.exists(pastePath..justName.."-"..clippedNum..clippedExt)
		clippedNum = "-"..(clippedNum)
		clippedName = justName..clippedNum..clippedExt

		fs.copy(clippedFile.path, pastePath..clippedName)
		return true
	elseif clippedFile ~= nil and fs.exists(clippedFile.path) then
		fs.copy(clippedFile.path, recycleDir.."copy/"..clippedFile.name)
		fs.copy(recycleDir.."copy/"..clippedFile.name, pastePath..clippedFile.name)
		fs.delete(recycleDir.."copy/")
		return true
	else
		return false
	end
end

function copyFile(file)
	if file then
		clipboard = {}
		table.insert(clipboard, {
		name = file.name,
		path = file.path,
		})
	end
end

function makeNewFile(param, file)
	term.redirect(contextWindow)
	term.setCursorPos(1,8)
	term.setBackgroundColor(colors.lightGray)
	local nameString = "Name "..param
	local fg = "0"
	local bg = "8"
	term.blit(nameString,string.rep(fg,#nameString),string.rep(bg,#nameString))
	term.write("            ")
	term.setCursorPos(#nameString+1,8)
	term.setCursorBlink(true)
    event, key = os.pullEvent("key")
	if key ~= keys.enter then
		term.setTextColor(colors.gray)
		term.setCursorPos(1,8)
		term.blit(string.rep(" ",#nameString),string.rep(fg,#nameString),string.rep(bg,#nameString))
		term.setCursorPos(1,8)
		local input = read()
		local targetDir = "/"
		if file and not file.readonly and file.type ~= FileType.FILE then targetDir = (file.path.."/") end
		if input ~= nil and input ~= "" and param == "folder" and not fs.exists(targetDir..input) then 
		fs.makeDir(targetDir..input)
		return true
		elseif input ~= nil and input ~= "" and param == "file" and not fs.exists(targetDir..input) then 
			local writeFile = fs.open(targetDir..input, "w")
			writeFile.close() 
			return true
		else return false
		end
	end
	term.setCursorBlink(false)
	term.redirect(ogTerm)
end

function mergeFolders(pastePath, clippedFile)
	local mergedFilePath = pastePath..clippedFile.name.."-merged"
	if fs.exists(mergedFilePath) then fs.delete(mergedFilePath) end
	fs.copy(clippedFile.path.."/*", mergedFilePath)
	if pastePath..clippedFile.name ~= "/"..clippedFile.path then
	-- Recursive file sorting inspired by shorun's ls.sh
	local pathname = pastePath..clippedFile.name
	local tempfile = fs.list(pathname)
	local count = 1
	local filename = tempfile[count]
	local filelist = {}
	local todo = {}
	repeat
		if filename and fs.isDir(pathname.."/"..filename) then 
			table.insert(todo, pathname.."/"..filename)
			count = count + 1
			filename = tempfile[count]
		elseif filename and fs.exists(pathname.."/"..filename) then 
			table.insert(filelist, filename)
			count = count + 1
			filename = tempfile[count]
		elseif todo[1] then
			pathname = todo[1]
			tempfile = fs.list(pathname)
			count = 1
			filename = tempfile[count]
			table.remove(todo, 1)
		else filename = nil end
	until filename == nil and not todo[1]
	for key, value in pairs(filelist) do
		if not fs.exists(mergedFilePath.."/"..value) then
			fs.copy(pastePath..clippedFile.name.."/"..value, mergedFilePath.."/"..value)
		end
	end
	end
end

local function clearScreen()
	term.setBackgroundColor(colors.black)
	term.setTextColor(colors.white)
	term.setCursorPos(1, 1)
	term.clear()
end

local function getProgramForExtension(extension)
	if not settings then return "edit" end
	return settings.get("minexp.programs." .. extension, settings.get("minexp.default_program", "edit"))
end

-- Edit files, expand/collapse folders
function doPrimaryAction(file)
	if file.type == FileType.FILE then
		local ext = getFileExtension(file.name)
		shell.run(getProgramForExtension(ext), "/" .. file.path)
		showEverything()
	else
		if file.expanded then collapse()
		else expand() end
		showFiles()
	end
end

-- Execute files, switch to folders and quit
-- Returns whether to exit
function doSecondaryAction(file, isTab)
	if file and file.type == FileType.FILE then
		if not isTab then
			clearScreen()
			shell.run(file.path)
			term.write("Press any key to continue")
			os.pullEvent("key")
			showEverything()
			return false
		else
			shell.switchTab(shell.openTab(file.path))
			return false
		end
	end
end

addListener("key", Focus.FILES, function(key)
	local selection = getSelectedIndex()
	local file = files[selection]
	if settings.get("minexp.disable_hotkeys") == true then return
	elseif key == keys.down or key == keys.j then
		if not selection then selection = 0 end

		if (selection <= #files - 1) then
			setSelection(selection + 1)
			updateSelection(selection, selection + 1)
		end

	elseif key == keys.up or key == keys.k then
		if not selection then selection = #files + 1 end

		if (selection > 1) then
			setSelection(selection - 1)
			updateSelection(selection, selection - 1)
		end

	elseif key == keys.home then
		setSelection(1)
		updateSelection(selection, 1)

	elseif key == keys["end"] then
		setSelection(#files)
		updateSelection(selection, #files)

	elseif key == keys.right or key == keys.l then
		expand()
		showFiles()

	elseif key == keys.left or key == keys.h then
		collapse()
		showFiles()

	-- Edit on leftCtrl
	elseif key == keys.leftCtrl then
		if not selection then return end

		doPrimaryAction(file)

	-- Run in shell on 'Enter'
	elseif key == keys.enter then
		if not selection then return end

		local file = files[selection]
		return doSecondaryAction(file)

	-- Rename on F1 or F2
	elseif key == keys.f1 or key == keys.f2 then
		if not selection then return end
		renameFile(selection)
		
	-- Deselect with 'Space'
	elseif key == keys.space then
		deselect()
		showEverything()
		
	-- Copy file/folder with 1 or 'c'
	elseif key == keys.one or key == keys.c then
		copyFile(file)
	
	-- Paste file/folder with 2 or 'v'
	elseif key == keys.two or key == keys.v then
		pasteFile(file)
		redrawFromContext()

	-- Delete file/folder with 'x' or 'Delete'
	elseif key == keys.x or key == keys.delete then
		if not selection then return end
		deleteFile(file)
		redrawFromContext("delete")
	
	-- Undo delete with 'z' or 'Backspace'
	elseif key == keys.z or key == keys.backspace then
		undoDelete()
		redrawFromContext()
		
	-- Run program in new tab with 'Tab'
	elseif key == keys.tab then
		if not selection then return end

		local file = files[selection]
		return doSecondaryAction(file, true)

	-- Create new file with 'Insert'
	elseif key == keys.insert then
		contextWindow.reposition(1,1)
		contextWindow.setVisible(true)
		fileFromContext("file", file, 1, 1)
	
	end
end)

function renameFile(selection)
		if not selection then return end
		local file = files[selection]
		create({
			text = file.name,
			x = file.depth + 3,
			y = getYFromFileIndex(selection),
			color = txtColor,
			backgroundColor = bgColor,
			highlightColor = activeColor,
			cancelKey = keys.f1,
			callback = function(newName)
				if #newName == 0 then return true end

				local newPath = fs.combine(fs.getDir(file.path), newName)

				if fs.exists(newPath) or fs.isReadOnly(file.path) then
					return false
				end

				fs.move(file.path, newPath)
				file.name = newName
				file.path = newPath

				showPath()
				if file.depth > 0 then redrawFromContext() else showFiles() end

				return true
			end
		})
end

function handleRecycling()
	if settings.get("minexp.recycle_on_leave") == true then fs.delete(recycleDir) end
end

function shutdownExplorer()
	clearScreen()
	handleRecycling()
	settings.clear()
	error("Exited MineExplorer+", 0)
end

-- Quit when pressing Q
-- This is in key up to prevent typing 'q' in the terminal
addListener("key_up", Focus.FILES, function(key)
	if key == keys.q then
		shutdownExplorer()
		return true
	end
end)

addListener("mouse_click", Focus.FILES, function(btn, x, y)
	local width, _ = term.getSize()
	if btn == 2 then showContextWindow(x,y) return end
	if btn ~= 1 then return end
	if (x <= width and x >= width-1 and y == 1) then 
	shutdownExplorer()
	return
	end

	local oldSelection = getSelectedIndex()
	local fileIndex = getFileIndexFromY(y)
	local file = files[fileIndex]

	-- Deselect when pressing outside
	if not file then
		deselect()
		showFiles()
		showPath()
		return
	end

	-- Select if not selected already
	if not file.selected then
		setSelection(fileIndex)
		updateSelection(oldSelection, fileIndex)
		return
	end

	doPrimaryAction(file)
end)



-- Input
-- * text
-- * x
-- * y
-- * color
-- * backgroundColor
-- * highlightColor
-- * cancelKey
-- * callback
local currentInput = nil
local cursorPos = nil

function create(input)
	currentInput = input
	cursorPos = #currentInput.text + 1
	setFocus(Focus.INPUT)
	drawInput(currentInput, cursorPos)
end

local function endInput()
	currentInput = nil
	setFocus(Focus.FILES)
	showFiles()
end

addListener("char", Focus.INPUT, function(char)
	currentInput.text = string.sub(currentInput.text, 1, cursorPos - 1) .. char .. string.sub(currentInput.text, cursorPos)
	cursorPos = cursorPos + 1
	drawInput(currentInput, cursorPos)
end)

addListener("key", Focus.INPUT, function(key)

	if key == keys.right then
		cursorPos = math.min(cursorPos + 1, #currentInput.text + 1)
		drawInput(currentInput, cursorPos)

	elseif key == keys.left then
		cursorPos = math.max(cursorPos - 1, 1)
		drawInput(currentInput, cursorPos)

	elseif key == keys.home then
		cursorPos = 1
		drawInput(currentInput, cursorPos)

	elseif key == keys["end"] then
		cursorPos = #currentInput.text + 1
		drawInput(currentInput, cursorPos)

	elseif key == keys.backspace then
		if cursorPos == 1 then return end
		currentInput.text = string.sub(currentInput.text, 1, cursorPos - 2) .. string.sub(currentInput.text, cursorPos)
		cursorPos = cursorPos - 1
		drawInput(currentInput, cursorPos)

	elseif key == keys.delete then
		if cursorPos == #currentInput.text + 1 then return end
		currentInput.text = string.sub(currentInput.text, 1, cursorPos - 1) .. string.sub(currentInput.text, cursorPos + 1)
		drawInput(currentInput, cursorPos)

	elseif key == keys.enter then
		currentInput.callback(currentInput.text)
		endInput()

	elseif key == currentInput.cancelKey then
		endInput()
	end
end)



FileType = {
	FILE = 0,
	DIRECTORY = 1,
	DISK = 2
}

-- File:
-- * name: string
-- * path: string
-- * type: FileType
-- * readonly: bool
-- * depth: int
-- * selected: bool
-- * expanded: bool
files = {}

function loadFiles(path, depth, index)
	-- Get new files
	local newFiles = {}
	for _, file in ipairs(fs.list(path)) do
		local filePath = fs.combine(path, file)
		local type

		if filePath == file and fs.getDrive(filePath) ~= "hdd" then type = FileType.DISK
		elseif fs.isDir(filePath) then type = FileType.DIRECTORY
		else type = FileType.FILE end
		
		table.insert(newFiles, {
			name = file,
			path = filePath,
			type = type,
			readonly = fs.isReadOnly(filePath),
			depth = depth + 1,
			selected = false,
			expanded = false,
		})
	end

	-- Sort by file type
	table.sort(newFiles, function(a, b)
		if a.type ~= b.type then
			return a.type > b.type
		end
		return a.name < b.name
	end)

	-- Add to files array
	for i, file in ipairs(newFiles) do
		table.insert(files, index + i, file)
	end
end

function loadAllFiles()
	loadFiles("/", 0, 0)
end

function getSelectedIndex()
	for i, file in ipairs(files) do
		if file.selected then return i end
	end
	return nil
end

function setSelection(index)
	for i, file in ipairs(files) do
		file.selected = i == index
	end	
end

function deselect()
	for _, file in ipairs(files) do
		file.selected = false
	end	
end

function expand()
	local index = getSelectedIndex()
	local file = files[index]

	if not file or file.type == FileType.FILE or file.expanded then return end

	loadFiles(file.path, file.depth, index)

	file.expanded = true
end

function collapse()
	local index = getSelectedIndex()
	local file = files[index]

	if not file or file.type == FileType.FILE or not file.expanded then return end

	local i = index + 1
	while i <= #files and files[i].depth > file.depth do
		table.remove(files, i)
	end

	file.expanded = false
	fixScreen()
end

function getFileExtension(name)
	if not string.find(name, "%.") then return "" end
	return string.gsub(name, "%w*%.", "")
end

function getCurrentPath()
	local index = getSelectedIndex()
	if not index then return "/" end
	return "/" .. files[index].path
end

_G["dir"] = fs.getDir(shell.getRunningProgram())
_G["shell"] = shell

term.clear()

loadAllFiles()
files[1].selected = true

showEverything()
drawContextWindow()

setFocus(Focus.FILES)
listen()
