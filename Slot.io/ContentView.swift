import SwiftUI
import AVFoundation

class GameViewModel: ObservableObject {
    // MARK: - Basic Variables
    @Published var balance: Int = UserDefaults.standard.integer(forKey: "balance") == 0 ? 1000 : UserDefaults.standard.integer(forKey: "balance")
    @Published var highscore: Int = UserDefaults.standard.integer(forKey: "highscore")
    @Published var lastClaimDate: Date = UserDefaults.standard.object(forKey: "lastClaimDate") as? Date ?? Date.distantPast
    @Published var dailyStreak: Int = UserDefaults.standard.integer(forKey: "dailyStreak")

    // MARK: - Game State
    @Published var slotResults: [[Int]] = [[-1], [-1, -1], [-1, -1, -1], [-1, -1, -1, -1], [-1, -1, -1, -1, -1]]
    @Published var bonusAmount = 0
    @Published var timeUntilNextBonus: String = ""
    @Published var gameOverMessage: String? = nil
    
    // MARK: - Slot Machine Configurations
    let slotNames = ["Poor Man's Slot", "Budget Slot", "Standard Slot", "Expensive Slot", "VIP Slot"]
    let slotCosts = [1, 50, 100, 250, 500]
    let slotChances = [0.5, 0.4, 0.3, 0.2, 0.1]
    let slotDigits = [1, 2, 3, 4, 5]

    // MARK: - Settings
    @Published var soundEnabled: Bool = UserDefaults.standard.bool(forKey: "soundEnabled")
    @Published var soundVolume: Float = UserDefaults.standard.float(forKey: "soundVolume")

    // MARK: - Sound Effects
    let spinSound = Bundle.main.path(forResource: "spin", ofType: "wav")
    let winSound = Bundle.main.path(forResource: "win", ofType: "wav")
    let loseSound = Bundle.main.path(forResource: "lose", ofType: "wav")

    // MARK: - Initialize & Update Timer
    init() {
        updateTimeUntilBonus()
    }

    // MARK: - Spin Slot
    func spinSlot(index: Int, completion: @escaping (_ didWin: Bool, _ prizeAmount: Int) -> Void) {
        guard balance >= slotCosts[index] else { return }
        balance -= slotCosts[index]
        saveGameData()
        playSound(sound: spinSound)

        DispatchQueue.global().async {
            let finalResult = (1...self.slotDigits[index]).map { _ in Int.random(in: 1...9) }

            for _ in 0..<20 {
                DispatchQueue.main.async {
                    self.slotResults[index] = (1...self.slotDigits[index]).map { _ in Int.random(in: 1...9) }
                }
                usleep(50000)
            }

            for i in finalResult.indices {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.2) {
                    self.slotResults[index][i] = finalResult[i]
                }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + Double(finalResult.count) * 0.2 + 0.5) {
                let prizeAmount = Int(finalResult.map { String($0) }.joined()) ?? 0
                let didWin = Double.random(in: 0...1) < self.slotChances[index]

                if didWin {
                    self.balance += prizeAmount
                    self.updateHighscore()
                    self.playSound(sound: self.winSound)
                } else {
                    self.playSound(sound: self.loseSound)
                }

                if self.balance <= 0 {
                    self.balance = 0
                    self.gameOverMessage = "You have succumbed to your gambling addiction, now you have to wait until you get another daily bonus :("
                }

                self.saveGameData()
                completion(didWin, didWin ? prizeAmount : 0)
            }
        }
    }

    // MARK: - Can Claim Daily Bonus?
    func canClaimBonus() -> Bool {
        return Calendar.current.isDateInToday(lastClaimDate) == false
    }

    // MARK: - Claim Daily Bonus
    func claimDailyBonus() {
        let baseBonus = 100
        let streakBonus = min(dailyStreak * 50, 500)
        bonusAmount = baseBonus + streakBonus

        balance += bonusAmount
        dailyStreak += 1
        lastClaimDate = Date()

        saveGameData()
    }

    // MARK: - Update Highscore
    func updateHighscore() {
        if balance > highscore {
            highscore = balance
            UserDefaults.standard.set(highscore, forKey: "highscore")
        }
    }

    // MARK: - Update Bonus Timer
    func updateTimeUntilBonus() {
        let now = Date()
        let nextBonusTime = Calendar.current.startOfDay(for: lastClaimDate).addingTimeInterval(86400)
        let timeLeft = max(nextBonusTime.timeIntervalSince(now), 0)

        let hours = Int(timeLeft) / 3600
        let minutes = (Int(timeLeft) % 3600) / 60
        let seconds = Int(timeLeft) % 60

        DispatchQueue.main.async {
            self.timeUntilNextBonus = String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        }

        if timeLeft > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self.updateTimeUntilBonus()
            }
        }
    }

    // MARK: - Play Sound
    func playSound(sound: String?) {
        guard let sound = sound, soundEnabled else { return }
        
        var soundID: SystemSoundID = 0
        AudioServicesCreateSystemSoundID(URL(fileURLWithPath: sound) as CFURL, &soundID)
        AudioServicesPlaySystemSoundWithCompletion(soundID) {
            AudioServicesSetProperty(kAudioServicesPropertyIsUISound, UInt32(MemoryLayout.size(ofValue: soundID)), &soundID, UInt32(MemoryLayout.size(ofValue: self.soundVolume)), &self.soundVolume)
        }
    }

    // MARK: - Toggle Sound
    func toggleSound() {
        soundEnabled.toggle()
        UserDefaults.standard.set(soundEnabled, forKey: "soundEnabled")
    }

    // MARK: - Reset Highscore
    func resetHighscore() {
        highscore = 0
        UserDefaults.standard.set(highscore, forKey: "highscore")
    }

    // MARK: - Save Game Data
    private func saveGameData() {
        UserDefaults.standard.set(balance, forKey: "balance")
        UserDefaults.standard.set(highscore, forKey: "highscore")
        UserDefaults.standard.set(dailyStreak, forKey: "dailyStreak")
        UserDefaults.standard.set(lastClaimDate, forKey: "lastClaimDate")
    }
}

