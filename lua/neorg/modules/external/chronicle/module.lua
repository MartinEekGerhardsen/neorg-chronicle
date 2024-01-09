local neorg = require("neorg.core")
local config, lib, log, modules = neorg.config, neorg.lib, neorg.log, neorg.modules

local module = neorg.modules.create("external.chronicle")

module.load = function()
    local core_subcommands = module.config.private.core_modes.daily.subcommands

    local custom_subcommands

    module.required["core.neorgcmd"].add_commands_from_table({
        chronicle = {
            subcommands = {


                daily = {
                    max_args = 3,
                    name = "external.chronicle.daily",
                    complete = {
                        module.config.private.daily.completions,
                    },
                },
                weekly = {
                    max_args = 2,
                    name = "external.chronicle.weekly",
                    complete = {
                        module.config.private.weekly.completions,
                    },
                },
                monthly = {
                    max_args = 2,
                    name = "external.chronicle.monthly",
                    complete = {
                        module.config.private.monthly.completions,
                    },
                },
                quarterly = {
                    max_args = 2,
                    name = "external.chronicle.quarterly",
                    complete = {
                        module.config.private.quarterly.completions,
                    },
                },
                yearly = {
                    max_args = 1,
                    name = "external.chronicle.yearly",
                    complete = {
                        module.config.private.yearly.completions,
                    },
                },
                calendar = {
                    args = 0,
                    name = "external.chronicle.calendar",
                },
                show = {
                    args = 1,
                    name = "external.chronicle.show",
                    complete = {
                        {
                            "all",
                            "daily",
                            "weekly",
                            "monthly",
                            "quarterly",
                            "yearly",
                        },
                    },
                },
                table.unpack(module.config.public.modes)
            },
        },
    })
end

module.on_event = function(event)
    if vim.tbl_contains({ "core.keybinds", "core.neorgcmd" }, event.split_type[1]) then
        if event.split_type[2] == "external.chronicle.daily" then
            module.private.open_daily(event.content)
        elseif event.split_type[2] == "external.chronicle.weekly" then
            module.private.open_weekly(event.content)
        elseif event.split_type[2] == "external.chronicle.monthly" then
            module.private.open_monthly(event.content)
        elseif event.split_type[2] == "external.chronicle.quarterly" then
            module.private.open_quarterly(event.content)
        elseif event.split_type[2] == "external.chronicle.yearly" then
            module.private.open_yearly(event.content)
        elseif event.split_type[2] == "external.chronicle.calendar" then
            local calendar = modules.get_module("core.ui.calendar")

            if not calendar then
                log.error("[ERROR]: `core.ui.calendar` is not loaded! This module is required for this operation.")
                return
            end

            calendar.select_date({
                callback = vim.schedule_wrap(function(osdate)
                    module.private.open_daily({
                        string.format("%02d", osdate.day),
                        string.format("%02d", osdate.month),
                        string.format("%04d", osdate.year),
                    })
                end),
            })
        elseif event.split_type[2] == "external.chronicle.show" then
            module.private.show(event.content)
        end
    end
end

module.events.subscribed = {
    ["core.neorgcmd"] = {
        ["external.chronicle.daily"] = true,
        ["external.chronicle.weekly"] = true,
        ["external.chronicle.monthly"] = true,
        ["external.chronicle.quarterly"] = true,
        ["external.chronicle.yearly"] = true,
        ["external.chronicle.calendar"] = true,
        ["external.chronicle.show"] = true,
    },
}

module.setup = function()
    return {
        success = true,
        requires = {
            "core.dirman",
            "core.neorgcmd",
            "core.ui.calendar",
        },
    }
end

