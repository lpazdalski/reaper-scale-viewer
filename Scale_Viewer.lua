-- @description Scale Viewer: guitar fretboard with the notes of a scale
-- @version 0.1.0
-- @about Dockable ReaImGui window. Requires ReaImGui 0.10+.

if not reaper.ImGui_GetBuiltinPath then
  reaper.MB('Scale Viewer requires ReaImGui. Install it via Extensions > ReaPack > Browse packages.',
    'Scale Viewer', 0)
  return
end

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua'
local ImGui = require 'imgui' '0.10'

local script_dir = debug.getinfo(1, 'S').source:match('^@?(.*[\\/])') or ''
local T = dofile(script_dir .. 'theory.lua')

local EXT_SECTION = 'ScaleViewer'

local COLORS = {
  window_bg   = 0x1A1A1AFF,
  board       = 0x3B2A20FF,
  open_column = 0x2A1E17FF,
  fret        = 0xA8A8A8FF,
  nut         = 0xE8E2D0FF,
  string      = 0xC9C9C9FF,
  inlay       = 0xFFFFFF38,
  fret_number = 0x9AA0A6FF,
  root        = 0xE5484DFF,
  scale_note  = 0x3B82F6FF,
  note_text   = 0xFFFFFFFF,
  note_border = 0x00000070,
}

local SPELLINGS = { 'auto', 'sharp', 'flat' }
local LABEL_MODES = { 'names', 'intervals', 'none' }
local MIN_FRETS, MAX_FRETS = 12, 24

local ROOT_ITEMS = 'C\0C#/Db\0D\0D#/Eb\0E\0F\0F#/Gb\0G\0G#/Ab\0A\0A#/Bb\0B\0'
local SPELLING_ITEMS = 'Auto\0#\0b\0'
local LABEL_ITEMS = 'Names\0Intervals\0None\0'

local function combo_items(list, field)
  local names = {}
  for i, item in ipairs(list) do names[i] = field and item[field] or item end
  return table.concat(names, '\0') .. '\0'
end

local SCALE_ITEMS = combo_items(T.SCALES, 'name')
local NOTE_ITEMS = {
  [false] = combo_items({ table.unpack(T.SHARP_NAMES, 0, 11) }),
  [true]  = combo_items({ table.unpack(T.FLAT_NAMES, 0, 11) }),
}

local function index_of(list, value)
  for i, v in ipairs(list) do if v == value then return i end end
end

-- state -------------------------------------------------------------------------

local state = {
  root     = 4, -- E
  scale    = 2, -- Minor
  spelling = 'auto',
  strings  = { table.unpack(T.TUNINGS[1].strings) },
  frets    = 24,
  labels   = 'names',
}

local function load_state()
  local function get(key) return reaper.GetExtState(EXT_SECTION, key) end
  local root = math.tointeger(tonumber(get('root')))
  if root and root >= 0 and root <= 11 then state.root = root end
  local scale = math.tointeger(tonumber(get('scale')))
  if scale and T.SCALES[scale] then state.scale = scale end
  if index_of(SPELLINGS, get('spelling')) then state.spelling = get('spelling') end
  state.strings = T.parse_tuning(get('tuning')) or state.strings
  local frets = math.tointeger(tonumber(get('frets')))
  if frets and frets >= MIN_FRETS and frets <= MAX_FRETS then state.frets = frets end
  if index_of(LABEL_MODES, get('labels')) then state.labels = get('labels') end
end

local function save_state()
  local function set(key, value) reaper.SetExtState(EXT_SECTION, key, tostring(value), true) end
  set('root', state.root)
  set('scale', state.scale)
  set('spelling', state.spelling)
  set('tuning', T.serialize_tuning(state.strings))
  set('frets', state.frets)
  set('labels', state.labels)
end

-- control bar -------------------------------------------------------------------

local ctx = ImGui.CreateContext('Scale Viewer')
local GAP = 16

-- Wraps control groups onto the next line when the window is too narrow.
local flow_x
local function flow(width, avail_w)
  if flow_x and flow_x + GAP + width <= avail_w then
    ImGui.SameLine(ctx, 0, GAP)
    flow_x = flow_x + GAP + width
  else
    flow_x = width
  end
end

local function labeled(label, item_w, avail_w, widget)
  local text_w = ImGui.CalcTextSize(ctx, label)
  local inner = 6
  flow(text_w + inner + item_w, avail_w)
  ImGui.BeginGroup(ctx)
  ImGui.AlignTextToFramePadding(ctx)
  ImGui.Text(ctx, label)
  ImGui.SameLine(ctx, 0, inner)
  ImGui.SetNextItemWidth(ctx, item_w)
  local changed = widget()
  ImGui.EndGroup(ctx)
  return changed
