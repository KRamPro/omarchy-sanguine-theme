-- Sanguine's Neovim layer derives the shared palette from the staged theme,
-- then changes only editor-specific presentation. Keep desktop/terminal colors
-- in colors.toml; add editor-only adjustments here.
local function colors_from_theme()
  local source = debug.getinfo(1, "S").source:sub(2)
  local colors_path = vim.fn.fnamemodify(source, ":h") .. "/colors.toml"
  local aliases = {
    background = "bg",
    dark_background = "dark_bg",
    darker_background = "darker_bg",
    lighter_background = "lighter_bg",
    foreground = "fg",
    dark_foreground = "dark_fg",
    light_foreground = "light_fg",
    bright_foreground = "bright_fg",
  }
  local colors = {}

  for _, line in ipairs(vim.fn.readfile(colors_path)) do
    local key, value = line:match('^%s*([%w_]+)%s*=%s*"(#[0-9a-fA-F]+)"')
    if key then
      colors[aliases[key] or key] = value
    end
  end

  colors.cursor = colors.bright_fg
  colors.foreground = colors.fg
  colors.background = colors.bg
  colors.selection_foreground = colors.bright_fg
  colors.selection_background = colors.selection
  return colors
end

return {
  {
    "bjarneo/aether.nvim",
    branch = "v3",
    name = "aether",
    priority = 1000,
    opts = {
      colors = vim.tbl_extend("force", colors_from_theme(), {
        -- Comments need a clearer text-value separation than the desktop's
        -- muted UI chrome, without adding a cool hue.
        muted = "#8a857c",
        -- A quieter editor-only selection than the desktop selection surface.
        selection = "#3a2b2b",
        selection_background = "#3a2b2b",
      }),
    },
  },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "aether",
    },
  },
}
