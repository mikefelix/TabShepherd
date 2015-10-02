require("./shoulda.js")
_ = require("./underscore-min.js")

global.extend = (hash1, hash2) ->
  for key of hash2
    hash1[key] = hash2[key]
  hash1
  extend global, require "./chromeStubs.js"

{TabShepherd} = require "./TabShepherd.js"

inputChanged = null
inputEntered = null
windowRemovedListener = null
openWindows = null
focusedWindowId = 1
focusedTabIds = {}
openTabs = null
defs = null
omniboxText = null
alertText = null
ts = null
chrome = null
idCount = 9
currentTest = null

withSavedDef = (name, callback) ->
  chrome.storage.local.get 'windowDefs', (data) ->
    callback data['windowDefs'][name]

suggest = (text) -> omniboxText = text[0].description
alert = (text) -> alertText = text
nextId = ->
  id = idCount
  idCount += 1
  id
createTab = (id, windowId, url) ->
  tab = id: id, windowId: windowId, url: url
  openTabs[id] = tab
  tab
log = (str) ->
  console.log "|#{currentTest}|  #{str}"

reset = (testName) ->
  currentTest = testName ? '?'
  idCount = 9
  openTabs =
    3:
      id: 3
      windowId: 1
      url: 'http://sweetthings.com'
      title: ''
    4:
      id: 4
      windowId: 1
      url: 'http://reallybitterthings.com'
      title: ''
    5:
      id: 5
      windowId: 2
      url: 'http://sourthings.com'
      title: ''
    6:
      id: 6
      windowId: 2
      url: 'http://salty.com'
      title: ''
  defs =
    hello:
      id: 100 # Wrong ID on purpose so that the window will get attached by firstUrl
      name: 'hello'
      patterns: ['yellow', 'white']
      firstUrl: 'http://sweetthings.com'
    goodbye:
      id: 2
      name: 'goodbye'
      patterns: ['blue']
      firstUrl: 'http://sourthings.com'
  focusedWindowId = 1
  openWindows =
    1:
      id: 1
      tabs: [ openTabs[3], openTabs[4] ]
      activeTabId: 4
    2:
      id: 2
      tabs: [ openTabs[5], openTabs[6] ]
      activeTabId: 5
  chrome =
    runtime: lastError: null
    storage: local:
      get: (name, cb) ->
        res = {}
        res[name] = defs if name == 'windowDefs'
        cb res
      set: (newDefs, cb) ->
        defs = newDefs['windowDefs']
        cb()
    omnibox:
      onInputChanged: addListener: (listener) -> inputChanged = listener
      onInputEntered: addListener: (listener) -> inputEntered = listener
    windows:
      onRemoved: addListener: (listener) -> windowRemovedListener = listener
      getCurrent: (o, cb) ->
        throw 'No current window defined' if !focusedWindowId? or !openWindows[focusedWindowId]?
        cb currentWindow()
      create: (ops, cb) ->
        winId = nextId()
        win = id: winId, tabs: [ ]
        tab = createTab nextId(), winId, ''
        win.tabs.push tab
        win.activeTabId = tab.id
        openWindows[winId] = win
        focusedWindowId = winId
        cb win
      get: (id, ops, cb) -> cb openWindows[id]
      getAll: (ops, cb) -> cb(v for own k, v of openWindows)
      update: (winId, ops, cb) ->
        focusedWindowId = winId if ops?.focused
        cb()
    tabs:
      create: (ops, cb) ->
        winId = ops.windowId
        tab = createTab nextId(), winId, ops.url
        win = openWindows[winId]
        win.tabs.push tab
        win.activeTabId = tab.id
        cb tab
      query: (ops, cb) ->
        fits = (t) ->
          res = true
          res = res && t.windowId == ops.windowId if ops.windowId?
          res = res && openWindows[t.windowId].activeTabId == t.id if ops.active
          res
        cb(tab for own id, tab of openTabs when fits(tab))
      get: (id, cb) ->
        cb openTabs[id]
      getAllInWindow: (winId, cb) ->
        cb(_.filter _.values(openTabs), (t) -> t.windowId == winId)
      update: (id, ops, cb) ->
        tab = openTabs[id]
        for own k, v of ops
          if k == 'active'
            openWindows[tab.windowId].activeTabId = tab.id
          else
            tab[k] = v
        cb tab
      move: (ids, ops, cb) ->
        newWin = openWindows[ops.windowId]
        ids = [ids] if typeof ids == 'number'
        for id in ids
          tab = openTabs[id]
          win = openWindows[tab.windowId]
          idx = _.findIndex win.tabs, (t) -> t.id == id
          win.tabs.splice idx, 1
          newWin.tabs.push(tab)
          openTabs[id].windowId = newWin.id
        cb() if cb?
      remove: (id, cb) ->
        tab = openTabs[id]
        win = openWindows[tab.windowId]
        idx = _.findIndex win.tabs, (t) -> t.id == id
        win.tabs.splice idx, 1
        delete openTabs[id]
        cb()
  ts = new TabShepherd chrome, alert

