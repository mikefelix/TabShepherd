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

  var error = function(obj){
    alert(obj[0].description);
  };

  var show = function (func, text) {
    func([ {content: " ", description: text} ]);
  };

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
      show(error, "No window named " + name);

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

  var commands = {
    name: {
      desc: "Change the name of the current window",
      help: function (newName, windows, suggest) {
        windows.withCurrentWindow(function (win) {
          if (win.name) {
            if (newName)
              show(suggest, "Press enter to change name window name from '" + win.name + "' to '" + newName + "'.");
            else
              show(suggest, "Enter a new name for this window (currently named '" + win.name + "').");
          }
          else {
            if (newName)
              show(suggest, "Press enter to name this window '" + newName + "'.");
            else
              show(suggest, "Enter a name for this window.");
          }
        });
      },
      run: function (name, windows, onFinish) {
        windows.withCurrentWindow(function (win) {
          windows.setName(win, name);
          onFinish();
        });
      }
    },
    new: {
      desc: "Create a new window and assign it a name",
      help: function (newName, windows, suggest) {
        windows.withCurrentWindow(function (win) {
          if (newName)
            show(suggest, "Press enter to open a new window and name it '" + win.name + "'.");
          else
            show(suggest, "Enter a name for the new window.");
        });
      },
      run: function (name, windows, onFinish) {
        windows.withCurrentWindow(function (win) {
          onFinish();
        });
      }
    },
    clear: {
      help: function (name, windows, suggest) {
        show(suggest, "Clear all window data. Enter \"all data\" to confirm.");
      },
      run: function (arg) {
        if (arg == 'all data')
          host.storage.local.remove('windows', function () { show(error, "Cleared all window data.");});
        else
          show(error, "No data cleared. Type \"clear all data\" to clear.")
      }
    },
    focus: {
      desc: "Switch to the window with the given name",
      help: function (name, windows, suggest) {
        if (windows.getByName(name)) {
          show(suggest, "Press enter to focus window '" + name + "'.");
        }
        else {
          show(suggest, "Type a defined window name.");
        }
      },
      run: function (name, windows, onFinish) {
        windows.withWindowNamed(name, function(win) {
          windows.focus(win);
          onFinish();
        });
      }
    },
    bring: {
      desc: "Bring tabs matching the regex argument to the current window",
      help: function (regex, windows, suggest) {
        if (regex) {
          windows.withTabsMatching(regex, function (matchingTabs) {
            var num = matchingTabs.length;
            if (num < 1) {
              show(suggest, "No tabs found matching /" + regex + "/.")
            }
            else {
              windows.withCurrentWindow(function (win) {
                show(suggest, "Press enter: bring " + num +
                  " tabs matching /" + regex + "/ to this window" +
                  (win.name ? " '" + win.name + "'." : "."));
              });
            }
          });
        }
        else {
          show(suggest, "Enter a regex.");
        }
      },
      run: function (regex, windows, onFinish) {
        windows.withTabsMatching(regex, function (matchingTabs) {
          if (matchingTabs.length < 1) {
            show(error, "No tabs found matching /" + regex + "/.");
          }
          else {
            windows.withCurrentWindow(function (win) {
              host.tabs.move(matchingTabs, {windowId: win.id, index: -1}, function () {
                onFinish();
              });
            });
          }
        });
      }
    },
    extract: {
      desc: "Extract tabs matching the regex argument into a new window named with that regex",
      help: function (regex, windows, suggest) {
        windows.withTabsMatching(regex, function(matchingTabs) {
          var num = matchingTabs.length;
          if (!regex){
            show(suggest, "Enter a regex.");
          }
          else if (num < 1) {
            show(suggest, "No tabs found matching /" + regex + "/.")
          }
          else {
            show(suggest, "Press enter to extract " + num + " tabs matching /" + regex + "/ into a new window.");
          }
        });
      },
      run: function (regex, windows, onFinish) {
        windows.withTabsMatching(regex, function (matchingTabs) {
          if (matchingTabs.length < 1) {
            show(error, "No tabs found matching /" + regex + "/.");
          }
          else {
            windows.withNewWindow(regex, function (win) {
              host.tabs.move(matchingTabs, {windowId: win.id, index: -1}, function () {
                host.tabs.remove(win.tabs[win.tabs.length - 1].id, function () {
                  onFinish();
                });
              });
            });
          }
        });
      }
    },
    find: {
      desc: "Find and focus a single tab",
      help: function (regex, windows, suggest) {
        windows.withTabsMatching(regex, function (matchingTabs) {
          if (matchingTabs.length > 1) {
            show(suggest, "Too many tabs (" + matchingTabs.length + ") match /" + regex + "/ . Narrow the regex.");
          }
          else if (matchingTabs.length < 1) {
            show(suggest, "No matching tabs found for /" + regex + "/.");
          }
          else {
            show(suggest, "Press enter to focus the matching tab.");
          }
        });
      },
      run: function (regex, windows) {
        windows.withTabsMatching(regex, function (matchingTabs) {
          if (matchingTabs.length > 1) {
            show(error, "Narrow the regex; too many tabs match (" + matchingTabs.length + ").");
          }
          else if (matchingTabs.length < 1) {
            show(error, "No matching tabs found for /" + regex + "/.");
          }
          else {
            host.tabs.get(matchingTabs[0], function (tab) {
              host.windows.update(tab.windowId, {focused: true}, function () {
                host.tabs.update(tab.id, {highlighted: true}, function(){});
              })
            });
          }
        });
      }
    },
    send: {
      desc: "Send the current tab to the window named in the argument",
      help: function (name, windows, suggest) {
        if (name) {
          var win = windows.getByName(name);
          show(suggest, "Press enter to send this tab to " + (win ? "" : "new ") + "window '" + name + "'.");
        }
        else {
          show(suggest, "Enter a window name to send this tab there.");
        }
      },
      run: function (name, windows, onFinish) {
        windows.withActiveTab(function (tab) {
          var existingWin = windows.getByName(name);
          if (existingWin) {
            host.tabs.move(tab.id, {windowId: existingWin.id, index: -1});
          }
          else {
            windows.withNewWindow(name, function (win) {
              host.tabs.move(tab.id, {windowId: win.id, index: -1}, function () {
                host.tabs.remove(win.tabs[win.tabs.length - 1].id, function () {
                  onFinish();
                });
              });
            });
          }
        });
      }
    },
    assign: {
      desc: "Assign a regex to the current window",
      help: function (regex, windows, suggest) {
        if (regex) {
          show(suggest, "Press enter to assign /" + arg + "/ to this window.");
        }
        else {
          show(suggest, "Enter a regex to assign to this window.");
        }
      },
      run: function (regex, windows, onFinish) {
        if (regex) {
          windows.withCurrentWindow(function (window) {
            windows.assignRegex(regex, window);
            onFinish();
          });
        }
        else {
          show(error, "No regex provided.");
        }
      }
    },
    unassign: {
      desc: "Remove a regex assignment from the current window",
      help: function (regex, windows, suggest) {
        if (regex) {
          if (windows.containsRegex(regex, window)) {
            show(suggest, "Press enter to remove /" + arg + "/ from this window.");
          }
          else {
            show(suggest, "Regex /" + regex + "/ is not assigned to this window.");
          }
        }
        else {
          show(suggest, "Enter a regex to remove from this window.");
        }
      },
      run: function (regex, windows, onFinish) {
        if (regex) {
          if (windows.containsRegex(regex, window)) {
            windows.withCurrentWindow(function (window) {
              windows.unassignRegex(regex, window);
              onFinish();
            });
          }
          else {
            show(error, "Regex /" + regex + "/ is not assigned to this window.");
          }
        }
        else {
          show(error, "No regex provided.");
        }
      }
    },
    list: {
      desc: "List regexes assigned to the current window",
      help: function (arg, windows, suggest) {
        show(suggest, "Press enter to list the regexes assigned to this window.");
      },
      run: function (arg, windows, onFinish) {
        onFinish();
      }
    },
    sort: {
      desc: "Sort all tabs into windows by assigned regexes",
      help: function (arg, windows, suggest) {
        show(suggest, "Press enter to sort all windows according to their assigned regexes.");
      },
      run: function (arg, windows, onFinish) {
        onFinish();
      }
    },
    help: {
      desc: "Get help",
      help: function (arg, windows, suggest) {
        if (!arg || !commands[arg] || arg == 'help')
          show(suggest, summarizeCommands(false));
        else
          show(suggest, arg + ": " + getCommand(arg).desc);
      },
      run: function (arg) {
        show(error, summarizeCommands(true));
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
//    host.storage.local.remove('windows', function (data) { });
    host.storage.local.get('windows', function (data) {
      var command = getCommand(text);
      var arg = getArg(text);
      var windows = new Windows(data['windows'] || {});
      command.help(arg, windows, suggest);
    });
  });

  host.omnibox.onInputEntered.addListener(function (text) {
    host.storage.local.get('windows', function (data) {
      var stored = data['windows'] || {};
      var command = getCommand(text);
      var arg = getArg(text);
      var windows = new Windows(stored);
      command.run(arg, windows, function () {
//        var str = '';
//        for (var key in stored){ str += key + "\n"; }
//        alert("Saving window data:\n" + str);
        host.storage.local.set({windows: stored}, function (){
          if (host.runtime.lastError)
            alert(host.runtime.lastError);
        });
      });
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

function testTabShepherd(){
  fchrome.omnibox.enterInput("id")
}