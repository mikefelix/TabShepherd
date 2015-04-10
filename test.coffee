require("./shoulda.js")
global.extend = (hash1, hash2) ->
  for key of hash2
    hash1[key] = hash2[key]
  hash1
  extend global, require "./chromeStubs.js"

{TabShepherd} = require "./TabShepherd.js"

chrome =
  storage:
    get: ->
    set: (defs) ->
  omnibox:
    onInputChanged:
      addListener: (listener) ->
        @inputChangedListener = listener
    onInputEntered:
      addListener: (listener) ->
        @inputEnteredListener = listener
  windows:
    onRemoved:
      addListener: (f) ->
    getCurrent: ->
    create: ->
  tabs:
    query: ->
  runtime:
    lastError: null


context "Commands",
  should "initialize", ->
    assert.equal 'function', typeof TabShepherd
    ts = new TabShepherd chrome.storage, chrome.omnibox, chrome.windows, chrome.tabs, chrome.runtime
    assert.equal 'object', typeof ts
    assert.isTrue chrome.omnibox.inputChangedListener?
#    assert.isTrue chrome.omnibox.inputEnteredListener?


Tests.run()