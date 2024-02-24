--[[----------------------------------------------------------------------------

ClientUtilities.lua

Procedures used by Client.lua. Moved to separate file as size of Client.lua
became unwieldy.

This file is part of MIDI2LR. Copyright 2015 by Rory Jaffe.

MIDI2LR is free software: you can redistribute it and/or modify it under the
terms of the GNU General Public License as published by the Free Software
Foundation, either version 3 of the License, or (at your option) any later version.

MIDI2LR is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with
MIDI2LR.  If not, see <http://www.gnu.org/licenses/>.
------------------------------------------------------------------------------]]

local Limits     = require 'Limits'
local Database   = require 'Database'
local Profiles   = require 'Profiles'
local LrApplication       = import 'LrApplication'
local LrApplicationView   = import 'LrApplicationView'
local LrDevelopController = import 'LrDevelopController'
local LrDialogs           = import 'LrDialogs'
local LrLocalization      = import 'LrLocalization'
local LrStringUtils       = import 'LrStringUtils'
local LrTasks             = import 'LrTasks'
--[[-----------debug section, enable by adding - to beginning this line
local LrMobdebug = import 'LrMobdebug'
--]]-----------end debug section
--local versions of global functions and tables, for speed
local LRValueToMIDIValue = Limits.LRValueToMIDIValue
local MIDIValueToLRValue = Limits.MIDIValueToLRValue
local getValue = LrDevelopController.getValue
local setValue = LrDevelopController.setValue
local resetToDefault = LrDevelopController.resetToDefault
--modules may be library develop map book slideshow print web
local needsModule = {
  [LrDevelopController.addAdjustmentChangeObserver]    = {module = 'develop', photoSelected = false },
  [LrDevelopController.addToCurrentMask]               = {module = 'develop', photoSelected = true },
  [LrDevelopController.createNewMask]                  = {module = 'develop', photoSelected = true },
  [LrDevelopController.decrement]                      = {module = 'develop', photoSelected = true },
  [LrDevelopController.getProcessVersion]              = {module = 'develop', photoSelected = true },
  [LrDevelopController.getRange]                       = {module = 'develop', photoSelected = true },
  [LrDevelopController.getSelectedTool]                = {module = 'develop', photoSelected = false },
  [LrDevelopController.getValue]                       = {module = 'develop', photoSelected = true },
  [LrDevelopController.increment]                      = {module = 'develop', photoSelected = true },
  [LrDevelopController.intersectWithCurrentMask]       = {module = 'develop', photoSelected = true },
  [LrDevelopController.resetAllDevelopAdjustments]     = {module = 'develop', photoSelected = true },
  [LrDevelopController.resetCrop]                      = {module = 'develop', photoSelected = true },
  [LrDevelopController.resetMasking]                   = {module = 'develop', photoSelected = true },
  [LrDevelopController.resetRedeye]                    = {module = 'develop', photoSelected = true },
  [LrDevelopController.resetSpotRemoval]               = {module = 'develop', photoSelected = true },
  [LrDevelopController.resetToDefault]                 = {module = 'develop', photoSelected = true },
  [LrDevelopController.resetTransforms]                = {module = 'develop', photoSelected = true },
  [LrDevelopController.revealAdjustedControls]         = {module = 'develop', photoSelected = false },
  [LrDevelopController.revealPanel]                    = {module = 'develop', photoSelected = false },
  [LrDevelopController.selectTool]                     = {module = 'develop', photoSelected = false },
  [LrDevelopController.setActiveColorGradingView]      = {module = 'develop', photoSelected = false },
  [LrDevelopController.setMultipleAdjustmentThreshold] = {module = 'develop', photoSelected = false },
  [LrDevelopController.setProcessVersion]              = {module = 'develop', photoSelected = true },
  [LrDevelopController.setTrackingDelay]               = {module = 'develop', photoSelected = false },
  [LrDevelopController.setValue]                       = {module = 'develop', photoSelected = true },
  [LrDevelopController.showClipping]                   = {module = 'develop', photoSelected = false},
  [LrDevelopController.startTracking]                  = {module = 'develop', photoSelected = false },
  [LrDevelopController.stopTracking]                   = {module = 'develop', photoSelected = false },
  [LrDevelopController.subtractFromCurrentMask]        = {module = 'develop', photoSelected = true },
}

local _needsModule = {
  __index = function (t,k)
    t[k] = {module = nil, photoSelected = false}
    return t[k]
  end
}
setmetatable ( needsModule, _needsModule)

local AltOptionStr = WIN_ENV and LOC('$$$/AgBezels/KeyRemapping/WinAlt=Alt') or LOC('$$$/AgBezels/KeyRemapping/MacOption=Option')
AltOptionStr = AltOptionStr .. ' ' .. LOC('$$$/MIDI2LR/Menu/PressAndHold=press and hold') .. ' '
local AltOptionStrAct = AltOptionStr .. LOC('$$$/AgLocation/EnableGeocoding/Enable=Activate')
local AltOptionStrDeact = AltOptionStr .. LOC('$$$/AgLocation/EnableGeocoding/Diable=Deactivate')
--public

local function HoldAltOptToggle()
  MIDI2LR.AltOpt = not MIDI2LR.AltOpt
  if ProgramPreferences.ClientShowBezelOnChange then
    LrDialogs.showBezel(MIDI2LR.AltOpt and AltOptionStrAct or AltOptionStrDeact)
  end
