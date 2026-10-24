-- Pure music theory and fretboard geometry. No reaper/ImGui calls here.
-- Pitch classes are integers 0..11 with C = 0.
local M = {}

M.STRING_COUNT = 6

M.SHARP_NAMES = { [0] = 'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B' }
M.FLAT_NAMES  = { [0] = 'C', 'Db', 'D', 'Eb', 'E', 'F', 'Gb', 'G', 'Ab', 'A', 'Bb', 'B' }

local INTERVAL_LABELS = { [0] = '1', 'b2', '2', 'b3', '3', '4', 'b5', '5', 'b6', '6', 'b7', '7' }

-- major_offset: semitones from the root to the tonic of the relative major,
-- used to choose sharps or flats.
M.SCALES = {
  { name = 'Major', intervals = { 0, 2, 4, 5, 7, 9, 11 }, major_offset = 0 },
  { name = 'Minor', intervals = { 0, 2, 3, 5, 7, 8, 10 }, major_offset = 3 },
}

-- Strings listed from the lowest to the highest.
M.TUNINGS = {
  { name = 'E std',  strings = { 4, 9, 2, 7, 11, 4 } },
  { name = 'Eb std', strings = { 3, 8, 1, 6, 10, 3 } },
  { name = 'D std',  strings = { 2, 7, 0, 5, 9, 2 } },
  { name = 'C std',  strings = { 0, 5, 10, 3, 7, 0 } },
  { name = 'Drop D', strings = { 2, 9, 2, 7, 11, 4 } },
  { name = 'Drop C', strings = { 0, 7, 0, 5, 9, 2 } },
  { name = 'Drop B', strings = { 11, 6, 11, 4, 8, 1 } },
}

-- Major keys written with flats: F, Bb, Eb, Ab, Db.
local FLAT_MAJOR_KEYS = { [5] = true, [10] = true, [3] = true, [8] = true, [1] = true }

local INLAYS = { [3] = 1, [5] = 1, [7] = 1, [9] = 1, [12] = 2,
                 [15] = 1, [17] = 1, [19] = 1, [21] = 1, [24] = 2 }

function M.pitch_class(open_pc, fret)
  return (open_pc + fret) % 12
end

function M.scale_pcs(root, scale)
  local pcs = {}
  for i, interval in ipairs(scale.intervals) do
    pcs[i] = (root + interval) % 12
  end
  return pcs
end

-- Semitones of `pc` above `root` if it belongs to the scale, otherwise nil.
function M.interval_of(root, scale, pc)
  local interval = (pc - root) % 12
  for _, i in ipairs(scale.intervals) do
    if i == interval then return interval end
  end
  return nil
end

function M.interval_label(semitones)
  return INTERVAL_LABELS[semitones % 12]
end

-- spelling: 'auto', 'sharp' or 'flat'
function M.use_flats(root, scale, spelling)
  if spelling == 'flat' then return true end
  if spelling == 'sharp' then return false end
  return FLAT_MAJOR_KEYS[(root + scale.major_offset) % 12] == true
end

function M.note_name(pc, flats)
  return (flats and M.FLAT_NAMES or M.SHARP_NAMES)[pc % 12]
end

function M.find_tuning(strings)
  for i, tuning in ipairs(M.TUNINGS) do
    local match = true
    for s = 1, M.STRING_COUNT do
      if tuning.strings[s] ~= strings[s] then match = false break end
    end
    if match then return i end
  end
  return nil
end

function M.serialize_tuning(strings)
  return table.concat(strings, ',')
end

function M.parse_tuning(str)
  if type(str) ~= 'string' then return nil end
  local strings = {}
  for part in str:gmatch('[^,]+') do
    local pc = tonumber(part)
    if not pc or pc ~= math.floor(pc) or pc < 0 or pc > 11 then return nil end
    strings[#strings + 1] = math.tointeger(pc)
  end
  if #strings ~= M.STRING_COUNT then return nil end
  return strings
end

-- Fret wire positions from the nut (0) to the last fret (1), spaced like a real
-- neck: the distance of fret f from the nut is proportional to 1 - 2^(-f/12).
function M.fret_positions(fret_count)
  local positions = { [0] = 0 }
  local total = 1 - 2 ^ (-fret_count / 12)
  for f = 1, fret_count do
    positions[f] = (1 - 2 ^ (-f / 12)) / total
  end
  return positions
end

-- Number of inlay dots on a fret (0, 1 or 2).
function M.inlay(fret)
  return INLAYS[fret] or 0
end

return M
