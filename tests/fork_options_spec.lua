local api = vim.api

local icon_map = {
  c = "C",
  go = "G",
  js = "J",
  lua = "L",
  py = "P",
  ts = "T",
  tsx = "X",
}

local original_devicons = package.loaded["nvim-web-devicons"]
local original_devicons_preload = package.preload["nvim-web-devicons"]

local function make_devicons(map)
  return {
    get_icon = function(name, extension, opts)
      local ext = extension or vim.fn.fnamemodify(name or "", ":e")
      local icon = map[ext:lower()]
      if opts and opts.default == false then return icon end
      return icon or "D"
    end,
  }
end

local function install_devicons(map)
  local provider = make_devicons(map)
  package.loaded["nvim-web-devicons"] = nil
  package.preload["nvim-web-devicons"] = function() return provider end

  -- extension hiding memoizes provider results and buffers keep its module table
  package.loaded["bufferline.extensions"] = nil
  package.loaded["bufferline.buffers"] = nil
  package.loaded["bufferline.models"] = nil
end

install_devicons(icon_map)
local bufferline = require("bufferline")

local function reset_plugin_modules()
  for _, module in ipairs({
    "bufferline.config",
    "bufferline.duplicates",
    "bufferline.extensions",
    "bufferline.groups",
    "bufferline.models",
    "bufferline.state",
    "bufferline.buffers",
  }) do
    package.loaded[module] = nil
  end
end

local base_options = {
  mode = "buffers",
  show_buffer_icons = true,
  show_buffer_close_icons = false,
  show_close_icon = false,
  show_duplicate_prefix = true,
  enforce_regular_tabs = false,
  truncate_names = false,
  tab_size = 0,
  padding_style = "compact",
  separator_style = "thin",
  sort_by = "id",
  persist_buffer_sort = false,
  hide_extension_when_icon_known = true,
}

local function setup(changes)
  local options = vim.tbl_deep_extend("force", vim.deepcopy(base_options), changes or {})
  bufferline.setup({ options = options })
end

local temp_root = vim.fn.tempname()
assert(vim.fn.mkdir(temp_root, "p") == 1, "could not create temporary directory")
assert(vim.fn.isdirectory(temp_root) == 1, "temporary directory was not created")

local function path(name) return temp_root .. "/" .. name end

local function add_buffer(name)
  local bufnr = api.nvim_create_buf(true, false)
  if name ~= "" then api.nvim_buf_set_name(bufnr, name) end
  vim.bo[bufnr].buflisted = true
  return bufnr
end

local function add_terminal(name)
  local bufnr = add_buffer(name)
  api.nvim_open_term(bufnr, {})
  vim.bo[bufnr].buflisted = true
  return bufnr
end

local function add_directory(name)
  vim.fn.mkdir(name, "p")
  assert.is_equal(vim.fn.isdirectory(name), 1)
  return add_buffer(name)
end

local function components_by_path()
  local by_path = {}
  for _, component in ipairs(require("bufferline.buffers").get_components({})) do
    by_path[component.path] = by_path[component.path] or {}
    table.insert(by_path[component.path], component)
  end
  return by_path
end

local function render_text()
  local rendered = nvim_bufferline()
  return rendered:gsub("%%%d+@v:lua%.___bufferline_private%.[%a_]+@", ""):gsub("%%#[^#]+#", ""):gsub("%%.", "")
end

