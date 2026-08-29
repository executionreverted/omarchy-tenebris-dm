local active_border_color = { colors = { "rgba(B8B2A7ff)", "rgba(7C0E13ff)" }, angle = 90 }
local inactive_border_color = "rgba(34322Faa)"

hl.config({
  general = {
    col = {
      active_border = active_border_color,
      inactive_border = inactive_border_color,
    },
  },
  group = {
    col = {
      border_active = active_border_color,
      border_inactive = inactive_border_color,
    },
  },
})
