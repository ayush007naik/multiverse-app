import React, { useMemo, useRef } from "react"
import { Canvas, useFrame } from "@react-three/fiber"
import { RoundedBox, useTexture } from "@react-three/drei"
import * as THREE from "three"

const SCREEN_ASPECT = 11 / 14 // 1100 x 1400

// One phone: rounded body + glowing screen showing a real app screenshot.
function Phone({ texture, position, rotation, scale = 1, loadAll }) {
  const bodyW = 0.62 * scale
  const bodyH = bodyW / (11 / 14) * 1.12 // body slightly taller than screen
  const screenW = 0.58 * scale
  const screenH = screenW / SCREEN_ASPECT

  const grp = useRef()
  const speed = 0.4 + Math.random() * 0.4
  const phase = Math.random() * Math.PI * 2

  useFrame((state) => {
    if (!grp.current) return
    const t = state.clock.getElapsedTime()
    grp.current.position.y = position[1] + Math.sin(t * speed + phase) * 0.05
    grp.current.rotation.z = rotation[2] + Math.sin(t * speed * 0.6 + phase) * 0.02
  })

  return (
    <group ref={grp} position={position} rotation={rotation}>
      {/* Body */}
      <RoundedBox args={[bodyW, bodyH, 0.035]} radius={0.05} smoothness={4} position={[0, 0, 0]}>
        <meshStandardMaterial color="#0b0b0d" metalness={0.9} roughness={0.35} envMapIntensity={0.4} />
      </RoundedBox>
      {/* Screen */}
      <mesh position={[0, 0, 0.02]}>
        <planeGeometry args={[screenW, screenH]} />
        <meshBasicMaterial map={texture} toneMapped={false} />
      </mesh>
      {/* Screen edge highlight */}
      <mesh position={[0, 0, 0.031]}>
        <planeGeometry args={[screenW, screenH]} />
        <meshBasicMaterial color="#ffffff" transparent opacity={0.06} blending={THREE.AdditiveBlending} depthWrite={false} />
      </mesh>
    </group>
  )
}

function Showcase({ mode }) {
  const textures = useTexture([
    "/assets/app_screens/marketplace.webp",
    "/assets/app_screens/movies.webp",
    "/assets/app_screens/appointments.webp",
    "/assets/app_screens/real_estate.webp",
  ])
  const [, marketplace, movies, appointments, realEstate] = textures

  return (
    <>
      <ambientLight intensity={0.5} />
      <directionalLight position={[4, 6, 5]} intensity={1.1} color="#ffa44d" />
      <directionalLight position={[-6, -3, -4]} intensity={0.5} color="#4d7fff" />
      <directionalLight position={[0, -4, -6]} intensity={0.35} color="#ffffff" />

      <group position={[0, 0, 0]}>
        {/* Front / primary: Marketplace */}
        <Phone texture={marketplace} position={[0, 0.05, 0.6]} rotation={[0, 0.05, -0.03]} scale={1} />
        {/* Left: Movies */}
        <Phone texture={movies} position={[-1.35, -0.3, 0.1]} rotation={[0.06, 0.5, -0.08]} scale={0.72} />
        {/* Right: Appointments */}
        <Phone texture={appointments} position={[1.35, -0.3, 0.1]} rotation={[0.06, -0.5, 0.08]} scale={0.72} />
        {/* Back center: Real Estate */}
        <Phone texture={realEstate} position={[0, 0.55, -0.75]} rotation={[0, 0.02, 0]} scale={0.85} />
      </group>
    </>
  )
}

function CameraRig({ children }) {
  const group = useRef()
  useFrame((state) => {
    if (!group.current) return
    // Subtle parallax toward pointer
    const x = (state.pointer.x || 0) * 0.12
    const y = (state.pointer.y || 0) * 0.08
    group.current.rotation.y = THREE.MathUtils.lerp(group.current.rotation.y, x, 0.05)
    group.current.rotation.x = THREE.MathUtils.lerp(group.current.rotation.x, y, 0.05)
  })
  return <group ref={group}>{children}</group>
}

export default function PhoneShowcase3D({ quality }) {
  const animate = quality?.mode === "full"
  const dpr = quality?.tier === "low" ? [1, 1] : [1, 1.5]

  return (
    <Canvas
      frameloop={animate ? "always" : "demand"}
      dpr={dpr}
      camera={{ position: [0, 0, 3.4], fov: 42 }}
      gl={{ antialias: false, powerPreference: "high-performance", alpha: true }}
      style={{ background: "transparent" }}
    >
      <CameraRig>
        <Showcase mode={quality?.mode} />
      </CameraRig>
    </Canvas>
  )
}
