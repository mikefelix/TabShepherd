class TabShepherd
  storage = null
  omnibox = null
  windows = null
  tabs = null
  runtime = null
  definitions = null
  alert = null
  lastCommand = null

  constructor: (chrome, _alert) ->
    storage = chrome.storage.local
    omnibox = chrome.omnibox
    windows = chrome.windows
    tabs = chrome.tabs
    runtime = chrome.runtime
    alert = _alert

    storage.get 'windowDefs', (data) =>
      definitions = data['windowDefs'] or {}

    omnibox.onInputChanged.addListener inputChanged
    omnibox.onInputEntered.addListener inputEntered

  inputChanged = (text, suggest) =>
    c = new Command text, (res) =>
      suggest [ content: ' ', description: res ] if res
    c.help()

  inputEntered = (text) =>
    console.log "Entered command: #{text}"
    output = if getCommandName(text) != 'help'
      (res) => alert res if res
    else
      (url) =>
        withCurrentWindow (win) =>
          tabs.create windowId: win.id, url: url, =>
    lastCommand = text if text != '.'
    new Command(text, output).run()

  getCommandName = (text) ->
    idx = if text then text.indexOf(' ') else -1
    if idx == -1 then text else text.substring(0, idx)

  getPossibleCommands = (text) ->
    name = getCommandName text
    k for own k, v of commands when k.indexOf(name) == 0

  getCommand = (text) ->
    cmds = getPossibleCommands text
    if cmds.length == 1
      commands[cmds[0]]
    else
      commands['help']

  getArgs = (text) ->
    text = text.trim()
    return [] if !/^\S+\s+\S+/.test(text)
    text.replace(/^\S+\s+/, '').split /\s+/

  makeText: -> makeText (a for a in arguments)...
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
        when '%w'
          if arg
            "\"#{arg}\""
          else
            '(unnamed)'
        else arg
      msg = msg.replace m, v ? ''
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
      'Informational'
    ]
    for type in types
      msg += "  #{type}:\n" if full
      for own name, cmd of commands when cmd.type == type
        if full
          msg += "    #{name}: #{cmd.desc}.\n"
        else
          msg += name + ' '
    msg

  focus: (win) -> focus win
  focus = (win) -> windows.update win.id, focused: true, ->

  deleteDefinition = (name) -> delete definitions[name]

  getDefinition: (name) -> getDefinition name
  getDefinition = (nameOrWin) ->
    if typeof nameOrWin == 'string'
      definitions[nameOrWin]
    else if nameOrWin.id?
      for own name, def of definitions
        return def if def.id == nameOrWin.id

  storeDefinitions: -> storeDefinitions()
  storeDefinitions = ->
    tabs.query index: 0, (tabz) ->
      for own name, def of definitions
        for tab in tabz when tab.windowId == def.id
          def.firstUrl = tab.url
      storage.set windowDefs: definitions, ->