struct HomeView: View {
    @EnvironmentObject var viewModel: GameViewModel
    @State private var showInfoAlert = false

    var body: some View {
        NavigationStack {
            ZStack {
                // MARK: - Background Gradient
                LinearGradient(gradient: Gradient(colors: [Color.purple.opacity(0.8), Color.black]), startPoint: .top, endPoint: .bottom)
                    .edgesIgnoringSafeArea(.all)

                VStack(spacing: 30) {
                    // MARK: - App Title
                    Text("🎰 Slot.io")
                        .font(.largeTitle)
                        .bold()
                        .foregroundColor(.white)
                        .shadow(radius: 5)
                        .padding(.top, 40)

                    // MARK: - Balance & Highscore
                    HStack(spacing: 50) {
                        BalanceView(title: "Balance", amount: viewModel.balance, color: .green)
                        BalanceView(title: "Highscore", amount: viewModel.highscore, color: .yellow)
                    }

                    Spacer()

                    // MARK: - Navigation Buttons
                    VStack(spacing: 20) {
                        NavigationLink(destination: SlotMachineView()) {
                            HomeButton(title: "🎰 Play Slots", color: .blue)
                        }

                        NavigationLink(destination: DailyBonusView()) {
                            HomeButton(title: "🎁 Daily Bonus", color: .green)
                        }

                        NavigationLink(destination: LeaderboardView()) {
                            HomeButton(title: "🏆 Leaderboard", color: .yellow)
                        }

                        NavigationLink(destination: SettingsView()) {
                            HomeButton(title: "⚙️ Settings", color: .gray)
                        }
                    }

                    Spacer()
                }
                .padding()
            }
            .navigationBarItems(
                leading: Button(action: {
                    showInfoAlert = true
                }) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.white)
                },
                trailing: Button(action: shareGame) {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(.white)
                }
            )
            .alert("About Slot.io", isPresented: $showInfoAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Slot.io is a fun slot machine game. Enjoy and play responsibly!")
            }
        }
    }

    // MARK: - Share Function
    private func shareGame() {
        let message = "I'm playing Slot.io and my balance is $\(viewModel.balance)! Try it out!"
        let activityVC = UIActivityViewController(activityItems: [message], applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(activityVC, animated: true, completion: nil)
        }
    }
}

// MARK: - BalanceView
struct BalanceView: View {
    @EnvironmentObject var viewModel: GameViewModel

    var title: String
    var amount: Int
    var color: Color

    var body: some View {
        VStack {
            Text(title)
                .font(.subheadline)
                .bold()
                .foregroundColor(.white)
            Text("$\(amount)")
                .font(.title)
                .bold()
                .foregroundColor(color)
                .shadow(radius: 5)
        }
    }
}

// MARK: - Home Button
struct HomeButton: View {
    let title: String
    let color: Color
    
    var body: some View {
        Text(title)
            .frame(maxWidth: .infinity, minHeight: 60)
            .background(color.opacity(0.8))
            .foregroundColor(.white)
            .font(.title2)
            .bold()
            .clipShape(RoundedRectangle(cornerRadius: 15))
            .shadow(radius: 5)
            .padding(.horizontal, 20)
    }
}