end

local function draw_controls()
  local avail_w = ImGui.GetContentRegionAvail(ctx)
  local changed, any = false, false
  flow_x = nil

  changed = labeled('Root', 80, avail_w, function()
    local c, v = ImGui.Combo(ctx, '##root', state.root, ROOT_ITEMS)
    state.root = v
    return c
  end)
  any = any or changed

  changed = labeled('Spelling', 60, avail_w, function()
    local c, v = ImGui.Combo(ctx, '##spelling', index_of(SPELLINGS, state.spelling) - 1, SPELLING_ITEMS)
    state.spelling = SPELLINGS[v + 1]
    return c
  end)
  any = any or changed

  changed = labeled('Scale', 100, avail_w, function()
    local c, v = ImGui.Combo(ctx, '##scale', state.scale - 1, SCALE_ITEMS)
    state.scale = v + 1
    return c
  end)
  any = any or changed

  changed = labeled('Tuning', 100, avail_w, function()
    local current = T.find_tuning(state.strings)
    local c = false
    if ImGui.BeginCombo(ctx, '##tuning', current and T.TUNINGS[current].name or 'Custom') then
      for i, tuning in ipairs(T.TUNINGS) do
        if ImGui.Selectable(ctx, tuning.name, i == current) then
          state.strings = { table.unpack(tuning.strings) }
          c = true
        end
      end
      ImGui.EndCombo(ctx)
    end
    return c
  end)
  any = any or changed

  changed = labeled('Frets', 120, avail_w, function()
    local c, v = ImGui.SliderInt(ctx, '##frets', state.frets, MIN_FRETS, MAX_FRETS)
    state.frets = v
    return c
  end)
  any = any or changed

  changed = labeled('Labels', 100, avail_w, function()
    local c, v = ImGui.Combo(ctx, '##labels', index_of(LABEL_MODES, state.labels) - 1, LABEL_ITEMS)
    state.labels = LABEL_MODES[v + 1]
    return c
  end)
  any = any or changed

  return any
end

-- fretboard ---------------------------------------------------------------------

local TUNE_W = 64          -- per-string tuning combo
local MIN_BOARD_W = 480

-- Screen geometry of the fretboard; everything else draws from this.
local function layout(x, y, w, h, frame_h, font_size)
  local g = {}
  g.number_h = font_size + 6
  g.left = x + TUNE_W + 8
  g.top = y + g.number_h
  g.right = x + w - 8
  g.bottom = y + h
  g.spacing = (g.bottom - g.top) / T.STRING_COUNT
  g.radius_cap = g.spacing * 0.4

  local board_w = g.right - g.left
  g.open_w = math.max(g.radius_cap * 2 + 8, board_w * 0.04)
  g.nut_x = g.left + g.open_w

  local positions = T.fret_positions(state.frets)
  g.fret_x = {}
  for f = 0, state.frets do
    g.fret_x[f] = g.nut_x + positions[f] * (g.right - g.nut_x)
  end
  g.frame_h = frame_h
  return g
end

-- String 1 is the lowest and is drawn at the bottom.
local function string_y(g, s)
  return g.bottom - (s - 0.5) * g.spacing
end

-- Horizontal centre of the cell where a note on `fret` is drawn.
local function note_x(g, fret)
  if fret == 0 then return g.left + g.open_w / 2 end
  return (g.fret_x[fret - 1] + g.fret_x[fret]) / 2
end

-- Note circles fill their fret cell, so they shrink toward the body like the frets.
local function note_radius(g, fret)
  if fret == 0 then return g.radius_cap end
  local cell_w = g.fret_x[fret] - g.fret_x[fret - 1]
  return math.max(7, math.min(g.radius_cap, cell_w * 0.45))
end

local function draw_text_centered(dl, size, cx, cy, color, text)
  local w = ImGui.CalcTextSize(ctx, text) * size / ImGui.GetFontSize(ctx)
  ImGui.DrawList_AddTextEx(dl, ImGui.GetFont(ctx), size, cx - w / 2, cy - size / 2, color, text)
end

