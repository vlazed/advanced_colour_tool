---@meta

---The purpose of this file is to provide type definitions for the developer, if they use
---Lua Language Server by sumneko.
---
---This file has no utility for the regular player.

---@class AdvColourInt
---@field UpdateRGB fun(self: AdvColourInt, r: number?, g: number?, b: number?, updateRed: boolean?, updateGreen: boolean?, updateBlue: boolean?)
---@field UpdateAlpha fun(self: AdvColourInt, alpha: number?)
---@field UpdateHEX fun(self: AdvColourInt, r: number?, g: number?, b: number?)
---@field UpdateHSL fun(self: AdvColourInt, r: number?, g: number?, b: number?, updateHue: boolean?, updateSaturation: boolean?, updateLightness: boolean?)
---@field GetRGB fun(self: AdvColourInt): r: number, g: number, b: number
---@field GetHSL fun(self: AdvColourInt): h: number, s: number, l: number
---@field GetA fun(self: AdvColourInt): alpha: number

---@class AdvColourCPanel: ControlPanel
---@field Int AdvColourInt

---@class ColourData
---@field Color Color?
---@field Reset boolean?

---@class AdvColourData
---@field ResetIndex boolean?
---@field ColorData ColourData[]
---@field RenderFX number?
---@field RenderMode number?
