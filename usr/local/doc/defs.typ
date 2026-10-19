#let running = context {
  let p = here().page()
  let k = p - locate(<main>).page() + 1
  let n = str(k)
  let here-p(h) = h.location().page() == p
  if query(heading.where(level: 1)).any(here-p) or query(heading.where(level: 2)).any(here-p) {
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
#let file = state("file", "")
#let text-of(path) = read(path).trim("\n", at: end).split("\n")
#let lines(a, b) = context {
  show raw.line: l => box(width: 3em, align(right, text(fill: gray, str(l.number + a - 1)))) + h(1em) + box(width: 1fr, l.body)
  raw(text-of(file.get()).slice(a - 1, b).join("\n"), block: true)
}
#let source(path) = { file.update(path); [#heading(level: 3, path)#label(if path.ends-with("/c.c") or path.ends-with(".ld") or path.starts-with("/usr/src/") or path.starts-with("/usr/include/sys/") or path.starts-with("/usr/local/test/") { path.split("/").slice(-2).join("/") } else { path.split("/").last() })] }
#let f(name) = link(label(name), raw(name))
#let listing(path) = { source(path); lines(1, text-of(path).len()) }
