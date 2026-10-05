import XCTest
@testable import RakuLLM

final class ConversationBranchingTests: XCTestCase {
    func testMessageVariants() {
        let msg = Message(
            conversationID: "conv-1",
            sequence: 1,
            role: .assistant,
            text: "First response variant"
        )

        XCTAssertEqual(msg.variants.count, 1)
        XCTAssertEqual(msg.activeVariant, 0)
        XCTAssertEqual(msg.activeText, "First response variant")

        // Regenerate -> appends new variant
        msg.appendVariant("Second regenerated variant")

        XCTAssertEqual(msg.variants.count, 2)
        XCTAssertEqual(msg.activeVariant, 1)
        XCTAssertEqual(msg.activeText, "Second regenerated variant")

        // Switch back to variant 0
        msg.activeVariant = 0
        XCTAssertEqual(msg.activeText, "First response variant")
    }

    func testUpdateActiveTextMaintainsVariants() {
        let msg = Message(
            conversationID: "conv-1",
            sequence: 1,
            role: .assistant,
            text: "Initial"
        )

        msg.updateActiveText("Updated chunk 1")
        XCTAssertEqual(msg.activeText, "Updated chunk 1")
        XCTAssertEqual(msg.variants[0], "Updated chunk 1")
    }

    func testConversationForkPointers() {
        let parentConv = Conversation(
            id: "parent-123",
            title: "Original Topic",
            providerKind: .anthropic,
            modelIdentifier: "claude-3-5-sonnet-20241022"
        )

        let forkedConv = Conversation(
            title: "Fork: Original Topic",
            providerKind: parentConv.providerKind,
            modelIdentifier: parentConv.modelIdentifier,
            forkedFromID: parentConv.id,
            forkedAtMessageID: "msg-456"
        )

        XCTAssertEqual(forkedConv.forkedFromID, "parent-123")
        XCTAssertEqual(forkedConv.forkedAtMessageID, "msg-456")
        XCTAssertEqual(forkedConv.title, "Fork: Original Topic")
    }
}
