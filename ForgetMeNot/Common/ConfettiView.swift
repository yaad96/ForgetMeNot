import SwiftUI

struct ConfettiView: View {
    @Binding var show: Bool
    let count: Int = 30

    @State private var animate: Bool = false

    var body: some View {
        ZStack {
            if show {
                // Celebration message
                VStack {
                    Spacer()
                    Text("🎉 All Tasks Complete! Happy Travels! 🎉")
                        .font(.title2.bold())
                        .foregroundColor(.green)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.black.opacity(0.7))
                        )
                    Spacer()
                }
                .zIndex(1)

                // Flying confetti
                ForEach(0..<count, id: \.self) { i in
                    ConfettiPiece(animate: animate, seed: i)
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.easeOut(duration: 1.4)) {
                animate = true
            }
            // Hide confetti and reset animation after 1.7 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.7) {
                show = false
                animate = false
            }
        }
    }
}

struct ConfettiPiece: View {
    var animate: Bool
    var seed: Int

    // Always deterministic and safe
    private var startX: CGFloat { CGFloat(seed * 12 % 280 - 140) }
    private var endY: CGFloat { CGFloat(500 + (seed * 43 % 120)) }
    private var color: Color {
        let colors: [Color] = [.red, .blue, .green, .yellow, .orange, .pink, .purple]
        return colors[seed % colors.count]
    }
    private var size: CGFloat { CGFloat(10 + (seed % 9)) }

    var body: some View {
        // All values are known at init
        Circle()
            .frame(width: size, height: size)
            .foregroundColor(color)
            .opacity(0.85)
            .position(x: UIScreen.main.bounds.midX + startX,
                      y: animate ? endY : -30)
            .animation(.easeOut(duration: 1.4).delay(Double(seed) * 0.03), value: animate)
    }
}