module.private = {
    wrapping_add_month = function(time, n_months)
        local date = os.date("*t", time)

        local year = date.year + math.floor((date.month + n_months - 1) / 12)
        local month = (date.month + n_months - 1) % 12 + 1

        return os.time({
            year = year,
            month = month,
            day = date.day,
            hour = date.hour,
            min = date.min,
            sec = date.sec,
            wday = date.wday,
            yday = date.yday,
            isdst = date.isdst,
        })
    end,

    time_format_functions = {
        get_first_day_of_year = function(time)
            local beginning_year = os.time({
                year = os.date("*t", time).year,
                month = 1,
                day = 1,
            })

            local first_day = tonumber(os.date("%w", beginning_year))

            -- correct sunday from 0 to 7
            if first_day == 0 then
                first_day = 7
            end

            return first_day
        end,

        get_day_add = function(time)
            local d = module.private.time_format_functions.get_first_day_of_year(time)

            if d < 5 then
                return d - 2
            else
                return d - 9
            end
        end,

        get_week_number = function(time)
            local day_of_year = os.date("%j", time)
            local day_add = module.private.time_format_functions.get_day_add(time)
            local corrected_day_of_year = day_of_year + day_add

            if corrected_day_of_year < 0 then
                -- week of last year - decide if 52 or 53
                local last_year_begin = os.time({
                    year = os.date("*t", time).year - 1,
                    month = 1,
                    day = 1,
                })
                local last_year_end = os.time({
                    year = os.date("*t", time).year - 1,
                    month = 12,
                    day = 31,
                })
                day_add = module.private.time_format_functions.get_day_add(last_year_begin)
                day_of_year = day_of_year + os.date("%j", last_year_end)
                corrected_day_of_year = day_of_year + day_add
            end

            local week_num = math.floor(corrected_day_of_year / 7) + 1

            if (corrected_day_of_year > 0) and week_num == 53 then
                -- check if it is not considered as part of week 1 of next year
                local next_year_begin = os.time({
                    year = os.date("*t", time).year + 1,
                    month = 1,
                    day = 1,
                })
                local beginning_day_of_year =
                    module.private.time_format_functions.get_first_day_of_year(next_year_begin)
                if beginning_day_of_year < 5 then
                    week_num = 1
                end
            end

            return week_num
        end,
    },

    get_template_path = function(template)
        return table.concat(template, config.pathsep)
    end,

    get_path = function(time, path)
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

    get_example_path = function(template)
        local template_path = module.private.get_template_path(template)

        local time = os.time({
            year = 1982,
            month = 11,
            day = 29,
            hour = 22,
            min = 58,
            sec = 31,
        })

        return module.private.get_path(time, template_path)
    end,

    open_daily = function(arguments)
        if arguments[1] == "today" then
            return module.public.open(os.time(), "daily")
        elseif arguments[1] == "yesterday" then
            return module.public.open(os.time() - 24 * 60 * 60, "daily")
        elseif arguments[1] == "tomorrow" then
            return module.public.open(os.time() + 24 * 60 * 60, "daily")
        elseif string.sub(arguments[1], 1, 1) == "+" then
            local n_days = tonumber(string.sub(arguments[1], 2))
            return module.public.open(os.time() + n_days * 24 * 60 * 60, "daily")
        elseif string.sub(arguments[1], 1, 1) == "-" then
            local n_days = tonumber(string.sub(arguments[1], 2))
            return module.public.open(os.time() - n_days * 24 * 60 * 60, "daily")
        else
            -- handling a date
            -- uses current time if any field is not set
            -- first argument will be interpreted as day,
            -- second as month,
            -- and thirds as year
            local day = tonumber(arguments[1])
            local month = tonumber(arguments[2])
            local year = tonumber(arguments[3])

            local current_time = os.time()
            local date = os.date("*t", current_time)

            local time = os.time({
                year = year or date.year,
                month = month or date.month,
                day = day or date.day,
            })

            return module.public.open(time, "daily")
        end
    end,

    open_weekly = function(arguments)
        if arguments[1] == "current" then
            return module.public.open(os.time(), "weekly")
        elseif arguments[1] == "previous" then
            return module.public.open(os.time() - 7 * 24 * 60 * 60, "weekly")
        elseif arguments[1] == "next" then
            return module.public.open(os.time() + 7 * 24 * 60 * 60, "weekly")
        elseif string.sub(arguments[1], 1, 1) == "+" then
            local n_weeks = tonumber(string.sub(arguments[1], 2))

            return module.public.open(os.time() + n_weeks * 7 * 24 * 60 * 60, "weekly")
        elseif string.sub(arguments[1], 1, 1) == "-" then
            local n_weeks = tonumber(string.sub(arguments[1], 2))

            return module.public.open(os.time() - n_weeks * 7 * 24 * 60 * 60, "weekly")
        else
            local week = tonumber(arguments[1])
            local year = tonumber(arguments[2])

            local current_time = os.time()
            local date = os.date("*t", current_time)

            if week then
                local selected_year = os.time({
                    year = year or date.year,
                    month = date.month,
                    day = date.day,
                })
                local first_day = module.private.time_format_functions.get_first_day_of_year(selected_year)

                return module.public.open(first_day + tostring(week) * 7 * 24 * 60 * 60, "weekly")
            else
                return module.public.open(current_time, "weekly")
            end
        end
    end,

    open_monthly = function(arguments)
        local current_time = os.time()
        local current_date = os.date("*t", current_time)
        if arguments[1] == "current" then
            return module.public.open(current_time, "monthly")
        elseif arguments[1] == "previous" then
            return module.public.open(module.private.wrapping_add_month(current_time, -1), "monthly")
        elseif arguments[1] == "next" then
            return module.public.open(module.private.wrapping_add_month(current_time, 1), "monthly")
        elseif string.sub(arguments[1], 1, 1) == "+" then
            local n_months = tonumber(string.sub(arguments[1], 2))

            return module.public.open(module.private.wrapping_add_month(current_time, n_months), "monthly")
        elseif string.sub(arguments[1], 1, 1) == "-" then
            local n_months = tonumber(string.sub(arguments[1], 2))
            return module.public.open(module.private.wrapping_add_month(current_time, n_months), "monthly")
        else
            local month = tonumber(arguments[1])
            local year = tonumber(arguments[2])

            return module.public.open(
                os.time({
                    year = year or current_date.year,
                    month = month or current_date.month,
                    day = 1,
                }),
                "monthly"
            )
        end
    end,

    open_quarterly = function(arguments)
        local current_time = os.time()
        local current_date = os.date("*t", current_time)

        if arguments[1] == "current" then
            return module.public.open(current_time, "quarterly")
        elseif arguments[1] == "previous" then
            return module.public.open(module.private.wrapping_add_month(current_time, -3), "quarterly")
        elseif arguments[1] == "next" then
            return module.public.open(module.private.wrapping_add_month(current_time, 3), "quarterly")
        elseif string.sub(arguments[1], 1, 1) == "+" then
            local n_quarters = string.sub(arguments[1], 2)

            return module.public.open(module.private.wrapping_add_month(current_time, 3 * n_quarters))
        elseif string.sub(arguments[1], 1, 1) == "-" then
            local n_quarters = string.sub(arguments[1], 2)

            return module.public.open(module.private.wrapping_add_month(current_time, -3 * n_quarters))
        else
            local quarter = tonumber(arguments[1])
            local year = tonumber(arguments[2])

            local month = current_date.month

            if quarter then
                month = 3 * quarter
            end

            return module.public.open(os.time({
                year = year or current_date.year,
                month = month,
                day = 1,
            }))
        end
    end,

    open_yearly = function(arguments)
        local current_time = os.time()
        local current_date = os.date("*t", current_time)

        if arguments[1] == "current" then
            return module.public.open(current_time, "yearly")
        elseif arguments[1] == "previous" then
            return module.public.open(
                os.time({
                    year = current_date.year - 1,
                    month = current_date.month,
                    day = current_date.day,
                }),
                "yearly"
            )
        elseif arguments[1] == "next" then
            return module.public.open(
                os.time({
                    year = current_date.year + 1,
                    month = current_date.month,
                    day = current_date.day,
                }),
                "yearly"
            )
        elseif string.sub(arguments[1], 1, 1) == "+" then
            local n_years = tonumber(string.sub(arguments[1], 2))

            return module.public.open(
                os.time({
                    year = current_date.year + n_years,
                    month = current_date.month,
                    day = current_date.day,
                }),
                "yearly"
            )
        elseif string.sub(arguments[1], 1, 1) == "-" then
            local n_years = tonumber(string.sub(arguments[1], 2))

            return module.public.open(
                os.time({
                    year = current_date.year - n_years,
                    month = current_date.month,
                    day = current_date.day,
                }),
                "yearly"
            )
        else
            local year = tonumber(arguments[1])

            return module.public.open(
                os.time({
                    year = year or current_date.year,
                    month = current_date.month,
                    day = current_date.day,
                }),
                "yearly"
            )
        end
    end,

    show = function(arguments)
        if arguments[1] then
            if arguments[1] == "all" then
                vim.print("daily: " .. module.private.get_example_path(module.config.public.daily.template_path))
                vim.print("weekly: " .. module.private.get_example_path(module.config.public.weekly.template_path))
                vim.print("monthly: " .. module.private.get_example_path(module.config.public.monthly.template_path))
                vim.print(
                    "quarterly: " .. module.private.get_example_path(module.config.public.quarterly.template_path)
                )
                vim.print("yearly: " .. module.private.get_example_path(module.config.public.yearly.template_path))
            elseif module.config.public[arguments[1]] then
                vim.print(module.private.get_example_path(module.config.public[arguments[1]].template_path))
            end
        end
    end,
}