// MARK: - SlotMachineView
struct SlotMachineView: View {
    @EnvironmentObject var viewModel: GameViewModel
    
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color.black, Color.purple.opacity(0.8)], startPoint: .top, endPoint: .bottom)
                .edgesIgnoringSafeArea(.all)

            VStack(spacing: 20) {
                Text("🎰 Select Your Slot Machine")
                    .font(.largeTitle)
                    .bold()
                    .foregroundColor(.white)
                    .shadow(radius: 5)

                ForEach(0..<5) { index in
                    NavigationLink(destination: slotMachineView(for: index)) {
                        Text(viewModel.slotNames[index])
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(LinearGradient(colors: [Color.blue.opacity(0.9), Color.purple.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .foregroundColor(.white)
                            .font(.title2)
                            .bold()
                            .clipShape(RoundedRectangle(cornerRadius: 15))
                            .shadow(color: Color.white.opacity(0.4), radius: 5, x: 0, y: 0)
                            .padding(.horizontal, 20)
                    }
                }
            }
            .padding()
        }
    }
    
    @ViewBuilder
    private func slotMachineView(for index: Int) -> some View {
        switch index {
        case 0:
            PoorMansSlotView()
        case 1:
            BudgetSlotView()
        case 2:
            StandardSlotView()
        case 3:
            ExpensiveSlotView()
        case 4:
            VIPSlotView()
        default:
            Text("Invalid Slot Machine")
        }
    }
}

// MARK: - PoorMansSlotView
struct PoorMansSlotView: View {
    @EnvironmentObject var viewModel: GameViewModel
    @State private var isSpinning = false
    @State private var resultMessage: String?

    var body: some View {
        VStack(spacing: 15) {
            Text("🪵 Poor Man’s Slot 🪵")
                .font(.title)
                .foregroundColor(.brown)

            Text("Balance: $\(viewModel.balance)")
                .font(.headline)
                .foregroundColor(.gray)

            HStack {
                ForEach(viewModel.slotResults[0], id: \.self) { number in
                    Text("\(number == -1 ? "?" : "\(number)")")
                        .font(.largeTitle)
                        .frame(width: 50, height: 50)
                        .background(Color.brown.opacity(0.7))
                        .cornerRadius(5)
                        .foregroundColor(.white)
                }
            }

            Button(action: spinSlot) {
                Text("Spin for $\(viewModel.slotCosts[0])")
                    .padding()
                    .background(Color.brown)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .disabled(isSpinning)
        }
        .padding()
        .background(Color.black.opacity(0.1))
        .cornerRadius(10)
    }
    
    // Extracted text logic for better performance
    private func slotNumberText(for number: Int) -> String {
        return number == -1 ? "?" : "\(number)"
    }

    func spinSlot() {
        guard viewModel.balance >= viewModel.slotCosts[0] else {
            resultMessage = "Not enough money!"
            return
        }
        isSpinning = true
        viewModel.spinSlot(index: 0) { didWin, prize in
            isSpinning = false
            resultMessage = didWin ? "You won $\(prize)!" : "You lost!"
        }
    }
}

// MARK: - BudgetSlotView
struct BudgetSlotView: View {
    @EnvironmentObject var viewModel: GameViewModel
    @State private var isSpinning = false
    @State private var resultMessage: String?

    var body: some View {
        VStack(spacing: 15) {
            Text("🎮 Budget Slot 🎮")
                .font(.title)
                .foregroundColor(.green)

            Text("Balance: $\(viewModel.balance)")
                .font(.headline)
                .foregroundColor(.white)

            HStack {
                ForEach(viewModel.slotResults[1], id: \.self) { number in
                    Text("\(number == -1 ? "?" : "\(number)")")
                        .font(.largeTitle)
                        .frame(width: 50, height: 50)
                        .background(Color.blue)
                        .cornerRadius(8)
                        .foregroundColor(.white)
                }
            }

            Button(action: spinSlot) {
                Text("Spin for $\(viewModel.slotCosts[1])")
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.black)
                    .cornerRadius(10)
            }
            .disabled(isSpinning)
        }
        .padding()
        .background(Color.black.opacity(0.9))
        .cornerRadius(10)
    }
    
    // Extracted text logic for better performance
    private func slotNumberText(for number: Int) -> String {
        return number == -1 ? "?" : "\(number)"
    }

    func spinSlot() {
        guard viewModel.balance >= viewModel.slotCosts[1] else {
            resultMessage = "Not enough money!"
            return
        }
        isSpinning = true
        viewModel.spinSlot(index: 1) { didWin, prize in
            isSpinning = false
            resultMessage = didWin ? "You won $\(prize)!" : "You lost!"
        }
    }
}

