"""The mission-event line validator: a draft-07 SUBSET read from docs/framework/mission-event.schema.json.

No dependency is added for it (the pinned set is fastapi, uvicorn, typer and what they require). It knows the
keywords that schema uses and REFUSES TO LOAD a schema that uses any other, so a keyword is never ignored
silently. pattern is ECMA-262 as JSON Schema says: unanchored search, and `$` is the end of the string only.
"""
import json
import re

_ANNOTATIONS = {"$schema", "$id", "title", "description"}
_KEYWORDS = {"type", "required", "properties", "additionalProperties", "pattern", "minimum", "minLength",
             "enum", "const", "items", "allOf", "anyOf", "not", "if", "then", "else"} | _ANNOTATIONS


def _ecma_pattern(p):
    """`$` outside a character class means end-of-input in ECMA-262 (no multiline flag); Python's `$` also
    matches before a final newline, so it becomes \\Z. ECMA-262's `.` matches no line terminator (LF, CR,
    U+2028, U+2029); Python's refuses LF only, so `.` becomes the class of everything else."""
    out, i, in_class = [], 0, False
    while i < len(p):
        c = p[i]
        if c == "\\" and i + 1 < len(p):
            out.append(p[i:i + 2]); i += 2; continue
        if c == "[" and not in_class:
            in_class = True
        elif c == "]" and in_class:
            in_class = False
        elif c == "$" and not in_class:
            out.append(r"\Z"); i += 1; continue
        elif c == "." and not in_class:
            out.append("[^\n\r\u2028\u2029]"); i += 1; continue
        out.append(c); i += 1
    return re.compile("".join(out))


def _is_type(v, t):
    if t == "null":
        return v is None
    if t == "boolean":
        return isinstance(v, bool)
    if t == "object":
        return isinstance(v, dict)
    if t == "array":
        return isinstance(v, list)
    if t == "string":
        return isinstance(v, str)
    if t == "integer":
        return (isinstance(v, int) and not isinstance(v, bool)) or (isinstance(v, float) and v.is_integer())
    if t == "number":
        return isinstance(v, (int, float)) and not isinstance(v, bool)
    raise ValueError("unknown type " + t)


def _equal(a, b):
    if isinstance(a, bool) or isinstance(b, bool):
        return type(a) is type(b) and a == b
    return a == b


class Validator:
    def __init__(self, schema):
        self.schema = schema
        self._compiled = {}
        self._check_keywords(schema, "")

    @classmethod
    def from_file(cls, path):
        with open(path, "rb") as f:
            return cls(json.loads(f.read().decode("utf-8")))

    def _check_keywords(self, s, ptr):
        if isinstance(s, bool):
            return
        unknown = set(s) - _KEYWORDS
        if unknown:
            raise ValueError("schema keyword(s) this validator does not implement at %s: %s" % (ptr or "/", ", ".join(sorted(unknown))))
        for k in ("properties",):
            for name, sub in s.get(k, {}).items():
                self._check_keywords(sub, ptr + "/" + k + "/" + name)
        for k in ("allOf", "anyOf"):
            for n, sub in enumerate(s.get(k, [])):
                self._check_keywords(sub, "%s/%s/%d" % (ptr, k, n))
        for k in ("not", "if", "then", "else", "items", "additionalProperties"):
            if isinstance(s.get(k), dict):
                self._check_keywords(s[k], ptr + "/" + k)
        if "pattern" in s:
            self._compiled[s["pattern"]] = _ecma_pattern(s["pattern"])

    def known_kinds(self):
        """The kinds the schema has an if/then block for (const or enum on kind) -- every other kind is unknown."""
        kinds = set()
        for blk in self.schema.get("allOf", []):
            kp = blk.get("if", {}).get("properties", {}).get("kind", {})
            if "const" in kp:
                kinds.add(kp["const"])
            kinds.update(kp.get("enum", []))
        return kinds

    def first_error(self, instance):
        """None when the instance validates, else the first failure as 'pointer: reason'."""
        return self._v(instance, self.schema, "")

    def _v(self, i, s, p):
        if isinstance(s, bool):
            return None if s else "%s: false schema" % (p or "/")
        at = p or "/"
        if "type" in s:
            types = s["type"] if isinstance(s["type"], list) else [s["type"]]
            if not any(_is_type(i, t) for t in types):
                return "%s: type is not %s" % (at, "|".join(types))
        if "const" in s and not _equal(i, s["const"]):
            return "%s: not const %r" % (at, s["const"])
        if "enum" in s and not any(_equal(i, e) for e in s["enum"]):
            return "%s: not in enum (%s)" % (at, ", ".join(map(str, s["enum"])))
        if isinstance(i, str):
            if "pattern" in s and not self._compiled[s["pattern"]].search(i):
                return "%s: does not match %s" % (at, s["pattern"])
            if "minLength" in s and len(i) < s["minLength"]:
                return "%s: shorter than %d" % (at, s["minLength"])
        if "minimum" in s and _is_type(i, "number") and i < s["minimum"]:
            return "%s: below %s" % (at, s["minimum"])
        if isinstance(i, dict):
            for r in s.get("required", []):
                if r not in i:
                    return "%s: required '%s' absent" % (at, r)
            props = s.get("properties", {})
            for name, sub in props.items():
                if name in i:
                    e = self._v(i[name], sub, p + "/" + name)
                    if e:
                        return e
            ap = s.get("additionalProperties", True)
            if ap is not True:
                for name in i:
                    if name not in props:
                        e = self._v(i[name], ap, p + "/" + name)
                        if e:
                            return e
        if isinstance(i, list) and "items" in s:
            for n, it in enumerate(i):
                e = self._v(it, s["items"], "%s/%d" % (p, n))
                if e:
                    return e
        for sub in s.get("allOf", []):
            e = self._v(i, sub, p)
            if e:
                return e
        if "anyOf" in s and all(self._v(i, sub, p) for sub in s["anyOf"]):
            return "%s: matches no anyOf branch" % at
        if "not" in s and not self._v(i, s["not"], p):
            return "%s: matches a 'not' schema" % at
        if "if" in s:
            if not self._v(i, s["if"], p):
                if "then" in s:
                    return self._v(i, s["then"], p)
            elif "else" in s:
                return self._v(i, s["else"], p)
        return None
