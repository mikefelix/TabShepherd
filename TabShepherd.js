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

  function Windows(windowData) {
    this.windowData = windowData;
  }

  Windows.prototype.focus = function (win) {
    host.windows.update(win.id, {focused: true}, function () { });
  };

  Windows.prototype.getByName = function (name) {
    return this.windowData[name];
  };

  Windows.prototype.setName = function (win, name) {
    delete this.windowData[win.name];
    this.windowData[name] = { id: win.id };
    win.name = name;
  };

  Windows.prototype.getName = function (win) {
    for (var name in this.windowData){
      if (this.windowData.hasOwnProperty(name) && this.windowData[name].id == win.id)
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
    var windowData = this.windowData;
    host.windows.create({type: "normal"}, function (win) {
      windowData[name] = { id: win.id };
      win.name = name;
      callback(win);
    });
  };

  Windows.prototype.withWindowNamed = function (name, callback) {
    var win = this.getByName(name);
    if (!win)
      alert("No window named " + name);

    host.windows.get(win.id, {}, function (w) {
      w.name = name;
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

  Windows.prototype.getWindowForRegex = function (regex) {

  };

  Windows.prototype.assignRegex = function (regex, window) {

  };

  Windows.prototype.unassignRegex = function (regex, window) {

  };

  Windows.prototype.containsRegex = function (regex) {
    if (!this.windowData[window.name])
      alert("Unknown window " + window.name);

    var regexes = this.windowData[window.name].regexes;
    if (!regexes) return false;

    for (var i = 0; i < regexes.length; i++){
      if (regexes[i] == regex) return true;
    }

    return false;
  };

  Windows.prototype.listRegexes = function (window) {

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
        var data = this.windowData[name];
        var res = condition(win, name, data) ?
                  action(win, name, data) :
                  '';
        msg = (msg ? ', ' : '') + res;
      }

      finish(msg);
    });
  };

  Windows.prototype.forEachDefinition = function(condition, action, finish){
    host.windows.getAll({}, function (wins) {
      var findWin = function (defName) {
        for (var i = 0; i < wins.length; i++) {
          var win = wins[i];
          if (win.name == defName) return win;
        }
        return undefined;
      };

      var msg = '';
      var names = Object.keys(this.windowData);
      for (var i = 0; i < names.length; i++){
        var name = names[i];
        var def = this.windowData[name];
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
      desc: "Change the name of the current window",
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
      help: function (arg, windows, finish) {
        finish("Press enter to list the window definitions.");
      },
      run: function (arg, windows, finish) {
        var msg = '';
        for (var win in windows.windowData){
          if (windows.windowData.hasOwnProperty(win))
            msg += win + "\n";
        }

        finish("Named windows:\n\n" + msg);
      }
    },
    new: {
      desc: "Create a new empty window and assign it a name",
      help: function (name, windows, finish) {
        if (!name)
          return finish("Enter a name for the new window.");

        windows.withWindowNamed(name, function (win) {
          if (win) finish("There is already a window named '" + name + "'.");
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
      desc: "Clear window definitions.",
      help: function (arg, windows, finish) {
        if (arg == 'all data')
          return finish("Press enter to clear all saved window definitions.");

        windows.withWindowNamed(name, function (win) {
          if (win)
            finish("Press enter to clear window definition '" + name + "'. Warning: currently assigned to a window.");
          else if (windows.windowData[name])
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
            delete windows.windowData[name];
            delete win.name;
            finish("Cleared window definition '" + name + "' and removed it from a window.");
          }
          else if (windows.windowData[name]) {
            delete windows.windowData[name];
            finish("Cleared window definition '" + name + "'.");
          }
          else
            finish("Window definition '" + name + "' not found.");
        });
      }
    },
    clean: {
      desc: "Clean window data, removing definitions for which no window is present.",
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
            delete windows.windowData[name];
            return "'" + name + "'";
          },
          function (msg) {                // finish
            finish(msg ? "Cleaned unused window definitions: " + msg : "No window definitions needed cleaning.");
          });
      }
    },
    focus: {
      desc: "Switch to the window with the given name",
      help: function (name, windows, finish) {
        if (!windows.getByName(name))
          return finish("Type a defined window name.");

        finish("Press enter to focus window '" + name + "'.");
      },
      run: function (name, windows, finish) {
        if (!windows.getByName(name))
          return finish("No such window '" + name + "'.");

        windows.withWindowNamed(name, function(win) {
          windows.focus(win);
          finish();
        });
      }
    },
    bring: {
      desc: "Bring tabs matching the regex argument to the current window",
      help: function (regex, windows, finish) {
        if (!regex)
          return finish("Enter a regex.");

        windows.withTabsMatching(regex, function (matchingTabs) {
          var num = matchingTabs.length;
          if (num < 1) {
            finish("No tabs found matching /" + regex + "/.");
          }
          else {
            windows.withCurrentWindow(function (win) {
              finish("Press enter: bring " + num + " tabs matching /" + regex + "/ to this window" + (win.name ? " '" + win.name + "'." : "."));
            });
          }
        });
      },
      run: function (regex, windows, finish) {
        windows.withTabsMatching(regex, function (matchingTabs) {
          if (!regex)
            return finish("Enter a regex.");

          if (matchingTabs.length < 1)
            return finish("No tabs found matching /" + regex + "/.");

          windows.withCurrentWindow(function (win) {
            host.tabs.move(matchingTabs, {windowId: win.id, index: -1}, function () {
              finish();
            });
          });
        });
      }
    },
    extract: {
      desc: "Extract tabs matching the regex argument into a new window named with that regex",
      help: function (regex, windows, finish) {
        windows.withTabsMatching(regex, function(matchingTabs) {
          var num = matchingTabs.length;
          if (!regex) return finish("Enter a regex.");
          if (num < 1) return finish("No tabs found matching /" + regex + "/.");
          finish("Press enter to extract " + num + " tabs matching /" + regex + "/ into a new window.");
        });
      },
      run: function (regex, windows, finish) {
        windows.withTabsMatching(regex, function (matchingTabs) {
          if (matchingTabs.length < 1)
            return finish("No tabs found matching /" + regex + "/.");

          windows.withNewWindow(regex, function (win) {
            host.tabs.move(matchingTabs, {windowId: win.id, index: -1}, function () {
              host.tabs.remove(win.tabs[win.tabs.length - 1].id, function () {
                finish();
              });
            });
          });
        });
      }
    },
    find: {
      desc: "Find and focus a single tab",
      help: function (regex, windows, finish) {
        windows.withTabsMatching(regex, function (matchingTabs) {
          if (matchingTabs.length > 1)
            return finish("Narrow the regex; too many tabs match (" + matchingTabs.length + ").");

          if (matchingTabs.length < 1)
            return finish("No matching tabs found for /" + regex + "/.");

          finish("Press enter to focus the matching tab.");
        });
      },
      run: function (regex, windows, finish) {
        windows.withTabsMatching(regex, function (matchingTabs) {
          if (matchingTabs.length > 1)
            return finish("Narrow the regex; too many tabs match (" + matchingTabs.length + ").");

          if (matchingTabs.length < 1)
            return finish("No matching tabs found for /" + regex + "/.");

          host.tabs.get(matchingTabs[0], function (tab) {
            host.windows.update(tab.windowId, {focused: true}, function () {
              host.tabs.update(tab.id, {highlighted: true}, function(){});
            })
          });
        });
      }
    },
    send: {
      desc: "Send the current tab to the window named in the argument",
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
    unnamed: {
      desc: "Go to a window having no definition.",
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
    assign: {
      desc: "Assign a regex to the current window",
      help: function (regex, windows, finish) {
        if (!regex)
          return finish("Enter a regex to assign to this window.");

        var currWin = windows.getWindowForRegex(regex);
        if (currWin) {
          finish("Press enter to reassign /" + arg + "/ to this window from window '" + currWin.name + "'.");
        }
        else {
          finish("Press enter to assign /" + arg + "/ to this window.");
        }
      },
      run: function (regex, windows, finish) {
        if (!regex)
          return finish("No regex provided.");

        windows.withCurrentWindow(function (window) {
          var msg;
          var currWin = windows.getWindowForRegex(regex);
          if (currWin) {
            windows.unassignRegex(regex, currWin);
            msg = "Regex /" + regex + "/ was moved from window '" + currWin.name + "' to window '" + window.name + "'.";
          }

          windows.assignRegex(regex, window);
          finish(msg);
        });
      }
    },
    unassign: {
      desc: "Remove a regex assignment from the current window",
      help: function (regex, windows, finish) {
        if (!regex)
          return finish("Enter a regex to remove from this window.");

        if (!windows.containsRegex(regex, window))
          return finish("Regex /" + regex + "/ is not assigned to this window.");

        finish("Press enter to remove /" + arg + "/ from this window.");
      },
      run: function (regex, windows, finish) {
        if (!regex)
          return finish("No regex provided.");

        if (!windows.containsRegex(regex, window))
          return finish("Regex /" + regex + "/ is not assigned to this window.");

        windows.withCurrentWindow(function (window) {
          windows.unassignRegex(regex, window);
          finish();
        });
      }
    },
    list: {
      desc: "List regexes assigned to the current window",
      help: function (arg, windows, finish) {
        finish("Press enter to list the regexes assigned to this window.");
      },
      run: function (arg, windows, finish) {
        windows.withCurrentWindow(function (window) {
          finish(windows.listRegexes(window));
        });
      }
    },
    sort: {
      desc: "Sort all tabs into windows by assigned regexes",
      help: function () {
        finish("Press enter to sort all windows according to their assigned regexes.");
      },
      run: function () {
      }
    },
    help: {
      desc: "Get help",
      help: function (arg) {
        if (!arg || !commands[arg] || arg == 'help')
          finish(summarizeCommands(false));
        else
          finish(arg + ": " + getCommand(arg).desc);
      },
      run: function () {
        finish(summarizeCommands(true));
      }
    }
  };

  var summarizeCommands = function (full) {
    var msg = '';
    if (full)
      msg += "Syntax: ts <command> <arguments>\n\n";

    msg += "Possible commands:" + (full ? "\n" : " ");

    for (var cmd in commands){
      if (commands.hasOwnProperty(cmd)) {
        if (full)
          msg += '  ' + cmd + ': ' + commands[cmd].desc + ".\n";
        else
          msg += cmd + ' ';
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
    host.storage.local.get('windows', function (windows) {
      var name = windows.getName(winId);
      if (name){
        delete windows[name];
        host.storage.local.set({windows: windows}, function (){
          if (host.runtime.lastError)
            alert(host.runtime.lastError);
        });
      }
    });
  });

})(chrome);
