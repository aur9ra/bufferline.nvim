---------------------------------------------------------------------------//
-- opt-in extension hiding: buffer labels drop a known-icon extension unless
-- another listed buffer would collide on the stripped stem. the collision
-- table is rebuilt per render frame (same philosophy as duplicates.reset()),
-- so no autocommands or dirty scans are needed; the scan only runs when the
-- hide_extension_when_icon_known option is enabled
---------------------------------------------------------------------------//

local M = {}

local utils = require("bufferline.utils") ---@module "bufferline.utils"

local fn, api = vim.fn, vim.api

local no_name = "[No Name]"

-- extension -> true/false, memoized so provider lookups happen once per
-- extension for the module lifetime (extension membership is stable between
-- provider loads)
local icon_cache = {}

-- stem -> false (at least two distinct tails collide under this stem) or the
-- single tail name; absent stems are unambiguous
local stems = {}

-- true when the devicon provider resolves this extension to a known icon.
-- the nil, nil default=false signal is the one portable across providers
-- (nvim-web-devicons and mini.icons' mock); comparing against a default icon
-- is not portable. an unavailable provider degrades to keeping extensions
-- instead of breaking the tabline.
local function has_devicon(ext)
  ext = ext:lower()
  local cached = icon_cache[ext]
  if cached ~= nil then return cached end
  local ok, devicons = pcall(require, "nvim-web-devicons")
  local result = ok and devicons.get_icon("x." .. ext, ext, { default = false }) ~= nil
  icon_cache[ext] = result
  return result
end

-- nil when the tail must keep its extension (dotfile, extensionless,
-- multi-dot, trailing-dot, or no devicon registered), otherwise the stem
local function stripped_stem(tail)
  local stem, ext = tail:match("^([^.]+)%.([^.]+)$")
  if not stem or not has_devicon(ext) then return nil end
  return stem
end

local function register(label, tail)
  local previous = stems[label]
  if previous == nil then
    stems[label] = tail
  elseif previous ~= tail then
    stems[label] = false
  end
end

---Rebuild the stem-collision table from every listed buffer. non-file
---buffers and directories register their display labels so that files whose
---stripped stem would collide with one keep their extension
function M.scan()
  stems = {}
  for _, bufnr in ipairs(utils.get_valid_buffers()) do
    local path = api.nvim_buf_get_name(bufnr)
    if path == "" then
      register(no_name, no_name)
    else
      local tail = fn.fnamemodify(path, ":t")
      local is_directory = fn.isdirectory(path) > 0
      local display_tail = is_directory and (tail .. "/") or tail
      if vim.bo[bufnr].buftype ~= "" or is_directory then
        register(display_tail, display_tail)
      else
        register(stripped_stem(display_tail) or display_tail, display_tail)
      end
    end
  end
end

---@param name string the display tail name (no trailing slash)
---@return string? the stripped stem when hiding is safe, nil to keep the name
function M.strip(name)
  local stem, ext = name:match("^([^.]+)%.([^.]+)$")
  if not stem or not has_devicon(ext) then return nil end
  if stems[stem] == false then return nil end
  return stem
end

return M
