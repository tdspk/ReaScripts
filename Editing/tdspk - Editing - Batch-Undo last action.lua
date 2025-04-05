-- @description Batch-Undo last action
-- @version 1.0.0
-- @author Tadej Supukovic (tdspk)
-- @changelog
--   First version

local first_undo = reaper.Undo_CanUndo2(0)

if first_undo then
  reaper.Undo_DoUndo2(0)
  local next_undo = reaper.Undo_CanUndo2(0)
  
  while(first_undo == next_undo) do
    reaper.Undo_DoUndo2(0)
    next_undo = reaper.Undo_CanUndo2(0)
  end
end