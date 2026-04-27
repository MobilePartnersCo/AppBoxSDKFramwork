struct WebQueue<Element> {
    private var elements: [Element] = []

    mutating func enqueue(_ element: Element) {
        elements.append(element)
    }

    mutating func dequeue() -> Element? {
        elements.isEmpty ? nil : elements.removeFirst()
    }

    func peek() -> Element? {
        elements.first
    }
}
