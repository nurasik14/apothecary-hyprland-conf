-- Apothecary Hyprland — nvim entry: require('apothecary').load('light'|'dark') or :colorscheme apothecary-light
local M = {}
function M.load(mode)
  mode = mode or 'light'
  local ok, p = pcall(require, 'apothecary.palette_' .. mode)
  if not ok then error('apothecary: palette_' .. mode .. ' not found (run apps/install.sh)') end
  require('apothecary.theme').apply(p)
end
-- follow the desktop: reads ~/.config/apothecary/mode when present
function M.auto()
  local f = io.open(vim.fn.expand('~/.config/apothecary/mode'), 'r')
  local mode = f and f:read('*l') or 'light'
  if f then f:close() end
  M.load(mode == 'dark' and 'dark' or 'light')
end
return M
