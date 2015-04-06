class TabShepherd
  
  constructor: (@storage, @omnibox, @windows, @tabs) ->
    @omnibox.onInputChanged.addListener (text, suggest) ->
      c = new Command text, (res) ->
        suggest [ content: ' ', description: res ] if res
      c.help()

    @omnibox.onInputEntered.addListener (text) ->
      c = new Command text, (res) ->
        alert res if res
      c.run()

    # init
    @storage.get 'windowDefs', (data) ->
      defMatchesWin = (def, win, tabs) ->
        def.id == win.id or (tabs[0] and def.firstUrl == tabs[0].url)

      @windows.getAll {}, (wins) ->
        for win in wins
          @tabs.getAllInWindow win.id, (tabs) ->
            for own defName, def of data['windowDefs'] when defMatchesWin(def, win, tabs)
              win.name = defName
              win.def = def

  commands =
    n: alias: 'name'
    name:
      desc: 'Change the name of the current window definition'
      type: 'Managing window definitions'
      examples: 'ts name awesome': "Create a definition for the current window named 'awesome'."
      help: ->
        newName = @args[0]
        @withCurrentWindow (win) =>
          if win.name?
            if newName?
              @finish "Press enter to change name window name from '%s' to '%s'.", win.name, newName
            else
              @finish "Enter a new name for this window (currently named '%s').", win.name
          else
            if newName?
              @finish "Press enter to name this window '%s'.", newName
            else
              @finish 'Enter a name for this window.'
      run: ->
        name = @args[0]
        return @finish('No name provided.') if !name
        @withCurrentWindow (win) =>
          @setName win, name
          @finish()
    attach:
      desc: 'Attach the current window to a previously defined window definition'
      type: 'Managing window definitions'
      examples: 'ts attach work': 'Attach the current window to the existing window definition called \'work\'.'
      help: ->
        @withCurrentWindow (win) =>
      run: ->
        @withCurrentWindow (win) =>
    defs:
      desc: 'List named window definitions'
      type: 'Managing window definitions'
      examples: 'ts defs': 'List all the window definitions that exist.'
      help: ->
        @finish 'Press enter to list the window definitions.'
      run: ->
        msg = ''
        @forEachDefinition
          run: (def, win, name) =>
            msg += name + ' (' + (if win then 'window ' + win.id else 'no attached window') + ')\n'
          then: =>
            @finish 'Named windows:\n\n%s', msg
    new:
      desc: 'Create a new empty window and assign it a definition'
      type: 'Managing window definitions'
      examples:
        'ts new cats': 'Create a new window with definition named \'cats\'.'
        'ts new cats \\bcats?\\b': 'Create a new window with definition named \'cats\' and containing one pattern. Move no tabs.'
      help: ->
        name = @args[0]
        return @finish('Enter a name for the new window.') if !name
        @withWindowNamed name, (win) =>
          if win?
            @finish 'There is already a window named \'%s\'.', name
          else
            @finish 'Press enter to open a new window and name it \'%s\'.', name
      run: ->
        name = @args[0]
        return @finish('No window name provided.') if !name
        @withWindowNamed name, (win) =>
          return @finish('There is already a window named \'%s\'.', name) if win
          @withNewWindow name, =>
            @finish()
    clear:
      desc: 'Clear window definitions'
      type: 'Managing window definitions'
      examples:
        'ts clear recipes': 'Remove the window definition \'recipes\'. No tabs are affected.'
        'ts clear all data': 'Remove all window definitions from storage. No tabs are affected.'
      help: ->
        name = @args[0]
        return finish('Press enter to clear all saved window definitions.') if name == 'all data'
        @withWindowNamed name, (win) =>
          if win?
            @finish 'Press enter to clear window definition \'%s\'. Warning: currently assigned to a window.', name
          else if definitions[name]
            @finish 'Press enter to clear window definition \'%s\', not currently assigned to a window.', name
          else
            @finish 'Window definition \'%s\' not found.', name
      run: ->
        name = @args[0]
        if name == 'all data'
          @storage.remove 'windows', =>
            @finish 'Cleared all window data.'
        @withWindowNamed name, (win) =>
          if win?
            delete definitions[name]
            delete win.name
            @finish 'Cleared window definition \'%s\' and removed it from a window.', name
          else if definitions[name]?
            delete definitions[name]
            @finish 'Cleared window definition \'%s\'.', name
          else
            @finish 'Window definition \'%s\' not found.', name
    clean:
      desc: 'Clean window data, removing definitions for which no window is present'
      type: 'Managing window definitions'
      examples: 'ts clean': 'Clean window data, removing definitions for which no window is present. No tabs are affected.'
      help: ->
        @forEachDefinition
          where: (def, win) -> !win
          run: (def, win, name) -> "'#{name}'"
          then: (msg) -> @finish if msg then 'Press enter to clean unused window definitions: ' + msg else 'No window definitions need cleaning.'
      run: ->
        @forEachDefinition
          where: (def, win) -> !win
          run: (def, win, name) =>
            delete @definitions[name]
            "'#{name}'"
          then: (msg) -> @finish if msg then 'Cleaned unused window definitions: ' + msg else 'No window definitions needed cleaning.'
    unnamed:
      desc: 'Go to a window having no definition'
      type: 'Managing window definitions'
      examples: 'ts unnamed': 'Find a window with no definition if such exists, and focus it; else do nothing.'
      help: ->
        @withWindow ((win) -> not win.name?), (win) =>
          if win?
            @finish 'Press enter to go to an open window that has no definition.'
          else
            @finish 'All windows have a definition.'
      run: ->
        @withWindow ((win) -> not win.name?), (win) =>
          focus win if win
          @finish()
    focus:
      desc: 'Switch to the window with the given name'
      type: 'Changing focus'
      examples: 'ts focus work': "Focus the window named 'work'."
      help: ->
        name = @args[0]
        if !@getDefinition(name)
          @finish('Type a defined window name.')
        else
          @finish "Press enter to focus window '%s'.", name
      run: ->
        name = @args[0]
        if !@getDefinition(name)
          @finish("No such window '%s'.", name)
        else @withWindowNamed name, (win) =>
          if !win?
            @finish("Window not found: '%s'.", name)
          else
            @focus win
            @finish()
    f: alias: 'find'
    go: alias: 'find'
    find:
      desc: 'Go to the first tab found matching a pattern.'
      type: 'Changing focus'
      examples: 'ts find google.com': 'Focus the first tab found to match /google.com/.'
      help: ->
        pattern = @args[0]
        @withTabsMatching pattern, (matchingTabs) =>
          if matchingTabs.length > 1
            @finish 'Press enter to focus the first of %s tabs matching /%s/.', matchingTabs.length, pattern
          else if matchingTabs.length == 1
            @finish 'Press enter to focus the tab matching /%s/.', pattern
          else
            @finish 'No matching tabs found for /%s/.', pattern
      run: ->
        pattern = @args[0]
        @withTabsMatching pattern, (matchingTabs) =>
          if matchingTabs.length >= 1
            @tabs.get matchingTabs[0], (tab) ->
              @windows.update tab.windowId, { focused: true }, ->
                @tabs.update tab.id, { highlighted: true }, ->
          else
            @finish("No matching tabs found for /#{pattern}/.")
    b: alias: 'bring'
    bring:
      desc: 'Bring tabs matching a pattern to the current window'
      type: 'Moving tabs'
      examples:
        'ts bring cute.*bunnies.com': 'Bring tabs whose URLs match the given pattern (e.g. cutewhitebunnies.com and cutefluffybunnies.com) to the current window.'
        'ts bring': 'Bring tabs whose URLs match all this window\'s assigned patterns to this window.'
      help: ->
        @withCurrentWindow (win) =>
          patterns = undefined
          if @args.length > 0
            patterns = @args
          else
            def = @getDefinition(win.name)
            if not (def? and def.patterns? and def.patterns.length == 0)
              @finish('Enter one or more patterns. No assigned patterns exist for this window.')
            else
              patterns = def.patterns
          @withTabsMatching patterns, (matchingTabs) =>
            num = matchingTabs.length
            if num < 1
              @finish 'No tabs found matching given pattern(s).'
            else
              name = if win.name then "'#{win.name}'" else ''
              @finish 'Press enter to bring %s tabs matching %s pattern(s) to this window%s, or enter different patterns.', num, patterns.length, name
      run: ->
        @withCurrentWindow (win) =>
          patterns = undefined
          noneMsg = 'Error'
          if @args.length > 0
            noneMsg = 'No tabs found matching %s given pattern%s:\n\n%s'
            patterns = @args
          else
            def = @getDefinition(win.name)
            if !def or !def.patterns or def.patterns.length == 0
              @finish('No patterns entered and this window has no assigned patterns.')
            else
              noneMsg = 'No tabs found matching %s assigned pattern%s:\n\n%s'
              patterns = def.patterns
          @withTabsMatching patterns, (matchingTabs) ->
            if matchingTabs.length < 1
              @finish(noneMsg, patterns.length, (if patterns.length == 1 then '' else 's'), @mkString(patterns, '\n'))
            else
              @tabs.move windowId: win.id, index: -1, -> @finish()
    s: alias: 'send'
    send:
      desc: 'Send the current tab to the window named in the argument'
      type: 'Moving tabs'
      examples: 'ts send research': 'Send the current tab to the window named \'research\'.'
      help: ->
        name = @args[0]
        if not name?
          @finish('Enter a window name to send this tab there.')
        else
          win = @getDefinition(name)
          @finish 'Press enter to send this tab to %swindow \'%s\'.', (if win? then '' else 'new '), name
      run: ->
        name = @args[0]
        @withActiveTab (tab) =>
          existingWin = @getDefinition(name)
          if existingWin?
            @tabs.move tab.id,
              windowId: existingWin.id
              index: -1
          else
            @withNewWindow name, (win) ->
              @tabs.move tab.id, {
                windowId: win.id
                index: -1
              }, ->
                @tabs.remove win.tabs[win.tabs.length - 1].id, ->
                  @finish()
    o: alias: 'open'
    open:
      desc: 'Open a URL or search in a different window'
      type: 'Moving tabs'
      examples: 'ts open work google.com': 'Opens the URL \'http://google.com\' in the window \'work\'.'
      help: ->
        name = @args[0]
        url = @args[1]
        if not (name? and url?)
          @finish('Enter a window name followed by a URL to open the URL there.')
        else
          win = @getDefinition(name)
          @finish 'Press enter to open this URL in %swindow \'%s\'.', (if win then '' else 'new '), name
      run: ->
        name = @args[0]
        url = @args[1]
        return @finish('Enter a window name followed by a URL.') if !name or !url

        openTab = (win) =>
          url = 'http://' + url if !/^http:\/\//.test(url)
          @tabs.create windowId: win.id, url: url, ->
            @finish()

        @withWindowNamed name, (existingWin) =>
          if existingWin?
            openTab existingWin
          else
            @withNewWindow name, (win) ->
              openTab win
    e: alias: 'extract'
    ex: alias: 'extract'
    extract:
      desc: 'Extract tabs matching the pattern argument into a new window named with that pattern'
      type: 'Moving tabs'
      examples: 'ts extract social facebook.com twitter.com': 'Create a new window, give it a definition named \'social\', assign patterns /facebook.com/ and /twitter.com/ to that definition, and move all tabs whose URLs match the patterns there. This is effectively "ts new social", followed by "ts assign facebook.com twitter.com", then "ts bring". '
      help: ->
        if @args.length == 0
          @finish('Enter a name or pattern.')
        else
          name = @args[0]
          patterns = if @args.length == 1 then [ @args[0] ] else @args.slice(1)
          @withTabsMatching patterns, (matchingTabs) =>
            num = matchingTabs.length
            if num < 1
              @finish('No tabs found matching the given pattern(s).')
            else
              @finish 'Press enter to extract %s tab(s) matching /%s/%s into a new window named \'%s\'.', num, patterns[0], (if patterns.length > 1 then ', ...' else ''), name
      run: ->
        if @args.length == 0
          @finish('Enter a name or pattern.')
        else
          name = @args[0]
          patterns = if @args.length == 1 then [ @args[0] ] else @args.slice(1)
          @withTabsMatching patterns, (matchingTabs) =>
            if matchingTabs.length < 1
              @finish('No tabs found matching the given pattern(s).')
            else
              @withNewWindow name, (win) ->
                @tabs.move matchingTabs, windowId: win.id,index: -1, ->
                  win.name = name
                  win.patterns = patterns
                  @tabs.remove win.tabs[win.tabs.length - 1].id, ->
                    @finish()
    sort:
      desc: 'Sort all tabs into windows by assigned patterns'
      type: 'Moving tabs'
      examples: 'ts sort': 'Move all tab that matches a defined pattern to that pattern\'s window. Effectively, perform "ts bring" for each window.'
      help: ->
        @finish 'Press enter to sort all windows according to their assigned regexes.'
      run: ->
    merge:
      desc: 'Merge all the tabs from a window into this window.'
      type: 'Moving tabs'
      examples: 'ts merge restaurants': 'Move all the tabs from the window \'restaurants\' into the current window and remove the \'restaurants\' definition.'
      help: ->
      run: ->
    assign:
      desc: 'Assign a pattern to the current window'
      type: 'Managing URL patterns'
      examples: 'ts assign reddit.com': 'Add /reddit.com/ to this window\'s assigned patterns. No tabs are affected.'
      help: ->
        pattern = @args[0]
        if not pattern?
          @finish('Enter a pattern to assign to this window.')
        else
          @withWindowForPattern pattern, (currWin) =>
            if currWin?
              @finish 'Press enter to reassign /%s/ to this window from window \'%s\'.', pattern, currWin.name
            else
              @finish 'Press enter to assign /%s/ to this window.', pattern
      run: ->
        pattern = @args[0]
        if not pattern?
          @finish('No pattern provided.')
        else
          @withCurrentWindow (window) ->
            @withWindowForPattern pattern, (currWin) ->
              msg = undefined
              if currWin?
                if @unassignPattern(pattern, currWin)
                  msg = @makeText('Pattern /%s/ was moved from window \'%s\' to window \'%s\'.', pattern, currWin.name, window.name)
                else
                  @finish 'Could not unassign pattern %s from window %s.', pattern, currWin.name
              if @assignPattern(pattern, window)
                @finish msg
              else
                @finish 'Could not assign pattern %s to window %s.', pattern, window.name
    unassign:
      desc: 'Remove a pattern assignment from the current window'
      type: 'Managing URL patterns'
      examples: 'ts unassign reddit.com': 'Remove /reddit.com/ from this window\'s patterns if it is assigned. No tabs are affected.'
      help: ->
        pattern = @args[0]
        if not pattern?
          @finish('Enter a pattern to remove from this window.')
        else if !@containsPattern(pattern, window)
          @finish('Pattern /%s/ is not assigned to this window.', pattern)
        else
          @finish 'Press enter to remove /%s/ from this window.', pattern
      run: ->
        if not pattern?
          @finish('No pattern provided.')
        else if !@containsPattern(pattern, window)
          @finish('Pattern /%s/ is not assigned to this window.')
        else
          @withCurrentWindow (window) =>
            if @unassignPattern(pattern, window)
              @finish()
            else
              @finish 'Could not unassign pattern %s from window %s.', pattern, window.name
    patterns:
      desc: 'List patterns assigned to the current window definition'
      type: 'Managing URL patterns'
      examples: 'ts patterns': 'List patterns assigned to the current window.'
      help: ->
        @finish 'Press enter to list the patterns assigned to this window.'
      run: ->
        @withCurrentWindow (window) =>
          @finish 'Patterns assigned to window \'%s\':\n\n%s', window.name, @listPatterns(window)
    help:
      desc: 'Get help on a command'
      type: 'Help'
      examples: 'ts help bring': 'Show the usage examples for the "bring" command.'
      help: ->
        arg = @args[0]
        if !arg or !commands[arg] or arg == 'help'
          @finish @summarizeCommands(false)
        else
          @finish arg + ': ' + @getCommand(arg).desc
      run: ->
        @finish @summarizeCommands(arg)

  class Command
    constructor: (text, output) ->
      @cmd = @getCommand(text)
      @args = @getArgs(text)
      @output = output

    getArgs: (text) ->
      text = text.trim()
      return [] if !/^\w+\s+\w+/.test(text)
      text.replace(/^\w+\s+/, '').split /\s+/

    getCommand: (text) ->
      idx = if text then text.indexOf(' ') else -1
      name = if idx == -1 then text else text.substring(0, idx)
      if commands[name]
        if commands[name]['alias']
          commands[commands[name]['alias']]
        else
          commands[name]
      else
        commands['help']

    showExamples: (cmd) ->
      return '' if not commands[cmd]?
      msg = '"' + cmd + '": ' + commands[cmd].desc + '.\n\nExamples:\n\n'
      command = commands[cmd]
      examples = command.examples
      for ex of examples
        msg += "#{ex}\n  #{examples[ex]}\n\n"
      msg

    summarizeCommands: (full) ->
      msg = ''
      return @showExamples(full) if full and full != true
      msg += 'Syntax: ts <command> <arguments>\n\n' if full
      msg += 'Possible commands:' + (if full then '\n' else ' ')
      types = [
        'Moving tabs'
        'Changing focus'
        'Managing window definitions'
        'Managing URL patterns'
        'Help'
      ]
      for type in types
        msg += "  #{type}:\n" if full
        for own name, cmd of commands when cmd.type == type
          if full
            msg += "    #{name}: #{cmd.desc}.\n"
          else
            msg += name + ' '
      msg

    makeText: (arr) ->
      return undefined if arr.length == 0
      return arr[0] if arr.length == 1
      a.replace('%s', a) for a in arr[1..]

    getId: (win) ->
      if typeof win == 'number'
        win
      else if typeof win == 'object'
        win.id
      else
        alert "Can't find id from " + typeof win

    focus: (win) ->
      @windows.update win.id, { focused: true }, ->

    getDefinition: (name) ->
      @definitions[name]

    setName: (win, name) ->
      delete @definitions[win.name]
      @definitions[name] = id: win.id
      win.name = name
      win.def = @definitions[name]

    getName: (win) ->
      id = @getId(win)
      for own name of @definitions
        return name if @definitions[name].id == id
      undefined

    withActiveTab: (callback) ->
      @tabs.query active: true, currentWindow: true, (tabs) ->
        callback tabs[0]

    withNewWindow: (name, callback) ->
      definitions = @definitions
      @windows.create type: 'normal', (win) ->
        definitions[name] = id: win.id
        win.name = name
        callback win

    withWindow: (test, callback) ->
      @windows.getAll {}, (wins) ->
        for win in wins
          return callback(win) if test(win)

    withWindowNamed: (name, callback) ->
      def = @getDefinition(name)
      return callback() if !def
      @windows.get def.id, {}, (w) ->
        if w
          w.name = name
          w.def = def
        callback w

    withCurrentWindow: (callback) ->
      @windows.getCurrent {}, (win) ->
        win.name = @getName(win)
        callback win

    getDefForPattern: (pattern) ->
      for own name, def of @definitions when def.patterns
        for pattern in def.patterns
          return def if pattern == def.patterns[i]

    withWindowForPattern: (pattern, callback) ->
      def = @getDefForPattern(pattern)
      return callback() if not def?
      if not def.id?
        alert "Definition #{def} found for pattern #{pattern} but it has no assigned window."
      else
        @windows.get def.id, {}, (w) ->
          w.def = def
          callback w

    assignPattern: (pattern, win) ->
      name = win.name
      if not name?
        alert 'Window has no name!'
        return false
      if not @definitions[name]?
        alert "Window #{name} has no definition!"
        return false
      def = @definitions[name]
      if not def.patterns?
        def.patterns = []
      def.patterns.push pattern
      true

    unassignPattern: (pattern, window) ->
      if not window.name?
        alert 'Window has no name.'
        return false
      def = @definitions[window.name]
      if not def?
        alert 'No definition found for name ' + window.name
        return false
      if not def.patterns?
        alert 'No patterns found in window ' + window.name
        return false
      i = 0
      while i < def.patterns.length
        if def.patterns[i] == pattern
          def.patterns.splice i, 1
          return true
        i++
      alert "Could not delete pattern #{pattern} from window '#{window.name}'."
      false

    containsPattern: (pattern) ->
      if !@definitions[window.name]
        alert 'Unknown window ' + window.name
      regexes = @definitions[window.name].regexes
      return false if !regexes
      for regex in regexes
        return true if regex == pattern
      false

    listPatterns: (window) ->
      def = @definitions[window.name]
      return '' if !def
      patterns = def.patterns or []
      "/#{patt}/\n" for patt in patterns

    withTabsMatching: (patterns, callback) ->
      return callback([]) if !patterns
      patterns = [ patterns ] if typeof patterns == 'string'
      return callback([]) if patterns.length == 0 or patterns[0] == ''

      matches = (tab) ->
        for p in patterns
          if /^\/.*\/$/.test(p)
            r = new RegExp(p)
            return true if r.test(tab.url) or r.test(tab.title)
          else if /[*+?{}\[\]]/.test(p)
            r = new RegExp('/' + p.replace(/\//, '\\/') + '/i')
            return true if r.test(tab.url) or r.test(tab.title)
          else
            return true if tab.url.toLowerCase().search(p) > -1 or tab.title.toLowerCase().search(p) > -1
        false

      @tabs.query pinned: false, status: 'complete', windowType: 'normal', (tabs) ->
        matchingTabs = (tab.id for tab in tabs when matches(tab))
        callback matchingTabs

    forEachWindow: (args) ->
      condition = args.where or -> true
      action = args.run
      finish = args.then
      @windows.getAll {}, (wins) =>
        def = @definitions[win.name]
        msgs = action(win, def, win.name) for win in wins when condition(win, def, win.name)
        finish msgs.join(',')

    forEachDefinition: (args) ->
      condition = args.where or -> true
      action = args.run
      finish = args.then
      @windows.getAll {}, (wins) =>
        findWin = (defName) ->
          for win in wins
            return win if win.name == defName
          undefined
        msgs = for own name, def of @definitions
          win = findWin(name)
          if condition(def, win, name)
            msgs.push action(def, win, name)
        if finish
          finish msgs.join(',')

    close: ->
      @forEachDefinition
        run: (def, win) ->
          if win
            @tabs.query index: 0, windowId: win.id, (tab) ->
              def.firstUrl = tab.url
        then: ->
          @storeDefinitions()

    storeDefinitions: ->
      console.dir @definitions
      @storage.set windowDefs: @definitions, =>
        if chrome.runtime.lastError
          alert chrome.runtime.lastError

    finish: ->
      status = @makeText(arguments)
      @output status
      @close() if @saveData

    run: ->
      @saveData = true
      @exec @cmd.run

    help: ->
      @saveData = false
      @exec @cmd.help

    exec: (f) ->
      self = this
      @storage.get 'windowDefs', (data) =>
        @definitions = data['windowDefs'] or {}
        f.call self


new TabShepherd chrome.storage.local, chrome.omnibox, chrome.windows, chrome.tabs