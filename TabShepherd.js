var fchrome = {
  runtime: {

  },
  storageData: {},
  storage: {
    local: {
      get: function (name, cb) {
        var r = fchrome.storagedata[name];
        cb(r);
        return r;
      },
      set: function (data, cb) {
        fchrome.storagedata = data;
        cb();
      }
    }
  },
  windows: {

  },
  tabs: {

  },
  omnibox: {
    onInputChanged: {
      addListener: function (listener) {
        fchrome.changedListeners.push(listener);
      }
    },
    onInputEntered: {
      addListener: function (listener) {
        fchrome.enteredListeners.push(listener);
      }
    }
  },
  changedListeners: [],
  enteredListeners: []
};

(function (host) {

  var showExamples = function (cmd) {
    var msg = '"' + cmd + "\": " + commands[cmd].desc + ".\n\nExamples:\n\n";
    var command = commands[cmd];
    var examples = command.examples;
    for (var ex in examples){
      if (examples.hasOwnProperty(ex))
        msg += ex + "\n  " + examples[ex] + "\n\n";
    }

    return msg;
  };

  var summarizeCommands = function (full) {
    var msg = '';
    if (full && full !== true)
      return showExamples(full);

    if (full)
      msg += "Syntax: ts <command> <arguments>\n\n";

    msg += "Possible commands:" + (full ? "\n" : " ");

    var types = ["Moving tabs", "Changing focus", "Managing window definitions", "Managing URL patterns", "Help"];
    for (var i = 0; i < types.length; i++) {
      if (full) msg += '  ' + types[i] + ":\n";
      for (var cmd in commands) {
        if (commands.hasOwnProperty(cmd) && commands[cmd].type == types[i]) {
          if (full)
            msg += '    ' + cmd + ': ' + commands[cmd].desc + ".\n";
          else
            msg += cmd + ' ';
        }
      }
    }

    return msg;
  };

  var getArg = function (text) {
    return text.indexOf(' ') < 0 ? '' : text.substring(text.indexOf(' ') + 1);
  };

  var getCommand = function (text) {
    var idx = text ? text.indexOf(' ') : -1;
    var name = idx == -1 ? text : text.substring(0, idx);
    return commands[name] || commands['help'];
  };

  var getId = function (win) {
    if (typeof win == 'number') return win;
    if (typeof win == 'object') return win.id;
    alert ("Can't find id from " + (typeof win));
  };

  function Windows(definitions) {
    this.definitions = definitions;
  }

  Windows.prototype.focus = function (win) {
    host.windows.update(win.id, {focused: true}, function () { });
  };

  Windows.prototype.getByName = function (name) {
    return this.definitions[name];
  };

  Windows.prototype.setName = function (win, name) {
    delete this.definitions[win.name];
    this.definitions[name] = { id: win.id };
    win.name = name;
    win.def = this.definitions[name];
    return true;
  };

  Windows.prototype.getName = function (win) {
    var id = getId(win);

    for (var name in this.definitions){
      if (this.definitions.hasOwnProperty(name) && this.definitions[name].id == id)
        return name;
    }

    return undefined;
  };

  Windows.prototype.withActiveTab = function (callback) {
    host.tabs.query({active: true, currentWindow: true}, function (tabs) {
      callback(tabs[0]);
    });
  };

  Windows.prototype.withNewWindow = function (name, callback) {
    var definitions = this.definitions;
    host.windows.create({type: "normal"}, function (win) {
      definitions[name] = { id: win.id };
      win.name = name;
      callback(win);
    });
  };

  Windows.prototype.withWindow = function (test, callback) {
    host.windows.getAll({}, function (wins) {
      for (var i = 0; i < wins.length; i++)
        if (test(wins[i]))
          return callback(wins[i]);
    });
  };

  Windows.prototype.withWindowNamed = function (name, callback) {
    var def = this.getByName(name);
    if (!def) return callback();

    host.windows.get(def.id, {}, function (w) {
      if (w) {
        w.name = name;
        w.def = def;
      }

      callback(w);
    });
  };

  Windows.prototype.withCurrentWindow = function (callback) {
    var windows = this;
    host.windows.getCurrent({}, function (win) {
      win.name = windows.getName(win);
      callback(win);
    });
  };

  Windows.prototype.getDefForPattern = function (pattern) {
    for (var def in this.definitions){
      if (this.definitions.hasOwnProperty(def)){
        if (def.patterns){
          for (var i = 0; i < def.patterns.length; i++) {
            if (pattern == def.patterns[i]){
              return def;
            }
          }
        }
      }
    }

    return undefined;
  };

  Windows.prototype.withWindowForPattern = function (pattern, callback) {
    var def = this.getDefForPattern(pattern);
    if (!def) return callback();
    if (!def.id) {
      alert("Definition " + def + " found for pattern " + pattern + " but it has no assigned window.");
    }
    else {
      host.windows.get(def.id, {}, function (w) {
        w.def = def;
        callback(w);
      });
    }
  };

  Windows.prototype.assignPattern = function (pattern, win) {
    var name = win.name;
    if (!name) { alert ("Window has no name!"); return false; }
    if (!this.definitions[name]) { alert ("Window " + name + " has no definition!"); return false; }

    var def = this.definitions[name];
    if (!def.patterns) def.patterns = [];
    def.patterns.push(pattern);
    return true;
  };

  Windows.prototype.unassignPattern = function (pattern, window) {
    if (!window.name) {alert("Window has no name."); return false;}

    var def = this.definitions[window.name];
    if (!def) {alert ("No definition found for name " + window.name); return false; }
    if (!def.patterns) {alert ("No patterns found in window " + window.name); return false; }

    for (var i = 0; i < def.patterns.length; i++) {
      if (def.patterns[i] == pattern) {
        def.patterns.splice(i, 1);
        return true;
      }
    }

    alert("Could not delete pattern " + pattern + " from window " + window.name);
    return false;
  };

  Windows.prototype.containsPattern = function (pattern) {
    if (!this.definitions[window.name])
      alert("Unknown window " + window.name);

    var regexes = this.definitions[window.name].regexes;
    if (!regexes) return false;

    for (var i = 0; i < regexes.length; i++){
      if (regexes[i] == pattern) return true;
    }

    return false;
  };

  Windows.prototype.listPatterns = function (window) {
    var msg = '';
    var patterns = this.definitions[window.name].patterns || [];
    for (var i = 0; i < patterns.length; i++) {
      var patt = patterns[i];
      msg += '/' + patt + "/\n";
    }

    return msg;
  };

  Windows.prototype.withTabsMatching = function (text, callback) {
    var matches = function (keywords, tab) {
      for (var i = 0; i < keywords.length; i++) {
        if ((tab.url.toLowerCase()).search(keywords[i]) > -1) {
          return true;
        }
        if ((tab.title.toLowerCase()).search(keywords[i]) > -1) {
          return true;
        }
      }
      return false;
    };

    var matchingTabs = [];
    var queryInfo = {
      pinned: false,
      status: "complete",
      windowType: "normal"
    };

    host.tabs.query(queryInfo, function (tabs) {
      var keywords = text.toLowerCase().split(" ");
      if (keywords[0] == "")
        return callback([]);

      for (var i = 0; i < tabs.length; i++) {
        if (matches(keywords, tabs[i]))
          matchingTabs.push(tabs[i].id);
      }

      callback(matchingTabs);
    });
  };

  /*
        var findWin = function (defName) {
        for (var j = 0; j < chromeWindows.length; j++) {
          var win = chromeWindows[j];
          if (win.name == defName) return win;
        }
        return undefined;
      };
   */
  Windows.prototype.forEachWindow = function(condition, action, finish){
    host.windows.getAll({}, function (wins) {
      var msg = '';
      for (var i = 0; i < wins.length; i++){
        var win = wins[i];
        var name = win.name;
        if (!win.name) continue;
        var data = this.definitions[name];
        var res = condition(win, name, data) ?
                  action(win, name, data) :
                  '';
        msg = (msg ? ', ' : '') + res;
      }

      finish(msg);
    });
  };

  Windows.prototype.forEachDefinition = function(condition, action, finish){
    var defs = this.definitions;
    host.windows.getAll({}, function (wins) {
      var findWin = function (defName) {
        for (var i = 0; i < wins.length; i++) {
          var win = wins[i];
          if (win.name == defName) return win;
        }
        return undefined;
      };

      var msg = '';
      var names = Object.keys(defs);
      for (var i = 0; i < names.length; i++){
        var name = names[i];
        var def = defs[name];
        var win = findWin(name);
        if (condition(win, name, def)) {
          var res = action(win, name, def);
          msg = (msg ? ', ' : '') + res;
        }
      }

      finish(msg);
    });
  };

  var commands = {
    name: {
      desc: "Change the name of the current window definition",
      type: "Managing window definitions",
      examples: {"ts name awesome": "Create a definition for the current window named 'awesome'."},
      help: function (newName, windows, finish) {
        windows.withCurrentWindow(function (win) {
          if (win.name) {
            if (newName)
              finish("Press enter to change name window name from '" + win.name + "' to '" + newName + "'.");
            else
              finish("Enter a new name for this window (currently named '" + win.name + "').");
          }
          else {
            if (newName)
              finish("Press enter to name this window '" + newName + "'.");
            else
              finish("Enter a name for this window.");
          }
        });
      },
      run: function (name, windows, finish) {
        if (!name)
          return finish("No name provided.");

        windows.withCurrentWindow(function (win) {
          windows.setName(win, name);
          finish();
        });
      }
    },
    defs: {
      desc: "List named window definitions",
      type: "Managing window definitions",
      examples: {"ts defs": "List all the window definitions that exist."},
      help: function (arg, windows, finish) {
        finish("Press enter to list the window definitions.");
      },
      run: function (arg, windows, finish) {
        var msg = '';
        for (var win in windows.definitions){
          if (windows.definitions.hasOwnProperty(win))
            msg += win + "\n";
        }

        finish("Named windows:\n\n" + msg);
      }
    },
    new: {
      desc: "Create a new empty window and assign it a definition",
      type: "Managing window definitions",
      examples: {"ts new cats": "Create a new window with definition named 'cats'.",
                 "ts new cats \\bcats?\\b": "Create a new window with definition named 'cats' and containing one pattern. Move no tabs."},
      help: function (name, windows, finish) {
        if (!name)
          return finish("Enter a name for the new window.");

        windows.withWindowNamed(name, function (win) {
          if (win)
            finish("There is already a window named '" + name + "'.");
          else
            finish("Press enter to open a new window and name it '" + name + "'.");
        });
      },
      run: function (name, windows, finish) {
        if (!name)
          return finish("No window name provided.");

        windows.withWindowNamed(name, function (win) {
          if (win)
            return finish("There is already a window named '" + name + "'.");

          windows.withNewWindow(name, function () {
            finish();
          });
        });
      }
    },
    clear: {
      desc: "Clear window definitions",
      type: "Managing window definitions",
      examples: {"ts clear recipes": "Remove the window definition 'recipes'. No tabs are affected.",
                 "ts clear all data": "Remove all window definitions from storage. No tabs are affected."},
      help: function (arg, windows, finish) {
        if (arg == 'all data')
          return finish("Press enter to clear all saved window definitions.");

        windows.withWindowNamed(name, function (win) {
          if (win)
            finish("Press enter to clear window definition '" + name + "'. Warning: currently assigned to a window.");
          else if (windows.definitions[name])
            finish("Press enter to clear window definition '" + name + "', not currently assigned to a window.");
          else
            finish("Window definition '" + name + "' not found.");
        })
      },
      run: function (arg, windows, finish) {
        if (arg == 'all data') {
          host.storage.local.remove('windows', function () {
            finish("Cleared all window data.");
          });
          return;
        }

        windows.withWindowNamed(name, function (win) {
          if (win) {
            delete windows.definitions[name];
            delete win.name;
            finish("Cleared window definition '" + name + "' and removed it from a window.");
          }
          else if (windows.definitions[name]) {
            delete windows.definitions[name];
            finish("Cleared window definition '" + name + "'.");
          }
          else
            finish("Window definition '" + name + "' not found.");
        });
      }
    },
    clean: {
      desc: "Clean window data, removing definitions for which no window is present",
      type: "Managing window definitions",
      examples: {"ts clean": "Clean window data, removing definitions for which no window is present. No tabs are affected."},
      help: function (arg, windows, finish) {
        windows.forEachDefinition(
          function (win) { return !win },                    // condition
          function (win, name) { return "'" + name + "'" },  // action if true
          function (msg) {                                   // finish
            finish(msg ? "Press enter to clean unused window definitions: " + msg : "No window definitions need cleaning.");
          });
      },
      run: function (arg, windows, finish) {
        windows.forEachDefinition(
          function (win) { return !win }, // condition
          function (win, name) {          // action if true
            delete windows.definitions[name];
            return "'" + name + "'";
          },
          function (msg) {                // finish
            finish(msg ? "Cleaned unused window definitions: " + msg : "No window definitions needed cleaning.");
          });
      }
    },
    unnamed: {
      desc: "Go to a window having no definition",
      type: "Managing window definitions",
      examples: {"ts unnamed": "Find a window with no definition if such exists, and focus it; else do nothing."},
      help: function (arg, windows, finish) {
        windows.withWindow(function(win){ return !win.name }, function(win) {
          if (win)
            finish("Press enter to go to an open window that has no definition.");
          else
            finish("All windows have a definition.");
        });
      },
      run: function (arg, windows, finish) {
        windows.withWindow(function(win){ return !win.name }, function(win) {
          if (win) windows.focus(win);
          finish();
        });
      }
    },

    
    
    focus: {
      desc: "Switch to the window with the given name",
      type: "Changing focus",
      examples: {"ts focus work": "Focus the window named 'work'."},
      help: function (name, windows, finish) {
        if (!windows.getByName(name))
          return finish("Type a defined window name.");

        finish("Press enter to focus window '" + name + "'.");
      },
      run: function (name, windows, finish) {
        if (!windows.getByName(name))
          return finish("No such window '" + name + "'.");

        windows.withWindowNamed(name, function(win) {
          if (!win) return finish("Window not found.");
          windows.focus(win);
          finish();
        });
      }
    },
    find: {
      desc: "Find and focus a single tab",
      type: "Changing focus",
      examples: {"ts find google.com": "If there is exactly one tab whose URL matches /google.com/, focus its window and select it."},
      help: function (pattern, windows, finish) {
        windows.withTabsMatching(pattern, function (matchingTabs) {
          if (matchingTabs.length > 1)
            return finish("Narrow the pattern; too many tabs match (" + matchingTabs.length + ").");

          if (matchingTabs.length < 1)
            return finish("No matching tabs found for /" + pattern + "/.");

          finish("Press enter to focus the matching tab.");
        });
      },
      run: function (pattern, windows, finish) {
        windows.withTabsMatching(pattern, function (matchingTabs) {
          if (matchingTabs.length > 1)
            return finish("Narrow the pattern; too many tabs match (" + matchingTabs.length + ").");

          if (matchingTabs.length < 1)
            return finish("No matching tabs found for /" + pattern + "/.");

          host.tabs.get(matchingTabs[0], function (tab) {
            host.windows.update(tab.windowId, {focused: true}, function () {
              host.tabs.update(tab.id, {highlighted: true}, function(){});
            })
          });
        });
      }
    },



    bring: {
      desc: "Bring tabs matching a pattern to the current window",
      type: "Moving tabs",
      examples: {"ts bring cute.*bunnies.com": "Bring tabs whose URLs match the given pattern (e.g. cutewhitebunnies.com and cutefluffybunnies.com) to the current window.",
                 "ts bring": "Bring tabs whose URLs match all this window's assigned patterns to this window."},
      help: function (pattern, windows, finish) {
        if (!pattern)
          return finish("Enter a pattern.");

        windows.withTabsMatching(pattern, function (matchingTabs) {
          var num = matchingTabs.length;
          if (num < 1) {
            finish("No tabs found matching /" + pattern + "/.");
          }
          else {
            windows.withCurrentWindow(function (win) {
              finish("Press enter: bring " + num + " tabs matching /" + pattern + "/ to this window" + (win.name ? " '" + win.name + "'." : "."));
            });
          }
        });
      },
      run: function (pattern, windows, finish) {
        windows.withTabsMatching(pattern, function (matchingTabs) {
          if (!pattern)
            return finish("Enter a pattern.");

          if (matchingTabs.length < 1)
            return finish("No tabs found matching /" + pattern + "/.");

          windows.withCurrentWindow(function (win) {
            host.tabs.move(matchingTabs, {windowId: win.id, index: -1}, function () {
              finish();
            });
          });
        });
      }
    },
    send: {
      desc: "Send the current tab to the window named in the argument",
      type: "Moving tabs",
      examples: {"ts send research": "Send the current tab to the window named 'research'."},
      help: function (name, windows, finish) {
        if (!name)
          return finish("Enter a window name to send this tab there.");

        var win = windows.getByName(name);
        finish("Press enter to send this tab to " + (win ? "" : "new ") + "window '" + name + "'.");
      },
      run: function (name, windows, finish) {
        windows.withActiveTab(function (tab) {
          var existingWin = windows.getByName(name);
          if (existingWin) {
            host.tabs.move(tab.id, {windowId: existingWin.id, index: -1});
          }
          else {
            windows.withNewWindow(name, function (win) {
              host.tabs.move(tab.id, {windowId: win.id, index: -1}, function () {
                host.tabs.remove(win.tabs[win.tabs.length - 1].id, function () {
                  finish();
                });
              });
            });
          }
        });
      }
    },
    extract: {
      desc: "Extract tabs matching the pattern argument into a new window named with that pattern",
      type: "Moving tabs",
      examples: {"ts extract facebook": "Create a new window, give it a definition named 'facebook', assign /facebook/ to that definition, and move all tabs whose URLs match /facebook/ there. This is effectively \"ts new facebook\", followed by \"ts assign facebook\", then \"ts bring\". "},
      help: function (pattern, windows, finish) {
        windows.withTabsMatching(pattern, function(matchingTabs) {
          var num = matchingTabs.length;
          if (!pattern) return finish("Enter a pattern.");
          if (num < 1) return finish("No tabs found matching /" + pattern + "/.");
          finish("Press enter to extract " + num + " tabs matching /" + pattern + "/ into a new window.");
        });
      },
      run: function (pattern, windows, finish) {
        windows.withTabsMatching(pattern, function (matchingTabs) {
          if (matchingTabs.length < 1)
            return finish("No tabs found matching /" + pattern + "/.");

          windows.withNewWindow(pattern, function (win) {
            host.tabs.move(matchingTabs, {windowId: win.id, index: -1}, function () {
              host.tabs.remove(win.tabs[win.tabs.length - 1].id, function () {
                finish();
              });
            });
          });
        });
      }
    },
    sort: {
      desc: "Sort all tabs into windows by assigned patterns",
      type: "Moving tabs",
      examples: {"ts sort": "Move all tab that matches a defined pattern to that pattern's window. Effectively, perform \"ts bring\" for each window."},
      help: function () {
        finish("Press enter to sort all windows according to their assigned regexes.");
      },
      run: function () {
      }
    },



    assign: {
      desc: "Assign a pattern to the current window",
      type: "Managing URL patterns",
      examples: {"ts assign reddit.com": "Add /reddit.com/ to this window's assigned patterns. No tabs are affected."},
      help: function (pattern, windows, finish) {
        if (!pattern)
          return finish("Enter a pattern to assign to this window.");

        windows.withWindowForPattern(pattern, function(currWin) {
          if (currWin) {
            finish("Press enter to reassign /" + pattern + "/ to this window from window '" + currWin.name + "'.");
          }
          else {
            finish("Press enter to assign /" + pattern + "/ to this window.");
          }
        });
      },
      run: function (pattern, windows, finish) {
        if (!pattern)
          return finish("No pattern provided.");

        windows.withCurrentWindow(function (window) {
          windows.withWindowForPattern(pattern, function(currWin) {
            var msg;
            if (currWin) {
              if (windows.unassignPattern(pattern, currWin))
                msg = "Pattern /" + pattern + "/ was moved from window '" + currWin.name + "' to window '" + window.name + "'.";
              else
                finish("Could not unassign pattern " + pattern + " from window " + currWin.name);
            }

            if (windows.assignPattern(pattern, window))
              finish(msg);
            else
              finish("Could not assign pattern " + pattern + " to window " + window.name);
          });
        });
      }
    },
    unassign: {
      desc: "Remove a pattern assignment from the current window",
      type: "Managing URL patterns",
      examples: {"ts unassign reddit.com": "Remove /reddit.com/ from this window's patterns if it is assigned. No tabs are affected."},
      help: function (pattern, windows, finish) {
        if (!pattern)
          return finish("Enter a pattern to remove from this window.");

        if (!windows.containsPattern(pattern, window))
          return finish("Pattern /" + pattern + "/ is not assigned to this window.");

        finish("Press enter to remove /" + pattern + "/ from this window.");
      },
      run: function (pattern, windows, finish) {
        if (!pattern)
          return finish("No pattern provided.");

        if (!windows.containsPattern(pattern, window))
          return finish("Pattern /" + pattern + "/ is not assigned to this window.");

        windows.withCurrentWindow(function (window) {
          if (windows.unassignPattern(pattern, window))
            finish();
          else
            finish("Could not unassign pattern " + pattern + " from window " + window.name);
        });
      }
    },
    list: {
      desc: "List patterns assigned to the current window definition",
      type: "Managing URL patterns",
      examples: {"ts list": "List patterns assigned to the current window."},
      help: function (arg, windows, finish) {
        finish("Press enter to list the regexes assigned to this window.");
      },
      run: function (arg, windows, finish) {
        windows.withCurrentWindow(function (window) {
          finish("Patterns assigned to window '" + window.name + "':\n\n" + windows.listPatterns(window));
        });
      }
    },


    help: {
      desc: "Get help on a command",
      type: "Help",
      examples: {"ts help bring": "Show the usage examples for the \"bring\" command."},
      help: function (arg, windows, finish) {
        if (!arg || !commands[arg] || arg == 'help')
          finish(summarizeCommands(false));
        else
          finish(arg + ": " + getCommand(arg).desc);
      },
      run: function (arg, windows, finish) {
        finish(summarizeCommands(arg));
      }
    }
  };

  host.omnibox.onInputChanged.addListener(function (text, suggest) {
    host.storage.local.get('windows', function (data) {
      var command = getCommand(text);
      var arg = getArg(text);
      var windows = new Windows(data['windows'] || {});
      command.help(arg, windows, function (result) {
        if (result) suggest([{content: " ", description: result}]);
      });
    });
  });

  host.omnibox.onInputEntered.addListener(function (text) {
    host.storage.local.get('windows', function (data) {
      var stored = data['windows'] || {};
      var command = getCommand(text);
      var arg = getArg(text);
      var windows = new Windows(stored);
      var result = command.run(arg, windows, function (status) {
//        var str = ''; for (var key in stored){ str += key + "\n"; }; alert("Saving window data:\n" + str);
        host.storage.local.set({windows: stored}, function (){
          if (host.runtime.lastError)
            alert(host.runtime.lastError);
          else if (status)
            alert(status);
        });
      });

      if (result) alert(result);
    });
  });

  host.windows.onRemoved.addListener(function (winId){
    host.storage.local.get('windows', function (data) {
      if (!data['windows']) return;
      var stored = data['windows'];
      var windows = new Windows(stored);
      var name = windows.getName(winId);
      if (name){
        delete windows.definitions[name];
        host.storage.local.set({windows: stored}, function (){
          if (host.runtime.lastError)
            alert(host.runtime.lastError);
        });
      }
    });
  });

})(chrome);
