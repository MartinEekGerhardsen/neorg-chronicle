local neorg = require("neorg.core")
local config, lib, log, modules = neorg.config, neorg.lib, neorg.log, neorg.modules

local module = neorg.modules.create("external.chronicle")


module.load = function ()
    -- print(module.private.get_example_path(module.config.public.daily.template_path))
    -- print(module.private.get_example_path(module.config.public.weekly.template_path))
    -- print(module.private.get_example_path(module.config.public.monthly.template_path))
    -- print(module.private.get_example_path(module.config.public.quarterly.template_path))
    -- print(module.private.get_example_path(module.config.public.yearly.template_path))

    module.required["core.neorgcmd"].add_commands_from_table({
        chronicle = {
            args = 1,
            -- min_args = 1,
            -- max_args = 4,
            subcommands = {
                daily = {
                    args = 1,
                    subcommands = {
                        today = {
                            args = 0,
                            name = "external.chronicle.daily.today"
                        },
                    },
                },
            },
        }
    })
end

module.setup = function ()
    return {
        success = true,
        requires = {
            "core.dirman",
            "core.neorgcmd",
            "core.ui.calendar",
            "core.integrations.treesitter",
        },
    }
end

module.private = {
    time_format_functions = {
        get_first_day_of_year = function (time)
            local beginning_year = os.time{
                year = os.date("*t", time).year,
                month = 1,
                day = 1,
            }

            local first_day = tonumber(
                os.date("%w", beginning_year)
            )

            -- correct sunday from 0 to 7
            if (first_day == 0) then
                first_day = 7
            end

            return first_day
        end,

        get_day_add = function (time)
            local d = module.private.time_format_functions.get_first_day_of_year(time)

            if d < 5 then
                return d - 2
            else
                return d - 9
            end
        end,

        get_week_number = function (time)
            local day_of_year = os.date("%j", time)
            local day_add = module.private.time_format_functions.get_day_add(time)
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
                day_add = module.private.time_format_functions.get_day_add(last_year_begin)
                day_of_year = day_of_year + os.date("%j", last_year_end)
                corrected_day_of_year = day_of_year + day_add
              end

            local week_num = math.floor(corrected_day_of_year / 7) + 1

            if (corrected_day_of_year > 0) and week_num == 53 then
                -- check if it is not considered as part of week 1 of next year
                local next_year_begin = os.time{
                    year = os.date("*t", time).year + 1,
                    month = 1,
                    day = 1,
                }
                local beginning_day_of_year = module.private.time_format_functions.get_first_day_of_year(
                    next_year_begin
                )
                if beginning_day_of_year < 5  then
                    week_num = 1
                end
            end

            return week_num
        end,
    },

    get_template_path = function (template)
        return table.concat(template, config.pathsep)
    end,

    get_path = function (time, path)
        local date = os.date("*t", time)

        local week = module.private.time_format_functions.get_week_number(time)
        local week_str = tostring(week)
        if week < 10 then
            week_str = "0" + week_str
        end

        path = string.gsub(path, "%%W", week_str)

        -- add 1 to round up and add 1 to go from 0-index to 1
        local quarter = math.floor(date.month / 4) + 2
        path = string.gsub(path, "%%Q", "0" + tostring(quarter))

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
        local workspace = (
            module.config.public.workspace
            or module.required["core.dirman"].get_current_workspace()[1]
        )

        local directory = module.config.public.directory

        local template = module.config.public[mode].template_path

        local path_format = module.private.get_template_path(
            template
        )
        local path = module.private.get_path(
            time,
            path_format
        )

        local workspace_path = module.required["core.dirman"].get_workspace(workspace)
        local file_path = workspace_path .. config.pathsep .. directory .. config.pathsep .. path

        local file_exists = module.required["core.dirman"].file_exists(file_path)

        module.required["core.dirman"].create_file(
            directory .. config.pathsep .. path,
            workspace,
            {
                no_open = true,
                force = false,
                metadata = {
                },
            }
        )

        local template_path = (
            directory .. config.pathsep
            .. module.config.public.template_directory .. config.pathsep
            .. module.config.public[mode].template_name
        )

        if
            not file_exists
            and module.config.public[mode].use_template
            and module.required["core.dirman"].file_exists(
                workspace_path .. config.pathsep .. template_path
            )
        then
            vim.cmd("0read " .. workspace_path .. config.pathsep .. template_path .. "| w")
        end
    end,
}

module.public = {
    version = "0.0.1",
}

module.config.public = {
    directory = "chronicle",
    template_directory = "templates",
    workspace = "notes",
    daily = {
        use_template = true,
        template_name = "daily.norg",
        template_path = {
            "%Y",
            "%m-%B",
            "%d-%A",
            "daily.norg",
        },

    },
    weekly = {
        use_template = false,
        template_name = "",
        template_path = {
            "%Y",
            "%m-%B",
            "%W",
            "weekly.norg",
        },

    },
    monthly = {
        use_template = false,
        template_name = "",
        template_path = {
            "%Y",
            "%m-%B",
            "monthly.norg",
        },

    },
    quarterly = {
        use_template = false,
        template_name = "",
        template_path = {
            "%Y",
            "%Q",
            "quaterly.norg",
        },

    },
    yearly = {
        use_template = false,
        template_name = "",
        template_path = {
            "%Y",
            "yearly.norg",
        },
    },
}

module.config.private = {
}

module.on_event = function (event)
    if vim.tbl_contains( { "core.keybinds", "core.neorgcmd" }, event.split_type[1] ) then
        if event.split_type[2] == "external.chronicle.daily.today" then
            module.private.open(os.time(), "daily")
        elseif event.split_type[2] == "chronicle.weekly" then
        elseif event.split_type[2] == "chronicle.monthly" then
        elseif event.split_type[2] == "chronicle.quarterly" then
        elseif event.split_type[2] == "chronicle.yearly" then
        end
    end
end

module.events.subscribed = {
    ["core.neorgcmd"] = {
        ["external.chronicle"] = true,
        ["external.chronicle.daily.today"] = true,
    },
}

return module
