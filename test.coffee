require("./shoulda.js")
require("./underscore-min.js")

global.extend = (hash1, hash2) ->
  for key of hash2
    hash1[key] = hash2[key]
  hash1
  extend global, require "./chromeStubs.js"

{TabShepherd} = require "./TabShepherd.js"

inputChanged = null
inputEntered = null
windowRemovedListener = null
focusedWindowId = null
activeTabId = null
tabValues = -> _.values(tabs)
windows = {}
tabs = {}
defs = {}
omniboxText = ''
alertText = ''
suggest = (text) -> omniboxText = text[0].description

randomId = -> Math.floor(Math.random() * 10000)

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
    getCurrent: (cb) -> cb windows[focusedWindowId]
    create: (ops, cb) ->
      id = id: randomId()
      tab = url: '', id: randomId(), windowId: id
      win = id: id, tabs: [ tab ]
      windows[id] = win
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



context "Commands",
  should "initialize", ->
    assert.equal 'function', typeof TabShepherd
    ts = new TabShepherd chrome
    assert.equal 'object', typeof ts
    assert.isTrue inputChanged?
    assert.isTrue inputEntered?
  should "show help", ->
    ts = new TabShepherd chrome
    inputChanged 'help', suggest
    assert.equal omniboxText, 'Get help on a command'


Tests.run()