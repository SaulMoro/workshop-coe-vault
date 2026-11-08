// json.mjs: todo lo que el vault necesita leer de un JSON, sin dependencias.
// Lo llaman export.sh y verify.sh. Cada subcomando escribe líneas separadas por
// tabuladores, fáciles de leer desde bash.
//
//   node json.mjs sets <asset-sets>            manifests de todos los sets, validados
//   node json.mjs root <manifest.json>         manifest raíz del vault
//   node json.mjs skill-manifest <fichero>     manifest opcional de una skill
//   node json.mjs hook <fichero>               comandos y env de un hook
//   node json.mjs mcp <fichero>                servidores y env de un mcp.json
//   node json.mjs merge-mcp <salida> <f>...    une varios mcp.json en uno
//   node json.mjs valid-date <AAAA-MM-DD>      0 si la fecha existe
//
// Códigos: 0 bien · 2 uso · 3 JSON no válido · 4 falta la clave principal · 5 clave repetida

import { readFileSync, readdirSync, statSync, existsSync, writeFileSync } from 'node:fs'
import { join } from 'node:path'

const STATUSES = ['PROPOSED', 'ACTIVE', 'DEPRECATED', 'SUSPENDED', 'ARCHIVED']
const SET_KEYS = ['name', 'description', 'version', 'kind', 'status', 'owner', 'dependencies', 'deprecation', 'suspension']
const DEPRECATION_KEYS = ['reason', 'retireOn', 'replacedBy']
const SUSPENSION_KEYS = ['reason']
const NAME_RE = /^[a-z\d]+(-[a-z\d]+)*$/
const SEMVER_RE = /^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$/

const clean = (value) => String(value ?? '').replace(/[\t\r\n]+/g, ' ').trim()
const out = (...fields) => process.stdout.write(fields.map(clean).join('\t') + '\n')

function readJson(file) {
  const text = readFileSync(file, 'utf8').replace(/^﻿/, '')
  return JSON.parse(text)
}

function isObject(value) {
  return value !== null && typeof value === 'object' && !Array.isArray(value)
}

function validDate(text) {
  if (typeof text !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(text)) return false
  const [y, m, d] = text.split('-').map(Number)
  const date = new Date(Date.UTC(y, m - 1, d))
  return date.getUTCFullYear() === y && date.getUTCMonth() === m - 1 && date.getUTCDate() === d
}

function distance(a, b) {
  const row = Array.from({ length: b.length + 1 }, (_, i) => i)
  for (let i = 1; i <= a.length; i++) {
    let previous = row[0]
    row[0] = i
    for (let j = 1; j <= b.length; j++) {
      const current = row[j]
      row[j] = Math.min(row[j] + 1, row[j - 1] + 1, previous + (a[i - 1] === b[j - 1] ? 0 : 1))
      previous = current
    }
  }
  return row[b.length]
}

function suggest(key, known) {
  let best = ''
  let bestDistance = 3
  for (const candidate of known) {
    const d = distance(key.toLowerCase(), candidate.toLowerCase())
    if (d < bestDistance) {
      best = candidate
      bestDistance = d
    }
  }
  return best
}

function unknownKeys(object, known, where, report) {
  for (const key of Object.keys(object)) {
    if (known.includes(key)) continue
    const close = suggest(key, known)
    report(
      `${where}: clave desconocida «${key}»`,
      close ? `¿querías decir «${close}»? Corrige el nombre de la clave` : `quítala; las claves válidas son ${known.join(', ')}`,
    )
  }
}

function stringList(value) {
  return Array.isArray(value) && value.every((item) => typeof item === 'string')
}

// ---------------------------------------------------------------- sets

