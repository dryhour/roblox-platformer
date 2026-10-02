local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

-- Shows one window at a time (Store, Inventory, Gifts, Settings, Profile, Trade). Opening one
-- closes the others. On a gamepad, the first button in the window gets selected so the D-pad
-- can move around it.
local Windows = {}

type Entry = { root: GuiObject, onOpen: (() -> ())? }

local entries: { [string]: Entry } = {}
local current: string? = nil

function Windows.register(name: string, root: GuiObject, onOpen: (() -> ())?)
	entries[name] = { root = root, onOpen = onOpen }
end

local function firstButton(root: Instance): GuiObject?
	for _, child in root:GetDescendants() do
		if child:IsA("GuiButton") and child.Visible and child.Name ~= "Close" then
			return child
		end
	end
	return nil
end

function Windows.open(name: string)
	local entry = entries[name]
	if not entry then
		return
	end
	for other, otherEntry in entries do
		otherEntry.root.Visible = other == name
	end
	current = name
	if entry.onOpen then
		entry.onOpen()
	end
	if UserInputService.GamepadEnabled then
		GuiService.SelectedObject = firstButton(entry.root)
	end
end

-- Closes the open window, or only `name` if given.
function Windows.close(name: string?)
	if name and name ~= current then
		return
	end
	if current then
		entries[current].root.Visible = false
		current = nil
	end
	GuiService.SelectedObject = nil
end

function Windows.toggle(name: string)
	if current == name then
		Windows.close()
	else
		Windows.open(name)
	end
end

function Windows.current(): string?
	return current
end

return Windows