#        console.dir definitions
        alert runtime.lastError if runtime.lastError

  loadDefinitions = (callback) ->
    storage.get 'windowDefs', (data) ->
      definitions = data['windowDefs'] or {}
      withEachDefinition
        where: (def, win) -> !win? && def.firstUrl?
        run: (def) ->
          tabs.query url: def.firstUrl, (tabz) ->
            def.id = tabz[0].windowId if tabz?.length
      callback()

  setName: (win, name) -> setName win, name
  setName = (win, name) ->
    currName = getName(win)
    return if name == currName
    if currName? and definitions[currName]?
      if currName != name
        definitions[name] = definitions[currName]
        delete definitions[currName]
    else
      definitions[name] = id: win.id

    definitions[name].name = name

  getName: (win) -> getName win
  getName = (win) ->
    id = getId(win)
    for own name of definitions
      return name if definitions[name].id == id

  getDefForPattern = (pattern) ->
    for own name, def of definitions when def.patterns
      for pattern in def.patterns
        return def if pattern == def.patterns[i]

  assignPattern: (win, pattern) -> assignPattern win, pattern
  assignPattern = (win, pattern) ->
    name = getName(win)
    if not name?
      alert 'Window has no name!'
      return false
    if not definitions[name]?
      alert "Window #{name} has no definition!"
      return false
    def = getDefinition name
    def.patterns = [] if not def.patterns?
    for p in def.patterns
      return false if pattern == p
    def.patterns.push pattern
    true

  unassignPattern = (window, pattern) ->
    if not window.name?
      alert 'Window has no name.'
      return false
    def = getDefinition window
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
    alert 'Unknown window ' + window.name if !getDefinition(window)?
    patt = getDefinitions(window).patterns
    return false if !patt?
    for p in patt
      return true if p == pattern
    false

  listPatterns = (window) ->
    def = getDefinition window
    return '' if !def?
    patterns = def.patterns ? []
    (makeText("%p\n", patt) for patt in patterns).join('')

  withWindowForPattern = (pattern, callback) ->
    withEachDefinition
      where: (def, win) -> win? and def?.patterns?.indexOf(pattern) >= 0
      run: callback
      otherwise: callback

  countWindowsAndTabs: (cb) -> countWindowsAndTabs cb
  countWindowsAndTabs = (cb) ->
    tabs.query status: 'complete', windowType: 'normal', (results) =>
      grouped = {}
      for tab in results
        id = tab.windowId
        grouped[id] = [] if !grouped[id]
        grouped[id].tabs = (grouped[id].tabs ? 0) + 1
        grouped[id].name = getName(id) ? "(unnamed)"
        grouped[id].id = id
      cb grouped

  matchesAny = (tab, patterns) =>
    for p in patterns
      if typeof p == 'boolean'
        return p
      if typeof p == 'function'
        return true if p(tab)
      else if /^\/.+\/$/.test(p)
        r = new RegExp(p.substring(1, p.length - 1))
        return true if r.test(tab.url) or r.test(tab.title)
      else if isRegex p
        r = new RegExp(p)
        return true if r.test(tab.url) or r.test(tab.title)
      else
        return true if tab.url.toLowerCase().search(p) > -1 or tab.title.toLowerCase().search(p) > -1
    false

  withTabsMatching = (patterns, callback) ->
    return callback([]) if !patterns
    patterns = [ patterns ] if typeof patterns == 'string' or typeof patterns == 'function'
    return callback([]) if patterns.length == 0 or patterns[0] == ''

    tabs.query status: 'complete', windowType: 'normal', (results) =>
      callback(tab.id for tab in results when matchesAny(tab, patterns))

  withEachWindow = (args) ->
    condition = args.where or -> true
    action = args.run
    finish = args.then
    reduce = args.reduce or (msgs) -> msgs.join(',')
    otherwise = args.otherwise
    windows.getAll {}, (wins) ->
      msgs = []
      for win in wins
        def = getDefinition win
        if condition win, def
          msgs.push action(win, def)
      if finish?
        finish reduce(msgs)
      else if msgs.length == 0 and otherwise?
        otherwise()

  windowMatching = (arg) ->
    switch typeof arg
      when 'string' then (win) => getName(win) == arg
      when 'number' then (win) => win.id == arg
      when 'function' then arg
      when 'object' then (win) => ((win[k] == v) for own k, v of arg).reduce((t, s) -> t and s)
      else alert "Can't use this argument type. #{typeof arg} #{arg}"

  withExistingWindow = (arg, callback) ->
    withEachWindow
      where: windowMatching arg
      run: callback

  withWindow: (arg, callback) -> withWindow arg, callback
  withWindow = (arg, callback) ->
    withEachWindow
      where: windowMatching arg
      run: callback
      otherwise: callback

  withEachDefinition = (args) ->
    condition = args.where or -> true
    action = args.run
    finish = args.then
    reduce = args.reduce or (msgs) -> msgs.join(',')
    otherwise = args.otherwise
    windows.getAll {}, (wins) ->
      findWin = (name) ->
        for win in wins
          return win if getName(win) == name
      msgs = []
      for own name, def of definitions
        win = findWin name
        if condition(def, win)
          msgs.push action(def, win)
      if finish?
        finish reduce(msgs)
      else if msgs.length == 0 and otherwise?
        otherwise()

  withActiveTab = (callback) ->
    tabs.query active: true, currentWindow: true, (tabs) ->
      callback tabs[0]

  withNewWindow = (name, callback) ->
    windows.create type: 'normal', (win) ->
      if name?
        definitions[name] = id: win.id, name: name if !getDefinition(name)?
        setName win, name
      callback win

  withCurrentWindow: (callback) -> withCurrentWindow callback
  withCurrentWindow = (callback) ->
    windows.getCurrent {}, (win) ->
      callback win

  withWindowNamed = (name, callback) ->
    windows.getAll {}, (wins) ->
      for win in wins
        return callback(win) if getName(win) == name
      callback undefined

  withHighlightedTab = (win, callback) ->
    tabs.query active: true, windowId: win.id, (tabs) ->
      callback tabs[0] if tabs.length > 0

  plur = (word, num) ->
    text = if num == 1
      word
    else if /y$/.test word
      word[0..-1] + 'ies'
    else if /s$/.test word
      word + 'es'
    else
      word + 's'
    "#{num} #{text}"

  class Command
    saveData = null
    output = null
    cmd = null

    constructor: (text, _output) ->
      poss = getPossibleCommands text
      if poss.length == 1
        @name = poss[0]
        cmd = commands[@name]
      else
        @name = text.replace /\s.*/, ''
        cmd = commands['help']
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
      status = makeText args...
      if status?
        if @name == 'help'
          output status
        else
          output "#{@name}: #{status}"
      close() if saveData

    run: ->
      saveData = true
      @exec cmd.run

    help: ->
      saveData = false
      @exec cmd.help


  getCommands: -> commands
  commands =
    tabs:
      desc: "Show active tab information"
      type: 'Informational'
      examples: "ts tabs": "Show information on each active tab."
      help: ->
        @finish "Press enter to see active tab information."
      run: ->
        tabs.query active: true, (t) =>
          @finish ("#{tab.windowId}: #{tab.url}" for tab in t).join("\n")
    wins:
      desc: "Show window information"
      type: 'Informational'
      examples: "ts tabs": "Show window information."
      help: ->
        @finish "Press enter to see window information."
      run: ->
        windows.getAll (wins) =>
          @finish ("#{win.id}: #{getName(win)}" for win in wins).join("\n")
    window:
      desc: "Show the current window's ID"
      type: 'Informational'
      examples: "ts id": "Show the current window's ID."
      help: ->
        withCurrentWindow (win) =>
          @finish "This window's ID is %s and its name is %w", win.id, getName(win)
      run: ->
        withCurrentWindow (win) =>
          @finish "This window's ID is %s and its name is %w", win.id, getName(win)
    name:
      desc: 'Change the name of the current window definition'
      type: 'Managing window definitions'
      examples: 'ts name awesome': "Create a definition for the current window named 'awesome'."
      help: (newName) ->
        withCurrentWindow (win) =>
          if getName(win)?
            if newName?
              @finish "Press enter to change window name from %w to %w.", getName(win), newName
            else
              @finish "Enter a new name for this window (currently named %w).", getName(win)
          else
            if newName?
              @finish "Press enter to name this window %w.", newName
            else
              @finish 'Enter a name for this window.'
      run: (name) ->
        withCurrentWindow (win) =>
          if !name?
            @finish('No name provided.')
          else
            setName win, name
            @finish()

    defs:
      desc: 'List named window definitions'
      type: 'Managing window definitions'
      examples: 'ts defs': 'List all the window definitions that exist.'
      help: ->
        @finish 'Press enter to list the window definitions.'
      run: ->
        withEachDefinition
          run: (def, win) =>
            winText = if win? then 'window ' + win.id else 'no attached window'
            "#{def.name} (#{winText})\n#{def.firstUrl}"
          reduce: (msgs) =>
            msgs.join("\n")
          then: (text) =>
            @finish 'Named windows:\n\n%s', text

    new:
      desc: 'Create a new window and assign it a definition'
      type: 'Managing window definitions'
      examples:
        'ts new cats': "Create a new window with definition named 'cats'."
        'ts new cats \\bcats?\\b': "Create a new window with definition named 'cats' and containing one pattern. Move no tabs."
      help: (name, patterns...) ->
        return @finish('Enter a name for the new window.') if !name
        withWindowNamed name, (win) =>
          if win?
            @finish "There is already a window named %w.", name
          else if patterns.length == 0
            @finish "Press enter to open a new window and name it %w.", name
          else if patterns.length == 1
            @finish "Press enter to open a new window named %w and assign it the pattern %p.", name, @args[1]
          else
            @finish "Press enter to open a new window named %w and assign it the given patterns.", name
      run: (name, patterns...) ->
        return @finish('No window name provided.') if !name
        withWindowNamed name, (win) =>
          return @finish("There is already a window named %w.", name) if win?
          withNewWindow name, (win) =>
            def = getDefinition name
            for p in patterns
              def.patterns = [] if !def.patterns?
              def.patterns.push p
            @finish()

    clear:
      desc: 'Clear window definitions'
      type: 'Managing window definitions'
      examples:
        'ts clear recipes': "Remove the window definition 'recipes'. No tabs are affected."
        'ts clear *': "Remove all window definitions from storage. No tabs are affected."
      help: (name) ->
        return @finish('Enter a window name or * to remove all.') if !name?
        return @finish('Press enter to clear all saved window definitions.') if name == '*'
        withWindowNamed name, (win) =>
          if win?
            @finish "Press enter to clear window definition %w. Warning: currently assigned to a window.", name
          else if getDefinition(name)?
            @finish "Press enter to clear window definition %w, not currently assigned to a window.", name
          else
            @finish "Window definition %w not found.", name
      run: (name) ->
        return @finish('Enter a window definition name') if !name?
        if name == '*'
          deleteDefinition(name) for own name, def of definitions
          @finish 'Cleared all window definitions.'
        else
          withWindowNamed name, (win) =>
            if win?
              deleteDefinition name
              @finish "Cleared window definition %w and removed it from a window.", name
            else if getDefinition(name)?
              deleteDefinition name
              @finish "Cleared window definition %w.", name
            else
              @finish "Window definition %w not found.", name

    clean:
      desc: 'Clean window data, removing definitions for which no window is present'
      type: 'Managing window definitions'
      examples: 'ts clean': 'Clean window data, removing definitions for which no window is present. No tabs are affected.'
      help: ->
        withEachDefinition
          where: (def, win) -> !win
          run: (def) -> "'#{def.name}'"
          then: (msg) => @finish if msg then 'Press enter to clean unused window definitions: ' + msg else 'No window definitions need cleaning.'
      run: ->
        withEachDefinition
          where: (def, win) -> !win
          run: (def) =>
            deleteDefinition(def.name)
            "'#{def.name}'"
          then: (msg) => @finish if msg then 'Cleaned unused window definitions: ' + msg else 'No window definitions needed cleaning.'

    unnamed:
      desc: 'Go to a window having no definition'
      type: 'Managing window definitions'
      examples: 'ts unnamed': 'Find a window with no definition if such exists, and focus it; else do nothing.'
      help: ->
        withWindow ((win) -> not getName(win)?), (win) =>
          if win?
            @finish 'Press enter to go to an open window that has no definition.'
          else
            @finish 'All windows have a definition.'
      run: ->
        withWindow ((win) -> not getName(win)?), (win) =>
          focus win if win
          @finish()
    open:
      desc: 'Open to the window with the given name, creating a new window if necessary'
      type: 'Changing focus'
      examples: 'ts focus work': "Focus the window with the definition \"work\" if it exists, otherwise create a window, give it definition \"work\" and focus it."
      help: (name) ->
        if not name?
          @finish "Enter a window name."
        else
          withWindow name, (win) =>
            if win?
              @finish "Press enter to open window %w.", name
            else if getDefinition(name)?
              @finish "Press enter to open a new window for existing definition %w.", name
            else
              @finish "Press enter to open new window %w.", name
      run: (name) ->
        if not name?
          @finish "Enter a window name."
        else
          withWindow name, (win) =>
            if win?
              focus win
              @finish()
            else
              withNewWindow name, (newWin) =>
                focus newWin
                @finish()
