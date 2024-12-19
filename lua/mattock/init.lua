local M = {}
local function validate_config(opts)
  if opts.pr_keymap and type(opts.pr_keymap) ~= "string" then
    error("pr_keymap must be a string")
  end
  if opts.git_host and type(opts.git_host) ~= "string" then
    error("git_host must be a string")
  end
  if opts.default_branch and type(opts.default_branch) ~= "string" then
    error("default_branch must be a string")
  end
end
local cache = {
  last_line = nil,
  last_file = nil,
  pr_url = nil,
}
-- Store configuration
M.config = {
  -- Default keymaps
  pr_keymap = "<leader>gp", -- open PR
  -- GitHub/GitLab domain (modify based on your git provider)
  git_host = "github.com",
  default_branch = "main",
}
function M.open(url)
  if vim.fn.has("nvim-0.10") == 0 then
    require("lazy.util").open(url, { system = true })
    return
  end
  vim.ui.open(url)
end
function M.open_pr()
  if not vim.fn.finddir(".git", ".;") then
    vim.notify("Not a git repository", vim.log.levels.ERROR)
    return
  end
  -- Get current line number and commit hash
  local current_line = vim.api.nvim_win_get_cursor(0)[1]
  local current_file = vim.fn.expand("%:p")

  -- Check cache
  if cache.last_line == current_line and cache.last_file == current_file and cache.pr_url then
    M.open(cache.pr_url)
    return
  end
  local cmd = string.format("git blame -L %d,%d %s", current_line, current_line, current_file)
  local handle = io.popen(cmd)
  if not handle then
    vim.notify("Failed to run git blame command", vim.log.levels.ERROR)
    return nil
  end
  local result = handle:read("*a")
  handle:close()

  local hash = result:match("^(%x+)")
  if not hash then
    vim.notify("Could not get commit hash", vim.log.levels.ERROR)
    return
  end

  -- Get and transform the repository remote URL
  handle = io.popen("git config --get remote.origin.url")
  if not handle then
    vim.notify("Failed to get remote origin url, check the git config", vim.log.levels.ERROR)
    return nil
  end
  local remote_url = handle:read("*a"):gsub("\n$", ""):gsub("%.git$", "")
  handle:close()

  if remote_url:match("^git@") then
    local domain, path = remote_url:match("^git@(.-):(.*)")
    remote_url = string.format("https://%s/%s", domain, path)
  end

  -- Try different approaches to find the PR number
  local pr_number

  -- 1. Check commit message
  local commit_msg_cmd = string.format('git show -s --format="%%B" %s', hash)
  handle = io.popen(commit_msg_cmd)
  if not handle then
    vim.notify("Failed to check commit message", vim.log.levels.ERROR)
    return nil
  end
  local commit_message = handle:read("*a")
  handle:close()

  pr_number = commit_message:match("%(#(%d+)%)")
    or commit_message:match("Merge pull request #(%d+)")
    or commit_message:match("#(%d+)")

  -- 2. Check merge commits if no PR found
  if not pr_number then
    local pr_cmd = string.format(
      'git log --merges --format="%%H %%s" %s..%s | grep -v "Merge branch" | head -n 1',
      hash,
      M.config.default_branch
    )
    handle = io.popen(pr_cmd)
    if not handle then
      vim.notify("Failed to run git log", vim.log.levels.ERROR)
      return nil
    end
    local merge_info = handle:read("*a")
    handle:close()

    if merge_info and merge_info ~= "" then
      pr_number = merge_info:match("#(%d+)")
    end
  end

  -- 3. Try ancestry path if still no PR found
  if not pr_number then
    local next_merge_cmd = string.format(
      'git log --merges --format="%%H %%s" --ancestry-path %s..%s | head -n 1',
      hash,
      M.config.default_branch
    )
    handle = io.popen(next_merge_cmd)
    if not handle then
      vim.notify("Failed to run git log", vim.log.levels.ERROR)
      return nil
    end
    local next_merge = handle:read("*a")
    handle:close()

    if next_merge and next_merge ~= "" then
      pr_number = next_merge:match("#(%d+)")
    end
  end

  if pr_number then
    local pr_url = string.format("%s/pull/%s", remote_url, pr_number)
    -- Update cache
    cache.last_line = current_line
    cache.last_file = current_file
    cache.pr_url = pr_url
    M.open(pr_url)
  else
    vim.notify("Could not find any PR reference for this commit", vim.log.levels.WARN)
  end
end
-- Setup function
function M.setup(opts)
  if opts then
    validate_config(opts)
  end
  -- Merge user config with defaults
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})

  -- Set up keymaps
  vim.keymap.set(
    "n",
    M.config.pr_keymap,
    M.open_pr,
    { desc = "Open PR for current line", noremap = true, silent = true }
  )
  -- Add command
  vim.api.nvim_create_user_command("MattockPR", M.open_pr, {
    desc = "Open PR for current line",
  })
end

return M
