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

  var commands = {
    name: {
      desc: "Change the name of the current window definition",
      type: "Managing window definitions",
      examples: {"ts name awesome": "Create a definition for the current window named 'awesome'."},
      help: function () {
        var self = this;
        var newName = self.args[0];
        self.withCurrentWindow(function (win) {
          if (win.name) {
            if (newName)
              self.finish("Press enter to change name window name from '%s' to '%s'.", win.name, newName);
            else
              self.finish("Enter a new name for this window (currently named '%s').", win.name);
          }
          else {
            if (newName)
              self.finish("Press enter to name this window '%s'.", newName);
            else
              self.finish("Enter a name for this window.");
          }
        });
      },
      run: function () {
        var self = this;
        var name = self.args[0];
        if (!name)
          return self.finish("No name provided.");

        self.withCurrentWindow(function (win) {
          self.setName(win, name);
          self.finish();
        });
      }
    },
    defs: {
      desc: "List named window definitions",
      type: "Managing window definitions",
      examples: {"ts defs": "List all the window definitions that exist."},
      help: function () {
        var self = this;
        self.finish("Press enter to list the window definitions.");
      },
      run: function () {
        var self = this;
        var msg = '';
        for (var win in self.definitions){
          if (self.definitions.hasOwnProperty(win))
            msg += win + "\n";
        }

        self.finish("Named windows:\n\n%s", msg);
      }
    },
    new: {
      desc: "Create a new empty window and assign it a definition",
      type: "Managing window definitions",
      examples: {"ts new cats": "Create a new window with definition named 'cats'.",
                 "ts new cats \\bcats?\\b": "Create a new window with definition named 'cats' and containing one pattern. Move no tabs."},
      help: function () {
        var self = this;
        var name = self.args[0];
        if (!name)
          return self.finish("Enter a name for the new window.");

        self.withWindowNamed(name, function (win) {
          if (win)
            self.finish("There is already a window named '%s'.", name);
          else
            self.finish("Press enter to open a new window and name it '%s'.", name);
        });
      },
      run: function () {
        var self = this;
        var name = self.args[0];
        if (!name)
          return self.finish("No window name provided.");

        self.withWindowNamed(name, function (win) {
          if (win)
            return self.finish("There is already a window named '%s'.", name);

          self.withNewWindow(name, function () {
            self.finish();
          });
        });
      }
    },
    clear: {
      desc: "Clear window definitions",
      type: "Managing window definitions",
      examples: {"ts clear recipes": "Remove the window definition 'recipes'. No tabs are affected.",
                 "ts clear all data": "Remove all window definitions from storage. No tabs are affected."},
      help: function () {
        var self = this;
        var name = self.args[0];
        if (name == 'all data')
          return finish("Press enter to clear all saved window definitions.");

        self.withWindowNamed(name, function (win) {
          if (win)
            self.finish("Press enter to clear window definition '%s'. Warning: currently assigned to a window.", name);
          else if (definitions[name])
            self.finish("Press enter to clear window definition '%s', not currently assigned to a window.", name);
          else
            self.finish("Window definition '%s' not found.", name);
        })
      },
      run: function () {
        var self = this;
        var name = self.args[0];
        if (name == 'all data') {
          host.storage.local.remove('windows', function () {
            finish("Cleared all window data.");
          });
          return;
        }

        self.withWindowNamed(name, function (win) {
          if (win) {
            delete definitions[name];
            delete win.name;
            self.finish("Cleared window definition '%s' and removed it from a window.", name);
          }
          else if (definitions[name]) {
            delete definitions[name];
            self.finish("Cleared window definition '%s'.", name);
          }
          else
            self.finish("Window definition '%s' not found.", name);
        });
      }
    },
    clean: {
      desc: "Clean window data, removing definitions for which no window is present",
      type: "Managing window definitions",
      examples: {"ts clean": "Clean window data, removing definitions for which no window is present. No tabs are affected."},
      help: function () {
        var self = this;
        self.forEachDefinition(
          function (win) { return !win },                    // condition
          function (win, name) { return "'" + name + "'" },  // action if true
          function (msg) {                                   // finish
            self.finish(msg ? "Press enter to clean unused window definitions: " + msg : "No window definitions need cleaning.");
          });
      },
      run: function () {
        var self = this;
        self.forEachDefinition(
          function (win) { return !win }, // condition
          function (win, name) {          // action if true
            delete self.definitions[name];
            return "'" + name + "'";
          },
          function (msg) {                // finish
            self.finish(msg ? "Cleaned unused window definitions: " + msg : "No window definitions needed cleaning.");
          });
      }
    },
    unnamed: {
      desc: "Go to a window having no definition",
      type: "Managing window definitions",
      examples: {"ts unnamed": "Find a window with no definition if such exists, and focus it; else do nothing."},
      help: function () {
        var self = this;
        self.withWindow(function(win){ return !win.name }, function(win) {
          if (win)
            self.finish("Press enter to go to an open window that has no definition.");
          else
            self.finish("All windows have a definition.");
        });
      },
      run: function () {
        var self = this;
        self.withWindow(function(win){ return !win.name }, function(win) {
          if (win) focus(win);
          self.finish();
        });
      }
    },



    focus: {
      desc: "Switch to the window with the given name",
      type: "Changing focus",
      examples: {"ts focus work": "Focus the window named 'work'."},
      help: function () {
        var self = this;
        if (!self.getByName(name))
          return self.finish("Type a defined window name.");

        self.finish("Press enter to focus window '%s'.", name);
      },
      run: function () {
        var self = this;
        if (!self.getByName(name))
          return self.finish("No such window '%s'.", name);

        self.withWindowNamed(name, function(win) {
          if (!win) return self.finish("Window not found.");
          focus(win);
          self.finish();
        });
      }
    },
    find: {
      desc: "Find and focus a single tab",
      type: "Changing focus",
      examples: {"ts find google.com": "If there is exactly one tab whose URL matches /google.com/, focus its window and select it."},
      help: function () {
        var self = this;
        var pattern = self.args[0];
        self.withTabsMatching(pattern, function (matchingTabs) {
          if (matchingTabs.length > 1)
            return self.finish("Narrow the pattern; too many tabs match (%s).", matchingTabs.length);

          if (matchingTabs.length < 1)
            return self.finish("No matching tabs found for /%s/.", pattern);

          self.finish("Press enter to focus the matching tab.");
        });
      },
      run: function () {
        var self = this;
        var pattern = self.args[0];
        self.withTabsMatching(pattern, function (matchingTabs) {
          if (matchingTabs.length > 1)
            return self.finish("Narrow the pattern; too many tabs match (%s).", matchingTabs.length);

          if (matchingTabs.length < 1)
            return self.finish("No matching tabs found for /" + pattern + "/.");

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
      help: function () {
        var self = this;
        var pattern = self.args[0];
        if (!pattern)
          return finish("Enter a pattern.");

        self.withTabsMatching(pattern, function (matchingTabs) {
          var num = matchingTabs.length;
          if (num < 1) {
            self.finish("No tabs found matching /%s/.", pattern);
          }
          else {
            self.withCurrentWindow(function (win) {
              var name = win.name ? " '" + win.name + "'" : '';
              self.finish("Press enter: bring %s tabs matching /%s/ to this window%s.", num, pattern, name);
            });
          }
        });
      },
      run: function () {
        var self = this;
        var pattern = self.args[0];
        self.withTabsMatching(pattern, function (matchingTabs) {
          if (!pattern)
            return self.finish("Enter a pattern.");

          if (matchingTabs.length < 1)
            return self.finish("No tabs found matching /%s/.", pattern);

          self.withCurrentWindow(function (win) {
            host.tabs.move(matchingTabs, {windowId: win.id, index: -1}, function () {
              self.finish();
            });
          });
        });
      }
    },
    send: {
      desc: "Send the current tab to the window named in the argument",
      type: "Moving tabs",
      examples: {"ts send research": "Send the current tab to the window named 'research'."},
      help: function () {
        var self = this;
        var name = self.args[0];
        if (!name)
          return self.finish("Enter a window name to send this tab there.");

        var win = self.getByName(name);
        self.finish("Press enter to send this tab to " + (win ? "" : "new ") + "window '" + name + "'.");
      },
      run: function () {
        var self = this;
        var name = self.args[0];
        self.withActiveTab(function (tab) {
          var existingWin = getByName(name);
          if (existingWin) {
            host.tabs.move(tab.id, {windowId: existingWin.id, index: -1});
          }
          else {
            self.withNewWindow(name, function (win) {
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
      help: function () {
        var self = this;
        var pattern = self.args[0];
        self.withTabsMatching(pattern, function(matchingTabs) {
          var num = matchingTabs.length;
          if (!pattern) return self.finish("Enter a pattern.");
          if (num < 1) return self.finish("No tabs found matching /%s/.", pattern);
          self.finish("Press enter to extract %s tabs matching /%s/ into a new window.", num, pattern);
        });
      },
      run: function () {
        var self = this;
        var pattern = self.args[0];
        self.withTabsMatching(pattern, function (matchingTabs) {
          if (matchingTabs.length < 1)
            return self.finish("No tabs found matching /%s/.", pattern);

          self.withNewWindow(pattern, function (win) {
            host.tabs.move(matchingTabs, {windowId: win.id, index: -1}, function () {
              host.tabs.remove(win.tabs[win.tabs.length - 1].id, function () {
                self.finish();
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
        var self = this;
        self.finish("Press enter to sort all windows according to their assigned regexes.");
      },
      run: function () {
        var self = this;
      }
    },



    assign: {
      desc: "Assign a pattern to the current window",
      type: "Managing URL patterns",
      examples: {"ts assign reddit.com": "Add /reddit.com/ to this window's assigned patterns. No tabs are affected."},
      help: function () {
        var self = this;
        var pattern = self.args[0];
        if (!pattern)
          return self.finish("Enter a pattern to assign to this window.");

        self.withWindowForPattern(pattern, function(currWin) {
          if (currWin) {
            self.finish("Press enter to reassign /%s/ to this window from window '%s'.", pattern, currWin.name);
          }
          else {
            self.finish("Press enter to assign /%s/ to this window.", pattern);
          }
        });
      },
      run: function () {
        var self = this;
        var pattern = self.args[0];
        if (!pattern)
          return self.finish("No pattern provided.");

        self.withCurrentWindow(function (window) {
          self.withWindowForPattern(pattern, function(currWin) {
            var msg;
            if (currWin) {
              if (self.unassignPattern(pattern, currWin))
                msg = self.makeText("Pattern /%s/ was moved from window '%s' to window '%s'.", pattern, currWin.name, window.name);
              else
                self.finish("Could not unassign pattern %s from window %s.", pattern, currWin.name);
            }

            if (self.assignPattern(pattern, window))
              self.finish(msg);
            else
              self.finish("Could not assign pattern %s to window %s.", pattern, window.name);
          });
        });
      }
    },
    unassign: {
      desc: "Remove a pattern assignment from the current window",
      type: "Managing URL patterns",
      examples: {"ts unassign reddit.com": "Remove /reddit.com/ from this window's patterns if it is assigned. No tabs are affected."},
      help: function () {
        var self = this;
        var pattern = self.args[0];
        if (!pattern)
          return self.finish("Enter a pattern to remove from this window.");

        if (!self.containsPattern(pattern, window))
          return self.finish("Pattern /%s/ is not assigned to this window.", pattern);

        self.finish("Press enter to remove /%s/ from this window.", pattern);
      },
      run: function () {
        var self = this;
        if (!pattern)
          return self.finish("No pattern provided.");

        if (!self.containsPattern(pattern, window))
          return self.finish("Pattern /%s/ is not assigned to this window.");

        self.withCurrentWindow(function (window) {
          if (self.unassignPattern(pattern, window))
            self.finish();
          else
            self.finish("Could not unassign pattern %s from window %s.", pattern, window.name);
        });
      }
    },
    list: {
      desc: "List patterns assigned to the current window definition",
      type: "Managing URL patterns",
      examples: {"ts list": "List patterns assigned to the current window."},
      help: function () {
        var self = this;
        self.finish("Press enter to list the regexes assigned to this window.");
      },
      run: function () {
        var self = this;
        self.withCurrentWindow(function (window) {
          self.finish("Patterns assigned to window '%s':\n\n%s", window.name, self.listPatterns(window));
        });
      }
    },


    help: {
      desc: "Get help on a command",
      type: "Help",
      examples: {"ts help bring": "Show the usage examples for the \"bring\" command."},
      help: function () {
        var self = this;
        var arg = self.args[0];
        if (!arg || !commands[arg] || arg == 'help')
          self.finish(self.summarizeCommands(false));
        else
          self.finish(arg + ": " + self.getCommand(arg).desc);
      },
      run: function () {
        var self = this;
        self.finish(self.summarizeCommands(self.args[0]));
      }
    }
  };

  function Command(text, output){
    var self = this;

    self.cmd = self.getCommand(text);
    self.args = self.getArgs(text);
    self.output = output;
  }

  Command.prototype.getArgs = function (text) {
    if (text.indexOf(' ') < 0) return '';

    return text.substring(text.indexOf(' ') + 1).split(/\s+/);
  };

  Command.prototype.getCommand = function (text) {
    var idx = text ? text.indexOf(' ') : -1;
    var name = idx == -1 ? text : text.substring(0, idx);
    return commands[name] || commands['help'];
  };

  Command.prototype.showExamples = function (cmd) {
    if (!commands[cmd]) return;

    var msg = '"' + cmd + "\": " + commands[cmd].desc + ".\n\nExamples:\n\n";
    var command = commands[cmd];
    var examples = command.examples;
    for (var ex in examples){
      if (examples.hasOwnProperty(ex))
        msg += ex + "\n  " + examples[ex] + "\n\n";
    }

    return msg;
  };

  Command.prototype.summarizeCommands = function (full) {
    var msg = '';
    if (full && full !== true)
      return this.showExamples(full);

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

  Command.prototype.makeText = function (arr) {
    if (arr.length == 0) return undefined;
    if (arr.length == 1) return arr[0];

    var msg = arr[0];
    for (var i = 1; i < arr.length; i++){
      msg = msg.replace("%s", arr[i]);
    }

    return msg;
  };

  Command.prototype.getId = function (win) {
    if (typeof win == 'number') return win;
    if (typeof win == 'object') return win.id;
    alert ("Can't find id from " + (typeof win));
  };

  Command.prototype.focus = function (win) {
    host.windows.update(win.id, {focused: true}, function () { });
  };

  Command.prototype.getByName = function (name) {
    return this.definitions[name];
  };

  Command.prototype.setName = function (win, name) {
    delete this.definitions[win.name];
    this.definitions[name] = { id: win.id };
    win.name = name;
    win.def = this.definitions[name];
    return true;
  };

  Command.prototype.getName = function (win) {
    var id = this.getId(win);

    for (var name in this.definitions){
      if (this.definitions.hasOwnProperty(name) && this.definitions[name].id == id)
        return name;
    }

    return undefined;
  };

  Command.prototype.withActiveTab = function (callback) {
    host.tabs.query({active: true, currentWindow: true}, function (tabs) {
      callback(tabs[0]);
    });
  };

  Command.prototype.withNewWindow = function (name, callback) {
    var definitions = this.definitions;
    host.windows.create({type: "normal"}, function (win) {
      definitions[name] = { id: win.id };
      win.name = name;
      callback(win);
    });
  };

  Command.prototype.withWindow = function (test, callback) {
    host.windows.getAll({}, function (wins) {
      for (var i = 0; i < wins.length; i++)
        if (test(wins[i]))
          return callback(wins[i]);
    });
  };

  Command.prototype.withWindowNamed = function (name, callback) {
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

  Command.prototype.withCurrentWindow = function (callback) {
    var self = this;
    host.windows.getCurrent({}, function (win) {
      win.name = self.getName(win);
      callback(win);
    });
  };

  Command.prototype.getDefForPattern = function (pattern) {
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

  Command.prototype.withWindowForPattern = function (pattern, callback) {
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

  Command.prototype.assignPattern = function (pattern, win) {
    var name = win.name;
    if (!name) { alert ("Window has no name!"); return false; }
    if (!this.definitions[name]) { alert ("Window " + name + " has no definition!"); return false; }

    var def = this.definitions[name];
    if (!def.patterns) def.patterns = [];
    def.patterns.push(pattern);
    return true;
  };

  Command.prototype.unassignPattern = function (pattern, window) {

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

  Command.prototype.containsPattern = function (pattern) {
    if (!this.definitions[window.name])
      alert("Unknown window " + window.name);

    var regexes = this.definitions[window.name].regexes;
    if (!regexes) return false;

    for (var i = 0; i < regexes.length; i++){
      if (regexes[i] == pattern) return true;
    }

    return false;
  };

  Command.prototype.listPatterns = function (window) {
    var msg = '';
    var def = this.definitions[window.name];
    if (!def) return '';

    var patterns = def.patterns || [];
    for (var i = 0; i < patterns.length; i++) {
      var patt = patterns[i];
      msg += '/' + patt + "/\n";
    }

    return msg;
  };

  Command.prototype.withTabsMatching = function (text, callback) {
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
  Command.prototype.forEachWindow = function(condition, action, finish){
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

  Command.prototype.forEachDefinition = function(condition, action, finish){
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

  Command.prototype.close = function () {
    var keyNames = '', keys = Object.keys(this.definitions);
    for (var i = 0; i < keys.length; i++) {
      var key = keys[i];
      keyNames += key + "\n";
      var subkeyNames = Object.keys(this.definitions[key]);
      for (var j = 0; j < subkeyNames.length; j++) {
        var subkey = subkeyNames[j];
        keyNames += '  ' + subkey + "\n";
      }
    }

    alert("Setting windowDefs with keys:\n\n" + keyNames);
    host.storage.local.set({"windowDefs": this.definitions}, function () {
      if (host.runtime.lastError) alert(host.runtime.lastError);
    });
  };

  Command.prototype.finish = function (/* varargs */) {
    var status = this.makeText(arguments);
    this.output(status);
    if (this.saveData) this.close();
  };

  Command.prototype.run = function () {
    this.saveData = true;
    this.exec(this.cmd.run);
  };

  Command.prototype.help = function () {
    this.saveData = false;
    this.exec(this.cmd.help);
  };

  Command.prototype.exec = function (f) {
    var self = this;
    host.storage.local.get('windowDefs', function (data) {
      self.definitions = data['windowDefs'] || {};
      f.call(self);
    });
  };

  host.omnibox.onInputChanged.addListener(function (text, suggest) {
    new Command(text, function (res) {
      if (res) suggest([{content:' ', description:res}]);
    }).help();
  });

  host.omnibox.onInputEntered.addListener(function (text) {
    new Command(text, function (res) {
      if (res) alert(res);
    }).run();
  });

/*
  host.windows.onRemoved.addListener(function (winId){
    host.storage.local.get('windowDefs', function (data) {
      if (!data) return;
      var name = getName(winId);
      if (name){
        delete data[name];
        host.storage.local.set({"windowDefs": data}, function (){
          if (host.runtime.lastError) alert(host.runtime.lastError);
        });
      }
    });
  });
*/


  // init
  host.windows.getAll({}, function (wins) {
    host.storage.local.get('windowDefs', function (data) {
      var defs = data['windowDefs'];
      for (var i = 0; i < wins.length; i++) {
        var win = wins[i];
        for (defName in defs) {
          if (!defs.hasOwnProperty(defName)) continue;
          var def = defs[defName];
          if (def.id == win.id){
            win.name = defName;
            win.def = def;
          }
        }
      }
    });
  });

})(chrome);
