local neorg = require("neorg.core")
local config, lib, log, modules = neorg.config, neorg.lib, neorg.log, neorg.modules

local module = neorg.modules.create("external.chronicle")


module.load = function ()
    print("Hello world")

    -- modules.await("core.neorgcmd", function (neorgcmd)
    --     neorgcmd.add_commands_from_table({
    --         test = {
    --             min_args = 1,
    --             max_args = 2,
    --             subcommands = {
    --                 print_thing = { args = 0, name = ""}
    --             }
    --         }
    --     })
    -- end)
end

module.setup = function ()
    return {
        success = true,
        requires = {
            "core.dirman",
            "core.integrations.treesitter",
        },
    }
end

module.private = {
    get_template_path = function (template)
        return table.concat(template, config.pathsep)
    end,

    get_path = function (time, path)
        return os.date(path, time)
    end,

    get_example_path = function (template)
        local template_path = module.private.get_template_path(template)
        local time = os.time {
            year = 1982,
            month = 11,
            day = 29,
            hour = 22,
            min = 58,
            sec = 31,
        }

        return module.private.get_path(time, template_path)
    end,

    open = function (time, mode)
        local template = module.config.private.templates[mode]

        local path_format = module.private.get_template_path(
            template.path
        )
        local path = module.private.get_path(
            time,
            path_format
        )


    end,
}

module.config.public = {
    folder = "chronicle",
    daily = {
        use_template = true,
        template_name = "",
    },
    weekly = {
        use_template = true,
        template_name = "",
    },
    monthly = {
        use_template = true,
        template_name = "",
    },
    quarterly = {
        use_template = true,
        template_name = "",
    },
    yearly = {
        use_template = true,
        template_name = "",
    },
}

module.config.private = {
    templates = {
        daily = {
            path = {
                "%Y-%m-%d.norg",
            },
        },
        weekly = {
            path = "%Y-%m-%d.norg",
        },
        monthly = {
            path = "%Y-%m-%d.norg",
        },
        quarterly = {
            path = "%Y-%m-%d.norg",
        },
        yearly = {
            path = "%Y-%m-%d.norg",
        },
    }
}

module.on_event = function (event)
    if vim.tbl_contains( { "core.keybinds", "core.neorgcmd" }, event.split_type[1] ) then
        if event.split_type[2] == "chronicle.test" then
            print(module.private.get_example_path("%Y-%m-%d.norg"))
        end
    end
end

module.events.subscribed = {
    ["core.neorgcmd"] = {
        ["chronicle.test"] = true,
    },
}

return module
