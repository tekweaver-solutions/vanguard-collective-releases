// WP-7's own reading of ui/src (UI-1 S3, s3-falsifiers.md L-3, L-7, L-8, L-10): parsed with the TypeScript compiler
// that ui/'s own lockfile pins, never by the subject's code. Prints one JSON object; WP-7 judges it.
//   usage: node tests/lam/wp7-ui-audit.mjs <ui-dir>
//   routes  -- App.tsx's routes array: its paths (L-3 "exactly four")
//   math    -- every `/`, `%`, `/=`, `%=` and `* 100` outside the vendored src/components/ui/, except pct()'s `* 100` and
//              duration()'s `/` in src/lib/format.ts, the display formatting (L-7 "the SPA computes no ratio")
//   kpi     -- the files that put data-kpi-tile on an element; the four screens and whether each reaches
//              components/KpiTile.tsx through its imports (L-8 "one component ... used by all four screens")
//   colours -- hex and rgb()/rgba() literals in src/ outside styles/tokens.css; named CSS colours in colour attributes,
//              style keys and Tailwind arbitrary values; the token file's custom properties per theme block; the files
//              that use the accent `brand` (L-10)
import fs from "node:fs"
import path from "node:path"
import { createRequire } from "node:module"

const ui = path.resolve(process.argv[2])
const src = path.join(ui, "src")
const ts = createRequire(path.join(ui, "package.json"))("typescript")

const files = []
;(function walk(d) {
  for (const e of fs.readdirSync(d, { withFileTypes: true })) {
    const p = path.join(d, e.name)
    if (e.isDirectory()) walk(p)
    else files.push(p)
  }
})(src)
const rel = (p) => path.relative(ui, p).split(path.sep).join("/")
const code = files.filter((f) => /\.(ts|tsx)$/.test(f))
const parse = (f) => ts.createSourceFile(f, fs.readFileSync(f, "utf8"), ts.ScriptTarget.Latest, true, f.endsWith(".tsx") ? ts.ScriptKind.TSX : ts.ScriptKind.TS)

const out = { routes: [], math: [], mathAllowed: [], kpi: { attribute: [], screens: {} }, colours: { literals: [], named: [], tokens: {}, brand: [] }, files: code.map(rel) }

