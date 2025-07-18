import SwiftUI

struct ParticleBackgroundView: View {
    let isVoiceActive: Bool
    let isAudioPlaying: Bool
    
    @State private var particles: [Particle] = []
    @State private var animationTimer: Timer?
    @State private var touchLocation: CGPoint = .zero
    @State private var isTouching: Bool = false
    @State private var touchRippleRadius: CGFloat = 0.0
    
    // Configuration
    private let particleCount = 80
    private let minSize: CGFloat = 1.5
    private let maxSize: CGFloat = 4.0
    private let baseSpeed: CGFloat = 0.5
    private let voiceActiveMultiplier: CGFloat = 2.0
    private let audioPlayingMultiplier: CGFloat = 1.8
    private let centerRadius: CGFloat = 160.0
    private let touchEffectRadius: CGFloat = 100.0
    
    var body: some View {
        Canvas { context, size in
            // Draw each particle
            for particle in particles {
                let opacity = particle.opacity * (isVoiceActive ? 1.0 : 0.6)
                let color = Color.white.opacity(opacity)
                
                context.fill(
                    Path(ellipseIn: CGRect(
                        x: particle.position.x - particle.size / 2,
                        y: particle.position.y - particle.size / 2,
                        width: particle.size,
                        height: particle.size
                    )),
                    with: .color(color)
                )
            }
            
            // Touch ripple effect removed
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
    
    private func setupParticles() {
        particles = (0..<particleCount).map { _ in
            createRandomParticle()
        }
    }
    
    private func createRandomParticle() -> Particle {
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height
        let centerX = screenWidth / 2
        let centerY = screenHeight / 2
        
        // Create particles in a circular cluster around center
        let angle = CGFloat.random(in: 0...(2 * .pi))
        let radius = CGFloat.random(in: 0...centerRadius)
        
        return Particle(
            position: CGPoint(
                x: centerX + cos(angle) * radius,
                y: centerY + sin(angle) * radius
            ),
            velocity: CGPoint(
                x: CGFloat.random(in: -baseSpeed...baseSpeed),
                y: CGFloat.random(in: -baseSpeed...baseSpeed)
            ),
            size: CGFloat.random(in: minSize...maxSize),
            opacity: CGFloat.random(in: 0.4...0.9),
            originalCenter: CGPoint(x: centerX, y: centerY)
        )
    }
    
    private func startAnimation() {
        animationTimer = Timer.scheduledTimer(withTimeInterval: 1/60, repeats: true) { _ in
            updateParticles()
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
            
            // Always have base movement
            particle.position.x += particle.velocity.x
            particle.position.y += particle.velocity.y
            
            // Update velocity for continuous movement
            particle.velocity.x += CGFloat.random(in: -0.01...0.01)
            particle.velocity.y += CGFloat.random(in: -0.01...0.01)
            
            // Apply different effects based on state
            if isVoiceActive {
                // When voice is active, create vibration effect
                let vibrateIntensity: CGFloat = 6.0
                particle.position.x += CGFloat.random(in: -vibrateIntensity...vibrateIntensity)
                particle.position.y += CGFloat.random(in: -vibrateIntensity...vibrateIntensity)
                
                // Increase base velocity during voice input
                let velocityBoost = voiceActiveMultiplier
                particle.velocity.x *= velocityBoost
                particle.velocity.y *= velocityBoost
            } else if isAudioPlaying {
                // When audio is playing (AI responding), create gentle pulsing effect
                let pulseIntensity: CGFloat = 4.0
                particle.position.x += CGFloat.random(in: -pulseIntensity...pulseIntensity)
                particle.position.y += CGFloat.random(in: -pulseIntensity...pulseIntensity)
                
                // Moderate velocity boost during audio playback
                let velocityBoost = audioPlayingMultiplier
                particle.velocity.x *= velocityBoost
                particle.velocity.y *= velocityBoost
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
}

#Preview {
    ParticleBackgroundView(isVoiceActive: false, isAudioPlaying: false)
        .background(Color.black)
}