import types #, constructs/cs_all_constructs
import lineparser

import os, system, times
import strutils, os, json

proc upcomingLines*(jsn: JsonNode): seq[string] =
  let x = jsn["Lines"].getElems()
  for ln in x:
    if ln["KindStr"].getStr() == "Decl":
      result.add ln["Declaration"].getStr()

proc getCsastFiles*(folder: string): seq[string] =
  for file in walkDirRec(folder):
    if file.fileExists and file.endsWith(".csast"):
      result.add file

import constructs/cs_root
import constructs/justtypes

proc processFiles*(root: var CsRoot; files: seq[string]) =
  echo "processing files"
  for f in files:
    assert f.endsWith(".csast")
    let linesJson = parseFile(f)
    let upcoming = upcomingLines(linesJson)
    parseExecFile(root, linesJson, upcoming)

import re, strutils
proc concatModulesOutput*(mods: seq[Module]): string =
  for m in mods:
    result &= m.output & "\n\n"
  var x = result.replace(re"((\r\n)|(\n)){2,}", "\n\n")
  result = x.strip(chars = {'\n'})

let safer* = false
const suffixOutputDir = "nim_code/dotnet"
let dt = now().format("yyyyMMddHHmm")

func mkModuleFilename*(target: string; moduleName: string, gl:GenLang): string =
  let ext =
    case gl
    of glNim: ".nim"
    of glCSharp: ".cs"

  result = target / moduleName.toLowerAscii.replace(".", "/") & ext

proc getTargetFolder(infolder: string): string =
  # if `infolder` is a file, take its parent.
  let folder = if fileExists(infolder):
    parentDir(infolder) else: infolder

  let cwd = folder
  var target = (cwd / suffixOutputDir)

  if safer:
    target &= dt
  result = target

proc doWrite(filename, output: string) =
  if not filename.parentDir.dirExists:
    createDir(filename.parentDir)

  if safer:
    var f: File
    try:
      f = open(filename, fmAppend)
      echo "writing to filename:" & filename
      f.write(output)
    finally:
      f.close
  else:
    echo "writing to filename:" & filename
    writeFile(filename, output)

proc writeModule*(infolder: string; module: Module, gl:GenLang) =
  let target = getTargetFolder(infolder)
  if not target.dirExists: createDir(target)

  let filename = mkModuleFilename(target, module.name, gl)
  doWrite(filename, module.output)



proc getWriteAllData*(dir: string; root: CsRoot, gl:GenLang): seq[(string, string)] =
  let list = root.gen(gl)
  for module in list:
    let t = getTargetFolder(dir)
    let f = mkModuleFilename(t, module.name, gl)
    result.add((f, module.output))

proc writeAll*(dir: string; root: CsRoot; gl:GenLang) =
  when true:
    echo "=== REACHED GENERATE STAGE ==="
    let list = root.gen(gl)
    for module in list:
      echo module.name
      writeModule(dir, module,gl)
  when false: # alternative impl, that uses the tested getWriteAllData.
    let whatToDo = getWriteAllData(dir, root)
    for (d, output) in whatToDo:
      doWrite(d, output)

import json, algorithm

import system
proc handleOne(root: var CsRoot; file: string) =
  var contents = file.readFile()
  var linesJson = json.parseJson(contents)
  let upcoming = upcomingLines(linesJson)
  parseExecFile(root, linesJson, upcoming)

proc handleJustOne*(inputFolder: string; root: var CsRoot;
    file: string) =
  echo "working on: " & file
  handleOne(root, file)

proc stats(i: int; f: string; len: int; sw: DateTime): string =
  let x = i + 1
  var str = (100*x/len).formatFloat(ffDecimal, 2) & "%\t" & $x &
      " / " & $len
  let time = now() - sw
  str &= "\t" & (time.inSeconds.float / x.toFloat).formatFloat(ffDecimal,
      3) & " s\t"
  result = str

proc handleMany*(inputFolder: string; root: var CsRoot; files: seq[string]) =
  var sw = now()
  for i, f in files.sorted:
    echo "working on: " & f

    let str = stats(i, f, files.len, sw)
    write(stdout, str)
    handleOne(root, f)