length = (obj) -> if obj.length? 
  obj.length 
else if typeof obj == 'object' 
  Object.keys(obj).length
else
  throw "Can't get length of #{typeof obj}" 
  
changeInput = (input) -> inputChanged input, suggest
enterInput = (input) -> inputEntered input
focusWindow = (id) -> focusedWindowId = id
focusTab = (id) -> currentWindow().activeTabId = id
currentWindow = -> openWindows[focusedWindowId]

assertOmni = (text) -> assertText text, omniboxText
assertAlert = (text) -> assertText text, alertText
assertNoOutput = ->
  assert.fail("Expected no omniboxText, got '#{omniboxText}'") if omniboxText != null
  assert.fail("Expected no alertText, got '#{alertText}'") if alertText != null

assertText = (texts, holder) ->
  run = (text) ->
    if typeof text.push == 'function'
      for t in text
        run t
    else if typeof text == 'object' and typeof text.test == 'function'
      assert.fail("No match for #{text} in #{holder}") if !new RegExp(text).test holder
    else if typeof text == 'string'
      assert.equal text, holder
    else
      throw "Can't test a text of type #{typeof text}."
  run texts
  omniboxText = null
  alertText = null

expectSuggestionFor = (text, output) ->
  changeInput text
  cmd = text.replace /\s.*/, ''
  assertOmni "#{cmd}: #{output}"
#  assertOmni output
expectResponseFor = (text, output) ->
  enterInput text
  cmd = text.replace /\s.*/, ''
  assertAlert "#{cmd}: #{output}"
#  assertAlert output
expectNoResponseFor = (text) ->
  enterInput text
  assertNoOutput()
assertFocus = (winId, tabId) ->
  assert.fail("Expected window #{winId} to be focused, was window #{focusedWindowId}") if winId != focusedWindowId
  assert.fail("Excpected tab #{tabId} to be focused, was tab #{openWindows[focusedWindowId].activeTabId}") if tabId != openWindows[focusedWindowId].activeTabId

context "TabShepherd",
  should "initialize", ->
    assert.equal 'function', typeof TabShepherd

    reset('init')

    assert.equal 'object', typeof ts
    assert.equal 'yellow', ts.getDefinition('hello').patterns[0]
    assert.isTrue ts.getDefinition('hello').id != 100
    assert.equal 'blue', ts.getDefinition('goodbye').patterns[0]
    assert.fail("Input not changed") if !inputChanged?
    assert.fail("Input not entered") if !inputEntered?

    # Check that loaded definition got attached
    win2 = openWindows[2]
    assert.equal 'goodbye', ts.getName(win2)
    def = ts.getDefinition('goodbye')
    assert.fail("No definition for goodbye") if !def?
    def = ts.getDefinition(win2)
    assert.fail("No definition for window #{win2.id}") if !def?
    assert.equal 'blue', def.patterns[0]

context "makeText",
  should "assemble strings", ->
    reset('makeText')

    assert.equal 'a string', ts.makeText('a string')
    assert.equal "window \"2\"'s color is bluegreen", ts.makeText("window %w's color is %s", 2, 'bluegreen')
    assert.equal "color is blue|green", ts.makeText("color is %s", 'blue|green')
    assert.equal 'color is /blue|green/', ts.makeText("color is %p", 'blue|green')
    assert.equal "color is 'bluegreen'", ts.makeText("color is %p", 'bluegreen')

