-- Run from the repo root: lua tests/theory_test.lua
local T = dofile('theory.lua')

local tests, failed = {}, 0
local function test(name, fn) tests[#tests + 1] = { name = name, fn = fn } end

local function eq(actual, expected, msg)
  if actual ~= expected then
    error(('%sexpected %s, got %s'):format(msg and (msg .. ': ') or '',
      tostring(expected), tostring(actual)), 2)
  end
end

local function list_eq(actual, expected)
  eq(#actual, #expected, 'length')
  for i = 1, #expected do eq(actual[i], expected[i], 'item ' .. i) end
end

local E, A, D, G, B, C, F = 4, 9, 2, 7, 11, 0, 5

-- pitch classes ---------------------------------------------------------------

test('pitch_class adds frets and wraps at the octave', function()
  eq(T.pitch_class(E, 0), E)
  eq(T.pitch_class(E, 5), A)
  eq(T.pitch_class(E, 12), E)
  eq(T.pitch_class(B, 1), C)
  eq(T.pitch_class(E, 24), E)
end)

-- scales ------------------------------------------------------------------------

test('scale list starts with Major and Minor', function()
  eq(T.SCALES[1].name, 'Major')
  eq(T.SCALES[2].name, 'Minor')
end)

test('scale_pcs of C major', function()
  list_eq(T.scale_pcs(C, T.SCALES[1]), { 0, 2, 4, 5, 7, 9, 11 })
end)

test('scale_pcs of E minor wraps around', function()
  list_eq(T.scale_pcs(E, T.SCALES[2]), { 4, 6, 7, 9, 11, 0, 2 })
end)

test('interval_of returns semitones above the root, or nil when out of scale', function()
  local minor = T.SCALES[2]
  eq(T.interval_of(A, minor, A), 0)
  eq(T.interval_of(A, minor, C), 3)
  eq(T.interval_of(A, minor, F), 8)
  eq(T.interval_of(A, minor, 1), nil) -- C# is not in A minor
end)

test('interval_label', function()
  eq(T.interval_label(0), '1')
  eq(T.interval_label(3), 'b3')
  eq(T.interval_label(4), '3')
  eq(T.interval_label(7), '5')
  eq(T.interval_label(8), 'b6')
  eq(T.interval_label(10), 'b7')
  eq(T.interval_label(11), '7')
end)

-- spelling ----------------------------------------------------------------------

test('auto spelling: sharp major keys', function()
  local major = T.SCALES[1]
  for _, root in ipairs { C, G, D, A, E, B, 6 } do
    eq(T.use_flats(root, major, 'auto'), false, 'root ' .. root)
  end
end)

test('auto spelling: flat major keys', function()
  local major = T.SCALES[1]
  for _, root in ipairs { F, 10, 3, 8, 1 } do
    eq(T.use_flats(root, major, 'auto'), true, 'root ' .. root)
  end
end)

test('auto spelling: minor follows the relative major', function()
  local minor = T.SCALES[2]
  eq(T.use_flats(E, minor, 'auto'), false) -- G major
  eq(T.use_flats(A, minor, 'auto'), false) -- C major
  eq(T.use_flats(D, minor, 'auto'), true)  -- F major
  eq(T.use_flats(C, minor, 'auto'), true)  -- Eb major
  eq(T.use_flats(G, minor, 'auto'), true)  -- Bb major
  eq(T.use_flats(6, minor, 'auto'), false) -- F# minor -> A major
end)

test('manual spelling overrides the key', function()
  eq(T.use_flats(F, T.SCALES[1], 'sharp'), false)
  eq(T.use_flats(G, T.SCALES[1], 'flat'), true)
end)

test('note_name', function()
  eq(T.note_name(1, false), 'C#')
  eq(T.note_name(1, true), 'Db')
  eq(T.note_name(10, true), 'Bb')
  eq(T.note_name(E, true), 'E')
end)

-- tunings -----------------------------------------------------------------------

test('tuning presets, low string first', function()
  local expected = {
    { 'E std',   { 4, 9, 2, 7, 11, 4 } },
    { 'Eb std',  { 3, 8, 1, 6, 10, 3 } },
    { 'D std',   { 2, 7, 0, 5, 9, 2 } },
    { 'C std',   { 0, 5, 10, 3, 7, 0 } },
    { 'Drop D',  { 2, 9, 2, 7, 11, 4 } },
    { 'Drop C',  { 0, 7, 0, 5, 9, 2 } },
    { 'Drop B',  { 11, 6, 11, 4, 8, 1 } },
  }
  eq(#T.TUNINGS, #expected, 'preset count')
  for i, e in ipairs(expected) do
    eq(T.TUNINGS[i].name, e[1])
    list_eq(T.TUNINGS[i].strings, e[2])
  end
end)

test('find_tuning matches a preset or returns nil for custom', function()
  eq(T.find_tuning { 2, 9, 2, 7, 11, 4 }, 5)
  eq(T.find_tuning { 4, 9, 2, 7, 11, 5 }, nil)
end)

test('tuning serializes to a string and back', function()
  local s = T.serialize_tuning { 11, 6, 11, 4, 8, 1 }
  eq(s, '11,6,11,4,8,1')
  list_eq(T.parse_tuning(s), { 11, 6, 11, 4, 8, 1 })
end)

test('parse_tuning rejects malformed input', function()
  eq(T.parse_tuning(nil), nil)
  eq(T.parse_tuning(''), nil)
  eq(T.parse_tuning('4,9,2,7,11'), nil)      -- 5 strings
  eq(T.parse_tuning('4,9,2,7,11,12'), nil)   -- out of range
  eq(T.parse_tuning('4,9,x,7,11,4'), nil)
end)

-- fretboard geometry ------------------------------------------------------------

test('fret_positions: nut at 0, last fret at 1, increasing', function()
  local p = T.fret_positions(24)
  eq(#p, 24)
  eq(p[0], 0)
  eq(p[24], 1)
  for f = 1, 24 do assert(p[f] > p[f - 1], 'fret ' .. f) end
end)

test('fret_positions: frets narrow toward the body', function()
  local p = T.fret_positions(24)
  assert(p[1] - p[0] > p[2] - p[1])
  assert(p[12] - p[11] > p[24] - p[23])
end)

test('fret_positions: 12th fret is half the scale length', function()
  -- 24 frets span 3/4 of the scale length, so the 12th fret (1/2) sits at 2/3
  local p = T.fret_positions(24)
  assert(math.abs(p[12] - 2 / 3) < 1e-9)
end)

test('inlay count per fret', function()
  eq(T.inlay(0), 0)
  eq(T.inlay(1), 0)
  eq(T.inlay(3), 1)
  eq(T.inlay(9), 1)
  eq(T.inlay(12), 2)
  eq(T.inlay(15), 1)
  eq(T.inlay(21), 1)
  eq(T.inlay(24), 2)
  eq(T.inlay(11), 0)
end)

-- runner ------------------------------------------------------------------------

for _, t in ipairs(tests) do
  local ok, err = pcall(t.fn)
  if ok then
    print('ok    ' .. t.name)
  else
    failed = failed + 1
    print('FAIL  ' .. t.name .. '\n      ' .. tostring(err))
  end
end
print(('\n%d tests, %d failed'):format(#tests, failed))
os.exit(failed == 0 and 0 or 1)
