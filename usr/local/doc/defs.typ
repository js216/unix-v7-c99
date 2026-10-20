#let running = context {
  let p = here().page()
  let k = p
  let n = str(k)
  let here-p(h) = h.location().page() == p
  if p == 1 or query(heading.where(level: 1)).any(here-p) or query(heading.where(level: 2)).any(here-p) {
    none
  } else if query(heading.where(level: 2).before(here())).len() == 0 {
    if calc.even(k) { n } else { align(right, n) }
  } else if calc.even(k) {
    let sec = query(heading.where(level: 2).before(here())).last()
    n + h(1fr) + emph(str(counter(heading).at(sec.location()).at(1)) + h(1em) + sec.body)
  } else {
    let on = query(heading.where(level: 3)).filter(here-p)
    let prev = query(heading.where(level: 3).before(here()))
    let sub = if on.len() > 0 { on.first() } else if prev.len() > 0 { prev.last() } else { none }
    if sub == none { align(right, n) } else { emph(sub.body) + h(1fr) + n }
  }
}
#let opening-foot = context {
  let p = here().page()
  let here-p(h) = h.location().page() == p
  if query(heading.where(level: 2)).any(here-p) and not query(heading.where(level: 1)).any(here-p) {
    align(center, str(p))
  }
}
#let file = state("file", "")
#let text-of(path) = read(path).trim("\n", at: end).split("\n")
#let source(path) = { file.update(path); [#heading(level: 3, path)#label(if path.ends-with("/c.c") or path.ends-with(".ld") or path.starts-with("/usr/src/") or path.starts-with("/usr/include/sys/") or path.starts-with("/usr/local/test/") { path.split("/").slice(-2).join("/") } else { path.split("/").last() })] }
#let f(name) = link(label(name), raw(name))

// Line references found by the text of the line, not by number.
#let lab-of(path) = if path.ends-with("/c.c") or path.ends-with(".ld") or path.starts-with("/usr/src/") or path.starts-with("/usr/include/sys/") or path.starts-with("/usr/local/test/") { path.split("/").slice(-2).join("/") } else { path.split("/").last() }

// The trimmed lines of a file, read once.
#let trimmed(path) = text-of(path).map(l => l.trim())

// The lines in [a, b] (1-based) whose trimmed text begins with needle,
// or, with exact, equals it.
#let hits-in(path, needle, a, b, exact: false) = {
  let ls = trimmed(path)
  range(a - 1, calc.min(b, ls.len())).filter(i => if exact { ls.at(i) == needle } else { ls.at(i).starts-with(needle) }).map(i => i + 1)
}

// Find the one line whose trimmed text begins with needle. With after:,
// the first such line after the unique line which begins with after; with
// before:, the last such line before it.
#let find(path, needle, after: none, before: none) = {
  let ls = trimmed(path)
  if before != none {
    let h = hits-in(path, before, 1, ls.len())
    assert(h.len() == 1, message: path + ": before " + repr(before) + " matches " + str(h.len()) + " lines")
    let h2 = hits-in(path, needle, 1, h.first() - 1)
    assert(h2.len() > 0, message: path + ": " + repr(needle) + " not found before " + repr(before))
    return h2.last()
  }
  if after != none {
    let h = hits-in(path, after, 1, ls.len())
    assert(h.len() == 1, message: path + ": after " + repr(after) + " matches " + str(h.len()) + " lines")
    let h2 = hits-in(path, needle, h.first() + 1, ls.len())
    assert(h2.len() > 0, message: path + ": " + repr(needle) + " not found after " + repr(after))
    return h2.first()
  }
  let h = hits-in(path, needle, 1, ls.len())
  assert(h.len() == 1, message: path + ": " + repr(needle) + " matches " + str(h.len()) + " lines")
  h.first()
}

#let target(path, n) = label(path + ":" + str(n))

// Print a line number which links to the line, if it is listed.
#let numlink(path, n, body) = context {
  let t = target(path, n)
  let q = query(t)
  if q.len() > 0 { link(q.first().location(), body) } else { link(label(lab-of(path)), body) }
}

// A reference within the current file's commentary: the line, linked.
#let l(needle, after: none, before: none) = context {
  let path = file.get()
  let n = find(path, needle, after: after, before: before)
  numlink(path, n, str(n))
}

// A range of lines, from the line of a to that of b.
#let lr(a, b) = [#l(a)--#l(b)]

// A reference to a line of any file: "file n", the number linked.
#let at(path, needle, after: none, before: none) = {
  let n = find(path, needle, after: after, before: before)
  [#link(label(lab-of(path)), raw(lab-of(path)))~#numlink(path, n, str(n))]
}

// A fragment of the current file, from where the last one ended to the
// line before the one beginning with until, or to the end of the file.
// Blank lines just before until end this fragment.
#let cursor = state("cursor", (path: "", a: 1, b: 0, next: 1))
#let fragment(a, b) = context {
  let path = file.get()
  show raw.line: ln => {
    let n = ln.number + a - 1
    [#metadata(none)#label(path + ":" + str(n))]
    box(width: 3em, align(right, text(fill: gray, str(n)))) + h(1em) + box(width: 1fr, ln.body)
  }
  raw(text-of(path).slice(a - 1, b).join("\n"), block: true)
}
// The cursor is moved by update functions, which Typst applies in order
// in a single pass, so a long run of fragments needs no extra iterations.
#let advance(path, until, lead, after, exact) = c => {
  let a = if c.path == path { c.next } else { 1 }
  let ls = trimmed(path)
  let b = if until == none { ls.len() } else {
    // after: search for until only past the first line, from a, which
    // begins with after.
    let from = a
    if after != none {
      let ha = hits-in(path, after, a, ls.len())
      assert(ha.len() > 0, message: path + ": fragment anchor " + repr(after) + " not found")
      from = ha.first() + 1
    }
    let h = hits-in(path, until, from, ls.len(), exact: exact)
    assert(h.len() > 0, message: path + ": fragment end " + repr(until) + " not found")
    let e = h.first() - 1
    // lead: the blank lines before until begin the next fragment.
    if lead { while e >= a and ls.at(e - 1) == "" { e -= 1 } }
    e
  }
  (path: path, a: a, b: b, next: b + 1)
}
#let lines-to(until, lead: false, after: none, exact: false) = context {
  cursor.update(advance(file.get(), until, lead, after, exact))
  context { let c = cursor.get(); fragment(c.a, c.b) }
}
// A numbered fragment, which also moves the cursor.
#let lines(a, b) = context {
  let path = file.get()
  cursor.update(c => (path: path, a: a, b: b, next: b + 1))
  fragment(a, b)
}
#let listing(path) = { source(path); lines(1, text-of(path).len()) }

#let pageref(l) = context link(l, str(counter(page).at(l).first()))
