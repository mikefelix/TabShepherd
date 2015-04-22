util = require "util"
fs = require "fs"
path = require "path"
child_process = require "child_process"

spawn = (procName, optArray, silent=false) ->
  if process.platform is "win32"
    # if win32, prefix arguments with "/c {original command}"
    # e.g. "coffee -c c:\git\vimium" becomes "cmd.exe /c coffee -c c:\git\vimium"
    optArray.unshift "/c", procName
    procName = "cmd.exe"
  proc = child_process.spawn procName, optArray
  unless silent
    proc.stdout.on 'data', (data) -> process.stdout.write data
    proc.stderr.on 'data', (data) -> process.stderr.write data
  proc

optArrayFromDict = (opts) ->
  result = []
  for key, value of opts
    if value instanceof Array
      result.push "--#{key}=#{v}" for v in value
    else
      result.push "--#{key}=#{value}"
  result

# visitor will get passed the file path as a parameter
visitDirectory = (directory, visitor) ->
  fs.readdirSync(directory).forEach (filename) ->
    filepath = path.join directory, filename
    if (fs.statSync filepath).isDirectory()
      return visitDirectory filepath, visitor

    return unless (fs.statSync filepath).isFile()
    visitor(filepath)

task "build", "compile all coffeescript files to javascript", ->
  coffee = spawn "coffee", ["-c", __dirname]
  coffee.on 'exit', (returnCode) -> process.exit returnCode

task "clean", "removes any js files which were compiled from coffeescript", ->
  visitDirectory __dirname, (filepath) ->
    return unless (path.extname filepath) == ".js"

    directory = path.dirname filepath

    # Check if there exists a corresponding .coffee file
    try
      coffeeFile = fs.statSync path.join directory, "#{path.basename filepath, ".js"}.coffee"
    catch _
      return

    fs.unlinkSync filepath if coffeeFile.isFile()

task "autobuild", "continually rebuild coffeescript files using coffee --watch", ->
  coffee = spawn "coffee", ["-cw", __dirname]

task "package", "Builds a zip file for submission to the Chrome store. The output is in dist/", ->
  # To get exec-sync, `npm install exec-sync`. We use this for synchronously executing shell commands.
  execSync = require("exec-sync")

  vimium_version = JSON.parse(fs.readFileSync("manifest.json").toString())["version"]

  invoke "build"

  execSync "rm -rf dist/vimium"
  execSync "mkdir -p dist/vimium"

  blacklist = [".*", "*.coffee", "*.md", "reference", "test_harnesses", "tests", "dist", "git_hooks",
               "CREDITS", "node_modules", "MIT-LICENSE.txt", "Cakefile"]
  rsyncOptions = [].concat.apply(
    ["-r", ".", "dist/vimium"],
    blacklist.map((item) -> ["--exclude", "'#{item}'"]))

  execSync "rsync " + rsyncOptions.join(" ")
  execSync "cd dist && zip -r vimium-#{vimium_version}.zip vimium"

# This builds a CRX that's distributable outside of the Chrome web store. Is this used by folks who fork
# Vimium and want to distribute their fork?
task "package-custom-crx", "build .crx file", ->
  # To get exec-sync, use `npm install exec-sync`. We use this for synchronously executing shell commands.
  # To get crxmake, use `sudo gem install crxmake`.
  invoke "build"

  # ugly hack to modify our manifest file on-the-fly
  origManifestText = fs.readFileSync "manifest.json"
  manifest = JSON.parse origManifestText
  manifest.update_url = "http://philc.github.com/vimium/updates.xml"
  fs.writeFileSync "manifest.json", JSON.stringify manifest

  pem = process.env.VIMIUM_CRX_PEM ? "vimium.pem"
  target = "vimium-latest.crx"

  console.log "Building crx file..."
  console.log "  using pem-file: #{pem}"
  console.log "  target: #{target}"

  crxmake = spawn "crxmake", optArrayFromDict
    "pack-extension": "."
    "pack-extension-key": pem
    "extension-output": target
    "ignore-file": "(^\\.|\\.(coffee|crx|pem|un~)$)"
    "ignore-dir": "^(\\.|test)"

  crxmake.on "exit", -> fs.writeFileSync "manifest.json", origManifestText

runUnitTests = (projectDir=".", testNameFilter) ->
  console.log "Running unit tests..."
  basedir = projectDir #path.join projectDir, "/tests/unit_tests/"
  test_files = fs.readdirSync(basedir).filter((filename) -> filename.indexOf("_test.js") > 0)
  test_files = test_files.map((filename) -> basedir + filename)
  test_files.forEach (file) -> require (if file[0] == '/' then '' else './') + file
  Tests.run(testNameFilter)
  return Tests.testsFailed

option '', '--filter-tests [string]', 'filter tests by matching string'
task "test", "run all tests", (options) ->
  unitTestsFailed = runUnitTests('.', options['filter-tests'])

  console.log "Running DOM tests..."
  phantom = spawn "phantomjs", ["./tests/dom_tests/phantom_runner.js"]
  phantom.on 'exit', (returnCode) ->
    if returnCode > 0 or unitTestsFailed > 0
      process.exit 1
    else
      process.exit 0