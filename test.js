// Generated by CoffeeScript 1.9.1
(function() {
  var TabShepherd, _, alert, alertText, assertAlert, assertFocus, assertNoOutput, assertOmni, assertText, changeInput, chrome, createTab, currentTest, currentWindow, defs, enterInput, expectNoResponseFor, expectResponseFor, expectSuggestionFor, focusTab, focusWindow, focusedTabIds, focusedWindowId, idCount, inputChanged, inputEntered, log, nextId, omniboxText, openTabs, openWindows, reset, suggest, ts, windowRemovedListener, withSavedDef,
    hasProp = {}.hasOwnProperty;

  require("./shoulda.js");

  _ = require("./underscore-min.js");

  global.extend = function(hash1, hash2) {
    var key;
    for (key in hash2) {
      hash1[key] = hash2[key];
    }
    hash1;
    return extend(global, require("./chromeStubs.js"));
  };

  TabShepherd = require("./TabShepherd.js").TabShepherd;

  inputChanged = null;

  inputEntered = null;

  windowRemovedListener = null;

  openWindows = null;

  focusedWindowId = 1;

  focusedTabIds = {};

  openTabs = null;

  defs = null;

  omniboxText = null;

  alertText = null;

  ts = null;

  chrome = null;

  idCount = 9;

  currentTest = null;

  withSavedDef = function(name, callback) {
    return chrome.storage.local.get('windowDefs', function(data) {
      return callback(data['windowDefs'][name]);
    });
  };

  suggest = function(text) {
    return omniboxText = text[0].description;
  };

  alert = function(text) {
    return alertText = text;
  };

  nextId = function() {
    var id;
    id = idCount;
    idCount += 1;
    return id;
  };

  createTab = function(id, windowId, url) {
    var tab;
    tab = {
      id: id,
      windowId: windowId,
      url: url
    };
    openTabs[id] = tab;
    return tab;
  };

  log = function(str) {
    return console.log("|" + currentTest + "|  " + str);
  };

  reset = function(testName) {
    currentTest = testName != null ? testName : '?';
    idCount = 9;
    openTabs = {
      3: {
        id: 3,
        windowId: 1,
        url: 'http://sweetthings.com',
        title: ''
      },
      4: {
        id: 4,
        windowId: 1,
        url: 'http://reallybitterthings.com',
        title: ''
      },
      5: {
        id: 5,
        windowId: 2,
        url: 'http://sourthings.com',
        title: ''
      },
      6: {
        id: 6,
        windowId: 2,
        url: 'http://salty.com',
        title: ''
      }
    };
    defs = {
      goodbye: {
        id: 2,
        name: 'goodbye',
        patterns: ['blue'],
        activeUrl: 'http://sourthings.com'
      }
    };
    focusedWindowId = 1;
    openWindows = {
      1: {
        id: 1,
        tabs: [openTabs[3], openTabs[4]],
        activeTabId: 4
      },
      2: {
        id: 2,
        tabs: [openTabs[5], openTabs[6]],
        activeTabId: 5
      }
    };
    chrome = {
      runtime: {
        lastError: null
      },
      storage: {
        local: {
          get: function(name, cb) {
            var res;
            res = {};
            if (name === 'windowDefs') {
              res[name] = defs;
            }
            return cb(res);
          },
          set: function(newDefs, cb) {
            defs = newDefs['windowDefs'];
            return cb();
          }
        }
      },
      omnibox: {
        onInputChanged: {
          addListener: function(listener) {
            return inputChanged = listener;
          }
        },
        onInputEntered: {
          addListener: function(listener) {
            return inputEntered = listener;
          }
        }
      },
      windows: {
        onRemoved: {
          addListener: function(listener) {
            return windowRemovedListener = listener;
          }
        },
        getCurrent: function(o, cb) {
          if ((focusedWindowId == null) || (openWindows[focusedWindowId] == null)) {
            throw 'No current window defined';
          }
          return cb(currentWindow());
        },
        create: function(ops, cb) {
          var tab, win, winId;
          winId = nextId();
          win = {
            id: winId,
            tabs: []
          };
          tab = createTab(nextId(), winId, '');
          win.tabs.push(tab);
          win.activeTabId = tab.id;
          openWindows[winId] = win;
          focusedWindowId = winId;
          return cb(win);
        },
        get: function(id, ops, cb) {
          return cb(openWindows[id]);
        },
        getAll: function(ops, cb) {
          var k, v;
          return cb((function() {
            var results;
            results = [];
            for (k in openWindows) {
              if (!hasProp.call(openWindows, k)) continue;
              v = openWindows[k];
              results.push(v);
            }
            return results;
          })());
        },
        update: function(winId, ops, cb) {
          if (ops != null ? ops.focused : void 0) {
            focusedWindowId = winId;
          }
          return cb();
        }
      },
      tabs: {
        create: function(winId, url, cb) {
          var tab, tabId;
          tabId = nextId();
          tab = createTab(tabId, winId, url);
          openWindows[winId].tabs.push(tab);
          return cb(tab);
        },
        query: function(ops, cb) {
          var fits, id, tab;
          fits = function(t) {
            var res;
            res = true;
            if (ops.windowId != null) {
              res = res && t.windowId === ops.windowId;
            }
            if (ops.active) {
              res = res && openWindows[t.windowId].activeTabId === t.id;
            }
            return res;
          };
          return cb((function() {
            var results;
            results = [];
            for (id in openTabs) {
              if (!hasProp.call(openTabs, id)) continue;
              tab = openTabs[id];
              if (fits(tab)) {
                results.push(tab);
              }
            }
            return results;
          })());
        },
        get: function(id, cb) {
          return cb(openTabs[id]);
        },
        getAllInWindow: function(winId, cb) {
          return cb(_.filter(_.values(openTabs), function(t) {
            return t.windowId === winId;
          }));
        },
        update: function(id, ops, cb) {
          var k, tab, v;
          tab = openTabs[id];
          for (k in ops) {
            if (!hasProp.call(ops, k)) continue;
            v = ops[k];
            if (k === 'active') {
              openWindows[tab.windowId].activeTabId = tab.id;
            } else {
              tab[k] = v;
            }
          }
          return cb(tab);
        },
        move: function(ids, ops, cb) {
          var i, id, idx, len, newWin, tab, win;
          newWin = openWindows[ops.windowId];
          if (typeof ids === 'number') {
            ids = [ids];
          }
          for (i = 0, len = ids.length; i < len; i++) {
            id = ids[i];
            tab = openTabs[id];
            win = openWindows[tab.windowId];
            idx = _.findIndex(win.tabs, function(t) {
              return t.id === id;
            });
            win.tabs.splice(idx, 1);
            newWin.tabs.push(tab);
            openTabs[id].windowId = newWin.id;
          }
          if (cb != null) {
            return cb();
          }
        },
        remove: function(id, cb) {
          var idx, tab, win;
          tab = openTabs[id];
          win = openWindows[tab.windowId];
          idx = _.findIndex(win.tabs, function(t) {
            return t.id === id;
          });
          win.tabs.splice(idx, 1);
          delete openTabs[id];
          return cb();
        }
      }
    };
    return ts = new TabShepherd(chrome, alert);
  };

  changeInput = function(input) {
    return inputChanged(input, suggest);
  };

  enterInput = function(input) {
    return inputEntered(input);
  };

  focusWindow = function(id) {
    return focusedWindowId = id;
  };

  focusTab = function(id) {
    return currentWindow().activeTabId = id;
  };

  currentWindow = function() {
    return openWindows[focusedWindowId];
  };

  assertOmni = function(text) {
    return assertText(text, omniboxText);
  };

  assertAlert = function(text) {
    return assertText(text, alertText);
  };

  assertNoOutput = function() {
    if (omniboxText !== null) {
      assert.fail("Expected no omniboxText, got '" + omniboxText + "'");
    }
    if (alertText !== null) {
      return assert.fail("Expected no alertText, got '" + alertText + "'");
    }
  };

  assertText = function(text, holder) {
    var out;
    out = (function() {
      if (typeof text === 'object' && typeof text.test === 'function') {
        if (!new RegExp(text).test(holder)) {
          return assert.fail("No match for " + text + " in " + holder);
        }
      } else if (typeof text === 'string') {
        return assert.equal(text, holder);
      } else {
        throw "Can't test a text of type " + (typeof text) + ".";
      }
    })();
    omniboxText = null;
    alertText = null;
    return out;
  };

  expectSuggestionFor = function(text, output) {
    changeInput(text);
    return assertOmni(output);
  };

  expectResponseFor = function(text, output) {
    enterInput(text);
    return assertAlert(output);
  };

  expectNoResponseFor = function(text) {
    enterInput(text);
    return assertNoOutput();
  };

  assertFocus = function(winId, tabId) {
    if (winId !== focusedWindowId) {
      assert.fail("Expected window " + winId + " to be focused, was window " + focusedWindowId);
    }
    if (tabId !== openWindows[focusedWindowId].activeTabId) {
      return assert.fail("Excpected tab " + tabId + " to be focused, was tab " + openWindows[focusedWindowId].activeTabId);
    }
  };

  context("TabShepherd", should("initialize", function() {
    var def, win2;
    assert.equal('function', typeof TabShepherd);
    reset('init');
    assert.equal('object', typeof ts);
    assert.equal('blue', ts.getDefinition('goodbye').patterns[0]);
    if (inputChanged == null) {
      assert.fail("Input not changed");
    }
    if (inputEntered == null) {
      assert.fail("Input not entered");
    }
    win2 = openWindows[2];
    assert.equal('goodbye', ts.getName(win2));
    def = ts.getDefinition('goodbye');
    if (def == null) {
      assert.fail("No definition for goodbye");
    }
    def = ts.getDefinition(win2);
    if (def == null) {
      assert.fail("No definition for window " + win2.id);
    }
    return assert.equal('blue', def.patterns[0]);
  }));

  context("makeText", should("assemble strings", function() {
    reset('makeText');
    assert.equal('a string', ts.makeText('a string'));
    assert.equal("window \"2\"'s color is bluegreen", ts.makeText("window %w's color is %s", 2, 'bluegreen'));
    assert.equal("color is blue|green", ts.makeText("color is %s", 'blue|green'));
    assert.equal('color is /blue|green/', ts.makeText("color is %p", 'blue|green'));
    return assert.equal("color is 'bluegreen'", ts.makeText("color is %p", 'bluegreen'));
  }));

  context("Commands", should("show help", function() {
    changeInput('help', suggest);
    return assertOmni(/^Possible commands:/);
  }));

  context("Commands", should("show help on a command", function() {
    var cmd, name, ref, results;
    ref = ts.commands();
    results = [];
    for (name in ref) {
      if (!hasProp.call(ref, name)) continue;
      cmd = ref[name];
      changeInput("help " + name, suggest);
      if ((cmd.alias == null) && name !== 'help') {
        results.push(assertOmni(name + ": " + cmd.desc));
      } else {
        results.push(void 0);
      }
    }
    return results;
  }));

  context("name", should("handle command", function() {
    reset('name');
    expectSuggestionFor('name', 'Enter a name for this window.');
    expectResponseFor('name', 'No name provided.');
    expectSuggestionFor('name foo', 'Press enter to name this window "foo".');
    expectNoResponseFor('name foo');
    assert.equal('foo', ts.getName(openWindows[focusedWindowId]));
    assert.isTrue(defs['foo'] != null);
    assert.equal('foo', defs['foo'].name);
    expectSuggestionFor('name ', 'Enter a new name for this window (currently named "foo").');
    expectSuggestionFor('name blah', 'Press enter to change window name from "foo" to "blah".');
    enterInput('name blah');
    assert.equal('blah', ts.getName(openWindows[focusedWindowId]));
    assert.isTrue(defs['blah'] != null);
    assert.isFalse(defs['foo'] != null);
    return assert.equal('blah', defs['blah'].name);
  }));

  context("defs/clear", should("list and clear definitions", function() {
    reset('clearall');
    expectResponseFor('clear *', 'Cleared all window definitions.');
    assert.equal(0, Object.keys(defs).length);
    reset('defs');
    expectSuggestionFor('defs', 'Press enter to list the window definitions.');
    expectResponseFor('defs', "Named windows:\n\ngoodbye (window 2)");
    enterInput('name hi');
    expectResponseFor('defs', "Named windows:\n\ngoodbye (window 2)\nhi (window 1)");
    expectSuggestionFor('clear blah', 'Window definition "blah" not found.');
    expectSuggestionFor('clear goodbye', 'Press enter to clear window definition "goodbye". Warning: currently assigned to a window.');
    assert.equal(2, Object.keys(defs).length);
    assert.equal('goodbye', defs['goodbye'].name);
    expectResponseFor('clear goodbye', 'Cleared window definition "goodbye" and removed it from a window.');
    assert.equal(1, Object.keys(defs).length);
    return assert.equal(void 0, defs['goodbye']);
  }));

  context("new", should("handle command", function() {
    reset('new');
    expectSuggestionFor('new', 'Enter a name for the new window.');
    expectSuggestionFor('new yes', 'Press enter to open a new window and name it "yes".');
    expectSuggestionFor('new yes okay', 'Press enter to open a new window named "yes" and assign it the pattern \'okay\'.');
    expectSuggestionFor('new yes hello|goodbye', 'Press enter to open a new window named "yes" and assign it the pattern /hello|goodbye/.');
    expectNoResponseFor('new yes okay');
    assert.equal('yes', ts.getName(openWindows[focusedWindowId]));
    withSavedDef('yes', function(def) {
      assert.isTrue(def != null);
      assert.equal('yes', def.name);
      return assert.equal('okay', def.patterns[0]);
    });
    return expectSuggestionFor('new yes', 'There is already a window named "yes".');
  }));

  context("find", should("handle command", function() {
    reset('find');
    expectSuggestionFor('find', 'Enter a pattern to find a tab.');
    expectResponseFor('find', 'Enter a pattern to find a tab.');
    expectSuggestionFor('find things', "Press enter to focus the first of 3 tabs matching 'things'.");
    expectNoResponseFor('find things');
    assertFocus(1, 3);
    expectSuggestionFor('find really', "Press enter to focus the tab matching 'really'.");
    expectNoResponseFor('find really');
    assertFocus(1, 4);
    expectSuggestionFor('find sweet|bitter', "Press enter to focus the first of 2 tabs matching /sweet|bitter/.");
    expectNoResponseFor('find sweet|bitter');
    assertFocus(1, 3);
    expectSuggestionFor('find salty', "Press enter to focus the tab matching 'salty' in window \"goodbye\".");
    expectNoResponseFor('find salty');
    assertFocus(2, 6);
    expectSuggestionFor('find s[aeiou]{2}r', "Press enter to focus the tab matching /s[aeiou]{2}r/ in window \"goodbye\".");
    expectNoResponseFor('find s[aeiou]{2}r');
    assertFocus(2, 5);
    expectSuggestionFor('find umami', "No matching tabs found for 'umami'.");
    expectResponseFor('find umami', "No matching tabs found for 'umami'.");
    assertFocus(2, 5);
    expectSuggestionFor('find um.*mi', "No matching tabs found for /um.*mi/.");
    expectResponseFor('find um.*mi', "No matching tabs found for /um.*mi/.");
    assertFocus(2, 5);
    return assert.equal(2, Object.keys(openWindows).length);
  }));

  context('bring', should('handle command', function() {
    reset('bring');
    focusWindow(1);
    assert.equal(2, currentWindow().tabs.length);
    expectSuggestionFor('bring', 'Enter one or more patterns. No assigned patterns exist for this window.');
    expectSuggestionFor('bring umami', "No tabs found matching 1 given pattern.");
    expectSuggestionFor('bring umami poo', "No tabs found matching 2 given patterns.");
    expectSuggestionFor('bring sour', "Press enter to bring 1 tab matching 1 pattern to this window (unnamed).");
    expectSuggestionFor('bring a', "Press enter to bring 2 tabs matching 1 pattern to this window (unnamed).");
    expectSuggestionFor('bring sour really', "Press enter to bring 2 tabs matching 2 patterns to this window (unnamed).");
    focusWindow(2);
    assert.equal(2, currentWindow().tabs.length);
    expectSuggestionFor('bring sour', 'Press enter to bring 1 tab matching 1 pattern to this window "goodbye".');
    expectSuggestionFor('bring a', 'Press enter to bring 2 tabs matching 1 pattern to this window "goodbye".');
    expectSuggestionFor('bring sour really', 'Press enter to bring 2 tabs matching 2 patterns to this window "goodbye".');
    expectResponseFor('bring xxxx (xxxx)+', "No tabs found matching 2 given patterns:\n\n'xxxx'\n/(xxxx)+/");
    assert.equal(2, currentWindow().tabs.length);
    expectNoResponseFor('bring sour really');
    assert.equal(3, currentWindow().tabs.length);
    focusWindow(1);
    return assert.equal(1, currentWindow().tabs.length);
  }));

  context('send', should('send to existing window', function() {
    reset('sendexist');
    focusWindow(1);
    focusTab(3);
    assert.equal(2, currentWindow().tabs.length);
    expectSuggestionFor('send', 'Enter a window name to send this tab there.');
    expectSuggestionFor('send goodbye', "Press enter to send this tab to window \"goodbye\".");
    expectNoResponseFor('send goodbye');
    assert.equal(1, currentWindow().tabs.length);
    focusWindow(2);
    return assert.equal(3, currentWindow().tabs.length);
  }));

  context('send', should('send to new window', function() {
    reset('sendnew');
    focusTab(3);
    assert.equal(2, currentWindow().tabs.length);
    expectSuggestionFor('send whatever', "Press enter to send this tab to new window \"whatever\".");
    expectNoResponseFor('send whatever');
    assert.equal(1, currentWindow().tabs.length);
    focusWindow(9);
    assert.equal('whatever', ts.getName(currentWindow()));
    return assert.equal(1, currentWindow().tabs.length);
  }));

  context('extract', should('extract tabs', function() {
    reset('extract');
    expectSuggestionFor('extract', 'Enter a name or pattern.');
    expectSuggestionFor('extract nothing', "No tabs found matching 'nothing'. Enter more args to use it as a name.");
    expectSuggestionFor('extract salts?', "Press enter to extract 1 tab matching /salts?/ into a new window named \"salts?\".");
    expectSuggestionFor('extract things', "Press enter to extract 3 tabs matching 'things' into a new window named \"things\".");
    expectSuggestionFor('extract stuff things', "Press enter to extract 3 tabs matching 'things' into a new window named \"stuff\".");
    expectSuggestionFor('extract stuff th[io]ngs', "Press enter to extract 3 tabs matching /th[io]ngs/ into a new window named \"stuff\".");
    expectSuggestionFor('extract stuff things items', "Press enter to extract 3 tabs matching 2 patterns into a new window named \"stuff\".");
    expectResponseFor('extract nothing', 'No tabs found matching the given pattern(s).');
    assert.equal(2, Object.keys(openWindows).length);
    expectNoResponseFor('extract stuff things items');
    assert.equal(3, Object.keys(openWindows).length);
    focusWindow(1);
    assert.equal(0, currentWindow().tabs.length);
    focusWindow(2);
    assert.equal(1, currentWindow().tabs.length);
    focusWindow(9);
    assert.equal(3, currentWindow().tabs.length);
    return assert.equal('stuff', ts.getName(currentWindow()));
  }));

  Tests.run();

}).call(this);
