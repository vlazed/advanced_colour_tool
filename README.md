# Advanced Colour Tool

This is a public, working repository for the [Advanced Colour Tool](https://steamcommunity.com/sharedfiles/filedetails/?id=692778306). It fixes multiple bugs in the workshop version, as listed below:
- It properly duplicates entities with advanced colors;
- It circumvents edge case with the `null` material causing black entities when colored, and
- it silences other Lua errors.

## Installation
If you want to use this in GMod, do the following steps:
1. Click the Green "<> Code" button, and click "Download Zip", and
2. Extract the folder (probably called `advanced_colour_tool-main`) into your `garrysmod/addons` directory.
3. If you are currently running a game, `reload_legacy_addons` and `reload` the server using the console. Otherwise, the fixed version should now take precedence over the workshop version.

## Disclaimer
I downloaded Advanced Colour Tool using [gmpublisher](https://github.com/WilliamVenner/gmpublisher) and uploaded its source here. My only contribution is patching the tool to minimize errors and fix duplicator functionality. All credits for the main functionality go to the unknown owner of the code. 

I do not aim to supplant the current workshop version of the Advanced Colour Tool. It would be nice if this version on the repository could be used in Steam Workshop.