context "help",
  should "show help", ->
    reset 'help'
    changeInput 'help'
    assertOmni 'help: Enter a command name or press enter to see possible commands.'
    changeInput 'help blah'
    assertOmni 'blah: No matching command found.'
    changeInput 'help find'
    assertOmni 'find: ' + ts.getCommands()['find'].desc
    changeInput 's'
    assertOmni 's: [send/sort/split] Keep typing to narrow command results.'

context "help",
  should "show help on a command", ->
    reset 'help'
    for own name, cmd of ts.getCommands() when name != 'help'
      changeInput "help #{name}"
      assertOmni "#{name}: #{cmd.desc}"

context "help",
  should "show help page", ->
    reset 'help'
    focusWindow 1
    assert.equal 2, length(currentWindow().tabs)
    expectNoResponseFor 'help name'
    assert.equal 3, length(currentWindow().tabs)
    assertFocus 1, 9

context "name",
  should "handle command", ->
    reset('name')

    expectSuggestionFor 'name', 'Enter a name for this window.'
    expectResponseFor 'name', 'No name provided.'
    expectSuggestionFor 'name foo', 'Press enter to name this window "foo".'

    expectNoResponseFor 'name foo'
    assert.equal 'foo', ts.getName(openWindows[focusedWindowId])
    assert.isTrue defs['foo']?
    assert.equal 'foo', defs['foo'].name

    expectSuggestionFor 'name ', 'Enter a new name for this window (currently named "foo").'
    expectSuggestionFor 'name blah', 'Press enter to change window name from "foo" to "blah".'
    enterInput 'name blah'
    assert.equal 'blah', ts.getName(openWindows[focusedWindowId])
    assert.isTrue defs['blah']?
    assert.isFalse defs['foo']?
    assert.equal 'blah', defs['blah'].name

context "defs/clear",
  should "list and clear definitions", ->
    reset('clearall')
    expectResponseFor 'clear *', 'Cleared all window definitions.'
    assert.equal 0, length(defs)

    reset('defs')
    expectSuggestionFor 'defs', 'Press enter to list the window definitions.'
    enterInput 'defs'
    assertText [/Named windows:/, /goodbye \(window 2\)/], alertText

    enterInput 'name hi'
    enterInput 'defs'
    assertText [/Named windows:/, /goodbye \(window 2\)/, /hi \(window 1\)/], alertText

    expectSuggestionFor 'clear blah', 'Window definition "blah" not found.'
    expectSuggestionFor 'clear goodbye', 'Press enter to clear window definition "goodbye". Warning: currently assigned to a window.'

    assert.equal 3, length(defs)
    assert.equal 'goodbye', defs['goodbye'].name
    expectResponseFor 'clear goodbye', 'Cleared window definition "goodbye" and removed it from a window.'
    assert.equal 2, length(defs)
    assert.equal undefined, defs['goodbye']

context "new",
  should "handle command", ->
    reset('new')

    expectSuggestionFor 'new', 'Enter a name for the new window.'
    expectSuggestionFor 'new yes', 'Press enter to open a new window and name it "yes".'
    expectSuggestionFor 'new yes okay', 'Press enter to open a new window named "yes" and assign it the pattern \'okay\'.'
    expectSuggestionFor 'new yes hello|goodbye', 'Press enter to open a new window named "yes" and assign it the pattern /hello|goodbye/.'

    expectNoResponseFor 'new yes okay'
    assert.equal 'yes', ts.getName(openWindows[focusedWindowId])
    withSavedDef 'yes', (def) ->
      assert.isTrue def?
      assert.equal 'yes', def.name
      assert.equal 'okay', def.patterns[0]

    expectSuggestionFor 'new yes', 'There is already a window named "yes".'