end


--------------------------------------------------------------------------------
-- Returns function passed to it, with appropriate switch to Lightroom module if
-- needed.
-- This should wrap a module-specific Lightroom SDK function call unless you
-- already know that Lightroom is set to the correct module. Stays in module that was
-- opened after function ends.
-- @tparam function F The function to use.
-- @param...Any arguments to the function.
-- @treturn function Function closure.
--------------------------------------------------------------------------------
local function wrapFOM(F,...)
  local openModule = needsModule[F]['module']
  if openModule == nil then
    return function()
      return F(unpack(arg))  --proper tail call
    end
  end
  return function()
    if needsModule[F]['photoSelected'] and LrApplication.activeCatalog():getTargetPhoto() == nil then return end
    if LrApplicationView.getCurrentModuleName() ~= openModule then
      LrApplicationView.switchToModule(openModule)
      LrTasks.yield() -- need this to allow module change before F is called
    end
    return F(unpack(arg)) --proper tail call
  end
end

--------------------------------------------------------------------------------
-- Executes function passed to it, with appropriate switch to Lightroom module if
-- needed.
-- This should wrap a module-specific Lightroom SDK function call unless you
-- already know that Lightroom is set to the correct module. Stays in module that was
-- opened after function ends.
-- @tparam function F The function to use.
-- @param...Any arguments to the function.
-- @return Results of passed function.
--------------------------------------------------------------------------------
local function execFOM(F,...)
  local openModule = needsModule[F]['module']
  if openModule == nil then
    return F(...) --proper tail call
  end
  if needsModule[F]['photoSelected'] and LrApplication.activeCatalog():getTargetPhoto() == nil then return end
  if LrApplicationView.getCurrentModuleName() ~= openModule then
    LrApplicationView.switchToModule(openModule)
    LrTasks.yield() -- need this to allow module change before F is called
  end
  return F(...) --proper tail call
end

local wfep_action = {
  QuickDevWBAuto                  = function(T) T:quickDevelopSetWhiteBalance("Auto") end,
  QuickDevWBCloudy                = function(T) T:quickDevelopSetWhiteBalance("Cloudy") end,
  QuickDevWBDaylight              = function(T) T:quickDevelopSetWhiteBalance("Daylight") end,
  QuickDevWBFlash                 = function(T) T:quickDevelopSetWhiteBalance("Flash") end,
  QuickDevWBFluorescent           = function(T) T:quickDevelopSetWhiteBalance("Fluorescent") end,
  QuickDevWBShade                 = function(T) T:quickDevelopSetWhiteBalance("Shade") end,
  QuickDevWBTungsten              = function(T) T:quickDevelopSetWhiteBalance("Tungsten") end,
  SetTreatmentBW                  = function(T) T:quickDevelopSetTreatment("grayscale") end,
  SetTreatmentColor               = function(T) T:quickDevelopSetTreatment("color") end,
  addOrRemoveFromTargetCollection = function(T) T:addOrRemoveFromTargetCollection() end,
  openExportDialog                = function(T) T:openExportDialog() end,
  openExportWithPreviousDialog    = function(T) T:openExportWithPreviousDialog() end,
  rotateLeft                      = function(T) T:rotateLeft() end,
  rotateRight                     = function(T) T:rotateRight() end,
}
-- equivalent to "LrApplication.activeCatalog():getTargetPhoto():rotateLeft()", e.g., with target checking
local function wrapForEachPhoto(F) --note lightroom applies this to all selected photos. no need to get all selected
  local SelectedAction = wfep_action[F]
  return function()
    local LrCat = LrApplication.activeCatalog()
    local TargetPhoto  = LrCat:getTargetPhoto()
    if TargetPhoto then
      SelectedAction(TargetPhoto)
    end
  end
end

local function QuickCropAspect(aspect)
  local TargetPhoto = LrApplication.activeCatalog():getTargetPhoto()
  if TargetPhoto then
    TargetPhoto:quickDevelopCropAspect(aspect)
  end
end

