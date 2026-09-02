const PROJECT_ID = "multiverses-8d207"
const API_KEY = "AIzaSyCCwrgcpuhh5v7IC8dIfSQdNhym3Z9QL00"
const BASE = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents`

function fields(doc) {
  const out = {}
  const f = (doc && doc.fields) || {}
  for (const k in f) {
    const v = f[k]
    if ("stringValue" in v) out[k] = v.stringValue
    else if ("booleanValue" in v) out[k] = v.booleanValue
    else if ("integerValue" in v) out[k] = parseInt(v.integerValue, 10)
    else if ("doubleValue" in v) out[k] = parseFloat(v.doubleValue)
    else if ("timestampValue" in v) out[k] = v.timestampValue
    else if ("mapValue" in v) out[k] = v.mapValue
    else out[k] = null
  }
  return out
}

async function runQuery(query) {
  try {
    const res = await fetch(`${BASE}:runQuery?key=${API_KEY}`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ structuredQuery: query }),
    })
    if (!res.ok) return []
    const results = await res.json()
    return (results || [])
      .filter((r) => r.document)
      .map((r) => ({
        id: r.document.name.split("/").pop(),
        ...fields(r.document),
      }))
  } catch (e) {
    return []
  }
}

export async function getCmsPage(slug) {
  try {
    const res = await fetch(`${BASE}/cms_pages/${slug}?key=${API_KEY}`)
    if (!res.ok) return null
    const doc = await res.json()
    const data = fields(doc)
    return {
      slug,
      title: data.title || "",
      content: data.content || "",
      published: data.published === undefined ? true : data.published,
    }
  } catch (e) {
    return null
  }
}

export async function getFaqs() {
  return runQuery({
    from: [{ collectionId: "faqs" }],
    orderBy: [{ field: { fieldPath: "order" }, direction: "ASCENDING" }],
  })
}

export async function getBlogs() {
  return runQuery({
    from: [{ collectionId: "blogs" }],
    where: {
      fieldFilter: {
        field: { fieldPath: "published" },
        op: "EQUAL",
        value: { booleanValue: true },
      },
    },
    orderBy: [{ field: { fieldPath: "createdAt" }, direction: "DESCENDING" }],
  })
}