local function draw_board(dl, g)
  local board_top = g.top
  ImGui.DrawList_AddRectFilled(dl, g.left, board_top, g.nut_x, g.bottom, COLORS.open_column)
  ImGui.DrawList_AddRectFilled(dl, g.nut_x, board_top, g.right, g.bottom, COLORS.board)

  local mid_y = (board_top + g.bottom) / 2
  local number_size = ImGui.GetFontSize(ctx)
  for f = 1, state.frets do
    local cx = note_x(g, f)
    local inlay_r = math.max(3, note_radius(g, f) * 0.4)
    local dots = T.inlay(f)
    if dots == 1 then
      ImGui.DrawList_AddCircleFilled(dl, cx, mid_y, inlay_r, COLORS.inlay)
    elseif dots == 2 then
      ImGui.DrawList_AddCircleFilled(dl, cx, mid_y - g.spacing, inlay_r, COLORS.inlay)
      ImGui.DrawList_AddCircleFilled(dl, cx, mid_y + g.spacing, inlay_r, COLORS.inlay)
    end
    draw_text_centered(dl, number_size, cx, g.top - g.number_h / 2, COLORS.fret_number, tostring(f))
    ImGui.DrawList_AddLine(dl, g.fret_x[f], board_top, g.fret_x[f], g.bottom, COLORS.fret, 2)
  end
  ImGui.DrawList_AddRectFilled(dl, g.nut_x - 3, board_top, g.nut_x + 3, g.bottom, COLORS.nut)

  for s = 1, T.STRING_COUNT do
    local sy = string_y(g, s)
    local thickness = 2.8 - (s - 1) * 0.35
    ImGui.DrawList_AddLine(dl, g.left, sy, g.right, sy, COLORS.string, thickness)
  end
end

local function draw_notes(dl, g)
  local scale = T.SCALES[state.scale]
  local flats = T.use_flats(state.root, scale, state.spelling)
  for s = 1, T.STRING_COUNT do
    local sy = string_y(g, s)
    for f = 0, state.frets do
      local pc = T.pitch_class(state.strings[s], f)
      local interval = T.interval_of(state.root, scale, pc)
      if interval then
        local cx = note_x(g, f)
        local radius = note_radius(g, f)
        local text_size = radius * 1.05
        local color = interval == 0 and COLORS.root or COLORS.scale_note
        ImGui.DrawList_AddCircleFilled(dl, cx, sy, radius, color)
        ImGui.DrawList_AddCircle(dl, cx, sy, radius, COLORS.note_border, 0, 1.5)
        local label
        if state.labels == 'names' then
          label = T.note_name(pc, flats)
        elseif state.labels == 'intervals' then
          label = T.interval_label(interval)
        end
        if label then draw_text_centered(dl, text_size, cx, sy, COLORS.note_text, label) end
      end
    end
  end
end

-- Returns true when a string's tuning changed.
local function draw_string_combos(g, x)
  local flats = T.use_flats(state.root, T.SCALES[state.scale], state.spelling)
  local changed = false
  for s = 1, T.STRING_COUNT do
    ImGui.SetCursorScreenPos(ctx, x, string_y(g, s) - g.frame_h / 2)
    ImGui.SetNextItemWidth(ctx, TUNE_W)
    local c, v = ImGui.Combo(ctx, '##string' .. s, state.strings[s], NOTE_ITEMS[flats])
    if c then
      state.strings[s] = v
      changed = true
    end
  end
  return changed
end

local function draw_fretboard()
  local x, y = ImGui.GetCursorScreenPos(ctx)
  local avail_w, avail_h = ImGui.GetContentRegionAvail(ctx)
  local frame_h = ImGui.GetFrameHeight(ctx)
  local font_size = ImGui.GetFontSize(ctx)
  local min_h = font_size + 6 + T.STRING_COUNT * (frame_h + 4)
  local w = math.max(avail_w, MIN_BOARD_W)
  local h = math.max(avail_h, min_h)

  local g = layout(x, y, w, h, frame_h, font_size)
  local dl = ImGui.GetWindowDrawList(ctx)
  draw_board(dl, g)
  draw_notes(dl, g)
  local changed = draw_string_combos(g, x)

  ImGui.SetCursorScreenPos(ctx, x, y)
  ImGui.Dummy(ctx, w, h)
  return changed
end

-- main loop ---------------------------------------------------------------------

local function loop()
  ImGui.SetNextWindowSize(ctx, 1000, 320, ImGui.Cond_FirstUseEver)
  ImGui.PushStyleColor(ctx, ImGui.Col_WindowBg, COLORS.window_bg)
  local visible, open = ImGui.Begin(ctx, 'Scale Viewer', true)
  ImGui.PopStyleColor(ctx)
  if visible then
    local changed = draw_controls()
    ImGui.Spacing(ctx)
    changed = draw_fretboard() or changed
    if changed then save_state() end
    ImGui.End(ctx)
  end
  if open then reaper.defer(loop) end
end

load_state()
reaper.defer(loop)