module.public = {
    version = "0.1.1",

    open = function(time, mode)
        local workspace = (module.config.public.workspace or module.required["core.dirman"].get_current_workspace()[1])

        local directory = module.config.public.directory

        local template = module.config.public[mode].template_path

        local path_format = module.private.get_template_path(template)
        local path = module.private.get_path(time, path_format)

        local workspace_path = module.required["core.dirman"].get_workspace(workspace)
        local file_path = (workspace_path .. config.pathsep .. directory .. config.pathsep .. path)

        module.required["core.dirman"].create_file(directory .. config.pathsep .. path, workspace, {
            no_open = false,
            force = false,
            metadata = {},
        })

        -- local file_exists = module.required["core.dirman"].file_exists(file_path)
        --
        -- local template_path = (
        --     directory
        --     .. config.pathsep
        --     .. module.config.public.template_directory
        --     .. config.pathsep
        --     .. module.config.public[mode].template_name
        -- )
        --
        -- if
        --     not file_exists
        --     and module.config.public[mode].use_template
        --     and module.required["core.dirman"].file_exists(
        --         workspace_path .. config.pathsep .. template_path
        --     )
        -- then
        --     vim.cmd("0read " .. workspace_path .. config.pathsep .. template_path .. "| w")
        -- end
    end,
}