context "find",
  should "handle command", ->
    reset('find')

    expectSuggestionFor 'find', 'Enter a pattern to find a tab.'
    expectResponseFor 'find', 'Enter a pattern to find a tab.'

    expectSuggestionFor 'find things', "Press enter to focus the first of 3 tabs matching 'things'."
    expectNoResponseFor 'find things'
    assertFocus 1, 3

    expectSuggestionFor 'find really', "Press enter to focus the tab matching 'really'."
    expectNoResponseFor 'find really'
    assertFocus 1, 4

    expectSuggestionFor 'find sweet|bitter', "Press enter to focus the first of 2 tabs matching /sweet|bitter/."
    expectNoResponseFor 'find sweet|bitter'
    assertFocus 1, 3

    expectSuggestionFor 'find salty', "Press enter to focus the tab matching 'salty' in window \"goodbye\"."
    expectNoResponseFor 'find salty'
    assertFocus 2, 6

    expectSuggestionFor 'find s[aeiou]{2}r', "Press enter to focus the tab matching /s[aeiou]{2}r/ in window \"goodbye\"."
    expectNoResponseFor 'find s[aeiou]{2}r'
    assertFocus 2, 5

    expectSuggestionFor 'find umami', "No matching tabs found for 'umami'."
    expectResponseFor 'find umami', "No matching tabs found for 'umami'."
    assertFocus 2, 5

    expectSuggestionFor 'find um.*mi', "No matching tabs found for /um.*mi/."
    expectResponseFor 'find um.*mi', "No matching tabs found for /um.*mi/."
    assertFocus 2, 5

    assert.equal 2, length(openWindows)

context 'bring',
  should 'handle command', ->
    reset('bring')

    focusWindow 1
    assert.equal 2, currentWindow().tabs.length
    expectSuggestionFor 'bring', 'Enter one or more patterns. No assigned patterns exist for this window.'
    expectSuggestionFor 'bring umami', "No tabs found matching 1 given pattern."
    expectSuggestionFor 'bring umami poo', "No tabs found matching 2 given patterns."
    expectSuggestionFor 'bring sour', "Press enter to bring 1 tab matching 1 pattern to this window (unnamed)."
    expectSuggestionFor 'bring a', "Press enter to bring 2 tabs matching 1 pattern to this window (unnamed)."
    expectSuggestionFor 'bring sour really', "Press enter to bring 2 tabs matching 2 patterns to this window (unnamed)."

    focusWindow 2
    assert.equal 2, currentWindow().tabs.length
    expectSuggestionFor 'bring sour', 'Press enter to bring 1 tab matching 1 pattern to this window "goodbye".'
    expectSuggestionFor 'bring a', 'Press enter to bring 2 tabs matching 1 pattern to this window "goodbye".'
    expectSuggestionFor 'bring sour really', 'Press enter to bring 2 tabs matching 2 patterns to this window "goodbye".'
    expectResponseFor 'bring xxxx (xxxx)+', "No tabs found matching 2 given patterns:\n\n'xxxx'\n/(xxxx)+/"
    assert.equal 2, currentWindow().tabs.length

    expectNoResponseFor 'bring sour really'
    assert.equal 3, currentWindow().tabs.length
    focusWindow 1
    assert.equal 1, currentWindow().tabs.length

context 'send',
  should 'send to existing window', ->
    reset('sendexist')
    focusWindow 1
    focusTab 3
    assert.equal 2, currentWindow().tabs.length
    expectSuggestionFor 'send', 'Enter a window name to send this tab there.'
    expectSuggestionFor 'send goodbye', "Press enter to send this tab to window \"goodbye\"."
    expectNoResponseFor 'send goodbye'
    assert.equal 1, currentWindow().tabs.length
    focusWindow 2
    assert.equal 3, currentWindow().tabs.length

context 'send',
  should 'send to new window', ->
    reset('sendnew')
    focusTab 3
    assert.equal 2, currentWindow().tabs.length
    expectSuggestionFor 'send whatever', "Press enter to send this tab to new window \"whatever\"."
    expectNoResponseFor 'send whatever'
    assert.equal 1, currentWindow().tabs.length
    focusWindow 9
    assert.equal 'whatever', ts.getName(currentWindow())
    assert.equal 1, currentWindow().tabs.length

