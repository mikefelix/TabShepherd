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
activeTabId = null
windows = null
focusedWindowId = 1
focusedTabIds = {}
tabs = null
defs = null
omniboxText = null
alertText = null
ts = null
chrome = null

tabValues = -> _.values(tabs)
withSavedDef = (name, callback) ->
  chrome.storage.local.get 'windowDefs', (data) ->
    callback data['windowDefs'][name]

suggest = (text) -> omniboxText = text[0].description
alert = (text) -> alertText = text
randomId = -> Math.floor(Math.random() * 10000)
createTab = (id, windowId, url) ->
  tab = id: id, windowId: windowId, url: url
  tabs[id] = tab
  tab

reset = ->
  tabs =
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
  defs = {
    goodbye:
      name: 'goodbye'
      patterns: ['blue']
      activeUrl: 'http://sourthings.com'
  }
  focusedWindowId = 1
  windows =
    1:
      id: 1
      tabs: [ tabs[3], tabs[4] ]
      activeTabId: 4
      name: 'hello'
    2:
      id: 2
      tabs: [ tabs[5], tabs[6] ]
      activeTabId: 5
      # name missing on purpose
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
        throw 'No current window defined' if !focusedWindowId? or !windows[focusedWindowId]?
        cb windows[focusedWindowId]
      create: (ops, cb) ->
        winId = randomId()
        win = id: winId, tabs: [ ]
        tab = createTab randomId(), winId, ''
        win.tabs.push tab
        win.activeTabId = tab.id
        windows[winId] = win
        focusedWindowId = winId
        cb win
      get: (id, ops, cb) -> cb windows[id]
      getAll: (ops, cb) -> cb(v for own k, v of windows)
      update: (winId, ops, cb) ->
        focusedWindowId = winId if ops?.focused
        cb()
    tabs:
      create: (winId, url, cb) ->
        tabId = randomId()
        tab = createTab tabId, winId, url
        windows[winId].tabs.push tab
        cb tab
      query: (ops, cb) ->
        fits = (t) ->
          res = true
          res = res && t.windowId == ops.windowId if ops.windowId?
          res = res && windows[t.windowId].activeTabId == t.id if ops.active
          res
        cb(tab for own id, tab of tabs when fits(tab))
      get: (id, cb) ->
        cb tabs[id]
      getAllInWindow: (winId, cb) ->
        cb(_.filter tabValues(), (t) -> t.windowId == winId)
      update: (id, ops, cb) ->
        tab = tabs[id]
        for own k, v of ops
          if k == 'active'
            windows[tab.windowId].activeTabId = tab.id
          else
            tab[k] = v
        cb tab
      move: (ids, ops, cb) ->
        newWin = windows[ops.windowId]
        for id in ids
          win = windows[tab.windowId]
          idx = _.findIndexOf win.tabs, (t) -> t.id == id
          win.tabs.splice idx, 1
          tab = tabs[id]
          newWin.tabs.push(tab)
        cb()
      remove: (id, cb) ->
        tab = tabs[id]
        win = windows[tab.windowId]
        idx = _.findIndexOf win.tabs, (t) -> t.id == id
        win.tabs.splice idx, 1
        delete tabs[id]
        cb()
  ts = new TabShepherd chrome, alert
#  console.log "Windows:"
#  console.dir windows

changeInput = (input) -> inputChanged input, suggest
enterInput = (input) -> inputEntered input

assertOmni = (text) -> assertText text, omniboxText
assertAlert = (text) -> assertText text, alertText
assertNoOutput = ->
  assert.fail("Expected no omniboxText, got '#{omniboxText}'") if omniboxText != null
  assert.fail("Expected no alertText, got '#{alertText}'") if alertText != null

assertText = (text, holder) ->
  out = if typeof text == 'object' and typeof text.test == 'function'
    assert.fail("No match for #{text} in #{holder}") if !new RegExp(text).test holder
  else if typeof text == 'string'
    assert.equal text, holder
  else
    throw "Can't test a text of type #{typeof text}."
  omniboxText = null
  alertText = null
  out

expectSuggestionFor = (text, output) ->
  changeInput text
  assertOmni output
expectResponseFor = (text, output) ->
  enterInput text
  assertAlert output
expectNoResponseFor = (text) ->
  enterInput text
  assertNoOutput()
assertFocus = (winId, tabId) ->
  assert.fail("Expected window #{winId} to be focused, was window #{focusedWindowId}") if winId != focusedWindowId
  assert.fail("Excpected tab #{tabId} to be focused, was tab #{windows[focusedWindowId].activeTabId}") if tabId != windows[focusedWindowId].activeTabId