module.config.public = {
    workspace = "notes",
    directory = "chronicle",
    -- template_directory = "templates",

    modes = {
        daily = {
            path_format = {
                "%Y",
                "%m-%B",
                "%d-%A",
                "daily.norg",
            }
        }
    },

    daily = {
        -- use_template = false,
        -- template_name = "daily.norg",
        template_path = {
            "%Y",
            "%m-%B",
            "%d-%A",
            "daily.norg",
        },
    },
    weekly = {
        -- use_template = false,
        -- template_name = "",
        template_path = {
            "%Y",
            "%m-%B",
            "%W",
            "weekly.norg",
        },
    },
    monthly = {
        -- use_template = false,
        -- template_name = "",
        template_path = {
            "%Y",
            "%m-%B",
            "monthly.norg",
        },
    },
    quarterly = {
        -- use_template = false,
        -- template_name = "",
        template_path = {
            "%Y",
            "%Q",
            "quarterly.norg",
        },
    },
    yearly = {
        -- use_template = false,
        -- template_name = "",
        template_path = {
            "%Y",
            "yearly.norg",
        },
    },
}

module.config.private = {
    core_modes = {
        daily = {
            subcommands = {
                tomorrow = { args = 0, name = "chronicle.tomorrow" },
                yesterday = { args = 0, name = "chronicle.yesterday" },
                today = { args = 0, name = "chronicle.today" },
                custom = { max_args = 1, name = "chronicle.custom" },
                template = { args = 0, name = "chronicle.template" },
                toc = {
                    args = 1,
                    name = "chronicle.toc",
                    subcommands = {
                        open = { args = 0, name = "chronicle.toc.open" },
                        update = { args = 0, name = "chronicle.toc.update" },
                    },
                },
            },
        },
    },


    daily = {
        completions = {
            "today",
            "yesterday",
            "tomorrow",
            "+",
            "-",
            "day",
            "day month",
            "day month year",
        },
    },
    weekly = {
        completions = {
            "current",
            "previous",
            "next",
            "+",
            "-",
            "week",
            "week year",
        },
    },
    monthly = {
        completions = {
            "current",
            "previous",
            "next",
            "+",
            "-",
            "month",
            "month year",
        },
    },
    quarterly = {
        completions = {
            "current",
            "previous",
            "next",
            "+",
            "-",
            "quarter",
            "quarter year",
        },
    },
    yearly = {
        completions = {
            "current",
            "previous",
            "next",
            "+",
            "-",
            "year",
        },
    },
}

return module