// MARK: - StandardSlotView
struct StandardSlotView: View {
    @EnvironmentObject var viewModel: GameViewModel
    @State private var isSpinning = false
    @State private var resultMessage: String?

    var body: some View {
        VStack(spacing: 15) {
            Text("🎰 Standard Slot 🎰")
                .font(.title)
                .foregroundColor(.yellow)

            Text("Balance: $\(viewModel.balance)")
                .font(.headline)
                .foregroundColor(.white)

            HStack {
                ForEach(viewModel.slotResults[2], id: \.self) { number in
                    Text("\(number == -1 ? "?" : "\(number)")")
                        .font(.largeTitle)
                        .frame(width: 60, height: 60)
                        .background(Color.red)
                        .cornerRadius(10)
                        .foregroundColor(.white)
                }
            }

            Button(action: spinSlot) {
                Text("Spin for $\(viewModel.slotCosts[2])")
                    .padding()
                    .background(Color.yellow)
                    .foregroundColor(.black)
                    .cornerRadius(10)
            }
            .disabled(isSpinning)
        }
        .padding()
        .background(Color.red.opacity(0.8))
        .cornerRadius(10)
    }
    
    // Extracted text logic for better performance
    private func slotNumberText(for number: Int) -> String {
        return number == -1 ? "?" : "\(number)"
    }

    func spinSlot() {
        guard viewModel.balance >= viewModel.slotCosts[2] else {
            resultMessage = "Not enough money!"
            return
        }
        isSpinning = true
        viewModel.spinSlot(index: 2) { didWin, prize in
            isSpinning = false
            resultMessage = didWin ? "You won $\(prize)!" : "You lost!"
        }
    }
}

// MARK: - ExpensiveSlotView
struct ExpensiveSlotView: View {
    @EnvironmentObject var viewModel: GameViewModel
    @State private var isSpinning = false
    @State private var resultMessage: String?

    var body: some View {
        VStack(spacing: 15) {
            Text("💰 Expensive Slot 💰")
                .font(.title)
                .foregroundColor(.yellow)

            Text("Balance: $\(viewModel.balance)")
                .font(.headline)
                .foregroundColor(.white)

            HStack {
                ForEach(viewModel.slotResults[3], id: \.self) { number in
                    Text(slotNumberText(for: number))
                        .font(.largeTitle)
                        .frame(width: 70, height: 70)
                        .background(Color.yellow) // Gold replacement
                        .cornerRadius(12)
                        .foregroundColor(.black)
                }
            }

            if let resultMessage = resultMessage {
                Text(resultMessage)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(10)
            }

            Button(action: spinSlot) {
                Text("Spin for $\(viewModel.slotCosts[3])")
                    .padding()
                    .background(Color.yellow) // Gold replacement
                    .foregroundColor(.black)
                    .cornerRadius(10)
            }
            .disabled(isSpinning)
        }
        .padding()
        .background(Color.black.opacity(0.8))
        .cornerRadius(10)
    }

    // Extracted text logic for better performance
    private func slotNumberText(for number: Int) -> String {
        return number == -1 ? "?" : "\(number)"
    }

    func spinSlot() {
        guard viewModel.balance >= viewModel.slotCosts[3] else {
            resultMessage = "Not enough money!"
            return
        }
        isSpinning = true
        resultMessage = nil

        viewModel.spinSlot(index: 3) { didWin, prize in
            DispatchQueue.main.async {
                isSpinning = false
                resultMessage = didWin ? "You won $\(prize)!" : "You lost!"
            }
        }
    }
}

// MARK: - VIPSlotView
struct VIPSlotView: View {
    @EnvironmentObject var viewModel: GameViewModel
    @State private var isSpinning = false
    @State private var resultMessage: String?