local sb_precisionList = {
  Blacks=0,
  BlueHue=0,
  BlueSaturation=0,
  Brightness=0,
  Clarity=0,
  ColorGradeBlending=0,
  ColorGradeGlobalHue=0,
  ColorGradeGlobalLum=0,
  ColorGradeGlobalSat=0,
  ColorGradeHighlightLum=0,
  ColorGradeMidtoneHue=0,
  ColorGradeMidtoneLum=0,
  ColorGradeMidtoneSat=0,
  ColorGradeShadowLum=0,
  ColorNoiseReduction=0,
  ColorNoiseReductionDetail=0,
  ColorNoiseReductionSmoothness=0,
  Contrast=0,
  CropAngle=3,
  CropBottom=3,
  CropLeft=3,
  CropRight=3,
  CropTop=3,
  DefringeGreenAmount=0,
  DefringeGreenHueHi=0,
  DefringeGreenHueLo=0,
  DefringePurpleAmount=0,
  DefringePurpleHueHi=0,
  DefringePurpleHueLo=0,
  Dehaze=0,
  Exposure=2,
  GrainAmount=0,
  GrainFrequency=0,
  GrainSize=0,
  GreenHue=0,
  GreenSaturation=0,
  Highlights=0,
  HueAdjustmentAqua=0,
  HueAdjustmentBlue=0,
  HueAdjustmentGreen=0,
  HueAdjustmentMagenta=0,
  HueAdjustmentOrange=0,
  HueAdjustmentPurple=0,
  HueAdjustmentRed=0,
  HueAdjustmentYellow=0,
  LensManualDistortionAmount=0,
  LensProfileChromaticAberrationScale=0,
  LensProfileDistortionScale=0,
  LensProfileVignettingScale=0,
  LuminanceAdjustmentAqua=0,
  LuminanceAdjustmentBlue=0,
  LuminanceAdjustmentGreen=0,
  LuminanceAdjustmentMagenta=0,
  LuminanceAdjustmentOrange=0,
  LuminanceAdjustmentPurple=0,
  LuminanceAdjustmentRed=0,
  LuminanceAdjustmentYellow=0,
  LuminanceNoiseReductionContrast=0,
  LuminanceNoiseReductionDetail=0,
  LuminanceSmoothing=0,
  ParametricDarks=0,
  ParametricHighlightSplit=0,
  ParametricHighlights=0,
  ParametricLights=0,
  ParametricMidtoneSplit=0,
  ParametricShadowSplit=0,
  ParametricShadows=0,
  PerspectiveAspect=0,
  PerspectiveHorizontal=0,
  PerspectiveRotate=1,
  PerspectiveScale=0,
  PerspectiveVertical=0,
  PerspectiveX=1,
  PerspectiveY=1,
  PostCropVignetteAmount=0,
  PostCropVignetteFeather=0,
  PostCropVignetteHighlightContrast=0,
  PostCropVignetteMidpoint=0,
  PostCropVignetteRoundness=0,
  RedHue=0,
  RedSaturation=0,
  Saturation=0,
  SaturationAdjustmentAqua=0,
  SaturationAdjustmentBlue=0,
  SaturationAdjustmentGreen=0,
  SaturationAdjustmentMagenta=0,
  SaturationAdjustmentOrange=0,
  SaturationAdjustmentPurple=0,
  SaturationAdjustmentRed=0,
  SaturationAdjustmentYellow=0,
  ShadowTint=0,
  Shadows=0,
  SharpenDetail=0,
  SharpenEdgeMasking=0,
  SharpenRadius=1,
  SplitToningBalance=0,
  SplitToningHighlightHue=0,
  SplitToningHighlightSaturation=0,
  SplitToningShadowHue=0,
  SplitToningShadowSaturation=0,
  Temperature=0,
  Texture=0,
  Tint=0,
  Vibrance=0,
  VignetteAmount=0,
  VignetteMidpoint=0,
  Whites=0,
  local_Blacks2012=0,
  local_Clarity=0,
  local_Contrast=0,
  local_Defringe=0,
  local_Dehaze=0,
  local_Exposure=2,
  local_Highlights=0,
  local_LuminanceNoise=0,
  local_Moire=0,
  local_Saturation=0,
  local_Shadows=0,
  local_Sharpness=0,
  local_Temperature=0,
  local_Tint=0,
  local_Whites2012=0,
  straightenAngle=3,
}
local function showBezel(param, value1, value2)
  local precision = sb_precisionList[param] or 4
  -- uses processVersion to index bezelname
  local processVersion = tonumber(LrDevelopController.getProcessVersion():match('%-?%d+'))
  -- ternary operator idiom. Note: not quite ternary operator. If [processVersion] doesn't match an entry, will use param instead.
  -- if CmdTrans[param] exists, will try first [processVersion] then, if that doesn't exist, [LatestPVSupported], then fallback to param
  -- this is in case someone doesn't update MIDI2LR but Adobe goes to a higher process version not supported by MIDI2LR CmdTrans table
  local bezelname = Database.CmdTrans[param] and (Database.CmdTrans[param][processVersion] or Database.CmdTrans[param][Database.LatestPVSupported]) or param
  if value2 then
    LrDialogs.showBezel(bezelname..'  '..LOC('$$$/MIDI2LR/Bezel/Pickup=Controller not synchronized. Adjust ^1 to Lightroom value: ^2.',LrStringUtils.numberToStringWithSeparators(value1,precision),LrStringUtils.numberToStringWithSeparators(value2,precision)) )
  else
    LrDialogs.showBezel(bezelname..'  '..LrStringUtils.numberToStringWithSeparators(value1,precision))
  end
end

local function fApplyFilter(filternumber)
  return function()
    local filterUuid = ProgramPreferences.Filters[filternumber]
    if filterUuid == nil then return end
    LrApplication.activeCatalog():setViewFilter(filterUuid)
    if ProgramPreferences.ClientShowBezelOnChange then
      local _,str = LrApplication.activeCatalog():getCurrentViewFilter()
      if str then LrDialogs.showBezel(str) end -- str nil if not defined
    end
  end
end
--see AppData\Roaming\Adobe\Lightroom\Filter Presets\Filters Off.lrtemplate
local nofilter = { --version = 2
  columnBrowserActive = false,
  customLabel = false,
  datePreset = "all",
  dateSearchActive = false,
  filtersActive = false,
  label1 = false,
  label2 = false,
  label3 = false,
  label4 = false,
  label5 = false,
  labelOp = "any",
  --minRating = "<nil>",
  noLabel = false,
  --pick = "<nil>",
  --edit = "<nil>",
  ratingOp = ">=",
  searchOp = "all",
  searchString = "",
  searchStringActive = false,
  searchTarget = "all",
  --usage = "<nil>",
  --whichCopies = "<nil>",
  visualSearchActive = false,
}

