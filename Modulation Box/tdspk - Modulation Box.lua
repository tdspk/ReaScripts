--@description Modulation Box
--@version 1.1
--@author Tadej Supukovic (tdspk)
--@about
--  # Modulation Box
--  Scripts to accelerate the REAPER modulation workflow. These scripts use NamedConfigParms to quickly add, copy, and paste modulation data like ACS and LFO for FX parameters. Link parameters easily with two actions.
--  These scripts are designed to be as modular as possible, so feel free to make shortcuts, add them to toolbars, use the scripts for your own scripts, etc.
--  # Requirements
--  SWS Extension, JS_ReaScriptAPI
--@links
--  Website https://www.tdspkaudio.com
--@donation
--  https://ko-fi.com/tdspkaudio
--  https://coindrop.to/tdspkaudio
--@provides
--  [nomain] .
--  tdspk - Modulation Box - Common Functions.lua
--  [main] tdspk - Modulation Box - Copy ACS settings from last touched FX parameter.lua
--  [main] tdspk - Modulation Box - Copy LFO Settings from last touched FX parameter.lua
--  [main] tdspk - Modulation Box - Enable ACS for last touched FX parameter.lua
--  [main] tdspk - Modulation Box - Enable LFO for last touched FX parameter.lua
--  tdspk - Modulation Box - Info Panel.lua
--  [main] tdspk - Modulation Box - Link last touched FX parameter to link parent.lua
--  tdspk - Modulation Box - List View.lua
--  [main] tdspk - Modulation Box - Paste ACS settings.lua
--  [main] tdspk - Modulation Box - Paste LFO settings.lua
--  [main] tdspk - Modulation Box - Set last touched FX parameter as link parent and auto-link following touched FX parameters (background).lua
--  [main] tdspk - Modulation Box - Set last touched FX parameter as link parent.lua
--  [main] tdspk - Modulation Box - Show knobs for each modulated FX parameter in TCP.lua
--  [main] tdspk - Modulation Box - Toggle TCP Knob Visibility When Adding Modulators.lua
--  [main] tdspk - Modulation Box - Unlink last touched parameter.lua
--@changelog
--  Implemented support for FX containers and media item FX
--  Fixed cmd_idbug in Toggle TCP Knob Visibility When Adding Modulations.lua
--  Support for FX Containers
--  Added support for tcp toggle
--  First version