context "Commands",
  should "initialize", ->
    reset()

    assert.equal 'function', typeof TabShepherd
    assert.equal 'object', typeof ts
    assert.isTrue inputChanged?
    assert.isTrue inputEntered?

    # Check that loaded definition got attached
    win2 = windows[2]
    assert.equal 'goodbye', win2.name
    def = ts.getDefinition(win2.name)
    assert.isTrue def?
    assert.equal 'blue', def.patterns[0]

context "makeText",
  should "assemble strings", ->
    reset()

    assert.equal 'a string', ts.makeText('a string')
    assert.equal "window \"2\"'s color is bluegreen", ts.makeText("window %w's color is %s", 2, 'bluegreen')
    assert.equal "color is blue|green", ts.makeText("color is %s", 'blue|green')
    assert.equal 'color is /blue|green/', ts.makeText("color is %p", 'blue|green')
    assert.equal "color is 'bluegreen'", ts.makeText("color is %p", 'bluegreen')

context "Commands",
  should "show help", ->
    changeInput 'help', suggest
    assertOmni /^Possible commands:/

context "Commands",
  should "show help on a command", ->
    for own name, cmd of ts.commands()
      changeInput "help #{name}", suggest
      if (!cmd.alias? and name != 'help')
        assertOmni "#{name}: #{cmd.desc}"

context "name",
  should "handle command", ->
    reset()

    expectSuggestionFor 'name', 'Enter a name for this window.'
    expectResponseFor 'name', 'No name provided.'
    expectSuggestionFor 'name foo', 'Press enter to name this window "foo".'

    expectNoResponseFor 'name foo'
    assert.equal 'foo', windows[focusedWindowId].name
    assert.isTrue defs['foo']?
    assert.equal 'foo', defs['foo'].name

    expectSuggestionFor 'name ', 'Enter a new name for this window (currently named "foo").'
    expectSuggestionFor 'name blah', 'Press enter to change window name from "foo" to "blah".'
    enterInput 'name blah'
    assert.equal 'blah', windows[focusedWindowId].name
    assert.isTrue defs['blah']?
    assert.isFalse defs['foo']?
    assert.equal 'blah', defs['blah'].name

context "defs",
  should "handle command", ->
    reset()

    expectSuggestionFor 'defs', 'Press enter to list the window definitions.'
    expectResponseFor 'defs', "Named windows:\n\ngoodbye (window 2)"

    enterInput 'name hi'
    expectResponseFor 'defs', "Named windows:\n\ngoodbye (window 2)\nhi (window 1)"

context "new",
  should "handle command", ->
    reset()
    expectSuggestionFor 'name foo', 'Press enter to name this window "foo".'

    expectSuggestionFor 'new', 'Enter a name for the new window.'
    expectSuggestionFor 'new yes', 'Press enter to open a new window and name it "yes".'
    expectSuggestionFor 'new yes okay', 'Press enter to open a new window named "yes" and assign it the pattern \'okay\'.'
    expectSuggestionFor 'new yes hello|goodbye', 'Press enter to open a new window named "yes" and assign it the pattern /hello|goodbye/.'

    expectNoResponseFor 'new yes okay'
    assert.equal 'yes', windows[focusedWindowId].name
    withSavedDef 'yes', (def) ->
      assert.isTrue def?
      assert.equal 'yes', def.name
      assert.equal 'okay', def.patterns[0]

    expectSuggestionFor 'new yes', 'There is already a window named "yes".'
context "find",
  should "handle command", ->
    reset()

    expectSuggestionFor 'find', 'Enter a pattern to find a tab.'
    expectResponseFor 'find', 'Enter a pattern to find a tab.'

    expectSuggestionFor 'find things', "Press enter to focus the first of 3 tabs matching 'things'."
    expectNoResponseFor 'find things'
    assertFocus 1, 3

    expectSuggestionFor 'find really', "Press enter to focus the tab matching 'really' in window \"hello\"."
    expectNoResponseFor 'find really'
    assertFocus 1, 4

    expectSuggestionFor 'find sweet|bitter', "Press enter to focus the first of 2 tabs matching /sweet|bitter/."
    expectNoResponseFor 'find sweet|bitter'
    assertFocus 1, 3

    expectSuggestionFor 'find s[aeiou]{2}r', "Press enter to focus the tab matching /s[aeiou]{2}r/ in window \"goodbye\"."
    expectNoResponseFor 'find s[aeiou]{2}r'
    assertFocus 2, 5

    expectSuggestionFor 'find umami', "No matching tabs found for 'umami'."
    expectResponseFor 'find umami', "No matching tabs found for 'umami'."
    assertFocus 2, 5

    expectSuggestionFor 'find um.*mi', "No matching tabs found for /um.*mi/."
    expectResponseFor 'find um.*mi', "No matching tabs found for /um.*mi/."
    assertFocus 2, 5

    assert.equal 2, Object.keys(windows).length


Tests.run()