local M = {}

function M.check()
  vim.health.start("Mattock")

  -- Check git installation
  if vim.fn.executable("git") == 1 then
    vim.health.ok("git executable found")
  else
    vim.health.error("git executable not found")
  end

  -- Check if in git repository
  if vim.fn.finddir(".git", ".;") then
    vim.health.ok("git repository detected")
  else
    vim.health.warn("not in a git repository")
  end
end

return M