#    go_exp:
#      desc: 'Perform either "find", "extract" or "focus", depending on the arguments'
#      type: 'Changing focus'
#      examples:
#        'ts go document': 'If there is one tab matching /document/, behave as "ts find document", else behave as "ts extract document".',
#        'ts go "work"' : 'If there is a window named "work", behave as "ts focus work", otherwise behave as "ts new work".'
#      help: (pattern, name) ->
#        name = pattern if !name?
#        if /^"/.test pattern
#          getCommand('focus').help.apply @, @args
#        else
#          getCommand('find').help.apply @, @args
#
#      run: (pattern, name) ->
#        name = pattern if !name?
#        if /^"/.test pattern
#          getCommand('focus').run.apply @, @args
#        else
#          getCommand('find').run.apply @, @args
    go:
      desc: 'Perform either "find", "extract" or "open", depending on the arguments and number of matches'
      type: 'Changing focus'
      examples:
        'ts go document': 'If there is one tab matching /document/, behave as "ts find document", else behave as "ts extract document".',
        'ts go "work"' : 'If there is a window named "work", behave as "ts open work", otherwise behave as "ts new work".'
      help: (pattern, name) ->
        name = pattern if !name?
        if /^"/.test pattern
          win = pattern.replace /"/g, ''
          if !getDefinition(win)?
            @finish "Press enter to create a new window named %w", win
          else
            @finish "Press enter to focus window %w.", win
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
          winName = pattern.replace /"/g, ''
          if !getDefinition(winName)?
            withNewWindow winName, =>
              @finish()
          else
            withWindow winName, (win) =>
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
                  setName win, name
                  assignPattern win, pattern
                  tabs.remove win.tabs[win.tabs.length - 1].id, =>
                    @finish()
            else
              @finish "No tabs found matching %p.", pattern
    find:
      desc: 'Go to the first tab found matching a pattern, never moving tabs'
      type: 'Changing focus'
      examples: "ts find google.com": "Focus the first tab found to match 'google.com', or do nothing if no tab is found."
      help: (pattern) ->
        return @finish('Enter a pattern to find a tab.') if !pattern?
        withTabsMatching pattern, (matchingTabs) =>
          if matchingTabs.length > 1
            @finish "Press enter to focus the first of %s tabs matching %p.", matchingTabs.length, pattern
          else if matchingTabs.length == 1
            tabs.get matchingTabs[0], (tab) =>
              windows.get tab.windowId, {}, (win) =>
                name = getName win
                if name?
                  @finish 'Press enter to focus the tab matching %p in window %w.', pattern, name
                else
                  @finish 'Press enter to focus the tab matching %p.', pattern
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
    bring:
      desc: 'Bring tabs matching a pattern to the current window'
      type: 'Moving tabs'
      examples:
        'ts bring cute.*bunnies.com': 'Bring tabs whose URLs match the given pattern (e.g. cutewhitebunnies.com and cutefluffybunnies.com) to the current window.'
        'ts bring': 'Bring tabs whose URLs match all this window\'s assigned patterns to this window.'
      help: (patterns...) ->
        withCurrentWindow (win) =>
          usingAssigned = patterns.length == 0
          if usingAssigned
            def = getDefinition win
            return @finish 'Enter one or more patterns. No assigned patterns exist for this window.' if !def?.patterns?.length
            patterns = def.patterns
          withTabsMatching patterns, (matchingTabs) =>
            num = matchingTabs.length
            if num < 1
              @finish 'No tabs found matching %s.', plur('given pattern', patterns.length)
            else
              extra = ", or enter different patterns" if usingAssigned
              @finish 'Press enter to bring %s matching %s to this window %w%s.', plur('tab', num), plur('pattern', patterns.length), getName(win), extra
      run: (patterns...) ->
        withCurrentWindow (win) =>
          usingAssigned = patterns.length == 0
          if usingAssigned
            def = getDefinition win
            return @finish 'No patterns entered and this window has no assigned patterns.' if !def or !def.patterns or def.patterns.length == 0
            patterns = def.patterns
          withTabsMatching patterns, (matchingTabs) =>
            if matchingTabs.length < 1
              type = if usingAssigned then 'assigned pattern' else 'given pattern'
              @finish 'No tabs found matching %s:\n\n%s', plur(type, patterns.length), (makeText("%p", pat) for pat in patterns).join("\n")
            else
              tabs.move matchingTabs, windowId: win.id, index: -1, => @finish()
    group:
      desc: 'Attempt to sort the current tab into a window according to pattern'
      type: 'Moving tabs'
      examples: 'ts group': "Match the current tab's URL and title against defined window patterns and send it to the first window that matches."
      help: () ->
        @finish "Press enter to attempt to group this tab according to the defined window patterns."
      run: () ->
        moved = false
        withActiveTab (tab) =>
          withEachDefinition
            where: (def, win) -> not moved and win.id != tab.windowId and matchesAny(tab, def.patterns or [])
            run: (def, win) =>
              tabs.move tab.id, windowId: win.id, index: -1, =>
                moved = true
                @finish()
    send:
      desc: 'Send the current tab to the window named in the argument, creating the window if necessary'
      type: 'Moving tabs'
      examples: 'ts send research': "Send the current tab to the window named 'research', first creating it if necessary."
      help: (name) ->
        if not name?
          @finish 'Enter a window name to send this tab there.'
        else
          win = getDefinition name
          @finish "Press enter to send this tab to %swindow %w.", (if win? then '' else 'new '), name
      run: (name) ->
        withActiveTab (tab) =>
          existingWin = getDefinition name
          if existingWin?
            tabs.move tab.id, windowId: existingWin.id, index: -1, =>
              @finish()
          else
            withNewWindow name, (win) =>
              tabs.move tab.id, windowId: win.id, index: -1, =>
                tabs.remove win.tabs[win.tabs.length - 1].id, =>
                  @finish()
