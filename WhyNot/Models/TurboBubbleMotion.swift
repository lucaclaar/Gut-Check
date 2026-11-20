import Foundation
import CoreGraphics

struct TurboBubbleMotion {
  let size: CGSize
  let diameter: CGFloat
  private(set) var centers: [CGPoint]

  private let bounds: CGRect
  private let anchors: [CGPoint]
  private let radius: CGFloat
  private var velocities: [CGVector]
  private var lastTime: TimeInterval?

  init(size: CGSize, count: Int, ringAllowance: CGFloat) {
    self.size = size
    let mascotSpace = min(44, size.height * 0.22)
    let bounds = CGRect(x: 0, y: mascotSpace, width: size.width, height: size.height - mascotSpace)
    self.bounds = bounds
    let rows = max(1, (count + 1) / 2)
    let gap: CGFloat = 10
    let outerDiameter = max(0, min(146, bounds.width * 0.43,
      (bounds.height - gap * CGFloat(rows - 1) - 12) / CGFloat(rows)))
    diameter = max(0, outerDiameter - ringAllowance)
    radius = outerDiameter / 2

    let step = outerDiameter + gap
    let anchors: [CGPoint] = (0..<count).map { slot in
      let row = slot / 2
      let y = bounds.midY + (CGFloat(row) - CGFloat(rows - 1) / 2) * step
      if count.isMultiple(of: 2) == false && slot == count - 1 {
        return CGPoint(x: bounds.midX, y: y)
      }
      let side: CGFloat = slot.isMultiple(of: 2) ? -1 : 1
      let stagger: CGFloat = row.isMultiple(of: 2) ? -3 : 3
      return CGPoint(x: bounds.midX + side * step / 2 + stagger, y: y)
    }
    self.anchors = anchors
    centers = anchors
    velocities = Array(repeating: .zero, count: count)
  }

  mutating func advance(to time: TimeInterval, activeSlots: [Int],
    drag: (slot: Int, target: CGPoint)?, reduceMotion: Bool) {
    let delta = min(1.0 / 30, max(0, time - (lastTime ?? time)))
    lastTime = time
    if reduceMotion && drag == nil {
      for slot in activeSlots {
        centers[slot] = anchors[slot]
        velocities[slot] = .zero
      }
      return
    }
    guard delta > 0 else { return }
    let previousCenters = centers
    for slot in activeSlots {
      let phase = Double(slot) * 2.15
      let drift: CGFloat = reduceMotion ? 0 : min(5.5, radius * 0.12)
      var target = CGPoint(x: anchors[slot].x + sin(time * 0.95 + phase) * drift,
        y: anchors[slot].y + cos(time * 1.10 + phase) * drift)
      let isDragged = drag?.slot == slot
      if let drag, isDragged { target = bounded(drag.target) }
      let stiffness: CGFloat = isDragged ? 85 : 18
      let damping = exp(-(isDragged ? 12.0 : 6.0) * delta)
      let dx = (velocities[slot].dx + (target.x - centers[slot].x) * stiffness * delta) * damping
      let dy = (velocities[slot].dy + (target.y - centers[slot].y) * stiffness * delta) * damping
      let speedLimit = 250 / max(250, hypot(dx, dy))
      velocities[slot] = CGVector(dx: dx * speedLimit, dy: dy * speedLimit)
      centers[slot].x += velocities[slot].dx * delta
      centers[slot].y += velocities[slot].dy * delta
      constrain(slot)
    }

    // Correct contacts using the outside edge of the progress ring.
    for _ in 0..<6 {
      for (index, first) in activeSlots.enumerated() {
        for second in activeSlots.dropFirst(index + 1) {
          resolveContact(first, second, bounce: reduceMotion ? 0 : 0.17)
        }
      }
      for slot in activeSlots { constrain(slot) }
    }
    // Keep a valid frame if several bubbles are squeezed against a wall at once.
    for (index, first) in activeSlots.enumerated() {
      for second in activeSlots.dropFirst(index + 1) {
        if hypot(centers[second].x - centers[first].x, centers[second].y - centers[first].y) < 2 * radius {
          centers = previousCenters
          velocities = Array(repeating: .zero, count: centers.count)
          return
        }
      }
    }
  }

  private mutating func resolveContact(_ first: Int, _ second: Int, bounce: CGFloat) {
    let dx = centers[second].x - centers[first].x
    let dy = centers[second].y - centers[first].y
    let distance = hypot(dx, dy)
    let overlap = 2 * radius + 0.5 - distance
    guard overlap > 0 else { return }
    let nx = distance == 0 ? 1 : dx / distance
    let ny = distance == 0 ? 0 : dy / distance
    let correction = overlap / 2
    centers[first].x -= nx * correction
    centers[first].y -= ny * correction
    centers[second].x += nx * correction
    centers[second].y += ny * correction

    let closingSpeed = (velocities[first].dx - velocities[second].dx) * nx
      + (velocities[first].dy - velocities[second].dy) * ny
    guard closingSpeed > 0 else { return }
    let impulse = (1 + bounce) * closingSpeed / 2
    velocities[first].dx -= impulse * nx
    velocities[first].dy -= impulse * ny
    velocities[second].dx += impulse * nx
    velocities[second].dy += impulse * ny
  }

  private func bounded(_ point: CGPoint) -> CGPoint {
    CGPoint(x: min(max(point.x, bounds.minX + radius), bounds.maxX - radius),
      y: min(max(point.y, bounds.minY + radius), bounds.maxY - radius))
  }

  private mutating func constrain(_ slot: Int) {
    let point = bounded(centers[slot])
    if point.x != centers[slot].x { velocities[slot].dx = 0 }
    if point.y != centers[slot].y { velocities[slot].dy = 0 }
    centers[slot] = point
  }
}