// routes
{
  const sf = parse(path.join(src, "App.tsx"))
  ts.forEachChild(sf, function visit(n) {
    if (ts.isVariableDeclaration(n) && n.name.getText() === "routes" && n.initializer && ts.isArrayLiteralExpression(n.initializer)) {
      for (const el of n.initializer.elements) {
        const p = ts.isObjectLiteralExpression(el) && el.properties.find((x) => x.name && x.name.getText() === "path")
        out.routes.push(p ? p.initializer.getText().replace(/^["'`]|["'`]$/g, "") : "(no path)")
      }
    }
    ts.forEachChild(n, visit)
  })
}

// math -- everywhere but the vendored components; in src/lib/format.ts only the two display formatters may do it:
// pct() multiplies an API ratio by 100, duration() divides the API's seconds into units. Anything else there -- a
// new helper, a division inside pct -- is reported like anywhere else.
const vendored = (f) => rel(f).startsWith("src/components/ui/")
const isHundred = (n) => ts.isNumericLiteral(n) && Number(n.text) === 100
const FORMAT_ALLOWED = { pct: "hundred", duration: "div" }
const enclosingFn = (n) => {
  for (let p = n.parent; p; p = p.parent) if (ts.isFunctionDeclaration(p) && p.name) return p.name.text
  return null
}
for (const f of code.filter((x) => !vendored(x))) {
  const sf = parse(f)
  const isFormat = rel(f) === "src/lib/format.ts"
  ts.forEachChild(sf, function visit(n) {
    if (ts.isBinaryExpression(n)) {
      const k = n.operatorToken.kind
      const div = k === ts.SyntaxKind.SlashToken || k === ts.SyntaxKind.PercentToken || k === ts.SyntaxKind.SlashEqualsToken || k === ts.SyntaxKind.PercentEqualsToken
      const hundred = k === ts.SyntaxKind.AsteriskToken && (isHundred(n.left) || isHundred(n.right))
      const slashOnly = k === ts.SyntaxKind.SlashToken
      const allowed = isFormat && ((FORMAT_ALLOWED[enclosingFn(n)] === "hundred" && hundred) || (FORMAT_ALLOWED[enclosingFn(n)] === "div" && slashOnly))
      if ((div || hundred) && !allowed) out.math.push(`${rel(f)}:${sf.getLineAndCharacterOfPosition(n.getStart()).line + 1}: ${n.getText().slice(0, 120)}`)
      if ((div || hundred) && allowed) out.mathAllowed.push(`${rel(f)}:${sf.getLineAndCharacterOfPosition(n.getStart()).line + 1} in ${enclosingFn(n)}(): ${n.getText().slice(0, 60)}`)
    }
    ts.forEachChild(n, visit)
  })
}

// kpi
const importsOf = (f) => {
  const sf = parse(f)
  const res = []
  ts.forEachChild(sf, (n) => {
    if ((ts.isImportDeclaration(n) || ts.isExportDeclaration(n)) && n.moduleSpecifier) res.push(n.moduleSpecifier.text)
    if (ts.isVariableStatement(n)) n.forEachChild(function v(m) { if (ts.isCallExpression(m) && m.expression.kind === ts.SyntaxKind.ImportKeyword) res.push(m.arguments[0].text); m.forEachChild(v) })
  })
  return res
    .filter((s) => s.startsWith("@/") || s.startsWith("."))
    .map((s) => (s.startsWith("@/") ? path.join(src, s.slice(2)) : path.resolve(path.dirname(f), s)))
    .map((b) => [b + ".tsx", b + ".ts", path.join(b, "index.tsx"), path.join(b, "index.ts"), b].find((c) => fs.existsSync(c) && fs.statSync(c).isFile()))
    .filter(Boolean)
}
const reaches = (start, target) => {
  const seen = new Set()
  const stack = [start]
  while (stack.length) {
    const f = stack.pop()
    if (seen.has(f)) continue
    seen.add(f)
    if (f === target) return true
    stack.push(...importsOf(f))
  }
  return false
}
for (const f of code) {
  const sf = parse(f)
  ts.forEachChild(sf, function visit(n) {
    if (ts.isJsxAttribute(n) && n.name.getText() === "data-kpi-tile") out.kpi.attribute.push(rel(f))
    ts.forEachChild(n, visit)
  })
}
const tile = path.join(src, "components", "KpiTile.tsx")
for (const s of ["FleetPage", "ProjectPage", "MissionStatsPage", "FleetStatsPage"]) {
  const f = path.join(src, "pages", s + ".tsx")
  out.kpi.screens[s] = fs.existsSync(f) && reaches(f, tile)
}
out.kpi.exports = fs.existsSync(tile) ? [...fs.readFileSync(tile, "utf8").matchAll(/^export (?:function|const|class) (\w+)/gm)].map((m) => m[1]) : []

// colours
for (const f of files.filter((x) => rel(x) !== "src/styles/tokens.css" && /\.(ts|tsx|css|js|mjs|html)$/.test(x))) {
  fs.readFileSync(f, "utf8").split("\n").forEach((l, i) => {
    if (/#[0-9a-fA-F]{3,8}\b/.test(l) || /\brgba?\s*\(/i.test(l) || /\bhsla?\s*\(\s*\d/i.test(l)) out.colours.literals.push(`${rel(f)}:${i + 1}: ${l.trim().slice(0, 120)}`)
    if (/\bbrand\b/.test(l.replace(/\/\/.*$/, ""))) out.colours.brand.push(`${rel(f)}:${i + 1}`)
  })
}
// named colours (validator round 1): a colour-bearing JSX attribute or style key whose value is a literal that is not
// a token reference, and a Tailwind arbitrary value naming a CSS colour (text-[crimson]), anywhere under src/.
const CSS_NAMES = new Set(("aliceblue antiquewhite aqua aquamarine azure beige bisque black blanchedalmond blue blueviolet brown burlywood " +
  "cadetblue chartreuse chocolate coral cornflowerblue cornsilk crimson cyan darkblue darkcyan darkgoldenrod darkgray darkgreen darkgrey " +
  "darkkhaki darkmagenta darkolivegreen darkorange darkorchid darkred darksalmon darkseagreen darkslateblue darkslategray darkslategrey " +
  "darkturquoise darkviolet deeppink deepskyblue dimgray dimgrey dodgerblue firebrick floralwhite forestgreen fuchsia gainsboro ghostwhite " +
  "gold goldenrod gray green greenyellow grey honeydew hotpink indianred indigo ivory khaki lavender lavenderblush lawngreen lemonchiffon " +
  "lightblue lightcoral lightcyan lightgoldenrodyellow lightgray lightgreen lightgrey lightpink lightsalmon lightseagreen lightskyblue " +
  "lightslategray lightslategrey lightsteelblue lightyellow lime limegreen linen magenta maroon mediumaquamarine mediumblue mediumorchid " +
  "mediumpurple mediumseagreen mediumslateblue mediumspringgreen mediumturquoise mediumvioletred midnightblue mintcream mistyrose moccasin " +
  "navajowhite navy oldlace olive olivedrab orange orangered orchid palegoldenrod palegreen paleturquoise palevioletred papayawhip peachpuff " +
  "peru pink plum powderblue purple rebeccapurple red rosybrown royalblue saddlebrown salmon sandybrown seagreen seashell sienna silver " +
  "skyblue slateblue slategray slategrey snow springgreen steelblue tan teal thistle tomato turquoise violet wheat white whitesmoke yellow yellowgreen").split(" "))
const TOKEN_VALUE = /^(hsl\(var\(--[\w-]+\)\)|var\(--[\w-]+\)|currentColor|none|transparent|inherit|url\(#[\w-]+\))$/
const COLOUR_ATTR = new Set(["stroke", "fill", "color", "stopColor", "floodColor", "lightingColor", "bgcolor", "background"])
const COLOUR_KEY = /(color|fill|stroke|background|border)$/i
const literalOf = (e) => (e && (ts.isStringLiteral(e) || ts.isNoSubstitutionTemplateLiteral(e)) ? e.text : null)
for (const f of code) {
  const sf = parse(f)
  const at = (n) => `${rel(f)}:${sf.getLineAndCharacterOfPosition(n.getStart()).line + 1}`
  ts.forEachChild(sf, function visit(n) {
    if (ts.isJsxAttribute(n) && COLOUR_ATTR.has(n.name.getText()) && n.initializer) {
      const v = literalOf(n.initializer) ?? (ts.isJsxExpression(n.initializer) ? literalOf(n.initializer.expression) : null)
      if (v !== null && !TOKEN_VALUE.test(v.trim())) out.colours.named.push(`${at(n)}: ${n.name.getText()}="${v}"`)
    }
    if (ts.isPropertyAssignment(n) && COLOUR_KEY.test(n.name.getText().replace(/["']/g, ""))) {
      const v = literalOf(n.initializer)
      if (v !== null && !TOKEN_VALUE.test(v.trim()) && v.split(/\s+/).some((w) => CSS_NAMES.has(w.toLowerCase()))) out.colours.named.push(`${at(n)}: ${n.name.getText()}: "${v}"`)
    }
    const s = literalOf(n)
    if (s !== null) for (const m of s.matchAll(/-\[([a-zA-Z]+)\]/g)) if (CSS_NAMES.has(m[1].toLowerCase())) out.colours.named.push(`${at(n)}: ${m[0]}`)
    ts.forEachChild(n, visit)
  })
}
{
  const css = fs.readFileSync(path.join(src, "styles", "tokens.css"), "utf8")
  for (const m of css.matchAll(/(:root|\.dark)\s*\{([^}]*)\}/g)) out.colours.tokens[m[1]] = [...m[2].matchAll(/--([\w-]+)\s*:/g)].map((x) => x[1])
  out.colours.tokenHex = (css.match(/#[0-9a-fA-F]{3,8}\b/g) || []).length
}
out.colours.validating = /Validating:\s*\{\s*tone:\s*"neutral",\s*dot:\s*"brand"\s*\}/.test(fs.readFileSync(path.join(src, "components", "Badges.tsx"), "utf8"))
console.log(JSON.stringify(out))
