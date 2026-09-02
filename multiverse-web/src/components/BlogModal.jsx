import React, { useEffect, useState } from "react"
import Modal from "./Modal"
import { getBlogs } from "../services/cms"

const FALLBACK_POSTS = [
  {
    title: "Multiverse City Launches in Mandi",
    date: "May 2026",
    content:
      "We are excited to announce the official launch of Multiverse City in Mandi, Himachal Pradesh. Starting with grocery delivery, movie tickets, and appointment booking, we aim to serve the entire district with a unified digital platform. Our goal is to empower local businesses and provide citizens with a seamless, world-class experience.",
  },
  {
    title: "How Multiverse City is Digitizing Local Commerce",
    date: "June 2026",
    content:
      "Local businesses are the backbone of every city. Multiverse City provides verified merchants with a digital storefront, real-time order management, and analytics dashboard — helping them reach thousands of new customers without any technical knowledge. Join 500+ businesses already on the platform.",
  },
  {
    title: "5 Ways to Save Money with Multiverse City",
    date: "June 2026",
    content:
      "1. Use the referral program to earn cashback on every friend's first order. 2. Check the Deals section daily for limited-time offers. 3. Bundle orders to save on delivery fees. 4. Use wallet cashback for instant discounts. 5. Subscribe to notifications so you never miss a flash sale.",
  },
  {
    title: "Real Estate on Multiverse City: Find Your Dream Home",
    date: "July 2026",
    content:
      "Buying or renting a property has never been easier. Browse verified listings with virtual tours, detailed floor plans, and direct agent connectivity. Whether you are looking for a 1BHK in Mandi or a commercial space in Sundernagar, Multiverse City has you covered with 100+ active listings.",
  },
  {
    title: "Behind the Scenes: How We Verify Businesses",
    date: "July 2026",
    content:
      "Trust is everything. Every business on Multiverse City goes through a rigorous 5-step verification process — document validation, physical address verification, quality audit, background check, and continuous monitoring. Only the best make it to the platform.",
  },
]

const formatDate = (ts) => {
  if (!ts) return null
  const d = new Date(ts)
  if (Number.isNaN(d.getTime())) return null
  return d.toLocaleDateString("en-IN", { month: "long", year: "numeric" })
}

const BlogModal = ({ onClose }) => {
  const [blogs, setBlogs] = useState(null)

  useEffect(() => {
    let active = true
    getBlogs().then((b) => {
      if (active) setBlogs(b)
    })
    return () => {
      active = false
    }
  }, [])

  const posts = blogs && blogs.length ? blogs : FALLBACK_POSTS

  return (
    <Modal title="Blog" onClose={onClose}>
      <div className="space-y-8 text-white/60 text-sm leading-relaxed">
        <p>
          Welcome to the Multiverse City Blog — your source for updates, tips, and stories from the
          Multiverse City ecosystem.
        </p>
        {posts.map((post, idx) => {
          const date = formatDate(post.createdAt) || post.date
          return (
            <article
              key={post.id || idx}
              className="glass-card p-6 hover:border-primary/20 transition-all"
            >
              {date && (
                <div className="flex items-center gap-3 mb-3">
                  <span className="text-[10px] font-bold uppercase tracking-widest text-primary bg-primary/10 px-3 py-1 rounded-full">
                    {date}
                  </span>
                </div>
              )}
              <h3 className="text-lg font-bold text-white mb-2">{post.title}</h3>
              <p>{post.content}</p>
            </article>
          )
        })}
      </div>
    </Modal>
  )
}

export default BlogModal
