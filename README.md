# ⛏️ mattock

A simple nvim plugin to open a PR associated with the current line

## 📥 Installation

With Lazy.nvim:

```lua
{
    "rangoons/mattock",
    event = "VeryLazy", -- Or `LspAttach`
    priority = 1000, -- needs to be loaded in first
    config = function()
        require('mattock').setup()
    end
}
```

## ⚙️ Options

```lua
{
  -- default configuration
  require("mattock").setup({
  -- Default keymap
  pr_keymap = "<leader>gp", -- open PR
  -- GitHub/GitLab domain (modify based on your git provider)
  git_host = "github.com",
  default_branch = "main",
  })
}
```
