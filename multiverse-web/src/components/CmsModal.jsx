import React, { useEffect, useState } from "react"
import Modal from "./Modal"
import { getCmsPage } from "../services/cms"
import { renderCmsContent } from "../utils/cmsRender"

const CmsModal = ({ slug, title, fallback, onClose }) => {
  const [page, setPage] = useState(null)
  const [ready, setReady] = useState(false)

  useEffect(() => {
    let active = true
    setPage(null)
    setReady(false)
    getCmsPage(slug).then((p) => {
      if (!active) return
      setPage(p)
      setReady(true)
    })
    return () => {
      active = false
    }
  }, [slug])

  const hasCms = ready && page && page.published && page.content && page.content.trim()

  return (
    <Modal title={ready && page && page.title ? page.title : title} onClose={onClose}>
      {hasCms ? (
        renderCmsContent(page.content)
      ) : fallback ? (
        fallback
      ) : (
        <p className="text-white/60 text-sm leading-relaxed">
          This content is being prepared. Please check back soon.
        </p>
      )}
    </Modal>
  )
}

export default CmsModal
