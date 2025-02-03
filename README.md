# luau_term

Terminal emulator for (Roblox) luau, mainly based on xterm.

https://github.com/user-attachments/assets/5f3b16a7-2c67-4aee-8dba-ea699ec69885

## Overview

This is a terminal emulator, it cannot run programs by itself, neither does it have
any user input processing capabilities. It only renders an image based on the buffer
that is given to it.

The `src` folder contains the code for the terminal emulator itself. It does not
have any Roblox-specific API (with the exception of `src/canvas/textlabel.luau`),
and can be ran in any Luau environment (including Lune, which is used in `tests`).

The `example` folder contains the code to run luau_term in Roblox. It has input
handling, which it uses to communicate with `example_proxy` through HttpService,
and sends the received data to the terminal emulator.

The `example_proxy` is a simple nodejs server running express and using `node-pty`
to create pseudoterminals and handle input/output through http requests.

**Note:** The `example_proxy` does not have any built-in security. The example creates
a shell on your actual computer using your user account, and any commands that you run
in the example will be executed on your machine.

## Usage

### Bitmap mode (`src/canvas/bitmap.luau`)

This mode renders the image to RGBA buffer, which is compatible with EditableImage:

```lua
local Terminal = require(path_to_luau_term)

local width, height = 80, 30
local term = Terminal.createTerminal("Bitmap", width, height)

-- Can be anything that accepts RGBA buffer
local image: EditableImage = ...

function render()
	-- Image buffer used by the terminal. Do not mutate.
	local canvas = Terminal.getActiveBuffer(term)
	image:WritePixelsBuffer(Vector2.new(0, 0), Vector2.new(width * 8, height * 16), canvas)
end

-- Renders colored "Hello, World!" to the terminal using SGR ANSI escape sequences
Terminal.stdout(term, buffer.fromstring("\27[31mHello\27[0m, \27[32mWorld\27[0m!"))

-- Need to update the image each time the terminal receives data
render()
```

### TextLabel mode (`src/canvas/textlabel.luau`)

This mode creates every character on the screen as a separate TextLabel. This is less
performant than Bitmap mode, due to how TextLabels are handled both in Roblox and in luau_term.
You should only use this mode if Bitmap mode is unavailable:

```lua
local Terminal = require(path_to_luau_term)

local width, height = 80, 30
local term = Terminal.createTerminal("TextLabel", width, height)

-- The container for the terminal
local container: GuiObject = ...

local normalScreenFrame, alternateScreenFrame = Terminal.getTextLabelContainers(term)
normalScreenFrame.Parent = container
alternateScreenFrame.Parent = container

-- Does not actually render, just shows the appropriate screen
function render()
	if term.currentScreen == term.screens.normal then
		normalScreenFrame.Visible = true
		alternateScreenFrame.Visible = false
	else
		normalScreenFrame.Visible = false
		alternateScreenFrame.Visible = true
	end
end

-- Renders colored "Hello, World!" to the terminal using SGR ANSI escape sequences
Terminal.stdout(term, buffer.fromstring("\27[31mHello\27[0m, \27[32mWorld\27[0m!"))

render()
```

## Bundling / Building

If you don't have darklua and rojo installed, install them using aftman:
```sh
aftman install
```

If you don't want to install aftman, install the dependencies yourself using cargo:
```sh
cargo install darklua
cargo install rojo
```

Finally, create a `build` folder (because rojo can't make one itself):
```sh
mkdir build
```

### Building a `.rbxm` file

After you installed the necessary dependencies, run this npm script
which will bundle the code into `./build/luau_term.rbxm` file:
```sh
npm run build-model
```

## Serving files

Make sure you install dependencies for the `example_proxy` folder:
```sh
cd example_proxy
npm install
```

For developing luau_term, or just as a faster way to insert the code in Roblox Studio,
you can serve the files using the following npm script:
```sh
npm run serve
```
This will simultaneously run darklua, rojo, and the `example_proxy` server.
