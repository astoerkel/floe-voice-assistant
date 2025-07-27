import SwiftUI
import Combine

struct ParticleBackgroundView: View {
    let isVoiceActive: Bool
    let isAudioPlaying: Bool
    let audioLevel: CGFloat // 0.0 to 1.0
    
    @State private var particles: [Particle] = []
    @State private var animationTimer: Timer?
    @State private var touchLocation: CGPoint = .zero
    @State private var isTouching: Bool = false
    @State private var touchRippleRadius: CGFloat = 0.0
    @State private var globalPhase: CGFloat = 0.0
    
    @Environment(\.colorScheme) var colorScheme
    
    // Configuration
    private let particleCount = 120
    private let minSize: CGFloat = 1.0
    private let maxSize: CGFloat = 3.5
    private let baseSpeed: CGFloat = 0.3
    private let voiceActiveMultiplier: CGFloat = 3.0
    private let audioPlayingMultiplier: CGFloat = 2.0
    private let centerRadius: CGFloat = 180.0
    private let touchEffectRadius: CGFloat = 120.0
    
    var body: some View {
        Canvas { context, size in
            // Create gradient effect for particles
            let particleColor = getParticleColor()
            
            // Draw each particle with enhanced effects
            for particle in particles {
                var opacity = particle.opacity
                
                // Enhance opacity based on state
                if isVoiceActive {
                    opacity *= (0.8 + audioLevel * 0.4)
                } else if isAudioPlaying {
                    opacity *= (0.7 + sin(globalPhase + particle.phase) * 0.3)
                } else {
                    opacity *= 0.5
                }
                
                // Apply size variations based on audio level
                let sizeMultiplier: CGFloat = isVoiceActive ? (1.0 + audioLevel * 0.5) : 1.0
                let currentSize = particle.size * sizeMultiplier
                
                // Create gradient for each particle
                let gradient = Gradient(colors: [
                    particleColor.opacity(opacity),
                    particleColor.opacity(opacity * 0.3)
                ])
                
                context.fill(
                    Path(ellipseIn: CGRect(
                        x: particle.position.x - currentSize / 2,
                        y: particle.position.y - currentSize / 2,
                        width: currentSize,
                        height: currentSize
                    )),
                    with: .radialGradient(gradient, center: CGPoint(x: particle.position.x, y: particle.position.y), startRadius: 0, endRadius: currentSize / 2)
                )
            }
            
            // Add subtle glow effect during voice activity
            if isVoiceActive && audioLevel > 0.3 {
                let glowIntensity = audioLevel * 0.15
                let glowGradient = Gradient(colors: [
                    particleColor.opacity(glowIntensity),
                    particleColor.opacity(0)
                ])
                
                context.fill(
                    Path(ellipseIn: CGRect(
                        x: size.width / 2 - 200,
                        y: size.height / 2 - 200,
                        width: 400,
                        height: 400
                    )),
                    with: .radialGradient(glowGradient, center: CGPoint(x: size.width / 2, y: size.height / 2), startRadius: 50, endRadius: 200)
                )
            }
        }
        .onAppear {
            setupParticles()
            startAnimation()
        }
        .onDisappear {
            stopAnimation()
        }
        .animation(.easeInOut(duration: 0.5), value: isVoiceActive)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    touchLocation = value.location
                    if !isTouching {
                        isTouching = true
                        startTouchRipple()
                    }
                }
                .onEnded { _ in
                    isTouching = false
                    touchRippleRadius = 0.0
                }
        )
    }
    
    private func getParticleColor() -> Color {
        if colorScheme == .dark {
            // Beautiful colors for dark mode
            if isVoiceActive {
                return Color(red: 0.4, green: 0.8, blue: 1.0) // Bright blue
            } else if isAudioPlaying {
                return Color(red: 0.6, green: 0.4, blue: 1.0) // Purple
            } else {
                return Color(red: 0.8, green: 0.8, blue: 0.9) // Light gray-blue
            }
        } else {
            // Beautiful colors for light mode
            if isVoiceActive {
                return Color(red: 0.2, green: 0.5, blue: 0.9) // Deep blue
            } else if isAudioPlaying {
                return Color(red: 0.5, green: 0.3, blue: 0.8) // Deep purple
            } else {
                return Color(red: 0.3, green: 0.3, blue: 0.4) // Dark gray
            }
        }
    }
    
    private func setupParticles() {
        particles = (0..<particleCount).map { i in
            createRandomParticle(index: i)
        }
    }
    
    private func createRandomParticle(index: Int) -> Particle {
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height
        let centerX = screenWidth / 2
        let centerY = screenHeight / 2
        
        // Create particles in multiple layers for depth
        let layerIndex = index % 3
        let layerRadiusMultiplier: CGFloat = [0.6, 1.0, 1.3][layerIndex]
        
        // Create particles in a circular cluster around center
        let angle = CGFloat.random(in: 0...(2 * .pi))
        let radius = CGFloat.random(in: 0...centerRadius) * layerRadiusMultiplier
        
        // Vary size by layer for depth perception
        let sizeRange = layerIndex == 0 ? (minSize...minSize * 1.5) : 
                       layerIndex == 1 ? (minSize * 1.2...maxSize * 0.8) :
                       (maxSize * 0.7...maxSize)
        
        return Particle(
            position: CGPoint(
                x: centerX + cos(angle) * radius,
                y: centerY + sin(angle) * radius
            ),
            velocity: CGPoint(
                x: CGFloat.random(in: -baseSpeed...baseSpeed),
                y: CGFloat.random(in: -baseSpeed...baseSpeed)
            ),
            size: CGFloat.random(in: sizeRange),
            opacity: CGFloat.random(in: 0.3...0.8),
            originalCenter: CGPoint(x: centerX, y: centerY),
            phase: CGFloat.random(in: 0...(2 * .pi)),
            layer: layerIndex
        )
    }
    
    private func startAnimation() {
        animationTimer = Timer.scheduledTimer(withTimeInterval: 1/60, repeats: true) { _ in
            updateParticles()
            // Update global phase for smooth animations
            globalPhase += 0.05
            if globalPhase > 2 * .pi {
                globalPhase -= 2 * .pi
            }
        }
    }
    
    private func stopAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
    }
    
    private func startTouchRipple() {
        // Touch ripple disabled
    }
    
    private func updateParticles() {
        for i in 0..<particles.count {
            var particle = particles[i]
            
            // Base organic movement
            particle.position.x += particle.velocity.x
            particle.position.y += particle.velocity.y
            
            // Add subtle brownian motion
            let brownianIntensity: CGFloat = 0.02
            particle.velocity.x += CGFloat.random(in: -brownianIntensity...brownianIntensity)
            particle.velocity.y += CGFloat.random(in: -brownianIntensity...brownianIntensity)
            
            // Apply different effects based on state
            if isVoiceActive {
                // Create reactive movement based on audio level
                let vibrateIntensity = 2.0 + audioLevel * 8.0
                let angle = CGFloat.random(in: 0...(2 * .pi))
                
                // Radial expansion based on audio
                let expansionForce = audioLevel * 3.0
                let directionFromCenter = atan2(
                    particle.position.y - particle.originalCenter.y,
                    particle.position.x - particle.originalCenter.x
                )
                
                particle.position.x += cos(directionFromCenter) * expansionForce
                particle.position.y += sin(directionFromCenter) * expansionForce
                
                // Add vibration
                particle.position.x += cos(angle) * vibrateIntensity * CGFloat.random(in: 0.3...1.0)
                particle.position.y += sin(angle) * vibrateIntensity * CGFloat.random(in: 0.3...1.0)
                
                // Velocity boost with damping
                let velocityBoost = 1.0 + (audioLevel * (voiceActiveMultiplier - 1.0))
                particle.velocity.x *= velocityBoost
                particle.velocity.y *= velocityBoost
                
            } else if isAudioPlaying {
                // Smooth wave-like motion during AI response
                let waveAmplitude = 2.0 + sin(globalPhase + particle.phase) * 1.5
                let waveSpeed = 0.1
                
                particle.position.x += cos(globalPhase * waveSpeed + particle.phase) * waveAmplitude
                particle.position.y += sin(globalPhase * waveSpeed + particle.phase * 1.2) * waveAmplitude
                
                // Gentle velocity modulation
                let velocityMod = 1.0 + sin(globalPhase + particle.phase) * 0.3
                particle.velocity.x *= velocityMod
                particle.velocity.y *= velocityMod
            }
            
            // Apply touch effects
            if isTouching {
                let distanceFromTouch = sqrt(
                    pow(particle.position.x - touchLocation.x, 2) +
                    pow(particle.position.y - touchLocation.y, 2)
                )
                
                if distanceFromTouch < touchEffectRadius {
                    // Push particles away from touch with force inversely proportional to distance
                    let pushForce = (touchEffectRadius - distanceFromTouch) / touchEffectRadius * 8.0
                    let directionX = (particle.position.x - touchLocation.x) / distanceFromTouch
                    let directionY = (particle.position.y - touchLocation.y) / distanceFromTouch
                    
                    particle.position.x += directionX * pushForce
                    particle.position.y += directionY * pushForce
                    
                    // Add velocity in push direction
                    particle.velocity.x += directionX * pushForce * 0.1
                    particle.velocity.y += directionY * pushForce * 0.1
                }
            }
            
            // Ensure particles don't drift too far from center
            let distanceFromCenter = sqrt(
                pow(particle.position.x - particle.originalCenter.x, 2) +
                pow(particle.position.y - particle.originalCenter.y, 2)
            )
            
            if distanceFromCenter > centerRadius {
                // Pull back towards center
                let pullForce: CGFloat = 0.08
                let directionX = (particle.originalCenter.x - particle.position.x) * pullForce
                let directionY = (particle.originalCenter.y - particle.position.y) * pullForce
                particle.position.x += directionX
                particle.position.y += directionY
            }
            
            // Gentle drift back towards center (stronger when not touching)
            let driftForce: CGFloat = isTouching ? 0.005 : 0.02
            let directionX = (particle.originalCenter.x - particle.position.x) * driftForce
            let directionY = (particle.originalCenter.y - particle.position.y) * driftForce
            particle.position.x += directionX
            particle.position.y += directionY
            
            // Constrain velocity
            let maxVelocity = baseSpeed * 2
            particle.velocity.x = max(-maxVelocity, min(maxVelocity, particle.velocity.x))
            particle.velocity.y = max(-maxVelocity, min(maxVelocity, particle.velocity.y))
            
            particles[i] = particle
        }
    }
}

struct Particle {
    var position: CGPoint
    var velocity: CGPoint
    var size: CGFloat
    var opacity: CGFloat
    var originalCenter: CGPoint
    var phase: CGFloat
    var layer: Int
}

#Preview {
    ParticleBackgroundView(isVoiceActive: false, isAudioPlaying: false, audioLevel: 0.0)
        .background(Color.black)
}