#    _old_open:
#      desc: 'Open a URL or search in a different window'
#      type: 'Moving tabs'
#      examples: 'ts open work google.com': "Opens the URL 'http://google.com' in the window 'work'."
#      help: (name, url) ->
#        if not (name? and url?)
#          @finish 'Enter a window name followed by a URL to open the URL there.'
#        else
#          win = getDefinition name
#          @finish "Press enter to open this URL in %swindow %w.", (if win then '' else 'new '), name
#      run: (name, url) ->
#        return @finish('Enter a window name followed by a URL.') if !name or !url
#
#        openTab: (win) =>
#          url = 'http://' + url if !/^http:\/\//.test(url)
#          tabs.create windowId: win.id, url: url, =>
#            @finish()
#
#        withWindowNamed name, (existingWin) =>
#          if existingWin?
#            openTab existingWin
#          else
#            withNewWindow name, (win) =>
#              openTab win
    extract:
      desc: 'Extract tabs matching the pattern arguments into a new window named with that pattern'
      type: 'Moving tabs'
      examples:
        'ts extract google': "Create a new window \"google\", assign pattern 'google' to that definition, and move all tabs whose URLs match the pattern there."
        'ts extract social facebook.com twitter.com': "Create a new window, give it a definition named 'social', assign patterns 'facebook.com' and 'twitter.com' to that definition, and move all tabs whose URLs match the patterns there. This is effectively \"ts new social\", followed by \"ts assign facebook.com twitter.com\", then \"ts bring\". "
      help: ->
        if @args.length == 0
          @finish 'Enter a name or pattern.'
        else
          name = @args[0]
          patterns = if @args.length == 1 then [ @args[0] ] else @args.slice(1)
          withTabsMatching patterns, (matchingTabs) =>
            num = matchingTabs.length
            if num < 1
              @finish 'No tabs found matching %p. Enter more args to use it as a name.', name
            else if patterns.length > 1
              @finish "Press enter to extract %s matching %s patterns into a new window named %w.", plur("tab", num), patterns.length, name
            else
              @finish "Press enter to extract %s matching %p into a new window named %w.", plur("tab", num), patterns[0], name
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
              withNewWindow name, (win) =>
                tabs.move matchingTabs, windowId: win.id, index: -1, =>
                  setName win, name
                  for p in patterns
                    assignPattern win, p
                  tabs.remove win.tabs[win.tabs.length - 1].id, =>
                    @finish()
    sort:
      desc: 'Sort all tabs into windows by assigned patterns'
      type: 'Moving tabs'
      examples: 'ts sort': "Move all tabs that match a defined pattern to that pattern's window. Effectively, perform \"ts bring\" for each window."
      help: ->
        @finish 'Press enter to sort all windows according to their assigned patterns.'
      run: ->
        for own name, def of definitions when def.patterns?
          withWindowNamed name, (win) =>
            withTabsMatching def.patterns, (tabz) =>
              tabs.move tabz, windowId: win.id, index: -1, =>
                @finish()
    merge:
      desc: 'Merge all tabs and patterns from another window into this window.'
      type: 'Moving tabs'
      examples: 'ts merge restaurants': "Move all the tabs and patterns from window 'restaurants' into the current window and remove the 'restaurants' definition."
      help: (name) ->
        return @finish 'Enter a defined window name, or press enter to merge the window with the fewest tabs.' if !name?
        withWindow name, (win) =>
          return @finish 'No such window %w', name if !win?
          withTabsMatching ((tab) -> tab.windowId == win.id), (tabz) =>
            patterns = getDefinition(win)?.patterns ? []
            withCurrentWindow (currWin) =>
              @finish 'Press enter to move %s and %s from window %w to this window %w.', plur('tab', tabz.length), plur('pattern', patterns.length), name, getName(currWin)
      run: (name) ->
        doIt = (win) =>
          return @finish 'No such window %w', name if !win?
          withTabsMatching ((tab) -> tab.windowId == win.id), (tabz) =>
            def = getDefinition win
            return @finish "Window %w has no definition!" if not def?
            withCurrentWindow (currWin) =>
              currDef = getDefinition currWin
              currDef.patterns = [] if !currDef.patterns?
              for p in def.patterns ? []
                currDef.patterns.push p
              tabs.move tabz, windowId: currWin.id, index: -1, =>
                delete definitions[name]
        if !name?
          countWindowsAndTabs (info) =>
            smallest = null
            for own k, inf of info
              smallest = inf if inf.tabs < smallest.tabs
            if smallest?
              withWindow smallest.name, (win) => doIt win
        else
          withWindow name, (win) => doIt win

    split:
      desc: 'Split a window in two, moving half of the tabs to a new window.'
      type: 'Moving tabs'
      examples: 'ts split': 'Move the last half the tabs in the current window into a new window.'
      help: ->
        @finish "Press enter to split this window in two."
      run: ->
        withCurrentWindow (win) =>
          withTabsMatching ((tab) -> tab.windowId == win.id), (matchingTabs) =>
            if (matchingTabs.length >= 2)
              withNewWindow undefined, (newWin) =>
                tabs.move matchingTabs.slice(matchingTabs.length / 2), windowId: newWin.id, index: -1, =>
                  @finish()
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
              @finish "Press enter to reassign %p to this window from window %w.", pattern, getName(currWin)
            else
              @finish 'Press enter to assign %p to this window.', pattern
      run: (pattern)->
        if not pattern?
          @finish 'No pattern provided.'
        else
          withCurrentWindow (window) =>
            withWindowForPattern pattern, (currWin) =>
              msg = undefined
              if currWin?
                if unassignPattern currWin, pattern
                  msg = makeText('Pattern %p was moved from window %w to window %w.', pattern, getName(currWin), getName(window))
                else
                  @finish 'Could not unassign pattern %p from window %w.', pattern, getName(currWin)
              if assignPattern window, pattern
                @finish msg
              else
                @finish 'Could not assign pattern %p to window %w.', pattern, getName(window)
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
            if unassignPattern window, pattern
              @finish()
            else
              @finish 'Could not unassign pattern %s from window %w.', pattern, getName(window)
    patterns:
      desc: 'List patterns assigned to the current window definition'
      type: 'Managing URL patterns'
      examples: 'ts patterns': 'List patterns assigned to the current window.'
      help: ->
        @finish 'Press enter to list the patterns assigned to this window.'
      run: ->
        withCurrentWindow (window) =>
          @finish "Patterns assigned to window %w:\n\n" + listPatterns(window), getName(window)
    '.':
      desc: 'Repeat the previously executed command.'
      type: 'Informational'
      examples: 'ts .': 'Repeat the previously executed command.'
      help: () ->
        if lastCommand?
          @finish "Press enter to run the previous command: #{lastCommand}"
        else
          @finish "No previous command found."
      run: () ->
        if lastCommand? and lastCommand != '.'
          @finish inputEntered(lastCommand)
        else
          @finish "No previous command found."
    help:
      desc: 'Get help on a command'
      type: 'Informational'
      examples: 'ts help bring': 'Show usage examples for the "bring" command.'
      help: () ->
        if @name == 'help'
          if (@args.length > 0)
            cmd = getCommand(@args[0])
            if not cmd? or cmd == commands['help']
              @finish "#{@args[0]}: No matching command found."
            else
              @finish "#{@args[0]}: #{cmd.desc}"
          else
            @finish 'help: Enter a command name or press enter to see possible commands.'
        else
          cmds = getPossibleCommands @name
          if cmds.length == 0
            @finish "#{@name}: No matching command found."
          else
            @finish "[#{cmds.join('/')}] Keep typing to narrow command results."
      run: () ->
        if (@args.length > 0)
          @finish "/help.html?command=#{@args[0]}"
        else
          @finish "/help.html"

root = exports ? window
root.TabShepherd = TabShepherd
