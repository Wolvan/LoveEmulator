# CPU Emulator

A PoC emulator for CPUs. This currently only implements a custom CPU with a very tiny instruction set to play with.

To run this, Love2D is required.

## Environments
The following environments can be set
* ) `generic`<br>A pseudo CPU with minimal instruction set as a PoC of the emulation
* ) `mos6502`<br>A (mostly complete) behavioral implementation of a MOS6502. Runs a small demo program.

## How to run
1. Install [Love2D version 0.9.x](https://bitbucket.org/rude/love/downloads/)
2. Set the environment in `conf.lua`
3. Run the project with `love .`

## Font
The font used to render the letters for registers is [Pixel Emulator](https://blogfonts.com/pixel-emulator.font?textfont=GmonTV+GmonTV).