local function RemoveFilters()
  LrApplication.activeCatalog():setViewFilter(nofilter)
  if ProgramPreferences.ClientShowBezelOnChange then
    LrDialogs.showBezel(Database.CmdTrans.FilterNone[1]) --PV doesn't matter
  end
end

local function fChangePanel(panelname)
  return function()
    execFOM(LrDevelopController.revealPanel,panelname)
    Profiles.changeProfile(panelname)
  end
end

local function fChangeModule(modulename)
  return function()
    LrApplicationView.switchToModule(modulename)
    Profiles.changeProfile(modulename)
  end
end

local function fToggle01(param)
  return function()
    if execFOM(getValue, param) == 0 then
      setValue(param,1)
    else
      setValue(param,0)
    end
  end
end

local function fToggle01Async(param)
  return function()
    LrTasks.startAsyncTask ( function ()
        --[[-----------debug section, enable by adding - to beginning this line
        LrMobdebug.on()
        --]]-----------end debug section
        if execFOM(getValue, param) == 0 then
          setValue(param,1)
        else
          setValue(param,0)
        end
      end )
  end
end

local function fToggle1ModN(param, N)
  return function()
    local v = execFOM(getValue, param)
    v = (v % N) + 1
    setValue(param,v)
  end
end

local function fToggleTFasync(param)
  return function()
    LrTasks.startAsyncTask ( function ()
        --[[-----------debug section, enable by adding - to beginning this line
        LrMobdebug.on()
        --]]-----------end debug section
        if LrApplication.activeCatalog():getTargetPhoto() == nil then return end
        LrApplication.activeCatalog():withWriteAccessDo(
          'MIDI2LR: Apply settings',
          function()
            local params = LrApplication.activeCatalog():getTargetPhoto():getDevelopSettings()
            params[param] = not params[param]
            LrApplication.activeCatalog():getTargetPhoto():applyDevelopSettings(params)
          end,
          { timeout = 4,
            callback = function()
              LrDialogs.showError(LOC("$$$/AgCustomMetadataRegistry/UpdateCatalog/Error=The catalog could not be updated with additional module metadata.")..' ApplySettings')
            end,
            asynchronous = true
          }
        )
      end
    )
  end
end

local function fToggleTool(param)
  return function()
    if LrApplicationView.getCurrentModuleName() ~= 'develop' then
      LrApplicationView.switchToModule('develop')
      LrTasks.yield() -- need this to allow module change before next action
    end
    if LrDevelopController.getSelectedTool() == param then -- toggle between the tool/loupe
      LrDevelopController.selectTool('loupe')
      Profiles.changeProfile('loupe', true)
    else
      LrDevelopController.selectTool(param)
      Profiles.changeProfile(param, true)
    end
  end
end

local ftt1_functionList = {
  dust = LrDevelopController.goToHealing,
  masking = LrDevelopController.goToMasking,
}

local function fToggleTool1(param) --for new version toggle tool
  return function()
    if LrApplicationView.getCurrentModuleName() == 'develop' and
    LrDevelopController.getSelectedTool() == param then
      LrDevelopController.selectTool('loupe')
    else
      ftt1_functionList[param]()
    end
  end
end


local function ApplySettings(settings)
  if LrApplication.activeCatalog():getTargetPhoto() == nil then return end
  LrTasks.startAsyncTask ( function ()
      --[[-----------debug section, enable by adding - to beginning this line
      LrMobdebug.on()
      --]]-----------end debug section
      LrApplication.activeCatalog():withWriteAccessDo(
        'MIDI2LR: Apply settings',
        function() LrApplication.activeCatalog():getTargetPhoto():applyDevelopSettings(settings) end,
        { timeout = 4,
          callback = function()
            LrDialogs.showError(LOC("$$$/AgCustomMetadataRegistry/UpdateCatalog/Error=The catalog could not be updated with additional module metadata.")..' ApplySettings')
          end,
          asynchronous = true
        }
      )
    end
  )
end

local function fSimulateKeys(keys, developonly, tool)
  return function()
    if developonly then
      if LrApplicationView.getCurrentModuleName() == 'develop' and LrApplication.activeCatalog():getTargetPhoto() ~= nil then
        if tool == nil or tool[LrDevelopController.getSelectedTool()] then
          MIDI2LR.SERVER:send('SendKey '..keys..'\n')
        end
      end
    else
      MIDI2LR.SERVER:send('SendKey '..keys..'\n')
    end
  end
end

local function UpdatePointCurve(settings)
  return function()
    fChangePanel('tonePanel')
    ApplySettings(settings)
  end
end

