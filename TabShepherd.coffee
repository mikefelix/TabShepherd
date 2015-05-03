class TabShepherd
  storage = null
  omnibox = null
  windows = null
  tabs = null
  runtime = null
  definitions = null
  alert = null

  constructor: (chrome, _alert) ->
    storage = chrome.storage.local
    omnibox = chrome.omnibox
    windows = chrome.windows
    tabs = chrome.tabs
    runtime = chrome.runtime
    alert = _alert

    storage.get 'windowDefs', (data) =>
      definitions = data['windowDefs'] or {}
#      console.log "TabShepherd found defs:"
#      console.dir definitions
      defMatchesWin = (def, win, activeTab) =>
        console.log "#{def.id} == #{win.id}" if def.id == win.id
        console.log "#{def.activeUrl} == #{activeTab.url}" if def.activeUrl == activeTab.url
        def.id == win.id or def.activeUrl == activeTab.url

      withEachWindow
        run: (win) =>
          tabs.query windowId: win.id, active: true, (tabs) =>
            tab = tabs[0]
            for own defName, def of definitions when defMatchesWin(def, win, tab)
              console.log "win #{win.id} gets name #{defName}"
              win.name = defName
              win.def = def

    omnibox.onInputChanged.addListener (text, suggest) =>
      c = new Command text, (res) =>
        suggest [ content: ' ', description: res ] if res
      c.help()

    omnibox.onInputEntered.addListener (text) =>
      c = new Command text, (res) =>
        alert res if res
      c.run()

    windows.onRemoved.addListener (windowId) =>
      withWindow windowId, (win) =>
        if (win.name?)
          def = getDefinition(win.name)
          withHighlightedTab win, (tabs) =>
            def.activeUrl = tabs[0].url if tabs.length > 0
            storeDefinitions()

  commands: -> commands

  getCommand = (text) ->
    idx = if text then text.indexOf(' ') else -1
    name = if idx == -1 then text else text.substring(0, idx)
    if commands[name]
      if commands[name]['alias']
        commands[commands[name]['alias']]
      else
        commands[name]
    else
      commands['help']

  getArgs = (text) ->
    text = text.trim()
    return [] if !/^\w+\s+\w+/.test(text)
    text.replace(/^\w+\s+/, '').split /\s+/

  makeText: -> makeText.apply null, (a for a in arguments)
  makeText = ->
    arr = (a for a in arguments)
    return undefined if arr.length == 0
    msg = arr.shift()
    return msg if arr.length == 0
    matches = msg.match /(%[spw])/g
    return msg if !matches?
    for m in matches
      arg = arr.shift()
      v = switch m
        when '%p'
          if isRegex arg
            "/#{arg}/"
          else
            "'#{arg}'"
        when '%w' then "\"#{arg}\""
        else arg
      msg = msg.replace m, v
    msg

  isRegex = (arg) -> /[*+|()$^?\[\]{}]/.test arg

  getId = (win) ->
    if typeof win == 'number'
      win
    else if typeof win == 'object'
      win.id
    else
      alert "Can't find id from " + typeof win

  showExamples = (cmd) ->
    return '' if not commands[cmd]?
    msg = '"' + cmd + '": ' + commands[cmd].desc + '.\n\nExamples:\n\n'
    command = commands[cmd]
    examples = command.examples
    for ex of examples
      msg += "#{ex}\n  #{examples[ex]}\n\n"
    msg

  summarizeCommands = (full) ->
    return showExamples(full) if full and full != true
    msg = ''
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

  focus = (win) -> windows.update win.id, focused: true, ->

  deleteDefinition = (name) -> delete definitions[name]

  getDefinition: (name) -> getDefinition name
  getDefinition = (name) -> definitions[name]

  storeDefinitions: -> storeDefinitions()
  storeDefinitions = ->
    storage.set windowDefs: definitions, ->
      if runtime.lastError
        alert runtime.lastError

  loadDefinitions = (callback) ->
    storage.get 'windowDefs', (data) ->
      definitions = data['windowDefs'] or {}
      callback()

  setName: (win, name) -> setName win, name
  setName = (win, name) ->
    if definitions[win.name]?
      definitions[name] = definitions[win.name]
      delete definitions[win.name]
    else
      definitions[name] = id: win.id
    win.name = name
    win.def = definitions[name]
    win.def.name = name

  getName = (win) ->
    id = getId(win)
    for own name of definitions
      return name if definitions[name].id == id

  getDefForPattern = (pattern) ->
    for own name, def of definitions when def.patterns
      for pattern in def.patterns
        return def if pattern == def.patterns[i]

  assignPattern: (pattern, win) -> assignPattern pattern, win
  assignPattern = (pattern, win) ->
    name = win.name
    if not name?
      alert 'Window has no name!'
      return false
    if not definitions[name]?
      alert "Window #{name} has no definition!"
      return false
    def = definitions[name]
    if not def.patterns?
      def.patterns = []
    def.patterns.push pattern
    true

  unassignPattern = (pattern, window) ->
    if not window.name?
      alert 'Window has no name.'
      return false
    def = definitions[window.name]
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

  containsPattern = (pattern) ->
    if !definitions[window.name]
      alert 'Unknown window ' + window.name
    regexes = definitions[window.name].regexes
    return false if !regexes
    for regex in regexes
      return true if regex == pattern
    false

  listPatterns = (window) ->
    def = definitions[window.name]
    return '' if !def
    patterns = def.patterns or []
    "/#{patt}/\n" for patt in patterns

  withWindowForPattern = (pattern, callback) ->
    def = getDefForPattern(pattern)
    return callback() if not def?
    if not def.id?
      alert "Definition #{def} found for pattern #{pattern} but it has no assigned window."
    else
      windows.get def.id, {}, (w) =>
        w.def = def
        callback w

  withTabsMatching = (patterns, callback) ->
    return callback([]) if !patterns
    patterns = [ patterns ] if typeof patterns == 'string'
    return callback([]) if patterns.length == 0 or patterns[0] == ''

    matches = (tab) =>
      for p in patterns
        if /^\/.+\/$/.test(p)
          r = new RegExp(p.substring(1, p.length - 1))
          return true if r.test(tab.url) or r.test(tab.title)
        else if isRegex p
          r = new RegExp(p)
          return true if r.test(tab.url) or r.test(tab.title)
        else
          return true if tab.url.toLowerCase().search(p) > -1 or tab.title.toLowerCase().search(p) > -1
      false

    tabs.query status: 'complete', windowType: 'normal', (results) =>
      callback(tab.id for tab in results when matches(tab))

  withEachWindow = (args) ->
    condition = args.where or => true
    action = args.run
    finish = args.then
    reduce = args.reduce or (msgs) => msgs.join(',')
    windows.getAll {}, (wins) =>
      msgs = []
      for win in wins
        def = definitions[win.name]
        if condition win, def, win.name
          msgs.push action(win, def, win.name)
      finish reduce(msgs) if finish?

  withWindow = (arg, callback) ->
    where = if typeof arg == 'string'
      (win) => win.name == arg
    else if typeof arg == 'number'
      (win) => win.id == arg
    else if typeof arg == 'function'
      arg
    else if typeof arg == 'object'
      (win) =>
        all = for own k, v of arg
          win[k] == v
        all.reduce (t, s) -> t and s
    else
      alert "Can't use this argument type."
      undefined

    if where
      withEachWindow where: where, run: callback

  withEachDefinition = (args) ->
    condition = args.where or -> true
    action = args.run
    finish = args.then
    reduce = args.reduce or (msgs) -> msgs.join(',')
    windows.getAll {}, (wins) ->
      findWin = (name) ->
        for win in wins
          return win if win.name == name
      msgs = []
      for own name, def of definitions
        win = findWin name
        if condition(def, win, name)
          msgs.push action(def, win, name)
      finish reduce(msgs) if finish?

  withActiveTab = (callback) ->
    tabs.query active: true, currentWindow: true, (tabs) ->
      callback tabs[0]

  withNewWindow = (name, callback) ->
    windows.create type: 'normal', (win) ->
      definitions[name] = id: win.id, name: name
      win.name = name
      callback win

  withCurrentWindow: (callback) -> withCurrentWindow callback
  withCurrentWindow = (callback) ->
    windows.getCurrent {}, (win) ->
      win.name = getName(win)
      callback win

  withWindowNamed = (name, callback) ->
    windows.getAll {}, (wins) ->
      for win in wins
        return callback(win) if win.name == name
      callback undefined

  withHighlightedTab = (win, callback) ->
    tabs.query active: true, windowId: win.id, (tabs) ->
      callback tabs[0] if tabs.length > 0
    
  class Command
    saveData = null
    output = null
    cmd = null

    constructor: (text, _output) ->
      cmd = getCommand(text)
      @args = getArgs(text)
      output = _output

    close = ->
      storeDefinitions()
  #      withEachDefinition
  #        where: (def, win) -> win?
  #        run: (def, win) -> withEachTab win, (tab) -> def.activeUrl = tab.url
  #        then: -> storeDefinitions()

    exec: (f) ->
      loadDefinitions =>
        f.apply @, @args

    finish: ->
      args = (a for a in arguments)
      status = makeText.apply null, args
      output status
      close() if saveData

    run: ->
      saveData = true
      @exec cmd.run

    help: ->
      saveData = false
      @exec cmd.help


  commands: -> commands
  commands =
    tabs:
      desc: "Show active tab information"
      type: 'Managing window definitions'
      examples: "ts tabs": "Show active tab information."
      help: ->
        @finish "Press enter to see active tab information."
      run: ->
        tabs.query active: true, (t) =>
          @finish ("#{tab.windowId}: #{tab.url}" for tab in t).join("\n")
    wins:
      desc: "Show window information"
      type: 'Managing window definitions'
      examples: "ts tabs": "Show window information."
      help: ->
        @finish "Press enter to see window information."
      run: ->
        windows.getAll (wins) =>
          @finish ("#{win.id}: #{win.name}" for win in wins).join("\n")
    id:
      desc: "Show the current window's ID"
      type: 'Managing window definitions'
      examples: "ts id": "Show the current window's ID."
      help: ->
        withCurrentWindow (win) =>
          @finish "This window's ID is %s and its name is %w", win.id, win.name
      run: ->
    n: alias: 'name'
    name:
      desc: 'Change the name of the current window definition'
      type: 'Managing window definitions'
      examples: 'ts name awesome': "Create a definition for the current window named 'awesome'."
      help: (newName) ->
        withCurrentWindow (win) =>
          if win.name?
            if newName?
              @finish "Press enter to change window name from %w to %w.", win.name, newName
            else
              @finish "Enter a new name for this window (currently named %w).", win.name
          else
            if newName?
              @finish "Press enter to name this window %w.", newName
            else
              @finish 'Enter a name for this window.'
      run: (name) ->
        return @finish('No name provided.') if !name
        withCurrentWindow (win) =>
          setName win, name
          @finish()

    attach:
      desc: 'Attach the current window to a previously defined window definition'
      type: 'Managing window definitions'
      examples: 'ts attach work': 'Attach the current window to the existing window definition called \'work\'.'
      help: ->
        withCurrentWindow (win) =>
      run: ->
        withCurrentWindow (win) =>

    defs:
      desc: 'List named window definitions'
      type: 'Managing window definitions'
      examples: 'ts defs': 'List all the window definitions that exist.'
      help: ->
        @finish 'Press enter to list the window definitions.'
      run: ->
        console.log definitions
        withEachDefinition
          run: (def, win, name) =>
            winText = if win? then 'window ' + win.id else 'no attached window'
            "#{name} (#{winText})"
          reduce: (msgs) =>
            msgs.join("\n")
          then: (text) =>
            @finish 'Named windows:\n\n%s', text

    new:
      desc: 'Create a new empty window and assign it a definition'
      type: 'Managing window definitions'
      examples:
        'ts new cats': "Create a new window with definition named 'cats'."
        'ts new cats \\bcats?\\b': "Create a new window with definition named 'cats' and containing one pattern. Move no tabs."
      help: (name) ->
        return @finish('Enter a name for the new window.') if !name
        withWindowNamed name, (win) =>
          if win?
            @finish "There is already a window named %w.", name
          else if @args.length == 1
            @finish "Press enter to open a new window and name it %w.", name
          else if @args.length == 2
            @finish "Press enter to open a new window named %w and assign it the pattern %p.", name, @args[1]
          else
            @finish "Press enter to open a new window named %w and assign it the patterns.", name
      run: (name) ->
        return @finish('No window name provided.') if !name
        withWindowNamed name, (win) =>
          return @finish("There is already a window named %w.", name) if win
          withNewWindow name, (win) =>
            def = getDefinition name
            for arg in @args.slice 1
              def.patterns = [] if !win.patterns?
              def.patterns.push arg
            @finish()

    clear:
      desc: 'Clear window definitions'
      type: 'Managing window definitions'
      examples:
        'ts clear recipes': 'Remove the window definition \'recipes\'. No tabs are affected.'
        'ts clear all data': 'Remove all window definitions from storage. No tabs are affected.'
      help: (name) ->
        return finish('Press enter to clear all saved window definitions.') if name == 'all data'
        withWindowNamed name, (win) =>
          if win?
            @finish 'Press enter to clear window definition \'%s\'. Warning: currently assigned to a window.', name
          else if getDefinition(name)?
            @finish 'Press enter to clear window definition \'%s\', not currently assigned to a window.', name
          else
            @finish 'Window definition \'%s\' not found.', name
      run: (name) ->
        if name == 'all data'
          storage.remove 'windows', =>
            @finish 'Cleared all window data.'
        withWindowNamed name, (win) =>
          if win?
            deleteDefinition name
            delete win.name
            @finish 'Cleared window definition \'%s\' and removed it from a window.', name
          else if getDefinition(name)?
            deleteDefinition name
            @finish 'Cleared window definition \'%s\'.', name
          else
            @finish 'Window definition \'%s\' not found.', name

    clean:
      desc: 'Clean window data, removing definitions for which no window is present'
      type: 'Managing window definitions'
      examples: 'ts clean': 'Clean window data, removing definitions for which no window is present. No tabs are affected.'
      help: ->
        withEachDefinition
          where: (def, win) -> !win
          run: (def, win, name) -> "'#{name}'"
          then: (msg) -> @finish if msg then 'Press enter to clean unused window definitions: ' + msg else 'No window definitions need cleaning.'
      run: ->
        withEachDefinition
          where: (def, win) -> !win
          run: (def, win, name) =>
            deleteDefinition(name)
            "'#{name}'"
          then: (msg) -> @finish if msg then 'Cleaned unused window definitions: ' + msg else 'No window definitions needed cleaning.'

    unnamed:
      desc: 'Go to a window having no definition'
      type: 'Managing window definitions'
      examples: 'ts unnamed': 'Find a window with no definition if such exists, and focus it; else do nothing.'
      help: ->
        withWindow ((win) -> not win.name?), (win) =>
          if win?
            @finish 'Press enter to go to an open window that has no definition.'
          else
            @finish 'All windows have a definition.'
      run: ->
        withWindow ((win) -> not win.name?), (win) =>
          focus win if win
          @finish()
    focus:
      desc: 'Switch to the window with the given name'
      type: 'Changing focus'
      examples: 'ts focus work': "Focus the window named 'work'."
      help: (name) ->
        if !getDefinition(name)
          @finish 'Type a defined window name.'
        else
          @finish "Press enter to focus window %w.", name
      run: (name) ->
        if !getDefinition(name)
          @finish "No such window %w.", name
        else withWindow name, (win) =>
          if !win?
            @finish "Window not found: %w.", name
          else
            focus win
            @finish()
    go_exp:
      desc: 'Perform either "find", "extract" or "focus", depending on the arguments'
      type: 'Changing focus'
      examples:
        'ts go document': 'If there is one tab matching /document/, behave as "ts find document", else behave as "ts extract document".',
        'ts go "work"' : 'If there is a window named "work", behave as "ts focus work", otherwise behave as "ts new work".'
      help: (pattern, name) ->
        name = pattern if !name?
        if /^"/.test pattern
          getCommand('focus').help.apply @, @args
        else
          getCommand('find').help.apply @, @args

      run: (pattern, name) ->
        name = pattern if !name?
        if /^"/.test pattern
          getCommand('focus').run.apply @, @args
        else
          getCommand('find').run.apply @, @args
    go:
      desc: 'Perform either "find", "extract" or "focus", depending on the arguments'
      type: 'Changing focus'
      examples:
        'ts go document': 'If there is one tab matching /document/, behave as "ts find document", else behave as "ts extract document".',
        'ts go "work"' : 'If there is a window named "work", behave as "ts focus work", otherwise behave as "ts new work".'
      help: (pattern, name) ->
        name = pattern if !name?
        if /^"/.test pattern
          if !getDefinition(pattern)
            @finish "Press enter to create a new window named %w", name.replace(/"/, "")
          else
            @finish "Press enter to focus window %w.", name.replace(/"/, "")
        else
          withTabsMatching pattern, (matchingTabsIds) =>
            if matchingTabsIds.length == 1
              @finish "Press enter to focus the single tab matching %p.", pattern
            else if matchingTabsIds.length > 1
              @finish "Press enter to extract the %s tabs matching %p into a new window named %w.", matchingTabsIds.length, pattern, name
            else
              @finish "No tabs found matching %p.", pattern
      run: (pattern, name) ->
        name = pattern if !name?
        if /^"/.test pattern
          win = pattern.replace(/"/, "")
          if !getDefinition(pattern)
            withNewWindow name, =>
              @finish()
          else
            withWindow name, (win) =>
              @finish "Window not found: %w.", name if !win?
              focus win
              @finish()
        else
          withTabsMatching pattern, (matchingTabsIds) =>
            if matchingTabsIds.length == 1
              tabs.get matchingTabsIds[0], (tab) =>
                windows.update tab.windowId, focused: true, =>
                  tabs.update tab.id, active: true, =>
            else if matchingTabsIds.length > 1
              withNewWindow name, (win) ->
                tabs.move matchingTabsIds, windowId: win.id, index: -1, =>
                  win.name = name
                  win.patterns = [ pattern ]
                  tabs.remove win.tabs[win.tabs.length - 1].id, =>
                    @finish()
            else
              @finish "No tabs found matching %p.", pattern
    f: alias: 'find'
    find:
      desc: 'Go to the first tab found matching a pattern.'
      type: 'Changing focus'
      examples: "ts find google.com': 'Focus the first tab found to match 'google.com'."
      help: (pattern) ->
        return @finish('Enter a pattern to find a tab.') if !pattern?
        withTabsMatching pattern, (matchingTabs) =>
          if matchingTabs.length > 1
            @finish "Press enter to focus the first of %s tabs matching %p.", matchingTabs.length, pattern
          else if matchingTabs.length == 1
            tabs.get matchingTabs[0], (tab) =>
              windows.get tab.windowId, {}, (win) =>
                @finish 'Press enter to focus the tab matching %p in window %w.', pattern, win.name ? win.id
          else
            @finish 'No matching tabs found for %p.', pattern
      run: (pattern) ->
        return @finish('Enter a pattern to find a tab.') if !pattern?
        withTabsMatching pattern, (matchingTabs) =>
          if matchingTabs.length >= 1
            tabs.get matchingTabs[0], (tab) =>
              windows.update tab.windowId, focused: true, =>
                tabs.update tab.id, active: true, =>
          else
            @finish "No matching tabs found for %p.", pattern
    b: alias: 'bring'
    bring:
      desc: 'Bring tabs matching a pattern to the current window'
      type: 'Moving tabs'
      examples:
        'ts bring cute.*bunnies.com': 'Bring tabs whose URLs match the given pattern (e.g. cutewhitebunnies.com and cutefluffybunnies.com) to the current window.'
        'ts bring': 'Bring tabs whose URLs match all this window\'s assigned patterns to this window.'
      help: ->
        withCurrentWindow (win) =>
          patterns = undefined
          if @args.length > 0
            patterns = @args
          else
            def = getDefinition(win.name)
            if not (def? and def.patterns? and def.patterns.length == 0)
              @finish 'Enter one or more patterns. No assigned patterns exist for this window.'
            else
              patterns = def.patterns
          withTabsMatching patterns, (matchingTabs) =>
            num = matchingTabs.length
            if num < 1
              @finish 'No tabs found matching given pattern(s).'
            else
              name = if win.name then "'#{win.name}'" else ''
              @finish 'Press enter to bring %s tabs matching %s pattern(s) to this window%s, or enter different patterns.', num, patterns.length, name
      run: ->
        withCurrentWindow (win) =>
          patterns = undefined
          noneMsg = 'Error'
          if @args.length > 0
            noneMsg = 'No tabs found matching %s given pattern%s:\n\n%s'
            patterns = @args
          else
            def = getDefinition(win.name)
            if !def or !def.patterns or def.patterns.length == 0
              @finish 'No patterns entered and this window has no assigned patterns.'
            else
              noneMsg = 'No tabs found matching %s assigned pattern%s:\n\n%s'
              patterns = def.patterns
          withTabsMatching patterns, (matchingTabs) ->
            if matchingTabs.length < 1
              @finish noneMsg, patterns.length, (if patterns.length == 1 then '' else 's'), (makeText("%p", pat) for pat in patterns).join("\n")
            else
              tabs.move windowId: win.id, index: -1, => @finish()
    s: alias: 'send'
    send:
      desc: 'Send the current tab to the window named in the argument'
      type: 'Moving tabs'
      examples: 'ts send research': "Send the current tab to the window named 'research'."
      help: (name) ->
        if not name?
          @finish 'Enter a window name to send this tab there.'
        else
          win = getDefinition(name)
          @finish "Press enter to send this tab to %swindow %w.", (if win? then '' else 'new '), name
      run: (name) ->
        withActiveTab (tab) =>
          existingWin = getDefinition(name)
          if existingWin?
            tabs.move tab.id,
              windowId: existingWin.id
              index: -1
          else
            withNewWindow name, (win) ->
              tabs.move tab.id, windowId: win.id, index: -1, =>
              tabs.remove win.tabs[win.tabs.length - 1].id, => @finish()
    o:
      alias: 'open'
    open:
      desc: 'Open a URL or search in a different window'
      type: 'Moving tabs'
      examples: 'ts open work google.com': "Opens the URL 'http://google.com' in the window 'work'."
      help: (name, url) ->
        if not (name? and url?)
          @finish 'Enter a window name followed by a URL to open the URL there.'
        else
          win = getDefinition(name)
          @finish "Press enter to open this URL in %swindow %w.", (if win then '' else 'new '), name
      run: (name, url) ->
        return @finish('Enter a window name followed by a URL.') if !name or !url

        openTab: (win) =>
          url = 'http://' + url if !/^http:\/\//.test(url)
          tabs.create windowId: win.id, url: url, =>
            @finish()

        withWindowNamed name, (existingWin) =>
          if existingWin?
            openTab existingWin
          else
            withNewWindow name, (win) =>
              openTab win
    e: alias: 'extract'
    ex: alias: 'extract'
    extract:
      desc: 'Extract tabs matching the pattern argument into a new window named with that pattern'
      type: 'Moving tabs'
      examples: 'ts extract social facebook.com twitter.com': "Create a new window, give it a definition named 'social', assign patterns /facebook.com/ and /twitter.com/ to that definition, and move all tabs whose URLs match the patterns there. This is effectively \"ts new social\", followed by \"ts assign facebook.com twitter.com\", then \"ts bring\". "
      help: ->
        if @args.length == 0
          @finish 'Enter a name or pattern.'
        else
          name = @args[0]
          patterns = if @args.length == 1 then [ @args[0] ] else @args.slice(1)
          withTabsMatching patterns, (matchingTabs) =>
            num = matchingTabs.length
            if num < 1
              @finish 'No tabs found matching the given pattern(s).'
            else
              @finish "Press enter to extract %s tab(s) matching %p%s into a new window named %w.", num, patterns[0], (if patterns.length > 1 then ', ...' else ''), name
      run: ->
        if @args.length == 0
          @finish 'Enter a name or pattern.'
        else
          name = @args[0]
          patterns = if @args.length == 1 then [ @args[0] ] else @args.slice(1)
          withTabsMatching patterns, (matchingTabs) =>
            if matchingTabs.length < 1
              @finish 'No tabs found matching the given pattern(s).'
            else
              withNewWindow name, (win) ->
                tabs.move matchingTabs, windowId: win.id, index: -1, =>
                  win.name = name
                  win.patterns = patterns
                  tabs.remove win.tabs[win.tabs.length - 1].id, =>
                    @finish()
    sort:
      desc: 'Sort all tabs into windows by assigned patterns'
      type: 'Moving tabs'
      examples: 'ts sort': "Move all tab that matches a defined pattern to that pattern's window. Effectively, perform \"ts bring\" for each window."
      help: ->
        @finish 'Press enter to sort all windows according to their assigned regexes.'
      run: ->
    merge:
      desc: 'Merge all the tabs from a window into this window.'
      type: 'Moving tabs'
      examples: 'ts merge restaurants': "Move all the tabs from the window 'restaurants' into the current window and remove the 'restaurants' definition."
      help: ->
      run: ->
    assign:
      desc: 'Assign a pattern to the current window'
      type: 'Managing URL patterns'
      examples: 'ts assign reddit.com': "Add /reddit.com/ to this window's assigned patterns. No tabs are affected."
      help: (pattern) ->
        if not pattern?
          @finish 'Enter a pattern to assign to this window.'
        else
          withWindowForPattern pattern, (currWin) =>
            if currWin?
              @finish "Press enter to reassign %p to this window from window %w.", pattern, currWin.name
            else
              @finish 'Press enter to assign %p to this window.', pattern
      run: (pattern)->
        if not pattern?
          @finish 'No pattern provided.'
        else
          withCurrentWindow (window) ->
            withWindowForPattern pattern, (currWin) ->
              msg = undefined
              if currWin?
                if unassignPattern(pattern, currWin)
                  msg = makeText('Pattern %p was moved from window %w to window %w.', pattern, currWin.name, window.name)
                else
                  @finish 'Could not unassign pattern %p from window %w.', pattern, currWin.name
              if assignPattern(pattern, window)
                @finish msg
              else
                @finish 'Could not assign pattern %p to window %w.', pattern, window.name
    unassign:
      desc: 'Remove a pattern assignment from the current window'
      type: 'Managing URL patterns'
      examples: 'ts unassign reddit.com': 'Remove /reddit.com/ from this window\'s patterns if it is assigned. No tabs are affected.'
      help: (pattern) ->
        if not pattern?
          @finish 'Enter a pattern to remove from this window.'
        else if !containsPattern(pattern, window)
          @finish 'Pattern %p is not assigned to this window.', pattern
        else
          @finish 'Press enter to remove %p from this window.', pattern
      run: (pattern)->
        if not pattern?
          @finish 'No pattern provided.'
        else if !containsPattern(pattern, window)
          @finish 'Pattern %p is not assigned to this window.'
        else
          withCurrentWindow (window) =>
            if unassignPattern(pattern, window)
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
        withCurrentWindow (window) =>
          @finish "Patterns assigned to window %w:\n\n%s", window.name, listPatterns(window)
    help:
      desc: 'Get help on a command'
      type: 'Help'
      examples: 'ts help bring': 'Show the usage examples for the "bring" command.'
      help: (arg) ->
        if !arg or !commands[arg] or arg == 'help'
          @finish summarizeCommands(false)
        else
          @finish arg + ': ' + getCommand(arg).desc
      run: (arg) ->
        @finish summarizeCommands(arg)

root = exports ? window
root.TabShepherd = TabShepherd