function validateSet(folder, file) {
  const where = `asset-sets/${folder}/manifest.json`
  const errors = []
  const warnings = []
  const error = (message, fix = '') => errors.push([message, fix])
  const warn = (message, fix = '') => warnings.push([message, fix])

  let manifest
  try {
    manifest = readJson(file)
  } catch (problem) {
    error(`${where}: el JSON no es válido (${problem.message})`, 'corrige la sintaxis: comas, comillas y llaves')
    return { errors, warnings, row: null }
  }
  if (!isObject(manifest)) {
    error(`${where}: el manifest tiene que ser un objeto JSON`, '')
    return { errors, warnings, row: null }
  }

  unknownKeys(manifest, SET_KEYS, where, error)

  const { name, description, version, kind, status, owner, dependencies, deprecation, suspension } = manifest

  if (typeof name !== 'string' || !NAME_RE.test(name)) {
    error(`${where}: name tiene que ser minúsculas y guiones`, `usa "name": "${folder}"`)
  } else if (name !== folder) {
    error(`${where}: name es «${name}» y la carpeta, «${folder}»`, `haz que coincidan: renombra la carpeta a ${name} o cambia name a "${folder}"`)
  }
  if (typeof description !== 'string' || description.trim() === '') {
    error(`${where}: falta description`, 'añade una frase que diga para qué sirve el set')
  }
  if (typeof version !== 'string' || !SEMVER_RE.test(version)) {
    error(`${where}: version tiene que ser SemVer, como 1.0.0`, 'un set nuevo empieza en "0.1.0"')
  }
  if (kind !== 'asset-set') {
    error(`${where}: kind tiene que ser "asset-set"`, 'añade "kind": "asset-set"')
  }
  if (!STATUSES.includes(status)) {
    error(`${where}: status tiene que ser uno de ${STATUSES.join(', ')}`, 'un set nuevo empieza en "PROPOSED"')
  }

  if (owner !== undefined && (typeof owner !== 'string' || owner.trim() === '')) {
    error(`${where}: owner tiene que ser un texto no vacío`, 'pon el equipo responsable del set')
  } else if (owner === undefined) {
    if (status === 'ACTIVE' || status === 'DEPRECATED') {
      error(`${where}: un set ${status} necesita owner`, 'añade "owner": "<equipo>"')
    } else if (status === 'PROPOSED') {
      warn(`${folder} no tiene owner: propón uno en el PR`, '')
    }
  }

  let deps = []
  if (dependencies !== undefined) {
    if (!stringList(dependencies)) {
      error(`${where}: dependencies tiene que ser una lista de nombres de set`, 'por ejemplo "dependencies": ["front-react"]')
    } else {
      deps = dependencies
      const seen = new Set()
      for (const dep of deps) {
        if (seen.has(dep)) error(`${where}: dependencies repite «${dep}»`, 'déjalo una sola vez')
        seen.add(dep)
      }
    }
  }

  let retireOn = ''
  let replacedBy = []
  if (status === 'DEPRECATED') {
    if (!isObject(deprecation)) {
      error(`${where}: un set DEPRECATED necesita deprecation`, 'añade "deprecation": { "reason": "…", "retireOn": "AAAA-MM-DD" }')
    } else {
      unknownKeys(deprecation, DEPRECATION_KEYS, `${where} (deprecation)`, error)
      if (typeof deprecation.reason !== 'string' || deprecation.reason.trim() === '') {
        error(`${where}: falta deprecation.reason`, 'explica en una frase por qué se retira')
      }
      if (!validDate(deprecation.retireOn)) {
        error(`${where}: deprecation.retireOn tiene que ser una fecha AAAA-MM-DD`, 'por ejemplo "retireOn": "2027-06-30"')
      } else {
        retireOn = deprecation.retireOn
      }
      if (deprecation.replacedBy !== undefined) {
        if (!stringList(deprecation.replacedBy)) {
          error(`${where}: deprecation.replacedBy tiene que ser una lista de sets`, 'por ejemplo "replacedBy": ["front-react"]')
        } else {
          replacedBy = deprecation.replacedBy
        }
      }
    }
  } else if (deprecation !== undefined) {
    error(`${where}: deprecation solo va en un set DEPRECATED`, 'quítala o cambia status')
  }

  if (status === 'SUSPENDED') {
    if (!isObject(suspension) || typeof suspension.reason !== 'string' || suspension.reason.trim() === '') {
      error(`${where}: un set SUSPENDED necesita suspension.reason`, 'añade "suspension": { "reason": "…" }')
    } else {
      unknownKeys(suspension, SUSPENSION_KEYS, `${where} (suspension)`, error)
    }
  } else if (suspension !== undefined) {
    error(`${where}: suspension solo va en un set SUSPENDED`, 'quítala o cambia status')
  }

  const row = [
    folder,
    typeof name === 'string' ? name : '',
    STATUSES.includes(status) ? status : '',
    typeof owner === 'string' ? owner : '',
    typeof version === 'string' ? version : '',
    deps.join(','),
    retireOn,
    replacedBy.join(','),
    isObject(suspension) ? suspension.reason ?? '' : '',
    typeof description === 'string' ? description : '',
  ]
  return { errors, warnings, row }
}

function commandSets(dir) {
  if (!existsSync(dir)) {
    process.stderr.write(`no existe ${dir}\n`)
    process.exit(2)
  }
  const folders = readdirSync(dir)
    .filter((entry) => !entry.startsWith('.') && statSync(join(dir, entry)).isDirectory())
    .sort((a, b) => (a < b ? -1 : a > b ? 1 : 0))
  for (const folder of folders) {
    const file = join(dir, folder, 'manifest.json')
    if (!existsSync(file)) {
      out('error', folder, `asset-sets/${folder}: falta manifest.json`, 'cada set necesita su manifest.json')
      continue
    }
    const { errors, warnings, row } = validateSet(folder, file)
    if (row) out('set', ...row)
    for (const [message, fix] of errors) out('error', folder, message, fix)
    for (const [message, fix] of warnings) out('warn', folder, message, fix)
  }
}

// ---------------------------------------------------------------- root

