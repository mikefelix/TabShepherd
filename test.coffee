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
tabs = null
defs = null
omniboxText = null
alertText = null
ts = null
chrome = null

tabValues = -> _.values(tabs)
suggest = (text) -> omniboxText = text[0].description
alert = (text) -> alertText = text
randomId = -> Math.floor(Math.random() * 10000)

reset = ->
  tabs = {}
  defs = {}
  focusedWindowId = 1
  windows =
    1:
      tabs: []
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
        id = id: randomId()
        tab = url: '', id: randomId(), windowId: id
        win = id: id, tabs: [ tab ]
        windows[id] = win
        focusedWindowId = id
        cb win
      get: (id, ops, cb) -> cb windows[id]
      getAll: (ops, cb) -> cb(v for own k, v of windows)
      update: (winId, ops, cb) ->
        focusedWindowId = winId if ops?.focused
        cb()
    tabs:
      create: (winId, url, cb) ->
        tabId = randomId()
        tab = url: url, id: randomId(), windowId: winId
        tabs[tabId] = tab
        windows[winId].tabs.push tab
        cb tab
      query: (ops, cb) ->
        fits = (t) ->
          (!ops.currentWindow or t.windowId == focusedWindowId) and
          (!ops.active or t.id == activeTabId)
        cb(t for t in tabValues() when fits(t))
      get: (id, cb) ->
        cb tabs[id]
      getAllInWindow: (winId, cb) ->
        cb(_.filter tabValues(), (t) -> t.windowId == winId)
      update: (id, ops, cb) ->
        tab = tabs[id]
        for own k, v of ops
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
          cb tab
      remove: (id, cb) ->
        tab = tabs[id]
        win = windows[tab.windowId]
        idx = _.findIndexOf win.tabs, (t) -> t.id == id
        win.tabs.splice idx, 1
        delete tabs[id]
        cb()
  ts = new TabShepherd chrome, alert

changeInput = (input) -> inputChanged input, suggest
enterInput = (input) -> inputEntered input

assertOmni = (text) -> assertText text, omniboxText
assertAlert = (text) -> assertText text, alertText
assertNoOutput = -> assert.isTrue omniboxText == null and alertText == null
assertText = (text, holder) ->
  out = if typeof text == 'object' and typeof text.test == 'function'
    assert.isTrue new RegExp(text).test holder
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

context "Commands",
  should "initialize", ->
    assert.equal 'function', typeof TabShepherd
    assert.equal 'object', typeof ts
    assert.isTrue inputChanged?
    assert.isTrue inputEntered?

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
    expectSuggestionFor 'name foo', "Press enter to name this window 'foo'."

    expectNoResponseFor 'name foo'
    assert.equal 'foo', windows[focusedWindowId].name
    assert.isTrue defs['foo']?
    assert.equal 'foo', defs['foo'].name

    expectSuggestionFor 'name ', "Enter a new name for this window (currently named 'foo')."
    expectSuggestionFor 'name blah', "Press enter to change window name from 'foo' to 'blah'."
    enterInput 'name blah'
    assert.equal 'blah', windows[focusedWindowId].name
    assert.isTrue defs['blah']?
    assert.isFalse defs['foo']?
    assert.equal 'blah', defs['blah'].name

context "defs",
  should "handle command", ->
    reset()

    expectSuggestionFor 'defs', 'Press enter to list the window definitions.'
    expectResponseFor 'defs', 'Named windows:\n\n'

    enterInput 'name hi'
    expectResponseFor 'defs', /^Named windows:\s+hi/

context "new",
  should "handle command", ->
    reset()

    expectSuggestionFor 'new', 'Enter a name for the new window.'
    expectSuggestionFor 'new yes', "Press enter to open a new window and name it 'yes'."
    expectSuggestionFor 'new yes okay', "Press enter to open a new window named 'yes' and assign it the pattern 'okay'."
    expectSuggestionFor 'new yes hello|goodbye', "Press enter to open a new window named 'yes' and assign it the pattern /hello|goodbye/."

    expectNoResponseFor 'new yes okay'
    assert.equal 'yes', windows[focusedWindowId].name
    assert.isTrue defs['yes']?
    assert.equal 'yes', defs['yes'].name
    assert.equal ['okay'], defs['yes'].patterns
    expectSuggestionFor 'new yes', "There is already a window named 'yes'."


Tests.run()