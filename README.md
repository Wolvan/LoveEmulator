# CPU Emulator

A PoC emulator for CPUs. This currently only implements a custom CPU with a very tiny instruction set to play with.

To run this, Love2D is required.

## Environments
The following environments can be set
* ) `generic`<br>A pseudo CPU with minimal instruction set as a PoC of the emulation
* ) `mos6502`<br>A (mostly complete) behavioral implementation of a MOS6502. Runs a small demo program.

### `generic` Environment
The `generic` environment is a proof of concept of CPU emulation in Lua/Love2D. It runs a simple counter program repeatedly.

### `mos6502` Environment
The `mos6502` environment features a debugger and multiple pre-compiled tests to verify functionality of the processor implementation.
#### Controls
```
Space - Step through instructions
R - Reset
N - NMI
I - IRQ
M - Change display mode (full memory - detailed debugger)
Up/Down - Change currently visible page by 1
Left/right - Change currently visible page by 16
C - Turn on/off autoclock, clockspeed ~0.01s
```

## How to run
1. Install [Love2D version 0.9.x](https://bitbucket.org/rude/love/downloads/)
2. Set the environment in `conf.lua`
3. Run the project with `love .`

## Font
The font used to render the letters for registers is [Pixel Emulator](https://blogfonts.com/pixel-emulator.font?textfont=GmonTV+GmonTV).