local curBlkDn = LOC('$$$/AgCameraRawController/TargetAdjustment/Decrease=^1 decrease: ^2',LOC('$$$/AgDevelop/Localized/Panel/Curve=Gradation Curve'),LOC('$$$/AgCameraRawUI/Blacks=Blacks'))
local curBlkUp = LOC('$$$/AgCameraRawController/TargetAdjustment/Increase=^1 increase: ^2',LOC('$$$/AgDevelop/Localized/Panel/Curve=Gradation Curve'),LOC('$$$/AgCameraRawUI/Blacks=Blacks'))
local curHiDn = LOC('$$$/AgCameraRawController/TargetAdjustment/Decrease=^1 decrease: ^2',LOC('$$$/AgDevelop/Localized/Panel/Curve=Gradation Curve'),LOC('$$$/AgCameraRawUI/Highlights=Highlights'))
local curHiUp = LOC('$$$/AgCameraRawController/TargetAdjustment/Increase=^1 increase: ^2',LOC('$$$/AgDevelop/Localized/Panel/Curve=Gradation Curve'),LOC('$$$/AgCameraRawUI/Highlights=Highlights'))
local function PointCurveUpDown(blacks, moveup, color)
  return function()
    if LrApplicationView.getCurrentModuleName() ~= 'develop' or LrApplication.activeCatalog():getTargetPhoto() == nil then return end
    local maxamount = 5
    local  factor  = 0
    local setting = 'ToneCurvePV2012'
    if color then setting = setting..color end
    local points = getValue(setting)
    local newpoints = {}
    local xval = 0
    local testamount = 0
    -- Find the left and right most points
    local xmin, ymin, xmax, ymax, xmindid, xmaxdid = nil, nil, nil, nil, false, false
    for idx,val in ipairs(points) do
      if math.floor(idx/2) ~= idx/2 then -- odd number, i.e. x
        if val < (xmin or 256) then xmin = val; xmindid = true end
        if val > (xmax or 0) then xmax = val; xmaxdid = true end
      elseif xmindid then
        ymin = val
        xmindid = false
      elseif xmaxdid then
        ymax = val
        xmaxdid = false
      end
    end
    -- There are two scales (explanation for blacks):
    -- xscale: diminishes the point movement the further right the point is, where the left most point has full effect (1 => maxamount), the right most point has 0 (does not move at all)
    -- yscale: is the percentage how much maxamount is in relation to the y-value of the leftmost point; this is for awkward curves where the leftmost point is not the lowest one,
    -- in such cases the points lower than the leftmost have to be affected more to keep the shape of the curve intact, as those values are more 'extreme', they are affected more
    local yscale = 0
    local xscale = 0
    if blacks then
      if not moveup and ymin < maxamount then maxamount = ymin end
      yscale = maxamount / (255 - ymin)
    else
      if moveup and (255 - ymax) < maxamount then maxamount = (255 - ymax) end
      yscale = maxamount / ymax
    end
    xscale = 1 / (xmax - xmin)
    -- Now all points are moved. 'factor' is the diminishing effect of xscale depending on the actual x-value of the point
    for idx,val in ipairs(points) do
      if math.floor(idx/2) ~= idx/2 then -- odd number, i.e. x
        if blacks then
          factor  = 1 - (xscale * (val - xmin))^2.5
        else
          factor  = 1 - (xscale * (xmax - val))^2.5
        end
        xval = val
      else -- even number, i.e. y
        newpoints[#newpoints+1] = xval
        if not moveup then  factor  =  factor  * -1 end
        if blacks then
          testamount = val + yscale * (255 - val) * factor
        else
          testamount = val + yscale * val * factor
        end
        if testamount < 0 then testamount = 0 end
        if testamount > 255 then testamount = 255 end
        newpoints[#newpoints+1] = testamount
      end
    end
    fChangePanel('tonePanel')
    setValue(setting, newpoints)
    if ProgramPreferences.ClientShowBezelOnChange then
      if blacks then
        LrDialogs.showBezel(moveup and curBlkUp or curBlkDn)
      else
        LrDialogs.showBezel(moveup and curHiUp or curHiDn)
      end
    end
  end
end

local cg_hsl_parms = {global={'ColorGradeGlobalHue','ColorGradeGlobalSat','ColorGradeGlobalLum'},
  highlight={'SplitToningHighlightHue','SplitToningHighlightSaturation','ColorGradeHighlightLum'},
  midtone={'ColorGradeMidtoneHue','ColorGradeMidtoneSat','ColorGradeMidtoneLum'},
  shadow={'SplitToningShadowHue','SplitToningShadowSaturation','ColorGradeShadowLum'}}

local cg_hsl = {0,0,0}

local function cg_hsl_copy()
  local currentView = LrDevelopController.getActiveColorGradingView()
  if currentView == '3-way' then
    return
  end
  cg_hsl = {getValue(cg_hsl_parms[currentView][1]),
    getValue(cg_hsl_parms[currentView][2]),
    getValue(cg_hsl_parms[currentView][3])}
end

local function cg_hsl_paste()
  local currentView = LrDevelopController.getActiveColorGradingView()
  if currentView == '3-way' then
    setValue(cg_hsl_parms.highlight[1],cg_hsl[1])
    setValue(cg_hsl_parms.highlight[2],cg_hsl[2])
    setValue(cg_hsl_parms.highlight[3],cg_hsl[3])
    setValue(cg_hsl_parms.midtone[1],cg_hsl[1])
    setValue(cg_hsl_parms.midtone[2],cg_hsl[2])
    setValue(cg_hsl_parms.midtone[3],cg_hsl[3])
    setValue(cg_hsl_parms.shadow[1],cg_hsl[1])
    setValue(cg_hsl_parms.shadow[2],cg_hsl[2])
    setValue(cg_hsl_parms.shadow[3],cg_hsl[3])
    Limits.RefreshMidiController()
    return
  end
  setValue(cg_hsl_parms[currentView][1],cg_hsl[1])
  setValue(cg_hsl_parms[currentView][2],cg_hsl[2])
  setValue(cg_hsl_parms[currentView][3],cg_hsl[3])
  Limits.RefreshMidiController()
end

local function cg_reset_3way()
  resetToDefault('SplitToningHighlightHue')
  resetToDefault('SplitToningHighlightSaturation')
  resetToDefault('ColorGradeHighlightLum')
  resetToDefault('ColorGradeMidtoneHue')
  resetToDefault('ColorGradeMidtoneSat')
  resetToDefault('ColorGradeMidtoneLum')
  resetToDefault('SplitToningShadowHue')
  resetToDefault('SplitToningShadowSaturation')
  resetToDefault('ColorGradeShadowLum')
  Limits.RefreshMidiController()
end

local function cg_reset_all()
  resetToDefault('ColorGradeGlobalHue')
  resetToDefault('ColorGradeGlobalSat')
  resetToDefault('ColorGradeGlobalLum')
  cg_reset_3way()
end

local function cg_reset_current()
  local currentView = LrDevelopController.getActiveColorGradingView()
  if currentView == '3-way' then
    cg_reset_3way()
    return
  end
  if currentView == 'global' then
    resetToDefault('ColorGradeGlobalHue')
    resetToDefault('ColorGradeGlobalSat')
    resetToDefault('ColorGradeGlobalLum')
    Limits.RefreshMidiController()
    return
  end
  if currentView == 'highlight' then
    resetToDefault('SplitToningHighlightHue')
    resetToDefault('SplitToningHighlightSaturation')
    resetToDefault('ColorGradeHighlightLum')
    Limits.RefreshMidiController()
    return
  end
  if currentView == 'midtone' then
    resetToDefault('ColorGradeMidtoneHue')
    resetToDefault('ColorGradeMidtoneSat')
    resetToDefault('ColorGradeMidtoneLum')
    Limits.RefreshMidiController()
    return
  end
  if currentView == 'shadow' then
    resetToDefault('SplitToningShadowHue')
    resetToDefault('SplitToningShadowSaturation')
    resetToDefault('ColorGradeShadowLum')
    Limits.RefreshMidiController()
    return
  end
end

local patrans = LOC('$$$/AgCameraRawNamedSettings/CameraRawSettingMapping/ProfileAmount=Profile amount')
local lastprofileadj = 0
local function ProfileAmount(value)
  local now = os.clock()
  if lastprofileadj + .1 > now then --throttle to 10x/second
    return
  end
  lastprofileadj = now
  local val = value -- make available to async task
  LrTasks.startAsyncTask ( function ()
      --[[-----------debug section, enable by adding - to beginning this line
      LrMobdebug.on()
      --]]-----------end debug section
      if LrApplication.activeCatalog():getTargetPhoto() == nil then return end
      LrApplication.activeCatalog():withWriteAccessDo(
        'MIDI2LR: Profile amount',
        function()
          local params = LrApplication.activeCatalog():getTargetPhoto():getDevelopSettings()
          if params and params.Look and params.Look.Amount then
            params.Look.Amount = val * 2
            LrApplication.activeCatalog():getTargetPhoto():applyDevelopSettings(params)
            if ProgramPreferences.ClientShowBezelOnChange then
              local bezelname = (Database.CmdTrans.ProfileAmount and Database.CmdTrans.ProfileAmount[Database.LatestPVSupported]) or patrans
              LrDialogs.showBezel(bezelname..'  '..LrStringUtils.numberToStringWithSeparators(val*200, 0))
            end
          end
        end,
        { timeout = 4,
          callback = function()
            LrDialogs.showError(LOC("$$$/AgCustomMetadataRegistry/UpdateCatalog/Error=The catalog could not be updated with additional module metadata.")..' '..patrans)
          end,
          asynchronous = true
        }
      )
    end
  )
end

local function ResetAllGrayMixer()
  resetToDefault('GrayMixerRed')
  resetToDefault('GrayMixerOrange')
  resetToDefault('GrayMixerYellow')
  resetToDefault('GrayMixerGreen')
  resetToDefault('GrayMixerAqua')
  resetToDefault('GrayMixerBlue')
  resetToDefault('GrayMixerPurple')
  resetToDefault('GrayMixerMagenta')
  if ProgramPreferences.ClientShowBezelOnChange then
    local bezelname = (Database.CmdTrans.ResetAllGrayMixer and Database.CmdTrans.ResetAllGrayMixer[Database.LatestPVSupported]) or "ResetAllGrayMixer"
    LrDialogs.showBezel(bezelname..'  '..LrStringUtils.numberToStringWithSeparators(0, 0))
  end
end

local function ResetAllHueAdjustment()
  resetToDefault('HueAdjustmentRed')
  resetToDefault('HueAdjustmentOrange')
  resetToDefault('HueAdjustmentYellow')
  resetToDefault('HueAdjustmentGreen')
  resetToDefault('HueAdjustmentAqua')
  resetToDefault('HueAdjustmentBlue')
  resetToDefault('HueAdjustmentPurple')
  resetToDefault('HueAdjustmentMagenta')
  if ProgramPreferences.ClientShowBezelOnChange then
    local bezelname = (Database.CmdTrans.ResetAllHueAdjustment and Database.CmdTrans.ResetAllHueAdjustment[Database.LatestPVSupported]) or "ResetAllHueAdjustment"
    LrDialogs.showBezel(bezelname..'  '..LrStringUtils.numberToStringWithSeparators(0, 0))
  end
end

local function ResetAllLuminanceAdjustment()
  resetToDefault('LuminanceAdjustmentRed')
  resetToDefault('LuminanceAdjustmentOrange')
  resetToDefault('LuminanceAdjustmentYellow')
  resetToDefault('LuminanceAdjustmentGreen')
  resetToDefault('LuminanceAdjustmentAqua')
  resetToDefault('LuminanceAdjustmentBlue')
  resetToDefault('LuminanceAdjustmentPurple')
  resetToDefault('LuminanceAdjustmentMagenta')
  if ProgramPreferences.ClientShowBezelOnChange then
    local bezelname = (Database.CmdTrans.ResetAllLuminanceAdjustment and Database.CmdTrans.ResetAllLuminanceAdjustment[Database.LatestPVSupported]) or "ResetAllLuminanceAdjustment"
    LrDialogs.showBezel(bezelname..'  '..LrStringUtils.numberToStringWithSeparators(0, 0))
  end
end

local function ResetAllSaturationAdjustment()
  resetToDefault('SaturationAdjustmentRed')
  resetToDefault('SaturationAdjustmentOrange')
  resetToDefault('SaturationAdjustmentYellow')
  resetToDefault('SaturationAdjustmentGreen')
  resetToDefault('SaturationAdjustmentAqua')
  resetToDefault('SaturationAdjustmentBlue')
  resetToDefault('SaturationAdjustmentPurple')
  resetToDefault('SaturationAdjustmentMagenta')
  if ProgramPreferences.ClientShowBezelOnChange then
    local bezelname = (Database.CmdTrans.ResetAllSaturationAdjustment and Database.CmdTrans.ResetAllSaturationAdjustment[Database.LatestPVSupported]) or "ResetAllSaturationAdjustment"
    LrDialogs.showBezel(bezelname..'  '..LrStringUtils.numberToStringWithSeparators(0, 0))
  end
  MIDI2LR.SERVER:send(string.format('%s %g\n', "AllSaturationAdjustment", LRValueToMIDIValue("SaturationAdjustmentRed")))
end

local cropbezel = LOC('$$$/AgCameraRawNamedSettings/SaveNamedDialog/Crop=Crop')..' ' -- no need to recompute each time we crop
local pct = '%'
if LrLocalization.currentLanguage() == 'fr' then
  pct = ' %'
end

local function RatioCrop(param, midi_value, UpdateParam)
  if LrApplication.activeCatalog():getTargetPhoto() == nil then return end
  if LrApplicationView.getCurrentModuleName() ~= 'develop' then
    LrApplicationView.switchToModule('develop')
  end
  LrDevelopController.selectTool('crop')
  local prior_c_bottom = getValue("CropBottom") --starts at 1
  local prior_c_top = getValue("CropTop") -- starts at 0
  local prior_c_left = getValue("CropLeft") -- starts at 0
  local prior_c_right = getValue("CropRight") -- starts at 1
  local ratio = (prior_c_right - prior_c_left) / (prior_c_bottom - prior_c_top)
  if param == "CropTopLeft" then
    local new_top = MIDIValueToLRValue('CropTop',midi_value)
    local new_left = prior_c_right - ratio * (prior_c_bottom - new_top)
    if new_left < 0 then
      new_top = prior_c_bottom - prior_c_right / ratio
      new_left = 0
    end
    if UpdateParam("CropTop",midi_value,
      cropbezel..LrStringUtils.numberToStringWithSeparators((prior_c_right-new_left)*(prior_c_bottom-new_top)*100,0)..pct)
    then
      UpdateParam("CropLeft",LRValueToMIDIValue("CropLeft",new_left),true,true)
    end
  elseif param == "CropTopRight" then
    local new_top = MIDIValueToLRValue('CropTop',midi_value)
    local new_right = prior_c_left + ratio * (prior_c_bottom - new_top)
    if new_right > 1 then
      new_top = prior_c_bottom - (1 - prior_c_left) / ratio
      new_right = 1
    end
    if UpdateParam("CropTop",midi_value,
      cropbezel..LrStringUtils.numberToStringWithSeparators((new_right-prior_c_left)*(prior_c_bottom-new_top)*100,0)..pct)
    then
      UpdateParam("CropRight",LRValueToMIDIValue("CropRight",new_right),true,true)
    end
  elseif param == "CropBottomLeft" then
    local new_bottom = MIDIValueToLRValue('CropBottom',midi_value)
    local new_left = prior_c_right - ratio * (new_bottom - prior_c_top)
    if new_left < 0 then
      new_bottom = prior_c_right / ratio + prior_c_top
      new_left = 0
    end
    if UpdateParam("CropBottom",midi_value,
      cropbezel..LrStringUtils.numberToStringWithSeparators((prior_c_right-new_left)*(new_bottom-prior_c_top)*100,0)..pct)
    then
      UpdateParam("CropLeft",LRValueToMIDIValue("CropLeft",new_left),true,true)
    end
  elseif param == "CropBottomRight" then
    local new_bottom = MIDIValueToLRValue('CropBottom',midi_value)
    local new_right = prior_c_left + ratio * (new_bottom - prior_c_top)
    if new_right > 1 then
      new_bottom = (1 - prior_c_left) / ratio + prior_c_top
      new_right = 1
    end
    if UpdateParam("CropBottom",midi_value,
      cropbezel..LrStringUtils.numberToStringWithSeparators((new_right-prior_c_left)*(new_bottom-prior_c_top)*100,0)..pct)
    then
      UpdateParam("CropRight",LRValueToMIDIValue("CropRight",new_right),true,true)
    end
  elseif param == "CropAll" then
    local new_bottom = MIDIValueToLRValue('CropBottom',midi_value)
    local new_right = prior_c_left + ratio * (new_bottom - prior_c_top)
    if new_right > 1 then
      new_right = 1
    end
    local new_top = math.max(prior_c_bottom - new_bottom + prior_c_top,0)
    local new_left = new_right - ratio * (new_bottom - new_top)
    if new_left < 0 then
      new_top = new_bottom - new_right / ratio
      new_left = 0
    end
    if UpdateParam("CropBottom",midi_value,
      cropbezel..LrStringUtils.numberToStringWithSeparators((new_right-new_left)*(new_bottom-new_top)*100,0)..pct)
    then
      UpdateParam("CropRight",LRValueToMIDIValue("CropRight",new_right),true,true)
      UpdateParam("CropTop",LRValueToMIDIValue("CropTop",new_top),true,true)
      UpdateParam("CropLeft",LRValueToMIDIValue("CropLeft",new_left),true,true)
    end
  elseif param == "CropMoveVertical" then
    local new_top = MIDIValueToLRValue('CropTop',midi_value)
    local new_bottom = new_top - prior_c_top + prior_c_bottom
    if new_bottom > 1 then -- preserve shape, don't move past border
      if
      UpdateParam('CropTop',1-(prior_c_bottom-prior_c_top))
      then
        UpdateParam('CropBottom',1,true,true)
      end
    else
      if UpdateParam('CropTop',LRValueToMIDIValue('CropTop',new_top)) then
        UpdateParam('CropBottom',LRValueToMIDIValue('CropBottom',new_bottom),true,true)
      end
    end
  elseif param == "CropMoveHorizontal" then
    local new_left = MIDIValueToLRValue('CropLeft',midi_value)
    local new_right = new_left - prior_c_left + prior_c_right
    if new_right > 1 then -- preserve shape, don't move past border
      if
      UpdateParam('CropLeft',1-(prior_c_right-prior_c_left))
      then
        UpdateParam('CropRight',1,true,true)
      end
    else
      if UpdateParam("CropLeft",LRValueToMIDIValue('CropLeft',new_left)) then
        UpdateParam("CropRight", LRValueToMIDIValue('CropRight',new_right),true,true)
      end
    end
  end
end

local function quickDevAdjust(par,val,cmd) --note lightroom applies this to all selected photos. no need to get all selected
  return function()
    LrTasks.startAsyncTask(
      function()
        --[[-----------debug section, enable by adding - to beginning this line
        LrMobdebug.on()
        --]]-----------end debug section
        local TargetPhoto  = LrApplication.activeCatalog():getTargetPhoto()
        if TargetPhoto then
          TargetPhoto:quickDevelopAdjustImage(par,val)
          if ProgramPreferences.ClientShowBezelOnChange then
            LrDialogs.showBezel(Database.CmdTrans[cmd][1])
          end
        end
      end
    )
  end
end

local function quickDevAdjustWB(par,val,cmd) --note lightroom applies this to all selected photos. no need to get all selected
  return function()
    LrTasks.startAsyncTask(
      function()
        --[[-----------debug section, enable by adding - to beginning this line
        LrMobdebug.on()
        --]]-----------end debug section
        local TargetPhoto  = LrApplication.activeCatalog():getTargetPhoto()
        if TargetPhoto then
          TargetPhoto:quickDevelopAdjustWhiteBalance(par,val)
          if ProgramPreferences.ClientShowBezelOnChange then
            LrDialogs.showBezel(Database.CmdTrans[cmd][1])
          end
        end
      end
    )
  end
end
return {
  ApplySettings = ApplySettings,
  HoldAltOptToggle = HoldAltOptToggle,
  PointCurveUpDown = PointCurveUpDown,
  ProfileAmount = ProfileAmount,
  QuickCropAspect = QuickCropAspect,
  RatioCrop = RatioCrop,
  RemoveFilters = RemoveFilters,
  ResetAllGrayMixer = ResetAllGrayMixer,
  ResetAllHueAdjustment = ResetAllHueAdjustment,
  ResetAllLuminanceAdjustment = ResetAllLuminanceAdjustment,
  ResetAllSaturationAdjustment = ResetAllSaturationAdjustment,
  UpdatePointCurve = UpdatePointCurve,
  cg_hsl_copy = cg_hsl_copy,
  cg_hsl_paste = cg_hsl_paste,
  cg_reset_3way = cg_reset_3way,
  cg_reset_all = cg_reset_all,
  cg_reset_current = cg_reset_current,
  execFOM = execFOM,
  fApplyFilter = fApplyFilter,
  fChangeModule = fChangeModule,
  fChangePanel = fChangePanel,
  fSimulateKeys = fSimulateKeys,
  fToggle01 = fToggle01,
  fToggle01Async = fToggle01Async,
  fToggle1ModN = fToggle1ModN,
  fToggleTFasync = fToggleTFasync,
  fToggleTool = fToggleTool,
  fToggleTool1 = fToggleTool1,
  quickDevAdjust = quickDevAdjust,
  quickDevAdjustWB = quickDevAdjustWB,
  showBezel = showBezel,
  wrapFOM = wrapFOM,
  wrapForEachPhoto = wrapForEachPhoto,
}