    var body: some View {
        VStack(spacing: 15) {
            Text("🚀 VIP Slot 🚀")
                .font(.title)
                .foregroundColor(.blue)

            Text("Balance: $\(viewModel.balance)")
                .font(.headline)
                .foregroundColor(.cyan)

            HStack {
                ForEach(viewModel.slotResults[4], id: \.self) { number in
                    Text("\(number == -1 ? "?" : "\(number)")")
                        .font(.largeTitle)
                        .frame(width: 75, height: 75)
                        .background(Color.cyan)
                        .cornerRadius(15)
                        .foregroundColor(.black)
                }
            }

            Button(action: spinSlot) {
                Text("Spin for $\(viewModel.slotCosts[4])")
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .disabled(isSpinning)
        }
        .padding()
        .background(Color.black.opacity(0.9))
        .cornerRadius(10)
    }
    
    // Extracted text logic for better performance
    private func slotNumberText(for number: Int) -> String {
        return number == -1 ? "?" : "\(number)"
    }
    
    func spinSlot() {
        guard viewModel.balance >= viewModel.slotCosts[4] else {
            resultMessage = "Not enough money!"
            return
        }
        isSpinning = true
        viewModel.spinSlot(index: 4) { didWin, prize in
            isSpinning = false
            resultMessage = didWin ? "You won $\(prize)!" : "You lost!"
        }
    }
}

// MARK: - DailyBonusView
struct DailyBonusView: View {
    @EnvironmentObject var viewModel: GameViewModel
    @State private var showBonusPopup = false

    var body: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: [Color.orange.opacity(0.8), Color.red]), startPoint: .top, endPoint: .bottom)
                .edgesIgnoringSafeArea(.all)

            VStack(spacing: 30) {
                Text("🎁 Daily Bonus")
                    .font(.largeTitle)
                    .bold()
                    .foregroundColor(.white)
                    .shadow(radius: 5)

                Text("Balance: $\(viewModel.balance)")
                    .font(.title2)
                    .bold()
                    .foregroundColor(.green)

                if viewModel.canClaimBonus() {
                    Button(action: {
                        viewModel.claimDailyBonus()
                        showBonusPopup = true
                    }) {
                        Text("Claim Your Bonus!")
                            .font(.title)
                            .bold()
                            .padding()
                            .frame(width: 250)
                            .background(Color.green)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 15))
                            .shadow(radius: 5)
                    }
                } else {
                    Text("Next Bonus: \(viewModel.timeUntilNextBonus)")
                        .font(.title2)
                        .foregroundColor(.white)
                        .padding()
                }
            }
            .padding()
        }
        .alert(isPresented: $showBonusPopup) {
            Alert(title: Text("🎉 Daily Bonus!"), message: Text("You received $\(viewModel.bonusAmount)"), dismissButton: .default(Text("Awesome!")))
        }
    }
}

// MARK: - LeaderboardView
struct LeaderboardView: View {
    @EnvironmentObject var viewModel: GameViewModel

    var body: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: [Color.blue.opacity(0.8), Color.purple]), startPoint: .top, endPoint: .bottom)
                .edgesIgnoringSafeArea(.all)

            VStack(spacing: 20) {
                Text("🏆 Leaderboard")
                    .font(.largeTitle)
                    .bold()
                    .foregroundColor(.white)
                    .shadow(radius: 5)

                // MARK: - Display Highscore
                VStack {
                    Text("Your Highscore:")
                        .font(.title2)
                        .foregroundColor(.white)
                    
                    Text("$\(viewModel.highscore)")
                        .font(.title)
                        .bold()
                        .foregroundColor(.yellow)
                        .shadow(radius: 5)
                }
                .padding()
                .background(Color.black.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 15))
                .shadow(radius: 5)

                Spacer()
            }
            .padding()
        }
    }
}

// MARK: - SettingsView
struct SettingsView: View {
    @State private var showResetHighscoreAlert = false
    @EnvironmentObject var viewModel: GameViewModel

    var body: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: [Color.gray.opacity(0.8), Color.black]), startPoint: .top, endPoint: .bottom)
                .edgesIgnoringSafeArea(.all)

            VStack(spacing: 20) {
                Text("⚙️ Settings")
                    .font(.largeTitle)
                    .bold()
                    .foregroundColor(.white)
                    .shadow(radius: 5)

                Toggle("Sound Effects", isOn: $viewModel.soundEnabled)
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
                    .padding()
                    .background(Color.black.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 15))
                    .shadow(radius: 5)

                VStack {
                    Text("Volume")
                        .font(.title2)
                        .foregroundColor(.white)

                    Slider(value: $viewModel.soundVolume, in: 0...1, step: 0.1)
                        .padding()
                        .accentColor(.blue)
                }

                Button(action: {
                    showResetHighscoreAlert = true
                }) {
                    Text("Reset Highscore")
                        .font(.title2)
                        .bold()
                        .padding()
                        .frame(width: 250)
                        .background(Color.red)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 15))
                        .shadow(radius: 5)
                }
                .alert("Are you sure you want to reset your highscore?", isPresented: $showResetHighscoreAlert) {
                    Button("Yes", role: .destructive) {
                        viewModel.resetHighscore()
                    }
                    Button("Cancel", role: .cancel) { }
                }
                .padding(.top, 20)

                Spacer()
            }
            .padding()
        }
    }
}