function commandRoot(file) {
  let manifest
  try {
    manifest = readJson(file)
  } catch (problem) {
    out('error', `manifest.json: el JSON no es válido (${problem.message})`)
    return
  }
  if (!isObject(manifest)) return out('error', 'manifest.json: tiene que ser un objeto JSON')
  unknownKeys(manifest, ['name', 'kind', 'description'], 'manifest.json', (message) => out('error', message))
  if (typeof manifest.name !== 'string' || !NAME_RE.test(manifest.name)) out('error', 'manifest.json: name tiene que ser minúsculas y guiones')
  if (manifest.kind !== 'vault') out('error', 'manifest.json: kind tiene que ser "vault"')
  if (typeof manifest.description !== 'string' || manifest.description.trim() === '') out('error', 'manifest.json: falta description')
  out('root', manifest.name ?? '')
}

// ---------------------------------------------------------------- skill manifest

function commandSkillManifest(file) {
  let manifest
  try {
    manifest = readJson(file)
  } catch (problem) {
    out('error', `el JSON no es válido (${problem.message})`)
    process.exit(3)
  }
  if (!isObject(manifest)) {
    out('error', 'tiene que ser un objeto JSON')
    process.exit(3)
  }
  unknownKeys(manifest, ['name', 'topic', 'calls'], 'manifest de skill', (message) => out('error', message))
  if (typeof manifest.topic !== 'string' || manifest.topic.trim() === '') out('error', 'falta topic')
  if (manifest.calls !== undefined && !stringList(manifest.calls)) out('error', 'calls tiene que ser una lista de skills')
  out('name', manifest.name ?? '')
  out('topic', manifest.topic ?? '')
  out('calls', stringList(manifest.calls) ? manifest.calls.join(',') : '')
}

// ---------------------------------------------------------------- hooks and mcp

function loadOrExit(file, key) {
  let data
  try {
    data = readJson(file)
  } catch (problem) {
    process.stderr.write(`${file}: el JSON no es válido (${problem.message})\n`)
    process.exit(3)
  }
  if (!isObject(data) || !isObject(data[key])) {
    process.stderr.write(`${file}: falta el objeto «${key}»\n`)
    process.exit(4)
  }
  return data
}

function printEnv(prefix, env) {
  if (!isObject(env)) return
  for (const key of Object.keys(env).sort()) out('env', prefix, key, env[key])
}

function commandHook(file) {
  const data = loadOrExit(file, 'hooks')
  const visit = (node, event) => {
    if (Array.isArray(node)) return node.forEach((item) => visit(item, event))
    if (!isObject(node)) return
    if (typeof node.command === 'string') {
      out('command', event, node.command)
      printEnv(event, node.env)
    }
    if (Array.isArray(node.hooks)) visit(node.hooks, event)
  }
  for (const event of Object.keys(data.hooks).sort()) visit(data.hooks[event], event)
}

function commandMcp(file) {
  const data = loadOrExit(file, 'mcpServers')
  for (const key of Object.keys(data.mcpServers).sort()) {
    const server = data.mcpServers[key]
    if (!isObject(server)) {
      out('server', key, '(no es un objeto)')
      continue
    }
    const parts = server.command ? [server.command, ...(Array.isArray(server.args) ? server.args : [])] : [server.url ?? server.type ?? '']
    out('server', key, parts.join(' '))
    printEnv(key, server.env)
  }
}

function commandMergeMcp(target, files) {
  const servers = {}
  const origin = {}
  for (const file of files) {
    const data = loadOrExit(file, 'mcpServers')
    for (const key of Object.keys(data.mcpServers)) {
      if (key in servers) {
        process.stderr.write(`el servidor MCP «${key}» está en dos sets de la línea de dependencia: ${origin[key]} y ${file}\n`)
        process.exit(5)
      }
      servers[key] = data.mcpServers[key]
      origin[key] = file
    }
  }
  // Servidores en orden alfabético; cada uno, tal como lo escribió su set.
  const sorted = Object.fromEntries(Object.keys(servers).sort().map((key) => [key, servers[key]]))
  writeFileSync(target, JSON.stringify({ mcpServers: sorted }, null, 2) + '\n')
}

// ---------------------------------------------------------------- main

const [command, ...args] = process.argv.slice(2)
switch (command) {
  case 'sets':
    commandSets(args[0])
    break
  case 'root':
    commandRoot(args[0])
    break
  case 'skill-manifest':
    commandSkillManifest(args[0])
    break
  case 'hook':
    commandHook(args[0])
    break
  case 'mcp':
    commandMcp(args[0])
    break
  case 'merge-mcp':
    commandMergeMcp(args[0], args.slice(1))
    break
  case 'valid-date':
    process.exit(validDate(args[0]) ? 0 : 1)
    break
  default:
    process.stderr.write('uso: node json.mjs sets|root|skill-manifest|hook|mcp|merge-mcp|valid-date …\n')
    process.exit(2)
}
