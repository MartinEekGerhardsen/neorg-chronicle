local neorg = require("neorg.core")
local config, lib, log, modules = neorg.config, neorg.lib, neorg.log, neorg.modules

local module = neorg.modules.create("external.chronicle")


module.load = function ()
    print(module.private.get_example_path(module.config.public.daily.template_path))
    print(module.private.get_example_path(module.config.public.weekly.template_path))
    print(module.private.get_example_path(module.config.public.monthly.template_path))
    print(module.private.get_example_path(module.config.public.quarterly.template_path))
    print(module.private.get_example_path(module.config.public.yearly.template_path))

    -- module.private.open(os.time(), "daily")
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
    get_first_day_of_year = function (time)
        print(time)
        local beginning_year = os.time{
            year = os.date("*t", time).year,
            month = 1,
            day = 1,
        }
        print(beginning_year)

        local first_day = tonumber(
            os.date("%w", beginning_year)
        )
        print(first_day)

        -- correct sunday from 0 to 7
        if (first_day == 0) then
            first_day = 7
        end
        print(first_day)

        return first_day
    end,

    get_day_add = function (time)
        local d = module.private.get_first_day_of_year(time)

        print(d)

        if d < 5 then
            return d - 2
        else
            return d - 9
        end
    end,

    get_week_number = function (time)
        local day_of_year = os.date("%j", time)
        local day_add = module.private.get_day_add(time)
        local corrected_day_of_year = day_of_year + day_add

        if corrected_day_of_year < 0 then
            -- week of last year - decide if 52 or 53
            local last_year_begin = os.time{
                year = os.date("*t", time).year - 1,
                month = 1,
                day = 1,
            }
            local last_year_end = os.time{
                year = os.date("*t", time).year - 1,
                month = 12,
                day = 31,
            }
            day_add = module.private.get_day_add(last_year_begin)
            day_of_year = day_of_year + os.date("%j", last_year_end)
            corrected_day_of_year = day_of_year + day_add
          end

        local week_num = math.floor(corrected_day_of_year / 7) + 1

        if( (corrected_day_of_year > 0) and week_num == 53) then
            -- check if it is not considered as part of week 1 of next year
            local next_year_begin = os.time{
                year = os.date("*t", time).year + 1,
                month = 1,
                day = 1,
            }
            local beginning_day_of_year = module.private.get_first_day_of_year(
                next_year_begin
            )
            if beginning_day_of_year < 5  then
                week_num = 1
            end
        end

        return week_num
    end,

    get_template_path = function (template)
        return table.concat(template, config.pathsep)
    end,

    get_path = function (time, path)
        local date = os.date("*t", time)

        local week = module.private.get_week_number(time)
        local week_str = tostring(week)
        if week < 10 then
            week_str = "0" + week_str
        end
        print(path)
        path = string.gsub(path, "%%W", week_str)
        print(path)

        -- add 1 to round up and add 1 to go from 0-index to 1
        local quarter = math.floor(date.month / 4) + 1 + 1
        path = string.gsub(path, "%%Q", "0" + tostring(quarter))
        print(path)

        return os.date(path, time)
    end,

    get_example_path = function (template)
        print(template)
        local template_path = module.private.get_template_path(template)

        print(template_path)
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
        local workspace = module.config.public.workspace or module.required["core.dirman"].get_current_workspace()[1]
        local directory = module.config.public.directory

        local template = module.config.private.templates[mode]

        local path_format = module.private.get_template_path(
            template.path
        )
        local path = module.private.get_path(
            time,
            path_format
        )

        local workspace_path = module.required["core.dirman"].get_workspace(workspace)
        local file_path = workspace_path .. config.pathsep .. directory .. config.pathsep .. path

        local file_exists = module.required["core.dirman"].file_exists(file_path)

        print(file_path)
    end,
}

module.public = {
    version = "0.0.1",
}

module.config.public = {
    directory = "chronicle",
    workspace = nil,
    daily = {
        use_template = true,
        template_name = "",
        template_path = {
            "%Y",
            "%m-%B",
            "%d-%A",
            "daily.norg",
        },

    },
    weekly = {
        use_template = true,
        template_name = "",
        template_path = {
            "%Y",
            "%m-%B",
            "%W",
            "weekly.norg",
        },

    },
    monthly = {
        use_template = true,
        template_name = "",
        template_path = {
            "%Y",
            "%m-%B",
            "monthly.norg",
        },

    },
    quarterly = {
        use_template = true,
        template_name = "",
        template_path = {
            "%Y",
            "%Q",
            "quaterly.norg",
        },

    },
    yearly = {
        use_template = true,
        template_name = "",
        template_path = {
            "%Y",
            "yearly.norg",
        },
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
        if event.split_type[2] == "chronicle.daily" then
            -- print(
            --     module.private.get_example_path(
            --         module.config.private.
            --     )
            -- )
        elseif event.split_type[2] == "chronicle.weekly" then
        elseif event.split_type[2] == "chronicle.monthly" then
        elseif event.split_type[2] == "chronicle.quarterly" then
        elseif event.split_type[2] == "chronicle.yearly" then
        end
    end
end

module.events.subscribed = {
    ["core.neorgcmd"] = {
        ["chronicle.daily"] = true,
    },
}

return module