context 'extract',
  should 'extract tabs', ->
    reset('extract')
    expectSuggestionFor 'extract', 'Enter a name or pattern.'
    expectSuggestionFor 'extract nothing', "No tabs found matching 'nothing'. Enter more args to use it as a name."
    expectSuggestionFor 'extract salts?', "Press enter to extract 1 tab matching /salts?/ into a new window named \"salts?\"."
    expectSuggestionFor 'extract things', "Press enter to extract 3 tabs matching 'things' into a new window named \"things\"."
    expectSuggestionFor 'extract stuff things', "Press enter to extract 3 tabs matching 'things' into a new window named \"stuff\"."
    expectSuggestionFor 'extract stuff th[io]ngs', "Press enter to extract 3 tabs matching /th[io]ngs/ into a new window named \"stuff\"."
    expectSuggestionFor 'extract stuff things items', "Press enter to extract 3 tabs matching 2 patterns into a new window named \"stuff\"."

    expectResponseFor 'extract nothing', 'No tabs found matching the given pattern(s).'
    assert.equal 2, length(openWindows)

    expectNoResponseFor 'extract stuff things items'
    assert.equal 3, length(openWindows)
    focusWindow 1
    assert.equal 0, currentWindow().tabs.length
    focusWindow 2
    assert.equal 1, currentWindow().tabs.length
    focusWindow 9
    assert.equal 3, currentWindow().tabs.length
    assert.equal 'stuff', ts.getName(currentWindow())

context 'open',
  should 'open new windows', ->
    reset('open')
    assert.equal 2, length(openWindows)

    expectSuggestionFor 'open stuff', 'Press enter to open new window "stuff".'
    expectNoResponseFor 'open stuff'
    assert.equal 3, length(openWindows)
    assert.equal 9, currentWindow().id

    expectSuggestionFor 'open goodbye', 'Press enter to open window "goodbye".'
    expectNoResponseFor 'open goodbye'
    assert.equal 3, length(openWindows)
    assert.equal 2, currentWindow().id

    defs['elephant'] =
      id: 15
      name: 'elephant'
      patterns: ['elephant']
      activeUrl: 'http://elephant.com'

    expectSuggestionFor 'open elephant', 'Press enter to open a new window for existing definition "elephant".'
    expectNoResponseFor 'open elephant'
    assert.equal 4, length(openWindows)
    assert.equal 11, currentWindow().id

context 'merge',
  should 'merge window by name', ->
    reset 'merge'

    focusWindow 1
    ts.setName currentWindow(), 'hello'
    expectSuggestionFor 'merge goodbye', 'Press enter to move 2 tabs and 1 pattern from window "goodbye" to this window "hello".'
    expectNoResponseFor 'merge goodbye'
    assert.equal 4, currentWindow().tabs.length
    assert.equal undefined, ts.getDefinition('goodbye')

  should 'merge default window', ->
    reset 'merge'

    focusWindow 1
    ts.setName currentWindow(), 'hello'
    expectSuggestionFor 'merge', 'Enter a defined window name, or press enter to merge the window with the fewest tabs.'
    expectNoResponseFor 'merge goodbye'
    assert.equal 4, currentWindow().tabs.length
    assert.equal undefined, ts.getDefinition('goodbye')

###
context 'sort',
  should 'sort tabs', ->
    reset 'sort'

    focusWindow 1
    currentWindow().tabs.push createTab(nextId(), currentWindow().id, 'http://bluepotatochips.com')
    assert.equal 3, currentWindow().tabs.length
    expectSuggestionFor 'sort', 'Press enter to sort all windows according to their assigned patterns.'
    expectNoResponseFor 'sort'
    assert.equal 2, currentWindow().tabs.length
    focusWindow 2
    assert.equal 3, currentWindow().tabs.length
###



###
context 'split',
  should 'split windows', ->
    reset('split')
    expectSuggestionFor 'split', "Press enter to split this window in two."

    expectNoResponseFor 'split'
    assert.equal 3, length(openWindows)
    focusWindow 1
    assert.equal 1, currentWindow().tabs.length
    focusWindow 9
    assert.equal 1, currentWindow().tabs.length
###


Tests.run()