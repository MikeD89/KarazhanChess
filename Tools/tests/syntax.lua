-- Karazhan Chess - compiles every addon Lua file to catch syntax errors offline
-- Run: node lua.js tests/syntax.lua file1.lua file2.lua ...
local failed = 0
for _, file in ipairs(arg) do
    local chunk, err = loadfile(file)
    if not chunk then
        failed = failed + 1
        print(err)
    end
end
print((#arg - failed) .. "/" .. #arg .. " files compile")
if failed > 0 then error("syntax errors") end
