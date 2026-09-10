local utils = require("tests.utils")

describe("Bufferline tests:", function()
  vim.opt.swapfile = false
  vim.opt.hidden = true
  vim.opt.termguicolors = true

  local bufferline
  local state ---@module "bufferline.state"
  local icons ---@module "nvim-web-devicons"
  local config ---@module "bufferline.config"

  before_each(function()
    package.loaded["bufferline"] = nil
    package.loaded["bufferline.state"] = nil
    package.loaded["nvim-web-devicons"] = nil
    -- dependent modules need to also be reset as
    -- they keep track of state themselves now
    package.loaded["bufferline.config"] = nil
    package.loaded["bufferline.commands"] = nil
    bufferline = require("bufferline")
    state = require("bufferline.state")
    config = require("bufferline.config")
    icons = require("nvim-web-devicons")
    icons.setup({ default = true })
  end)

  after_each(function() vim.cmd("silent %bwipeout!") end)

  describe("render buffer - ", function()
    it("should create corresponding buffers in state", function()
      bufferline.setup()
      vim.cmd("edit test-1.txt")
      vim.cmd("edit test-2.txt")
      local tabline = nvim_bufferline()
      assert.truthy(tabline)
      assert.is.equal(#state.components, 2)
    end)

    it("should allow configuring the indicator icon", function()
      local icon = "R"
      bufferline.setup({
        options = {
          indicator = { icon = { icon } },
        },
      })
      vim.cmd("edit test.txt")
      local tabline = nvim_bufferline()
      assert.truthy(tabline)
      assert.is_truthy(tabline:match(icon))
    end)

    it("should allow specifying how icons are fetched", function()
      local icon = "Q"
      bufferline.setup({
        options = {
          get_element_icon = function() return icon end,
        },
      })
      vim.cmd("edit test.txt")
      local tabline = nvim_bufferline()
      assert.truthy(tabline)
      assert.is_truthy(tabline:match(icon))
    end)

    it("should allow formatting names", function()
      bufferline.setup({
        options = {
          name_formatter = function(buf)
            if buf.path:match("test.txt") then return "TEST" end
          end,
        },
      })
      vim.cmd("edit test.txt")
      local tabline = nvim_bufferline()
      assert.truthy(tabline)
      assert.truthy(tabline:match("TEST"))
    end)
  end)

  describe("Snapshots - ", function()
    local snapshots = {
      "       a.txt       ▕       b.txt       ▕▎      c.txt       ",
      "        a.txt       ▕        b.txt       ▕▎       c.txt       ",
      "       a.txt              b.txt              c.txt       ",
    }
    it("should add correct padding if close icons are present", function()
      bufferline.setup({ options = { get_element_icon = function() return "" end } })
      vim.cmd("file! a.txt")
      vim.cmd("edit b.txt")
      vim.cmd("edit c.txt")
      local tabline, components = nvim_bufferline()
      assert.is_truthy(tabline)
      local snapshot = utils.tabline_from_components(components)
      assert.is_equal(snapshot, snapshots[1])
    end)

    it("should add correct padding if close icons are absent", function()
      bufferline.setup({
        options = {
          get_element_icon = function() return "" end,
          show_buffer_close_icons = false,
        },
      })
      vim.cmd("file! a.txt")
      vim.cmd("edit b.txt")
      vim.cmd("edit c.txt")
      local tabline, components = nvim_bufferline()
      assert.is_truthy(tabline)
      local snapshot = utils.tabline_from_components(components)
      assert.is_equal(snapshot, snapshots[2])
    end)
    it("should show the correct separators", function()
      bufferline.setup({
        options = {
          get_element_icon = function() return "" end,
          separator_style = "slant",
        },
      })
      vim.cmd("file! a.txt")
      vim.cmd("edit b.txt")
      vim.cmd("edit c.txt")
      local tabline, components = nvim_bufferline()
      assert.is_truthy(tabline)
      local snapshot = utils.tabline_from_components(components)
      assert.is_equal(snapshot, snapshots[3])
    end)

    it("should show a default icon if specified", function()
      bufferline.setup({})
      vim.cmd("edit test.rrj")
      local _, components = nvim_bufferline()
      local snapshot = utils.tabline_from_components(components)
      local icon = icons.get_icon("")
      assert.is_true(snapshot:match(icon) ~= nil)
    end)
  end)

  describe("compact padding - ", function()
    local base_options = {
      buffer_close_icon = "x",
      close_icon = "X",
      modified_icon = "M",
      get_element_icon = function() return "F" end,
      show_close_icon = false,
      show_buffer_close_icons = false,
      tab_size = 0,
      truncate_names = false,
      separator_style = "thin",
      sort_by = "id",
    }

    local function configure(overrides)
      bufferline.setup({ options = vim.tbl_extend("force", vim.deepcopy(base_options), overrides or {}) })
    end

    local function open_tabs()
      vim.cmd("file! a.txt")
      vim.cmd("edit b.txt")
      vim.cmd("edit c.txt")
    end

    local function snapshot()
      local tabline, components = nvim_bufferline()
      assert.is_truthy(tabline)
      return utils.tabline_from_components(components), components
    end

    local function component_width(component)
      local width = 0
      for _, segment in ipairs(component) do
        width = width + vim.api.nvim_strwidth(segment.text or "")
      end
      return width
    end

    it("should use strict one-space margins for auto-sized tabs when compact", function()
      configure({ padding_style = "compact" })
      open_tabs()
      local rendered, components = snapshot()
      assert.is_equal(#components, 3)
      assert.is_equal(rendered, " F a.txt ▕ F b.txt ▕▎F c.txt ")
    end)

    it("should keep placeholder margins for auto-sized tabs when padded", function()
      configure({ padding_style = "padded" })
      open_tabs()
      local rendered = snapshot()
      assert.is_equal(rendered, "  F a.txt   ▕  F b.txt   ▕▎ F c.txt   ")
    end)

    it("should widen a modified compact tab by exactly two display cells", function()
      configure({ padding_style = "compact" })
      vim.cmd("file! a.txt")
      local _, unmodified = snapshot()
      local unmodified_width = component_width(unmodified[1])

      vim.bo[vim.api.nvim_get_current_buf()].modified = true
      local _, modified = snapshot()
      local modified_width = component_width(modified[1])

      assert.is_equal(modified_width - unmodified_width, 2)
      assert.is_equal(utils.tabline_from_components(modified), "▎F a.txt M ")
    end)

    it("should match padded output when tab_size is greater than zero", function()
      open_tabs()
      configure({ padding_style = "compact", tab_size = 18 })
      local compact = snapshot()
      configure({ padding_style = "padded", tab_size = 18 })
      local padded = snapshot()
      assert.is_equal(compact, padded)
      assert.is_equal(compact, "       F a.txt       ▕       F b.txt       ▕▎      F c.txt       ")
    end)

    it("should match padded output when buffer close icons are visible", function()
      open_tabs()
      configure({ padding_style = "compact", show_buffer_close_icons = true })
      local compact = snapshot()
      configure({ padding_style = "padded", show_buffer_close_icons = true })
      local padded = snapshot()
      assert.is_equal(compact, padded)
      assert.is_equal(compact, " F a.txt x ▕ F b.txt x ▕▎F c.txt x ")
    end)

    it("should behave like padded when padding_style is omitted", function()
      open_tabs()
      configure()
      local omitted = snapshot()
      configure({ padding_style = "padded" })
      local padded = snapshot()
      assert.is_equal(omitted, padded)
      assert.is_equal(omitted, "  F a.txt   ▕  F b.txt   ▕▎ F c.txt   ")
    end)

    it("should behave like padded for an unknown padding_style", function()
      open_tabs()
      configure({ padding_style = "unknown" })
      local unknown = snapshot()
      configure({ padding_style = "padded" })
      local padded = snapshot()
      assert.is_equal(unknown, padded)
    end)
  end)

  describe("clicking - ", function()
    it("should left handle mouse clicks correctly", function()
      local bufnum = vim.api.nvim_get_current_buf()
      bufferline.setup({
        options = {
          left_mouse_command = "vertical sbuffer %d",
        },
      })
      ___bufferline_private.handle_click(bufnum, nil, "l")
      vim.wait(10)
      assert.is_equal(#vim.api.nvim_list_wins(), 2)
    end)

    it("should middle handle mouse clicks correctly", function()
      local bufnum = vim.api.nvim_get_current_buf()
      bufferline.setup({
        options = {
          middle_mouse_command = function(bufid) vim.bo[bufid].filetype = "test" end,
        },
      })
      ___bufferline_private.handle_click(bufnum, nil, "m")
      assert.is_equal(vim.bo[bufnum].filetype, "test")
    end)

    it("should right handle mouse clicks correctly", function()
      local bufnum = vim.api.nvim_get_current_buf()
      bufferline.setup({
        options = {
          right_mouse_command = "setfiletype egg",
        },
      })
      ___bufferline_private.handle_click(bufnum, nil, "r")
      vim.wait(10)
      assert.is_equal(vim.bo.filetype, "egg")
    end)

    it("should handle close click correctly", function()
      local bufnum = vim.api.nvim_get_current_buf()
      local count = 1
      local expected = bufnum + count
      bufferline.setup({
        options = {
          close_command = function(bufid) count = count + bufid end,
        },
      })
      ___bufferline_private.handle_close(bufnum)
      assert.is_equal(count, expected)
    end)
  end)

  -- FIXME: nvim_bufferline() needs to be manually called
  describe("commands - ", function()
    it("should close buffers to the right of the current buffer", function()
      bufferline.setup({
        options = {
          close_command = function(bufid) vim.api.nvim_buf_delete(bufid, { force = true }) end,
        },
      })
      vim.cmd("file! a.txt")
      vim.cmd("edit b.txt")
      vim.cmd("edit c.txt")
      vim.cmd("edit d.txt")
      vim.cmd("edit e.txt")
      nvim_bufferline()

      vim.cmd("edit c.txt")
      bufferline.close_in_direction("right")
      local bufs = vim.api.nvim_list_bufs()
      assert.is_equal(3, #bufs)
    end)

    it("should close buffers to the left of the current buffer", function()
      bufferline.setup({
        options = {
          close_command = function(bufid) vim.api.nvim_buf_delete(bufid, { force = true }) end,
        },
      })
      vim.cmd("edit! a.txt")
      vim.cmd("edit b.txt")
      vim.cmd("edit c.txt")
      vim.cmd("edit d.txt")
      vim.cmd("edit e.txt")
      nvim_bufferline()

      assert.is.equal(5, #state.components)

      local bufs = vim.api.nvim_list_bufs()
      assert.is_equal(5, #bufs)
      bufferline.close_in_direction("left")
      bufs = vim.api.nvim_list_bufs()
      assert.is_equal(1, #bufs)
    end)
  end)

  describe("Theme - ", function()
    it("should update the colors if the colorscheme changes", function()
      vim.cmd("colorscheme blue")

      local colors = require("bufferline.colors")
      local blue_bg = colors.get_color({ name = "Normal", attribute = "bg" })
      local blue_fg = colors.get_color({ name = "Normal", attribute = "fg" })

      bufferline.setup()

      assert.equal(config.highlights.buffer_selected.bg, blue_bg)
      assert.equal(config.highlights.buffer_selected.fg, blue_fg)

      vim.cmd("colorscheme desert")
      local desert_bg = colors.get_color({ name = "Normal", attribute = "bg" })
      local desert_fg = colors.get_color({ name = "Normal", attribute = "fg" })

      assert.equal(config.highlights.buffer_selected.bg, desert_bg)
      assert.equal(config.highlights.buffer_selected.fg, desert_fg)

      assert.not_equal(blue_bg, desert_bg)
    end)
  end)
end)
