import Foundation

struct ReflectionQuestion: Identifiable, Codable, Equatable {
  let id: Int
  let lens: ReflectionLens
  let eyebrow: String
  let text: String
  let mascot: String

  static let all: [Self] = [
    .init(
      id: 1, lens: .best, eyebrow: "IN 10 YEARS", text: "Will you be glad you did it?",
      mascot: "MascotBestCase1"),
    .init(
      id: 2, lens: .best, eyebrow: "80-YEAR-OLD YOU", text: "Would they tell you to go for it?",
      mascot: "MascotBestCase2"),
    .init(
      id: 3, lens: .mixed, eyebrow: "IF NO ONE WAS WATCHING", text: "Would you still choose it?",
      mascot: "MascotMixedEmotions3"),
    .init(
      id: 4, lens: .mixed, eyebrow: "YOUR BEST FRIEND",
      text: "If they were in your shoes, would you tell them to do it?",
      mascot: "MascotMixedEmotions1"),
    .init(
      id: 5, lens: .worst, eyebrow: "IF IT GOES WRONG", text: "Could you live with it?",
      mascot: "MascotWorstCase1"),
    .init(
      id: 6, lens: .worst, eyebrow: "IF IT FAILS", text: "Would you still want the experience?",
      mascot: "MascotWorstCase3"),
  ]
}