describe("Fork naming options", function()
  vim.o.columns = 120
  vim.o.hidden = true
  vim.o.showtabline = 2
  vim.o.swapfile = false

  before_each(function()
    install_devicons(icon_map)
    reset_plugin_modules()
    vim.cmd("silent %bwipeout!")
  end)

  after_each(function() vim.cmd("silent %bwipeout!") end)

  it("strips known singleton extensions and keeps exempt names", function()
    setup()

    local app = path("app.py")
    local dotfile = path(".gitignore")
    local multi_dot = path("component.test.tsx")
    local extensionless = path("Makefile")
    local unknown = path("mystery.unknown")
    local trailing_dot = path("trailing.")
    local directory = path("project")
    local terminal = path("terminal.lua")

    add_buffer(app)
    add_buffer(dotfile)
    add_buffer(multi_dot)
    add_buffer(extensionless)
    add_buffer(unknown)
    add_buffer(trailing_dot)
    add_directory(directory)
    local terminal_buf = add_terminal(terminal)

    assert.is_equal(vim.bo[terminal_buf].buftype, "terminal")

    local by_path = components_by_path()
    assert.is_equal(by_path[app][1].name, "app")
    assert.is_equal(by_path[dotfile][1].name, ".gitignore")
    assert.is_equal(by_path[multi_dot][1].name, "component.test.tsx")
    assert.is_equal(by_path[extensionless][1].name, "Makefile")
    assert.is_equal(by_path[unknown][1].name, "mystery.unknown")
    assert.is_equal(by_path[trailing_dot][1].name, "trailing.")
    assert.is_equal(by_path[directory][1].name, "project/")
    assert.is_equal(by_path[terminal][1].name, "terminal.lua")
    assert.is_truthy(by_path[""])
    assert.is_equal(by_path[""][1].name, "[No Name]")
  end)

  it("keeps known extensions that collide with non-file labels", function()
    setup()

    local unnamed_file = path("[No Name].lua")
    local terminal = path("shell")
    local terminal_file = path("shell.lua")

    add_buffer(unnamed_file)
    add_terminal(terminal)
    add_buffer(terminal_file)

    local by_path = components_by_path()
    assert.is_equal(by_path[""][1].name, "[No Name]")
    assert.is_equal(by_path[unnamed_file][1].name, "[No Name].lua")
    assert.is_equal(by_path[terminal][1].name, "shell")
    assert.is_equal(by_path[terminal_file][1].name, "shell.lua")
  end)

  it("keeps different extensions distinct and renders them without prefixes", function()
    setup()

    local typescript = path("client/user.ts")
    local go = path("server/user.go")
    add_buffer(typescript)
    add_buffer(go)

    local by_path = components_by_path()
    assert.is_equal(by_path[typescript][1].name, "user.ts")
    assert.is_equal(by_path[go][1].name, "user.go")
    assert.is_falsy(by_path[typescript][1].duplicated)
    assert.is_falsy(by_path[go][1].duplicated)

    local rendered = render_text()
    assert.is_truthy(rendered:find("user.ts", 1, true))
    assert.is_truthy(rendered:find("user.go", 1, true))
    assert.is_falsy(rendered:find("/user", 1, true))
    assert.is_falsy(rendered:find("client/", 1, true))
    assert.is_falsy(rendered:find("server/", 1, true))
  end)

  it("uses raw names for duplicate identity after formatting", function()
    local function strip_extension(info) return info.name:gsub("%.[^.]+$", "") end

    setup({ name_formatter = strip_extension })

    local typescript = path("client/user.ts")
    local go = path("server/user.go")
    add_buffer(typescript)
    add_buffer(go)

    local by_path = components_by_path()
    assert.is_equal(by_path[typescript][1].name, "user")
    assert.is_equal(by_path[go][1].name, "user")
    assert.is_equal(by_path[typescript][1].raw_name, "user.ts")
    assert.is_equal(by_path[go][1].raw_name, "user.go")
    assert.is_falsy(by_path[typescript][1].duplicated)
    assert.is_falsy(by_path[go][1].duplicated)

    local rendered = render_text()
    assert.is_falsy(rendered:find("/user", 1, true))
    assert.is_falsy(rendered:find("client/", 1, true))
    assert.is_falsy(rendered:find("server/", 1, true))
  end)

  it("prefixes true same-tail duplicates from different directories", function()
    setup()

    local left = path("left/user.ts")
    local right = path("right/user.ts")
    add_buffer(left)
    add_buffer(right)

    local by_path = components_by_path()
    for _, duplicate_path in ipairs({ left, right }) do
      local component = by_path[duplicate_path][1]
      assert.is_equal(component.name, "user")
      assert.is_equal(component.raw_name, "user.ts")
      assert.is_equal(component.duplicated, "path")
      assert.is_equal(component.prefix_count, 2)
    end

    local rendered = render_text()
    assert.is_truthy(rendered:find("left/user", 1, true))
    assert.is_truthy(rendered:find("right/user", 1, true))
  end)

  it("renders original labels when extension hiding is disabled", function()
    local app = path("app.py")
    local config_file = path("config.lua")
    add_buffer(app)
    add_buffer(config_file)

    local explicit_off = vim.deepcopy(base_options)
    explicit_off.hide_extension_when_icon_known = false
    bufferline.setup({ options = explicit_off })
    local explicit_render = render_text()

    local omitted = vim.deepcopy(base_options)
    omitted.hide_extension_when_icon_known = nil
    bufferline.setup({ options = omitted })
    local default_render = render_text()

    assert.is_equal(explicit_render, default_render)
    assert.is_truthy(explicit_render:find("app.py", 1, true))
    assert.is_truthy(explicit_render:find("config.lua", 1, true))
  end)
end)

vim.fn.delete(temp_root, "rf")
package.loaded["nvim-web-devicons"] = original_devicons
package.preload["nvim-web-devicons"] = original_devicons_preload
