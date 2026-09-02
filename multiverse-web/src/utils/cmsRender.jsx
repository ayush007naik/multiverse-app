import React from "react"

function renderInline(text) {
  const parts = text.split(/(\*\*[^*]+\*\*)/g)
  return parts.map((part, i) =>
    part.startsWith("**") && part.endsWith("**") ? (
      <strong key={i} className="text-white font-bold">
        {part.slice(2, -2)}
      </strong>
    ) : (
      <React.Fragment key={i}>{part}</React.Fragment>
    )
  )
}

export function renderCmsContent(content) {
  if (!content || !content.trim()) return null
  const lines = content.split("\n")
  const blocks = []
  let list = null
  let paragraph = []

  const flushParagraph = () => {
    if (paragraph.length) {
      blocks.push({ type: "p", text: paragraph.join(" ") })
      paragraph = []
    }
  }
  const flushList = () => {
    if (list) {
      blocks.push({ type: list.type, items: list.items })
      list = null
    }
  }

  for (const raw of lines) {
    const trimmed = raw.trim()
    if (!trimmed) {
      flushParagraph()
      flushList()
      continue
    }
    const hMatch = trimmed.match(/^(#{1,4})\s+(.*)$/)
    if (hMatch) {
      flushParagraph()
      flushList()
      blocks.push({ type: "h", level: hMatch[1].length, text: hMatch[2] })
      continue
    }
    const ulMatch = trimmed.match(/^[-*]\s+(.*)$/)
    if (ulMatch) {
      flushParagraph()
      if (!list || list.type !== "ul") {
        flushList()
        list = { type: "ul", items: [] }
      }
      list.items.push(ulMatch[1])
      continue
    }
    const olMatch = trimmed.match(/^\d+[.)]\s+(.*)$/)
    if (olMatch) {
      flushParagraph()
      if (!list || list.type !== "ol") {
        flushList()
        list = { type: "ol", items: [] }
      }
      list.items.push(olMatch[1])
      continue
    }
    flushList()
    paragraph.push(trimmed)
  }
  flushParagraph()
  flushList()

  return (
    <div className="space-y-5 text-white/60 text-sm leading-relaxed">
      {blocks.map((b, i) => {
        switch (b.type) {
          case "h": {
            const Tag = ["h1", "h2", "h3", "h4"][b.level - 1] || "h2"
            const cls =
              b.level === 1
                ? "text-2xl font-black text-white"
                : b.level === 2
                ? "text-xl font-bold text-white"
                : "text-lg font-bold text-white"
            return (
              <Tag key={i} className={`${cls} mt-2`}>
                {renderInline(b.text)}
              </Tag>
            )
          }
          case "p":
            return <p key={i}>{renderInline(b.text)}</p>
          case "ul":
            return (
              <ul key={i} className="list-disc pl-5 space-y-2">
                {b.items.map((it, j) => (
                  <li key={j}>{renderInline(it)}</li>
                ))}
              </ul>
            )
          case "ol":
            return (
              <ol key={i} className="list-decimal pl-5 space-y-2">
                {b.items.map((it, j) => (
                  <li key={j}>{renderInline(it)}</li>
                ))}
              </ol>
            )
          default:
            return null
        }
      })}
    </div>
  )
}
